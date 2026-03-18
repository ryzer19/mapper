import Foundation
import CoreLocation
import MapKit
import SwiftUI

// MARK: - Models

/// A single continuous GPS segment driven in one session.
/// Points are added in real time as the user drives.
struct DrivenSegment: Codable, Identifiable {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var points: [CodableCoordinate] = []
    var isActive: Bool = true   // currently being driven
}

struct CodableCoordinate: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    init(_ coord: CLLocationCoordinate2D) {
        latitude  = coord.latitude
        longitude = coord.longitude
    }
}

// MARK: - Personalisation Models

/// Visual filter applied to the map view.
struct MapFilter: Equatable {
    var saturation: Double  = 1.0
    var hueRotation: Double = 0
    var contrast: Double    = 1.0
    var brightness: Double  = 0
    var grayscale: Double   = 0
}



enum LineColour: String, CaseIterable, Identifiable {
    case white   = "white"
    case blue    = "blue"
    case green   = "green"
    case coral   = "coral"
    case gold    = "gold"
    case purple  = "purple"
    case cyan    = "cyan"
    case magenta = "magenta"

    var id: String { rawValue }

    var label: String { rawValue.capitalized }

    var colour: UIColor {
        switch self {
        case .white:   return UIColor(white: 1.0, alpha: 1.0)
        case .blue:    return UIColor(red: 0.20, green: 0.60, blue: 1.00, alpha: 1.0)
        case .green:   return UIColor(red: 0.20, green: 0.90, blue: 0.50, alpha: 1.0)
        case .coral:   return UIColor(red: 1.00, green: 0.40, blue: 0.35, alpha: 1.0)
        case .gold:    return UIColor(red: 1.00, green: 0.80, blue: 0.20, alpha: 1.0)
        case .purple:  return UIColor(red: 0.70, green: 0.35, blue: 1.00, alpha: 1.0)
        case .cyan:    return UIColor(red: 0.00, green: 0.95, blue: 1.00, alpha: 1.0)
        case .magenta: return UIColor(red: 1.00, green: 0.08, blue: 0.65, alpha: 1.0)
        }
    }

    var swiftColour: Color {
        switch self {
        case .white:   return .white
        case .blue:    return Color(red: 0.20, green: 0.60, blue: 1.00)
        case .green:   return Color(red: 0.20, green: 0.90, blue: 0.50)
        case .coral:   return Color(red: 1.00, green: 0.40, blue: 0.35)
        case .gold:    return Color(red: 1.00, green: 0.80, blue: 0.20)
        case .purple:  return Color(red: 0.70, green: 0.35, blue: 1.00)
        case .cyan:    return Color(red: 0.00, green: 0.95, blue: 1.00)
        case .magenta: return Color(red: 1.00, green: 0.08, blue: 0.65)
        }
    }
}

// MARK: - UserStore

class UserStore: ObservableObject {

    @Published var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode") }
    }

    // MARK: - Map filters

    /// Dark mode: CartoDB dark tiles for standard, Tesla-style cool tint for satellite.
    /// Light mode: Apple native for standard, unmodified for satellite.
    func mapFilter(isSatellite: Bool) -> MapFilter {
        if isDarkMode {
            if isSatellite {
                // Full-colour aerial imagery tinted dark — subtle desaturation +
                // cool blue shift + slight brightness pull, like Tesla's night satellite.
                return MapFilter(saturation: 0.65, hueRotation: -8, contrast: 1.12, brightness: -0.08, grayscale: 0)
            } else {
                // CartoDB dark tiles handle the base look; leave them alone.
                return MapFilter()
            }
        } else {
            // Light mode — unfiltered in both cases.
            return MapFilter()
        }
    }

    /// Tile URL for the standard (non-satellite) map.
    /// Dark mode uses CartoDB dark tiles; light mode uses Apple native (empty = native).
    func resolvedTileURL() -> String {
        isDarkMode
            ? "https://cartodb-basemaps-a.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png"
            : ""
    }
    @Published var lineColour: LineColour {
        didSet { UserDefaults.standard.set(lineColour.rawValue, forKey: "lineColour") }
    }
    @Published var lineOpacity: Double {
        didSet { UserDefaults.standard.set(lineOpacity, forKey: "lineOpacity") }
    }
    @Published var pulseActive: Bool {
        didSet { UserDefaults.standard.set(pulseActive, forKey: "pulseActive") }
    }

    /// All segments ever driven — active one is last if isActive == true
    @Published var segments: [DrivenSegment] = [] { didSet { save() } }

    /// Simulation car avatar
    @Published var simCarPosition: CLLocationCoordinate2D? = nil
    @Published var simCarHeading: Double = 0

    // MARK: - Derived

    var activeSegment: DrivenSegment? { segments.last(where: { $0.isActive }) }

    var totalDrivenMiles: Double {
        var total = 0.0
        for seg in segments {
            let pts = seg.points
            guard pts.count >= 2 else { continue }
            for i in 1 ..< pts.count {
                let a = CLLocation(latitude: pts[i-1].latitude, longitude: pts[i-1].longitude)
                let b = CLLocation(latitude: pts[i].latitude,   longitude: pts[i].longitude)
                total += a.distance(from: b)
            }
        }
        return total / 1609.34
    }

    var totalSegments: Int { segments.filter { $0.points.count >= 2 }.count }

    // MARK: - Init

    init() {
        if UserDefaults.standard.object(forKey: "isDarkMode") == nil {
            self.isDarkMode = true
        } else {
            self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        }
        self.lineColour = LineColour(rawValue: UserDefaults.standard.string(forKey: "lineColour") ?? "") ?? .white
        self.lineOpacity = UserDefaults.standard.object(forKey: "lineOpacity") == nil
            ? 0.85
            : UserDefaults.standard.double(forKey: "lineOpacity")
        self.pulseActive = UserDefaults.standard.object(forKey: "pulseActive") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "pulseActive")
        load()
        // Mark any leftover active segments as inactive (app was killed mid-drive)
        for i in segments.indices where segments[i].isActive {
            segments[i].isActive = false
        }
    }

    // MARK: - Real-time tracking

    /// Called on every GPS fix while tracking — adds point to active segment
    func recordPoint(_ coordinate: CLLocationCoordinate2D) {
        if let idx = segments.indices.last(where: { segments[$0].isActive }) {
            segments[idx].points.append(CodableCoordinate(coordinate))
        }
    }

    func startSegment() {
        // Close any lingering active segments first
        for i in segments.indices where segments[i].isActive {
            segments[i].isActive = false
        }
        segments.append(DrivenSegment())
    }

    func endSegment() {
        for i in segments.indices where segments[i].isActive {
            segments[i].isActive = false
        }
        // Remove segments with < 2 points (never really drove)
        segments.removeAll { $0.points.count < 2 }
    }

    // MARK: - Simulation

    private var simCancelled = false

    func cancelSimulation() {
        simCancelled = true
        simCarPosition = nil
        // End the sim segment
        endSegment()
    }

    func simulateRoute(from origin: CLLocationCoordinate2D,
                       to destination: CLLocationCoordinate2D,
                       onStart: @escaping () -> Void,
                       onComplete: @escaping () -> Void,
                       onError: @escaping (String) -> Void) {
        simCancelled = false

        let req = MKDirections.Request()
        req.source      = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        req.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        req.transportType = .automobile
        req.requestsAlternateRoutes = false

        MKDirections(request: req).calculate { [weak self] resp, error in
            guard let self else { return }
            DispatchQueue.main.async {
                if let error = error {
                    onError("Route failed: \(error.localizedDescription)")
                    return
                }
                guard let route = resp?.routes.first else {
                    onError("No driveable route found.")
                    return
                }

                // Extract full route polyline
                let n = route.polyline.pointCount
                var coords = [CLLocationCoordinate2D](repeating: .init(), count: n)
                route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: n))

                // Start a new segment for this simulation
                self.startSegment()
                onStart()
                self.driveCoords(coords, index: 0, onComplete: {
                    self.endSegment()
                    self.simCarPosition = nil
                    onComplete()
                })
            }
        }
    }

    private func driveCoords(_ coords: [CLLocationCoordinate2D],
                              index: Int,
                              onComplete: @escaping () -> Void) {
        guard !simCancelled else { simCarPosition = nil; onComplete(); return }
        guard index < coords.count else { onComplete(); return }

        let coord = coords[index]

        // Update car avatar
        simCarPosition = coord
        if index + 1 < coords.count {
            simCarHeading = bearing(from: coord, to: coords[index + 1])
        }

        // Record point into active segment
        recordPoint(coord)

        // Delay proportional to real distance at ~50 km/h
        var delay: TimeInterval = 0.05
        if index + 1 < coords.count {
            let a = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let b = CLLocation(latitude: coords[index + 1].latitude,
                               longitude: coords[index + 1].longitude)
            let dist = a.distance(from: b)
            delay = max(0.025, min(dist / 14.0, 0.18))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.driveCoords(coords, index: index + 1, onComplete: onComplete)
        }
    }

    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude  * .pi / 180
        let lat2 = to.latitude    * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: - Reset

    func resetProgress() {
        segments = []
        simCarPosition = nil
    }

    // MARK: - Persistence

    private func save() {
        if let d = try? JSONEncoder().encode(segments) {
            UserDefaults.standard.set(d, forKey: "segments_v1")
        }
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: "segments_v1"),
           let s = try? JSONDecoder().decode([DrivenSegment].self, from: d) {
            segments = s
        }
    }
}
