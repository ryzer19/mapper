import SwiftUI

struct ContentView: View {
    @EnvironmentObject var userStore: UserStore
    @EnvironmentObject var locationManager: LocationManager

    var body: some View {
        TabView {
            Tab("Map", systemImage: "map.fill") {
                MapView()
            }
            Tab("Routes", systemImage: "road.lanes") {
                ProgressTabView()
            }
            Tab("Profile", systemImage: "person.fill") {
                ProfileView()
            }
        }
        .preferredColorScheme(userStore.isDarkMode ? .dark : .light)
        .onAppear {
            // Wire every GPS point directly to the active segment — no geocoding
            locationManager.onTrackingPoint = { coordinate in
                userStore.recordPoint(coordinate)
            }
        }
    }
}
