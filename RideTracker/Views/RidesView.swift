import SwiftUI

struct RidesView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSortMenu = false
    @State private var showingShareSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Park Toggle
                if appState.parks.count > 1 {
                    ParkToggleView()
                }

                // Entity Type Tabs
                EntityTabsView()

                // Search and Filters
                FilterBarView()

                // Content
                if appState.isLoading && appState.entities.isEmpty {
                    LoadingView()
                } else if let error = appState.errorMessage {
                    ErrorView(message: error) {
                        Task {
                            await appState.refreshData()
                        }
                    }
                } else if appState.filteredEntities.isEmpty {
                    EmptyStateView()
                } else {
                    RideListView()
                }
            }
            .navigationTitle(appState.selectedPark?.name ?? "Rides")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appState.locationService.updateOnce()
                    } label: {
                        Image(systemName: "location")
                    }
                }
            }
            .refreshable {
                await appState.refreshData()
            }
        }
    }
}

// MARK: - Park Toggle

struct ParkToggleView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            ForEach(appState.parks) { park in
                Button {
                    appState.selectPark(park)
                } label: {
                    Text(parkShortName(park.name))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            appState.selectedPark?.id == park.id
                                ? Color.blue
                                : Color(.systemGray5)
                        )
                        .foregroundColor(
                            appState.selectedPark?.id == park.id
                                ? .white
                                : .primary
                        )
                        .cornerRadius(20)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private func parkShortName(_ name: String) -> String {
        if name.contains("California Adventure") {
            return "DCA"
        } else if name.contains("Disneyland") {
            return "Disneyland"
        }
        return name
    }
}

// MARK: - Entity Tabs

struct EntityTabsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            ForEach(EntityType.allCases, id: \.self) { type in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.selectedEntityType = type
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.title3)
                        Text(type.displayName)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        appState.selectedEntityType == type
                            ? Color.blue.opacity(0.1)
                            : Color.clear
                    )
                    .foregroundColor(
                        appState.selectedEntityType == type
                            ? .blue
                            : .secondary
                    )
                }
            }
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
}

// MARK: - Filter Bar

struct FilterBarView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSortPicker = false

    var body: some View {
        HStack(spacing: 12) {
            // Search Field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search", text: $appState.searchText)
                    .textFieldStyle(.plain)
                if !appState.searchText.isEmpty {
                    Button {
                        appState.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)

            // Favorites Filter
            Button {
                withAnimation {
                    appState.showFavoritesOnly.toggle()
                }
            } label: {
                Image(systemName: appState.showFavoritesOnly ? "star.fill" : "star")
                    .foregroundColor(appState.showFavoritesOnly ? .yellow : .secondary)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }

            // Sort Menu
            Menu {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button {
                        appState.setSortOrder(order)
                    } label: {
                        Label(order.displayName, systemImage: order.icon)
                    }
                }
            } label: {
                Image(systemName: appState.sortOrder.icon)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

// MARK: - Ride List

struct RideListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(appState.filteredEntities) { entity in
                    RideCardView(entity: entity)
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Supporting Views

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading rides...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Error loading data")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct EmptyStateView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: appState.showFavoritesOnly ? "star.slash" : "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(appState.showFavoritesOnly ? "No favorites yet" : "No results found")
                .font(.headline)
            Text(appState.showFavoritesOnly
                 ? "Star some rides to see them here"
                 : "Try adjusting your search or filters")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
