import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    @Published var currentLocation: CLLocation?
    @Published var currentHeading: CLHeading?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false

    var onCenterRequested: ((CLLocationCoordinate2D) -> Void)?
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onTrackingPoint: ((CLLocationCoordinate2D) -> Void)?  // fires every GPS point while tracking

    // Kalman filter state for smoothing
    private var kalmanLat: KalmanFilter = KalmanFilter()
    private var kalmanLon: KalmanFilter = KalmanFilter()
    private var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 3          // fire every 3 metres
        manager.headingFilter = 2           // fire every 2 degrees of heading change
        manager.activityType = .automotiveNavigation
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
        authorizationStatus = manager.authorizationStatus
    }

    func setup() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        default:
            break
        }
    }

    func centerOnUser() {
        if let loc = currentLocation {
            onCenterRequested?(loc.coordinate)
        } else {
            manager.startUpdatingLocation()
        }
    }

    func startTracking() {
        isTracking = true
        // Tightest possible settings while tracking
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 3
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func stopTracking() {
        isTracking = false
        // Relax accuracy when not tracking to save battery
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
    }

    // MARK: - Delegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { self.authorizationStatus = manager.authorizationStatus }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async { self.currentHeading = newHeading }
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        // Take all locations — process each one for smoothness
        for loc in locations {
            // Reject clearly bad readings
            guard loc.horizontalAccuracy > 0,
                  loc.horizontalAccuracy < 50 else { continue }

            // Reject points that are impossibly fast (GPS jump)
            if let last = lastLocation {
                let timeDelta = loc.timestamp.timeIntervalSince(last.timestamp)
                let distance  = loc.distance(from: last)
                let speed     = distance / max(timeDelta, 0.1)
                if speed > 80 { continue }  // > 80 m/s (~288 km/h) = GPS glitch
            }

            // Kalman smooth the coordinate
            kalmanLat.update(measurement: loc.coordinate.latitude,
                             accuracy: loc.horizontalAccuracy)
            kalmanLon.update(measurement: loc.coordinate.longitude,
                             accuracy: loc.horizontalAccuracy)

            let smoothedCoord = CLLocationCoordinate2D(
                latitude:  kalmanLat.value,
                longitude: kalmanLon.value
            )

            let smoothedLoc = CLLocation(
                coordinate: smoothedCoord,
                altitude: loc.altitude,
                horizontalAccuracy: loc.horizontalAccuracy,
                verticalAccuracy: loc.verticalAccuracy,
                course: loc.course,
                speed: loc.speed,
                timestamp: loc.timestamp
            )

            lastLocation = smoothedLoc

            DispatchQueue.main.async {
                let isFirst = self.currentLocation == nil
                self.currentLocation = smoothedLoc
                self.onLocationUpdate?(smoothedLoc)
                if isFirst { self.onCenterRequested?(smoothedCoord) }
                if self.isTracking { self.onTrackingPoint?(smoothedCoord) }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}

// MARK: - Kalman Filter
// Simple 1D Kalman filter for GPS coordinate smoothing.
// Reduces GPS jitter without adding latency.

class KalmanFilter {
    var value: Double = 0
    private var variance: Double = -1
    private let minAccuracy: Double = 1

    func update(measurement: Double, accuracy: Double) {
        let acc = max(accuracy, minAccuracy)
        if variance < 0 {
            // First measurement — initialise
            value = measurement
            variance = acc * acc
            return
        }
        // Predict: variance grows over time (we don't model velocity here)
        variance += 3.0  // process noise — how fast position can change

        // Update: weight new measurement by accuracy
        let gain = variance / (variance + acc * acc)
        value    = value + gain * (measurement - value)
        variance = (1 - gain) * variance
    }
}
