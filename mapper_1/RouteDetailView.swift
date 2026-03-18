import SwiftUI
import MapKit
import CoreLocation

// MARK: - Route Detail View

struct RouteDetailView: View {
    let segment: DrivenSegment
    @Environment(\.dismiss) var dismiss

    @State private var screenPoints: [CGPoint] = []
    @State private var mapSpan: Double = 0.01
    @State private var sweepStart: Date? = nil

    private var distance: Double {
        let pts = segment.points
        guard pts.count >= 2 else { return 0 }
        var total = 0.0
        for i in 1 ..< pts.count {
            let a = CLLocation(latitude: pts[i-1].latitude, longitude: pts[i-1].longitude)
            let b = CLLocation(latitude: pts[i].latitude,   longitude: pts[i].longitude)
            total += a.distance(from: b)
        }
        return total / 1609.34
    }

    var body: some View {
        ZStack {
            RouteDetailMapView(segment: segment) { pts, span in
                screenPoints = pts
                mapSpan      = span
                sweepStart   = Date()
            }
            .ignoresSafeArea()

            if let start = sweepStart, !screenPoints.isEmpty {
                FlowMapOverlay(points: screenPoints, span: mapSpan, sweepStart: start)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Dismiss — top left
            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.50), in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                Spacer()
            }

            // Bottom info card
            VStack {
                Spacer()
                routeCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 44)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var routeCard: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(segment.startedAt, style: .date)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f miles", distance))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 1, height: 44)
                .padding(.horizontal, 20)
            VStack(alignment: .trailing, spacing: 4) {
                Text(segment.startedAt, style: .time)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("\(segment.points.count) pts")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - Locked Satellite Map

struct RouteDetailMapView: UIViewRepresentable {
    let segment: DrivenSegment
    /// Callback receives screen-space points and the map's latitudeDelta span.
    let onPointsMapped: ([CGPoint], Double) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.mapType = .hybridFlyover
        map.isScrollEnabled   = false
        map.isZoomEnabled     = false
        map.isRotateEnabled   = false
        map.isPitchEnabled    = false
        map.showsUserLocation = false
        map.showsCompass      = false
        map.delegate = context.coordinator

        let coords = segment.points.map { $0.coordinate }
        map.setRegion(regionFitting(coords), animated: false)

        context.coordinator.segment         = segment
        context.coordinator.onPointsMapped  = onPointsMapped
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    private func regionFitting(_ coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coords.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 53.3, longitude: -8.0),
                span:   MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        }
        let lats   = coords.map(\.latitude)
        let lons   = coords.map(\.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let center = CLLocationCoordinate2D(latitude:  (minLat + maxLat) / 2,
                                             longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta:  (maxLat - minLat) * 1.5 + 0.003,
            longitudeDelta: (maxLon - minLon) * 1.5 + 0.003)
        return MKCoordinateRegion(center: center, span: span)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var segment: DrivenSegment?
        var onPointsMapped: (([CGPoint], Double) -> Void)?
        var hasMapped = false

        func mapViewDidFinishRenderingMap(_ mapView: MKMapView, fullyRendered: Bool) {
            guard !hasMapped, let seg = segment else { return }
            hasMapped = true

            let span   = mapView.region.span.latitudeDelta

            // Downsample long routes for canvas performance
            let raw    = seg.points
            let step   = max(1, raw.count / 500)
            var pts    = raw.indices.filter { $0 % step == 0 }.map { raw[$0] }
            if let last = raw.last, pts.last.map({ $0.latitude != last.latitude }) ?? true {
                pts.append(last)
            }

            let screenPts = pts.map { mapView.convert($0.coordinate, toPointTo: mapView) }
            DispatchQueue.main.async { self.onPointsMapped?(screenPts, span) }
        }
    }
}

// MARK: - Flow Overlay  (sweep animation, span-scaled sizing)

struct FlowMapOverlay: View {
    let points: [CGPoint]
    let span: Double          // map latitudeDelta — drives line + glow size
    let sweepStart: Date

    // First colour repeated at the end so t=1.0 interpolates back to t=0.0
    // with no jump — the wrap-around is a smooth violet→violet cycle.
    private let palette: [Color] = [
        Color(red: 0.55, green: 0.08, blue: 0.92),  // violet
        Color(red: 0.15, green: 0.38, blue: 1.00),  // blue
        Color(red: 0.00, green: 0.78, blue: 1.00),  // cyan
        Color(red: 0.08, green: 0.95, blue: 0.62),  // mint
        Color(red: 0.55, green: 0.08, blue: 0.92),  // violet — closes the loop
    ]

    private let sweepCycleDuration: Double = 4.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let elapsed = context.date.timeIntervalSince(sweepStart)
            // colorOffset shifts the palette position along the route over time
            let colorOffset = CGFloat(elapsed / sweepCycleDuration)
                .truncatingRemainder(dividingBy: 1.0)
            let core = coreLineWidth
            Canvas { ctx, _ in
                drawFlow(ctx: ctx, colorOffset: colorOffset, coreWidth: core)
            }
        }
    }

    /// Line width scaled to the map's zoom level — identical formula to MapView.
    private var coreLineWidth: CGFloat {
        let metersPerDegree: Double = 111_000
        let mapWidthMeters          = span * metersPerDegree
        let pointsPerMeter          = 375.0 / mapWidthMeters
        let width                   = CGFloat(8.0 * pointsPerMeter)
        return min(max(width, 1.0), 5.0)
    }

    private func drawFlow(ctx: GraphicsContext, colorOffset: CGFloat, coreWidth: CGFloat) {
        guard points.count >= 2 else { return }
        let total      = points.count - 1
        let glowWidth  = coreWidth * 3.0
        let blurRadius = coreWidth * 1.8   // proportional — shrinks with zoom

        for i in 0 ..< total {
            // Shift the palette position so colours appear to chase along the route
            let t     = (CGFloat(i) / CGFloat(total) + colorOffset)
                            .truncatingRemainder(dividingBy: 1.0)
            let color = interpolated(palette, t: t)

            var seg = Path()
            seg.move(to: points[i])
            seg.addLine(to: points[i + 1])

            // Glow — blurred, width scales with zoom
            var gc = ctx
            gc.addFilter(.blur(radius: blurRadius))
            gc.stroke(seg, with: .color(color.opacity(0.40)),
                      style: StrokeStyle(lineWidth: glowWidth, lineCap: .round))

            // Core
            ctx.stroke(seg, with: .color(color.opacity(0.95)),
                       style: StrokeStyle(lineWidth: coreWidth, lineCap: .round))
        }
    }

    private func interpolated(_ colors: [Color], t: CGFloat) -> Color {
        guard colors.count >= 2 else { return colors.first ?? .white }
        let scaled = t * CGFloat(colors.count - 1)
        let idx    = min(Int(scaled), colors.count - 2)
        let local  = scaled - CGFloat(idx)
        let c1 = UIColor(colors[idx])
        let c2 = UIColor(colors[idx + 1])
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red:   Double(r1 + (r2 - r1) * local),
            green: Double(g1 + (g2 - g1) * local),
            blue:  Double(b1 + (b2 - b1) * local)
        )
    }
}
