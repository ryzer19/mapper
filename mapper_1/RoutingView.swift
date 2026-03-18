import SwiftUI
import CoreLocation
import MapKit
import ObjectiveC

private var routingPulseKey: UInt8 = 0

// MARK: - RoutingView

struct RoutingView: View {
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.colorScheme) var colorScheme
    @Binding var isPresented: Bool

    @State private var headingUp = true
    @State private var heading: CLLocationDirection = 0
    @State private var speed: Double = 0
    @State private var isSatellite = false

    var isDark: Bool { colorScheme == .dark }
    var speedKmh: String { String(format: "%.0f", speed * 3.6) }

    var body: some View {
        ZStack {
            LiveTrackingMapView(
                segments: userStore.segments,
                headingUp: headingUp,
                isDark: isDark,
                isSatellite: isSatellite,
                resolvedTileURL: userStore.resolvedTileURL(labels: userStore.showMapLabels),
                lineColour: userStore.lineColour,
                lineOpacity: userStore.lineOpacity,
                pulseActive: userStore.pulseActive
            )
            .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Top bar
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TRACKING")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(2)
                            .foregroundStyle(.secondary)
                        Text(locationManager.isTracking ? "Active" : "Starting…")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(isDark ? .white : .black)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    // Satellite + Compass cluster
                    GlassEffectContainer(spacing: 8) {
                        Button {
                            withAnimation(.spring(response: 0.3)) { isSatellite.toggle() }
                        } label: {
                            Image(systemName: isSatellite ? "map.fill" : "globe.europe.africa.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(isSatellite ? Color.blue : .primary)
                                .frame(width: 50, height: 50)
                        }
                        .glassEffect(.regular.interactive(), in: Circle())

                        Button {
                            withAnimation(.spring(response: 0.35)) { headingUp.toggle() }
                        } label: {
                            Image(systemName: "location.north.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(headingUp ? Color.blue : .primary)
                                .rotationEffect(.degrees(headingUp ? 0 : -heading))
                                .animation(.easeOut(duration: 0.2), value: heading)
                                .frame(width: 50, height: 50)
                        }
                        .glassEffect(.regular.interactive(), in: Circle())
                    }
                }
                .padding(.top, 56).padding(.horizontal, 16)

                Spacer()

                // Bottom panel
                VStack(spacing: 14) {
                    HStack(spacing: 0) {
                        StatBlock(value: speedKmh,    label: "km/h",  isDark: isDark)
                        Divider().frame(height: 36).opacity(0.3)
                        StatBlock(value: "\(userStore.totalSegments)", label: "Routes", isDark: isDark)
                        Divider().frame(height: 36).opacity(0.3)
                        StatBlock(value: String(format: "%.1f", userStore.totalDrivenMiles),
                                  label: "Miles", isDark: isDark)
                    }
                    .padding(.vertical, 16)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Button {
                        locationManager.stopTracking()
                        userStore.endSegment()
                        withAnimation(.spring(response: 0.4)) { isPresented = false }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Stop Tracking")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(red: 0.95, green: 0.25, blue: 0.20))
                                .shadow(color: Color(red: 0.95, green: 0.25, blue: 0.20).opacity(0.4),
                                        radius: 12, y: 4)
                        )
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 36)
            }
        }
        .onAppear {
            userStore.startSegment()
            locationManager.startTracking()
            locationManager.onLocationUpdate = { loc in
                if loc.speed > 0.8 && loc.course >= 0 { heading = loc.course }
                speed = max(0, loc.speed)
            }
        }
        .onDisappear {
            locationManager.onLocationUpdate = nil
        }
    }
}

// MARK: - LiveTrackingMapView
// Dedicated routing map — uses MKUserTrackingMode for smooth auto-follow

struct LiveTrackingMapView: UIViewRepresentable {
    var segments: [DrivenSegment]
    var headingUp: Bool
    var isDark: Bool
    var isSatellite: Bool = false
    var resolvedTileURL: String = ""
    var lineColour: LineColour = .white
    var lineOpacity: Double = 0.85
    var pulseActive: Bool = true

    private var tileURL: String? {
        guard !isSatellite else { return nil }
        return resolvedTileURL.isEmpty ? nil : resolvedTileURL
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass = false
        map.isRotateEnabled = true
        map.isPitchEnabled = false
        map.userTrackingMode = .followWithHeading
        if let url = tileURL {
            context.coordinator.applyTile(to: map, url: url)
        } else {
            map.mapType = .hybridFlyover
        }
        context.coordinator.currentTileURL = tileURL ?? ""
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator
        c.isDark = isDark
        c.lineColour = lineColour
        c.lineOpacity = lineOpacity
        c.pulseActive = pulseActive

        // Tile swap
        let resolvedURL = tileURL ?? ""
        if c.currentTileURL != resolvedURL {
            c.currentTileURL = resolvedURL
            map.overlays.filter { $0 is MKTileOverlay }.forEach { map.removeOverlay($0) }
            if let url = tileURL {
                map.mapType = .standard
                c.applyTile(to: map, url: url)
            } else {
                map.mapType = .hybridFlyover
            }
        }

        // Tracking mode
        let desired: MKUserTrackingMode = headingUp ? .followWithHeading : .follow
        if map.userTrackingMode != desired { map.setUserTrackingMode(desired, animated: true) }

        // Segment overlays
        let totalPoints = segments.reduce(0) { $0 + $1.points.count }
        let styleHash   = "\(lineColour.rawValue)-\(lineOpacity)-\(pulseActive)"
        if c.lastTotalPoints != totalPoints || c.lastSegmentCount != segments.count || c.lastStyleHash != styleHash {
            c.lastTotalPoints  = totalPoints
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

    func makeCoordinator() -> Coordinator { Coordinator(tileURL: tileURL ?? "") }

    class Coordinator: NSObject, MKMapViewDelegate {
        var currentTileURL: String
        var isDark = true
        var lastTotalPoints = 0
        var lastSegmentCount = 0

        var renderers: [ObjectIdentifier: MKPolylineRenderer] = [:]
        var lastSpan: Double = 0.006
        var lineColour: LineColour = .white
        var lineOpacity: Double = 0.85
        var pulseActive: Bool = true
        var lastStyleHash: String = ""

        init(tileURL: String) { self.currentTileURL = tileURL }

        func applyTile(to map: MKMapView, url: String) {
            let tile = MKTileOverlay(urlTemplate: url)
            tile.canReplaceMapContent = true
            tile.tileSize = CGSize(width: 256, height: 256)
            tile.minimumZ = 0; tile.maximumZ = 19
            map.insertOverlay(tile, at: 0, level: .aboveRoads)
        }

        func lineWidth(for span: Double, isActive: Bool) -> CGFloat {
            let pts = CGFloat(8.0 * 375.0 / (span * 111_000.0))
            return min(max(pts, 1.0), isActive ? 6.0 : 5.0)
        }

        func applyStyle(to r: MKPolylineRenderer, isActive: Bool, span: Double) {
            r.lineWidth = lineWidth(for: span, isActive: isActive)
            let alpha = isActive ? lineOpacity : lineOpacity * 0.65
            r.strokeColor = lineColour.colour.withAlphaComponent(CGFloat(alpha))
            r.lineCap = .round; r.lineJoin = .round
        }

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
            objc_setAssociatedObject(r, &routingPulseKey, { active = false }, .OBJC_ASSOCIATION_RETAIN)
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
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ map: MKMapView, regionDidChangeAnimated animated: Bool) {
            let span = map.region.span.latitudeDelta
            guard abs(span - lastSpan) / lastSpan > 0.05 else { return }
            lastSpan = span
            for overlay in map.overlays {
                guard let seg = overlay as? SegmentOverlay,
                      let r = renderers[ObjectIdentifier(seg)] else { continue }
                r.lineWidth = lineWidth(for: span, isActive: seg.isActive)
                r.invalidatePath()
            }
        }
    }
}

// MARK: - StatBlock (shared with RoutingView)

struct StatBlock: View {
    let value: String
    let label: String
    let isDark: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(isDark ? .white : .black)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(isDark ? .white.opacity(0.4) : .black.opacity(0.35))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }
}
