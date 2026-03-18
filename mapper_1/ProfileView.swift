import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var userStore: UserStore
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            List {
                // Stats
                Section {
                    HStack(spacing: 24) {
                        BigStat(value: "\(userStore.totalSegments)", label: "Routes")
                        Divider().frame(height: 36)
                        BigStat(value: String(format: "%.1f", userStore.totalDrivenMiles), label: "Miles")
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }

                // Personalise — navigation row
                Section {
                    NavigationLink(destination: PersonaliseView().environmentObject(userStore)) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Personalise")
                                    .font(.body)
                                Text("Map style, line colour, animations")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.45, green: 0.30, blue: 0.95),
                                                Color(red: 0.20, green: 0.55, blue: 0.95)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 30, height: 30)
                                Image(systemName: "paintpalette.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }

                // How it works
                Section(header: Text("How It Works")) {
                    Label("Tap Start to begin tracking", systemImage: "play.circle")
                    Label("Drive anywhere — your route is drawn live", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
                    Label("Zoom in to see your driven lines", systemImage: "magnifyingglass")
                    Label("All data stays on this device", systemImage: "internaldrive")
                }
                .foregroundStyle(.secondary)
                .font(.subheadline)

                // Reset
                Section {
                    Button(role: .destructive) { showResetConfirm = true } label: {
                        Label("Reset All Data", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog("Reset All Data?",
                                isPresented: $showResetConfirm,
                                titleVisibility: .visible) {
                Button("Reset", role: .destructive) { userStore.resetProgress() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All driven routes and GPS history will be erased permanently.")
            }
        }
    }
}

struct BigStat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 36, weight: .bold, design: .rounded))
            Text(label).font(.caption).foregroundStyle(.secondary)
                .textCase(.uppercase).tracking(1)
        }
        .frame(maxWidth: .infinity)
    }
}
