import SwiftUI
import MapKit

// MARK: - Simulation state
enum SimulationMode { case idle, pickingPin, routing, running }

// MARK: - MapView

struct MapView: View {
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.colorScheme) var colorScheme

    @State private var jumpRegion: MKCoordinateRegion? = nil
    @State private var jumpID: UUID? = nil
    @State private var userCentered = false
    @State private var simMode: SimulationMode = .idle
    @State private var pinCoord: CLLocationCoordinate2D? = nil
    @State private var showRouting = false
    @State private var isSatellite = false
    @State private var routeError: String? = nil

    @Namespace private var glassNS

    var isDark: Bool { colorScheme == .dark }
    var currentFilter: MapFilter {
        userStore.mapFilter(isSatellite: isSatellite)
    }

    var body: some View {
        ZStack {
            TrackingMapView(
                segments: userStore.segments,
                jumpTo: jumpRegion,
                jumpID: jumpID,
                pinCoord: pinCoord,
                carPosition: userStore.simCarPosition,
                carHeading: userStore.simCarHeading,
                pickingPin: simMode == .pickingPin,
                isDark: isDark,
                isSatellite: isSatellite,
                resolvedTileURL: userStore.resolvedTileURL(),
                lineColour: userStore.lineColour,
                lineOpacity: userStore.lineOpacity,
                pulseActive: userStore.pulseActive,
                homeCoordinate: userStore.homeCoordinate,
                furthestCoordinate: userStore.furthestPointFromHome?.coordinate,
                onTap: { coord in
                    guard simMode == .pickingPin else { return }
                    pinCoord = coord
                    beginSimulation(to: coord)
                }
            )
            .ignoresSafeArea(.all)
            .grayscale(currentFilter.grayscale)
            .saturation(currentFilter.saturation)
            .hueRotation(.degrees(currentFilter.hueRotation))
            .contrast(currentFilter.contrast)
            .brightness(currentFilter.brightness)
            .animation(.easeInOut(duration: 0.4), value: currentFilter)

            VStack(spacing: 0) {
                Spacer().frame(height: 60)

                // Stats
                HStack {
                    StatsWidget(segments: userStore.totalSegments,
                                miles: userStore.totalDrivenMiles)
                    Spacer()
                }
                .padding(.horizontal, 16)

                // Furthest point card
                if let fp = userStore.furthestPointFromHome {
                    HStack(spacing: 8) {
                        Image(systemName: "house.fill")
                            .font(.caption2).foregroundStyle(.blue)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Image(systemName: "star.fill")
                            .font(.caption2).foregroundStyle(.orange)
                        Text(String(format: "%.1f mi from home", fp.distanceMiles))
                            .font(.caption.weight(.medium))
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16).padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Denied banner
                if locationManager.authorizationStatus == .denied ||
                   locationManager.authorizationStatus == .restricted {
                    HStack(spacing: 8) {
                        Image(systemName: "location.slash.fill").foregroundStyle(.red)
                            .font(.caption)
                        Text("Location access denied").font(.caption)
                        Spacer()
                        Button("Settings") {
                            if let u = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(u)
                            }
                        }
                        .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16).padding(.top, 8)
                }

                // Status pills
                statusPill
                    .animation(.spring(response: 0.3), value: simMode == .idle)

                if let err = routeError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.caption)
                        Text(err).font(.caption)
                        Spacer()
                        Button { withAnimation { routeError = nil } } label: {
                            Image(systemName: "xmark").font(.caption2)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16).padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                // Controls
                HStack(alignment: .bottom, spacing: 12) {
                    Button { showRouting = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Start").font(.system(size: 16, weight: .bold))
                        }
                        .padding(.horizontal, 24).padding(.vertical, 15)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .tint(.blue)

                    GlassEffectContainer(spacing: 0) {
                        Button { handleSimButton() } label: {
                            Image(systemName: simIcon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(simColour)
                                .frame(width: 50, height: 50)
                        }
                        .glassEffect(.regular.interactive(), in: Circle())
                        .glassEffectID("sim", in: glassNS)
                    }

                    Spacer()

                    GlassEffectContainer(spacing: 8) {
                        Button { locationManager.centerOnUser() } label: {
                            Image(systemName: userCentered ? "location.fill" : "location")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(userCentered ? .blue : .primary)
                                .frame(width: 50, height: 50)
                        }
                        .glassEffect(.regular.interactive(), in: Circle())
                        .glassEffectID("loc", in: glassNS)

                        Button {
                            withAnimation(.spring(response: 0.3)) { isSatellite.toggle() }
                        } label: {
                            Image(systemName: isSatellite ? "map.fill" : "globe.europe.africa.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(isSatellite ? .blue : .primary)
                                .frame(width: 50, height: 50)
                        }
                        .glassEffect(.regular.interactive(), in: Circle())
                        .glassEffectID("sat", in: glassNS)

                        Button {
                            withAnimation {
                                if userStore.homeCoordinate != nil {
                                    userStore.homeCoordinate = nil
                                } else if let loc = locationManager.currentLocation {
                                    userStore.homeCoordinate = loc.coordinate
                                }
                            }
                        } label: {
                            Image(systemName: userStore.homeCoordinate != nil ? "house.fill" : "house")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(userStore.homeCoordinate != nil ? .blue : .primary)
                                .frame(width: 50, height: 50)
                        }
                        .glassEffect(.regular.interactive(), in: Circle())
                        .glassEffectID("home", in: glassNS)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 28)
            }
        }
        .onAppear {
            locationManager.onCenterRequested = { coord in
                let r = MKCoordinateRegion(center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012))
                jumpRegion = r
                jumpID = UUID()
                userCentered = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    jumpRegion = nil
                    jumpID = nil
                }
            }
            if let loc = locationManager.currentLocation {
                let r = MKCoordinateRegion(center: loc.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012))
                jumpRegion = r
                jumpID = UUID()
                userCentered = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    jumpRegion = nil
                    jumpID = nil
                }
            }
            locationManager.setup()
        }
        .fullScreenCover(isPresented: $showRouting) {
            RoutingView(isPresented: $showRouting)
                .environmentObject(userStore)
                .environmentObject(locationManager)
        }
    }

    // MARK: - Status pill

    @ViewBuilder
    var statusPill: some View {
        switch simMode {
        case .pickingPin:
            HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill").foregroundStyle(.blue)
                Text("Tap the map to set destination").font(.caption.weight(.medium))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .glassEffect(.regular, in: Capsule()).padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))

        case .routing:
            HStack(spacing: 8) {
                ProgressView().progressViewStyle(.circular).scaleEffect(0.7)
                Text("Calculating route…").font(.caption.weight(.medium))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .glassEffect(.regular, in: Capsule()).padding(.top, 8)
            .transition(.opacity)

        case .running:
            HStack(spacing: 8) {
                Image(systemName: "car.fill").foregroundStyle(.blue).font(.system(size: 12))
                Text("Simulating…").font(.caption.weight(.medium))
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .glassEffect(.regular, in: Capsule()).padding(.top, 8)
            .transition(.opacity)

        case .idle:
            EmptyView()
        }
    }

    // MARK: - Sim button

    var simIcon: String {
        switch simMode {
        case .idle: return "mappin.and.ellipse"
        case .pickingPin: return "xmark"
        case .routing, .running: return "stop.fill"
        }
    }
    var simColour: Color {
        switch simMode {
        case .idle: return .primary
        case .pickingPin: return .orange
        case .routing, .running: return .red
        }
    }

    func handleSimButton() {
        switch simMode {
        case .idle:
            withAnimation { simMode = .pickingPin; pinCoord = nil; routeError = nil }
        default:
            withAnimation { simMode = .idle; pinCoord = nil; routeError = nil }
            userStore.cancelSimulation()
        }
    }

    func beginSimulation(to destination: CLLocationCoordinate2D) {
        guard let origin = locationManager.currentLocation?.coordinate else {
            withAnimation { simMode = .idle; pinCoord = nil }
            return
        }
        withAnimation { simMode = .routing }

        // Zoom to show full route
        let mid = CLLocationCoordinate2D(
            latitude:  (origin.latitude  + destination.latitude)  / 2,
            longitude: (origin.longitude + destination.longitude) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta:  abs(origin.latitude  - destination.latitude)  * 1.6 + 0.01,
            longitudeDelta: abs(origin.longitude - destination.longitude) * 1.6 + 0.01)
        jumpRegion = MKCoordinateRegion(center: mid, span: span)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { jumpRegion = nil }

        userStore.simulateRoute(from: origin, to: destination,
            onStart:    { withAnimation { simMode = .running } },
            onComplete: { withAnimation { simMode = .idle; pinCoord = nil } },
            onError:    { msg in withAnimation { simMode = .idle; pinCoord = nil; routeError = msg } }
        )
    }
}

// MARK: - TrackingMapView

struct TrackingMapView: UIViewRepresentable {
    var segments: [DrivenSegment]
    var jumpTo: MKCoordinateRegion?
    var jumpID: UUID?
    var pinCoord: CLLocationCoordinate2D?
    var carPosition: CLLocationCoordinate2D?
    var carHeading: Double
    var pickingPin: Bool
    var isDark: Bool
    var isSatellite: Bool
    var resolvedTileURL: String = ""
    var lineColour: LineColour = .white
    var lineOpacity: Double = 0.85
    var pulseActive: Bool = true
    var homeCoordinate: CLLocationCoordinate2D? = nil
    var furthestCoordinate: CLLocationCoordinate2D? = nil
    var onTap: ((CLLocationCoordinate2D) -> Void)?

    private var tileURL: String? {
        guard !isSatellite else { return nil }
        return resolvedTileURL.isEmpty ? nil : resolvedTileURL
    }

    /// Composite key encoding both tile URL and mode so Normal+road vs Normal+sat are distinct.
    private var tileKey: String {
        isSatellite ? "__sat__" : (tileURL ?? "__native__")
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass = true
        map.isRotateEnabled = true
        if let url = tileURL { context.coordinator.applyTile(to: map, url: url) }
        else if isSatellite { map.mapType = .hybridFlyover }
        else { map.mapType = .standard }
        context.coordinator.currentTileURL = tileKey
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                          action: #selector(Coordinator.tapped(_:)))
        map.addGestureRecognizer(tap)
        context.coordinator.mapView = map
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator
        c.onTap = onTap
        c.pickingPin = pickingPin
        c.isDark = isDark
        c.lineColour = lineColour
        c.lineOpacity = lineOpacity
        c.pulseActive = pulseActive

        // Jump — fires whenever jumpID changes (UUID guarantees uniqueness)
        if let r = jumpTo, jumpID != c.lastJumpID {
            c.lastJumpID = jumpID
            map.setRegion(r, animated: true)
        }

        // Tile / map type
        if c.currentTileURL != tileKey {
            c.currentTileURL = tileKey
            map.overlays.filter { $0 is MKTileOverlay }.forEach { map.removeOverlay($0) }
            if let u = tileURL { map.mapType = .standard; c.applyTile(to: map, url: u) }
            else if isSatellite { map.mapType = .hybridFlyover }
            else { map.mapType = .standard }
        }

        // Car avatar
        c.lastCarHeading = carHeading
        let cars = map.annotations.filter { $0 is CarAnnotation }
        if let pos = carPosition {
            if let car = cars.first as? CarAnnotation {
                car.coordinate = pos; car.heading = carHeading
                (map.view(for: car) as? CarAnnotationView)?.updateHeading(carHeading)
            } else {
                cars.forEach { map.removeAnnotation($0) }
                map.addAnnotation(CarAnnotation(coordinate: pos, heading: carHeading))
            }
        } else { cars.forEach { map.removeAnnotation($0) } }

        // Destination pin
        let pins = map.annotations.filter { $0 is DestinationPin }
        if let coord = pinCoord {
            if pins.isEmpty { map.addAnnotation(DestinationPin(coordinate: coord)) }
        } else { pins.forEach { map.removeAnnotation($0) } }

        // Home annotation
        let homeKey = homeCoordinate.map { "\($0.latitude),\($0.longitude)" } ?? ""
        if c.lastHomeKey != homeKey {
            c.lastHomeKey = homeKey
            map.annotations.filter { $0 is HomeAnnotation }.forEach { map.removeAnnotation($0) }
            if let h = homeCoordinate { map.addAnnotation(HomeAnnotation(coordinate: h)) }
        }

        // Furthest annotation + dashed line
        let furthestKey = furthestCoordinate.map { "\($0.latitude),\($0.longitude)" } ?? ""
        if c.lastFurthestKey != furthestKey {
            c.lastFurthestKey = furthestKey
            map.annotations.filter { $0 is FurthestAnnotation }.forEach { map.removeAnnotation($0) }
            map.overlays.filter { $0 is FurthestLineOverlay }.forEach { map.removeOverlay($0) }
            if let f = furthestCoordinate, let h = homeCoordinate {
                map.addAnnotation(FurthestAnnotation(coordinate: f))
                var coords = [h, f]
                map.addOverlay(FurthestLineOverlay(coordinates: &coords, count: 2),
                               level: .aboveRoads)
            }
        }

        // Segment overlays — redraw when data OR any visual style changes
        let totalCount  = segments.reduce(0) { $0 + $1.points.count }
        let styleHash   = "\(lineColour.rawValue)-\(lineOpacity)-\(pulseActive)"
        let needsRedraw = c.lastTotalPoints != totalCount
                       || c.lastSegmentCount != segments.count
                       || c.lastStyleHash != styleHash

        if needsRedraw {
            c.lastTotalPoints  = totalCount
            c.lastSegmentCount = segments.count
            c.lastStyleHash    = styleHash

            map.overlays.filter { $0 is SegmentOverlay }.forEach {
                c.renderers.removeValue(forKey: ObjectIdentifier($0 as AnyObject))
                map.removeOverlay($0)
            }
            for seg in segments {
                guard seg.points.count >= 2 else { continue }
                var coords = seg.points.map { $0.coordinate }
                let overlay = SegmentOverlay(coordinates: &coords, count: coords.count)
                overlay.isActive = seg.isActive
                map.addOverlay(overlay, level: .aboveLabels)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(tileURL: tileKey) }

    // MARK: Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var currentTileURL: String
        var isDark = true
        var lastJumpID: UUID? = nil
        var lastCarHeading: Double = 0
        var lastTotalPoints = 0
        var lastSegmentCount = 0
        var pickingPin = false
        var onTap: ((CLLocationCoordinate2D) -> Void)?
        weak var mapView: MKMapView?

        // Cache renderers so we can update lineWidth on zoom
        var renderers: [ObjectIdentifier: MKPolylineRenderer] = [:]
        var lastSpan: Double = 0.01
        var lineColour: LineColour = .white
        var lineOpacity: Double = 0.85
        var pulseActive: Bool = true
        var lastStyleHash: String = ""
        var lastHomeKey: String = ""
        var lastFurthestKey: String = ""

        init(tileURL: String) { self.currentTileURL = tileURL }

        @objc func tapped(_ gr: UITapGestureRecognizer) {
            guard pickingPin, let map = gr.view as? MKMapView else { return }
            onTap?(map.convert(gr.location(in: map), toCoordinateFrom: map))
        }

        func applyTile(to map: MKMapView, url: String) {
            let t = MKTileOverlay(urlTemplate: url)
            t.canReplaceMapContent = true
            t.tileSize = CGSize(width: 256, height: 256)
            t.minimumZ = 0; t.maximumZ = 19
            map.insertOverlay(t, at: 0, level: .aboveRoads)
        }

        func mapView(_ map: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            if let seg = overlay as? SegmentOverlay {
                let r = MKPolylineRenderer(polyline: seg)
                applyStyle(to: r, isActive: seg.isActive,
                           span: map.region.span.latitudeDelta)
                renderers[ObjectIdentifier(seg)] = r
                if seg.isActive && pulseActive { addPulse(to: r) }
                return r
            }
            if let line = overlay as? FurthestLineOverlay {
                let r = MKPolylineRenderer(polyline: line)
                r.strokeColor = UIColor.systemOrange.withAlphaComponent(0.45)
                r.lineWidth = 1.5
                r.lineDashPattern = [4, 7]
                r.lineCap = .round
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        /// Recalculate line width from map span so lines stay road-width at all zoom levels.
        /// At span 0.01° (~1km view) lines are ~4pt. At span 0.5° (~50km) they shrink to ~1pt.
        func lineWidth(for span: Double, isActive: Bool) -> CGFloat {
            // Target: line represents ~8 metres of real road width
            // At span=0.01, map is ~1km across screen (~375pt) → 8m = 3pt
            // Scale linearly with span, clamped so it never disappears or bloats
            let metersPerDegree = 111_000.0
            let mapWidthMeters  = span * metersPerDegree
            let screenWidth: Double = 375
            let pointsPerMeter = screenWidth / mapWidthMeters
            let roadWidthMeters: Double = isActive ? 9 : 7
            let width = CGFloat(roadWidthMeters * pointsPerMeter)
            return min(max(width, 1.0), isActive ? 6.0 : 5.0)
        }

        func applyStyle(to r: MKPolylineRenderer, isActive: Bool, span: Double) {
            r.lineWidth = lineWidth(for: span, isActive: isActive)
            let alpha = isActive ? lineOpacity : lineOpacity * 0.65
            r.strokeColor = lineColour.colour.withAlphaComponent(CGFloat(alpha))
            r.lineCap = .round; r.lineJoin = .round
        }

        /// Adds a repeating opacity pulse to an active segment renderer
        func addPulse(to r: MKPolylineRenderer) {
            let baseColour = lineColour.colour
            let low  = CGFloat(lineOpacity) * 0.35
            let high = CGFloat(lineOpacity)
            var alpha = high
            var increasing = false
            var active = true   // set to false externally to stop timer
            r.strokeColor = baseColour.withAlphaComponent(alpha)
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak r] timer in
                guard active, let r = r else { timer.invalidate(); return }
                if increasing {
                    alpha = min(alpha + 0.025, high)
                    if alpha >= high { increasing = false }
                } else {
                    alpha = max(alpha - 0.025, low)
                    if alpha <= low { increasing = true }
                }
                r.strokeColor = baseColour.withAlphaComponent(alpha)
                r.invalidatePath()
            }
            // Store stop closure on renderer so overlay removal can cancel it
            objc_setAssociatedObject(r, &pulseKey, { active = false }, .OBJC_ASSOCIATION_RETAIN)
        }

        /// Called whenever user zooms or pans — update all cached renderer widths
        func mapView(_ map: MKMapView, regionDidChangeAnimated animated: Bool) {
            let span = map.region.span.latitudeDelta
            guard abs(span - lastSpan) / lastSpan > 0.05 else { return } // >5% change
            lastSpan = span
            for overlay in map.overlays {
                guard let seg = overlay as? SegmentOverlay,
                      let r = renderers[ObjectIdentifier(seg)] else { continue }
                r.lineWidth = lineWidth(for: span, isActive: seg.isActive)
                r.invalidatePath()
            }
        }

        func mapView(_ map: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let car = annotation as? CarAnnotation {
                let av = (map.dequeueReusableAnnotationView(withIdentifier: "car") as? CarAnnotationView)
                    ?? CarAnnotationView(annotation: car, reuseIdentifier: "car")
                av.annotation = annotation
                av.updateHeading(car.heading)
                return av
            }
            if annotation is HomeAnnotation {
                let av = (map.dequeueReusableAnnotationView(withIdentifier: "home") as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "home")
                av.markerTintColor = .systemBlue
                av.glyphImage = UIImage(systemName: "house.fill")
                av.annotation = annotation
                return av
            }
            if annotation is FurthestAnnotation {
                let av = (map.dequeueReusableAnnotationView(withIdentifier: "furthest") as? MKMarkerAnnotationView)
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "furthest")
                av.markerTintColor = .systemOrange
                av.glyphImage = UIImage(systemName: "star.fill")
                av.animatesWhenAdded = true
                av.annotation = annotation
                return av
            }
            if annotation is DestinationPin {
                let av = map.dequeueReusableAnnotationView(withIdentifier: "pin")
                    ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "pin")
                if let m = av as? MKMarkerAnnotationView {
                    m.markerTintColor = .systemBlue
                    m.glyphImage = UIImage(systemName: "flag.fill")
                    m.animatesWhenAdded = true
                }
                av.annotation = annotation; return av
            }
            guard annotation is MKUserLocation else { return nil }
            let av = map.dequeueReusableAnnotationView(withIdentifier: "user")
                ?? MKAnnotationView(annotation: annotation, reuseIdentifier: "user")
            av.annotation = annotation
            av.subviews.forEach { $0.removeFromSuperview() }
            let rW: CGFloat = 26
            let ring = UIView(frame: CGRect(x: 0, y: 0, width: rW, height: rW))
            ring.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.18)
            ring.layer.cornerRadius = rW / 2
            let dW: CGFloat = 13; let off = (rW - dW) / 2
            let dot = UIView(frame: CGRect(x: off, y: off, width: dW, height: dW))
            dot.backgroundColor = .systemBlue; dot.layer.cornerRadius = dW / 2
            dot.layer.borderWidth = 2
            dot.layer.borderColor = UIColor.white.withAlphaComponent(0.95).cgColor
            dot.layer.shadowColor = UIColor.systemBlue.cgColor
            dot.layer.shadowRadius = 5; dot.layer.shadowOpacity = 0.55; dot.layer.shadowOffset = .zero
            ring.addSubview(dot); av.addSubview(ring); av.frame = ring.frame
            return av
        }
    }
}

// MARK: - Overlay / Annotation types

private var pulseKey: UInt8 = 0

class SegmentOverlay: MKPolyline {
    var isActive: Bool = false
}

class CarAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var heading: Double
    init(coordinate: CLLocationCoordinate2D, heading: Double) {
        self.coordinate = coordinate; self.heading = heading
    }
}

class CarAnnotationView: MKAnnotationView {
    private let arrow = CAShapeLayer()
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }
    private func setup() {
        frame = CGRect(x: 0, y: 0, width: 36, height: 36)
        backgroundColor = .clear; isOpaque = false
        let p = UIBezierPath()
        p.move(to:    CGPoint(x: 18, y: 2))
        p.addLine(to: CGPoint(x: 30, y: 30))
        p.addLine(to: CGPoint(x: 18, y: 23))
        p.addLine(to: CGPoint(x: 6,  y: 30))
        p.close()
        arrow.path = p.cgPath
        arrow.fillColor   = UIColor.systemBlue.cgColor
        arrow.strokeColor = UIColor.white.cgColor
        arrow.lineWidth = 2
        arrow.shadowColor   = UIColor.systemBlue.cgColor
        arrow.shadowRadius  = 6
        arrow.shadowOpacity = 0.7
        arrow.shadowOffset  = .zero
        arrow.frame = bounds
        layer.addSublayer(arrow)
    }
    func updateHeading(_ h: Double) {
        UIView.animate(withDuration: 0.15) {
            self.transform = CGAffineTransform(rotationAngle: CGFloat(h * .pi / 180))
        }
    }
}

class DestinationPin: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
}

class HomeAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
}

class FurthestAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    init(coordinate: CLLocationCoordinate2D) { self.coordinate = coordinate }
}

class FurthestLineOverlay: MKPolyline {}

// MARK: - Stats Widget

struct StatsWidget: View {
    let segments: Int
    let miles: Double
    var body: some View {
        HStack(spacing: 20) {
            StatPill(value: "\(segments)", label: "Routes")
            StatPill(value: String(format: "%.1f", miles), label: "Miles")
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct StatPill: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 22, weight: .bold, design: .rounded))
            Text(label).font(.system(size: 9, weight: .semibold))
                .tracking(1.5).foregroundStyle(.secondary).textCase(.uppercase)
        }
    }
}

// MARK: - Previews

#Preview("Dark") {
    MapView()
        .environmentObject({ let s = UserStore(); s.isDarkMode = true; return s }())
        .environmentObject(LocationManager())
        .preferredColorScheme(.dark)
}
#Preview("Light") {
    MapView()
        .environmentObject({ let s = UserStore(); s.isDarkMode = false; return s }())
        .environmentObject(LocationManager())
        .preferredColorScheme(.light)
}
