import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            RidesView()
                .tabItem {
                    Label("Rides", systemImage: "list.bullet")
                }
                .tag(AppTab.rides)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(AppTab.history)
        }
        .tint(.blue)
    }
}
