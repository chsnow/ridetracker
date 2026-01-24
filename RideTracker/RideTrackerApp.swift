import SwiftUI

@main
struct RideTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "ridetracker",
              url.host == "queue",
              let pathComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path.split(separator: "/"),
              pathComponents.count >= 2 else {
            return
        }

        let action = String(pathComponents[0])
        let rideId = String(pathComponents[1])

        switch action {
        case "cancel":
            appState.cancelQueue(entityId: rideId)
        case "log":
            appState.endQueue(rideId: rideId)
        default:
            break
        }
    }
}
