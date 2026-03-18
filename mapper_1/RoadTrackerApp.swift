import SwiftUI

@main
struct RoadTrackerApp: App {
    @StateObject private var userStore = UserStore()
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userStore)
                .environmentObject(locationManager)
        }
    }
}
