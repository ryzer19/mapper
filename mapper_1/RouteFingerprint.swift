import SwiftUI
import CoreLocation

// MARK: - Fingerprint Style

enum FingerprintStyle: Int, CaseIterable, Identifiable {
    case trace = 0
    case echo  = 1
    case flow  = 2

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .trace: return "Trace"
        case .echo:  return "Echo"
        case .flow:  return "Flow"
        }
    }

    var subtitle: String {
        switch self {
        case .trace: return "Precise & minimal"
        case .echo:  return "Ripples through space"
        case .flow:  return "The journey in colour"
        }
    }
}

// MARK: - Route Fingerprint View

struct RouteFingerprintView: View {
    let segment: DrivenSegment
    @Environment(\.dismiss) var dismiss
    @State private var styleIndex = 0

    private var segmentDistance: Double {
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

    private var currentStyle: FingerprintStyle {
        FingerprintStyle(rawValue: styleIndex) ?? .trace
    }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.07).ignoresSafeArea()

            VStack(spacing: 0) {

                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(segment.startedAt, style: .date)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f miles", segmentDistance))
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.08), in: Circle())
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 12)

                // Artwork — swipeable
                TabView(selection: $styleIndex) {
                    ForEach(FingerprintStyle.allCases) { style in
                        FingerprintCanvas(segment: segment, style: style)
                            .padding(.horizontal, 24)
                            .tag(style.rawValue)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.3), value: styleIndex)

                // Page dots + style label
                VStack(spacing: 14) {
                    HStack(spacing: 7) {
                        ForEach(FingerprintStyle.allCases) { style in
                            Capsule()
                                .fill(styleIndex == style.rawValue
                                      ? Color.white
                                      : Color.white.opacity(0.22))
                                .frame(width: styleIndex == style.rawValue ? 22 : 6, height: 6)
                                .animation(.spring(response: 0.3), value: styleIndex)
                        }
                    }

                    VStack(spacing: 3) {
                        Text(currentStyle.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(currentStyle.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .animation(.easeInOut(duration: 0.2), value: styleIndex)
                }
                .padding(.bottom, 48)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Fingerprint Canvas

struct FingerprintCanvas: View {
    let segment: DrivenSegment
    let style: FingerprintStyle

    var body: some View {
        GeometryReader { geo in
            let pts = normalizedPoints(in: geo.size)
            Canvas { ctx, size in
                switch style {
                case .trace: drawTrace(ctx: ctx, points: pts)
                case .echo:  drawEcho(ctx: ctx,  points: pts, size: size)
                case .flow:  drawFlow(ctx: ctx,  points: pts)
                }
            }
        }
    }

    // MARK: – Coordinate normalisation

    private func normalizedPoints(in size: CGSize, padding: CGFloat = 52) -> [CGPoint] {
        let raw = segment.points
        guard raw.count >= 2 else { return [] }

        let lats    = raw.map(\.latitude)
        let lons    = raw.map(\.longitude)
        let minLat  = lats.min()!, maxLat = lats.max()!
        let minLon  = lons.min()!, maxLon = lons.max()!
        let latRange = maxLat - minLat
        let lonRange = maxLon - minLon

        guard latRange > 0 || lonRange > 0 else {
            return Array(repeating: CGPoint(x: size.width / 2, y: size.height / 2), count: raw.count)
        }

        // Compensate for longitude compression at the route's latitude
        let cosLat   = cos((minLat + maxLat) / 2 * .pi / 180)
        let adjLon   = lonRange * cosLat
        let drawW    = size.width  - padding * 2
        let drawH    = size.height - padding * 2
        let scaleX   = adjLon    > 0 ? drawW / adjLon    : .infinity
        let scaleY   = latRange  > 0 ? drawH / latRange  : .infinity
        let scale    = min(scaleX, scaleY)
        let offsetX  = (size.width  - adjLon   * scale) / 2
        let offsetY  = (size.height - latRange * scale) / 2

        return raw.map {
            CGPoint(
                x: ($0.longitude - minLon) * cosLat * scale + offsetX,
                y: (maxLat - $0.latitude)           * scale + offsetY
            )
        }
    }

    private func makePath(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard pts.count >= 2 else { return p }
        p.move(to: pts[0])
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        return p
    }

    // Reduce point density for artwork — keeps fidelity but avoids
    // thousands of draw calls on long routes.
    private func downsample(_ pts: [CGPoint], target: Int = 400) -> [CGPoint] {
        guard pts.count > target else { return pts }
        let step = pts.count / target
        var result = pts.indices.filter { $0 % step == 0 }.map { pts[$0] }
        if result.last != pts.last { result.append(pts[pts.count - 1]) }
        return result
    }

    // MARK: – Style 1: Trace
    // Clean pen-plotter aesthetic — three passes build a crisp white glow.

    private func drawTrace(ctx: GraphicsContext, points: [CGPoint]) {
        let path = makePath(points)
        let stroke = StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)

        // Outer diffuse glow
        var gc1 = ctx
        gc1.addFilter(.blur(radius: 14))
        gc1.stroke(path, with: .color(.white.opacity(0.14)),
                   style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))

        // Mid glow
        var gc2 = ctx
        gc2.addFilter(.blur(radius: 5))
        gc2.stroke(path, with: .color(.white.opacity(0.30)),
                   style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))

        // Crisp core
        ctx.stroke(path, with: .color(.white.opacity(0.90)), style: stroke)
    }

    // MARK: – Style 2: Echo
    // The route radiates outward in concentric cyan halos.

    private func drawEcho(ctx: GraphicsContext, points: [CGPoint], size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let cyan   = Color(red: 0.00, green: 0.82, blue: 1.00)

        // (scale, opacity, blur)
        let layers: [(CGFloat, Double, CGFloat)] = [
            (1.60, 0.04, 22),
            (1.38, 0.07, 14),
            (1.20, 0.12, 8),
            (1.08, 0.20, 4),
            (1.00, 0.85, 0),
        ]

        for (scale, opacity, blur) in layers {
            let scaled = points.map {
                CGPoint(x: center.x + ($0.x - center.x) * scale,
                        y: center.y + ($0.y - center.y) * scale)
            }
            let path = makePath(scaled)
            let width = CGFloat(1.2 + (scale - 1.0) * 4)

            if blur > 0 {
                var gc = ctx
                gc.addFilter(.blur(radius: blur))
                gc.stroke(path, with: .color(cyan.opacity(opacity)),
                          style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            } else {
                // Core — a soft glow pass then the crisp line
                var gc = ctx
                gc.addFilter(.blur(radius: 3))
                gc.stroke(path, with: .color(cyan.opacity(0.40)),
                          style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                ctx.stroke(path, with: .color(cyan.opacity(0.92)),
                           style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
            }
        }
    }

    // MARK: – Style 3: Flow
    // Each segment is tinted by its position along the journey.

    private func drawFlow(ctx: GraphicsContext, points: [CGPoint]) {
        let pts = downsample(points)
        guard pts.count >= 2 else { return }

        let palette: [Color] = [
            Color(red: 0.55, green: 0.08, blue: 0.92),   // deep violet
            Color(red: 0.15, green: 0.38, blue: 1.00),   // electric blue
            Color(red: 0.00, green: 0.78, blue: 1.00),   // cyan
            Color(red: 0.08, green: 0.95, blue: 0.62),   // mint
        ]
        let total = pts.count - 1

        for i in 0 ..< total {
            let t     = CGFloat(i) / CGFloat(total)
            let color = interpolateColor(palette, t: t)
            var seg   = Path()
            seg.move(to: pts[i])
            seg.addLine(to: pts[i + 1])

            // Glow pass
            var gc = ctx
            gc.addFilter(.blur(radius: 5))
            gc.stroke(seg, with: .color(color.opacity(0.35)),
                      style: StrokeStyle(lineWidth: 6, lineCap: .round))

            // Core
            ctx.stroke(seg, with: .color(color.opacity(0.90)),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }

    // MARK: – Helpers

    private func interpolateColor(_ colors: [Color], t: CGFloat) -> Color {
        guard colors.count >= 2 else { return colors.first ?? .white }
        let scaled  = t * CGFloat(colors.count - 1)
        let idx     = min(Int(scaled), colors.count - 2)
        let localT  = scaled - CGFloat(idx)
        let c1 = UIColor(colors[idx])
        let c2 = UIColor(colors[idx + 1])
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red:   Double(r1 + (r2 - r1) * localT),
            green: Double(g1 + (g2 - g1) * localT),
            blue:  Double(b1 + (b2 - b1) * localT)
        )
    }
}
