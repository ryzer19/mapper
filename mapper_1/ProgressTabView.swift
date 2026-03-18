import SwiftUI
import CoreLocation

struct ProgressTabView: View {
    @EnvironmentObject var userStore: UserStore
    @State private var selectedRoute: DrivenSegment? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 0) {
                        SummaryCell(value: "\(userStore.totalSegments)",
                                    label: "Routes Driven")
                        Divider()
                        SummaryCell(value: String(format: "%.1f mi", userStore.totalDrivenMiles),
                                    label: "Total Distance")
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("All Routes")) {
                    if userStore.segments.filter({ $0.points.count >= 2 }).isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "car.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary.opacity(0.4))
                            Text("No routes recorded yet")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("Tap Start on the Map tab and drive.")
                                .font(.caption)
                                .foregroundStyle(.secondary.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(userStore.segments.filter { $0.points.count >= 2 }.reversed()) { seg in
                            Button {
                                guard !seg.isActive else { return }
                                selectedRoute = seg
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: seg.isActive
                                          ? "record.circle.fill" : "checkmark.circle.fill")
                                        .foregroundStyle(seg.isActive ? .red : .secondary.opacity(0.5))
                                        .font(.system(size: 15))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(seg.isActive ? "In progress…" : routeTitle(seg))
                                            .font(.subheadline)
                                        Text(seg.startedAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(routeDistance(seg))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    if !seg.isActive {
                                        Image(systemName: "chevron.right")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Routes")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(item: $selectedRoute) { seg in
                RouteDetailView(segment: seg)
            }
        }
    }

    func routeTitle(_ seg: DrivenSegment) -> String {
        "Route \(seg.startedAt.formatted(.dateTime.month().day()))"
    }

    func routeDistance(_ seg: DrivenSegment) -> String {
        let pts = seg.points
        guard pts.count >= 2 else { return "0.0 mi" }
        var total = 0.0
        for i in 1 ..< pts.count {
            let a = CLLocation(latitude: pts[i-1].latitude, longitude: pts[i-1].longitude)
            let b = CLLocation(latitude: pts[i].latitude,   longitude: pts[i].longitude)
            total += a.distance(from: b)
        }
        return String(format: "%.1f mi", total / 1609.34)
    }
}

struct SummaryCell: View {
    let value: String; let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 26, weight: .bold, design: .rounded))
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
