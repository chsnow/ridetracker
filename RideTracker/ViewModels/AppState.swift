import Foundation
import Combine
import CoreLocation

@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties

    @Published var parks: [Park] = []
    @Published var selectedPark: Park?
    @Published var entities: [Entity] = []
    @Published var liveData: [String: LiveData] = [:]
    @Published var selectedEntityType: EntityType = .attraction
    @Published var selectedTab: AppTab = .rides

    @Published var rideHistory: [RideHistoryEntry] = []
    @Published var activeQueues: [String: ActiveQueue] = [:]
    @Published var favorites: Set<String> = []
    @Published var notes: [String: String] = [:]
    @Published var collapsedDays: Set<String> = []

    @Published var sortOrder: SortOrder = .waitTimeLowToHigh
    @Published var searchText: String = ""
    @Published var showFavoritesOnly: Bool = false

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Services

    private let api = ThemeParksAPI.shared
    private let storage = StorageService.shared
    let locationService = LocationService.shared

    // MARK: - Timer

    private var timerCancellable: AnyCancellable?

    // MARK: - Initialization

    init() {
        loadLocalData()
        startQueueTimer()
        Task {
            await loadParks()
        }
    }

    // MARK: - Data Loading

    private func loadLocalData() {
        Task {
            rideHistory = await storage.getRideHistory()
            activeQueues = await storage.getActiveQueues()
            favorites = await storage.getFavorites()
            notes = await storage.getNotes()
            collapsedDays = await storage.getCollapsedDays()
            sortOrder = await storage.getSortOrder()
        }
    }

    func loadParks() async {
        isLoading = true
        errorMessage = nil

        do {
            if let resort = try await api.fetchDisneylandResort() {
                parks = resort.parks
                if let lastParkId = await storage.getLastParkId(),
                   let park = parks.first(where: { $0.id == lastParkId }) {
                    selectedPark = park
                } else {
                    selectedPark = parks.first
                }
                if let park = selectedPark {
                    await loadParkData(park)
                }
            }
        } catch is CancellationError {
            // Ignore cancellation errors
        } catch let error as URLError where error.code == .cancelled {
            // Ignore URL cancellation errors
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func loadParkData(_ park: Park, showLoading: Bool = true) async {
        // Only set isLoading for initial loads, not refreshes
        // Setting state during .refreshable can cause task cancellation
        if showLoading {
            isLoading = true
        }
        errorMessage = nil

        await storage.saveLastParkId(park.id)

        do {
            async let entitiesTask = api.fetchEntities(for: park.id)
            async let liveDataTask = api.fetchLiveData(for: park.id)

            let (fetchedEntities, fetchedLiveData) = try await (entitiesTask, liveDataTask)
            entities = fetchedEntities
            liveData = Dictionary(uniqueKeysWithValues: fetchedLiveData.map { ($0.id, $0) })
        } catch is CancellationError {
            print("[AppState] loadParkData() - CancellationError caught")
        } catch let error as URLError where error.code == .cancelled {
            print("[AppState] loadParkData() - URLError.cancelled caught")
        } catch {
            print("[AppState] loadParkData() - Error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        if showLoading {
            isLoading = false
        }
    }

    func refreshData() async {
        print("[AppState] refreshData() called")
        guard let park = selectedPark else {
            print("[AppState] refreshData() - no park selected, returning early")
            return
        }
        print("[AppState] refreshData() - refreshing park: \(park.name)")
        // Pass showLoading: false to avoid state changes that cancel the refresh task
        await loadParkData(park, showLoading: false)
        print("[AppState] refreshData() completed")
    }

    // MARK: - Filtered & Sorted Entities

    var filteredEntities: [Entity] {
        var result = entities.filter { $0.entityType == selectedEntityType }

        if showFavoritesOnly {
            result = result.filter { favorites.contains($0.id) }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        return sortEntities(result)
    }

    private func sortEntities(_ entities: [Entity]) -> [Entity] {
        switch sortOrder {
        case .name:
            return entities.sorted { $0.name < $1.name }

        case .distance:
            return entities.sorted { e1, e2 in
                guard let coord1 = e1.coordinate,
                      let coord2 = e2.coordinate else {
                    return e1.name < e2.name
                }
                let dist1 = locationService.distance(to: coord1) ?? Double.infinity
                let dist2 = locationService.distance(to: coord2) ?? Double.infinity
                return dist1 < dist2
            }

        case .waitTimeLowToHigh:
            return entities.sorted { e1, e2 in
                let wait1 = liveData[e1.id]?.waitMinutes ?? Int.max
                let wait2 = liveData[e2.id]?.waitMinutes ?? Int.max
                if wait1 == wait2 {
                    return e1.name < e2.name
                }
                return wait1 < wait2
            }

        case .waitTimeHighToLow:
            return entities.sorted { e1, e2 in
                let wait1 = liveData[e1.id]?.waitMinutes ?? -1
                let wait2 = liveData[e2.id]?.waitMinutes ?? -1
                if wait1 == wait2 {
                    return e1.name < e2.name
                }
                return wait1 > wait2
            }

        case .llReturnEarliest:
            return entities.sorted { e1, e2 in
                let ll1 = liveData[e1.id]?.lightningLaneInfo
                let ll2 = liveData[e2.id]?.lightningLaneInfo
                let time1 = llReturnDate(ll1)
                let time2 = llReturnDate(ll2)

                // Entities with LL come first, sorted by return time
                switch (time1, time2) {
                case (.some(let t1), .some(let t2)):
                    return t1 < t2
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return e1.name < e2.name
                }
            }

        case .llReturnLatest:
            return entities.sorted { e1, e2 in
                let ll1 = liveData[e1.id]?.lightningLaneInfo
                let ll2 = liveData[e2.id]?.lightningLaneInfo
                let time1 = llReturnDate(ll1)
                let time2 = llReturnDate(ll2)

                // Entities with LL come first, sorted by return time (latest first)
                switch (time1, time2) {
                case (.some(let t1), .some(let t2)):
                    return t1 > t2
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return e1.name < e2.name
                }
            }
        }
    }

    private func llReturnDate(_ ll: LightningLane?) -> Date? {
        guard let returnStart = ll?.returnStart else { return nil }
        return ISO8601DateFormatter().date(from: returnStart)
    }

    // MARK: - Park Selection

    func selectPark(_ park: Park) {
        guard park.id != selectedPark?.id else { return }
        selectedPark = park
        Task {
            await loadParkData(park)
        }
    }

    // MARK: - Sort Order

    func setSortOrder(_ order: SortOrder) {
        sortOrder = order
        Task {
            await storage.saveSortOrder(order)
        }
    }

    // MARK: - Favorites

    func toggleFavorite(_ entityId: String) {
        Task {
            let isFav = await storage.toggleFavorite(entityId)
            if isFav {
                favorites.insert(entityId)
            } else {
                favorites.remove(entityId)
            }
        }
    }

    func isFavorite(_ entityId: String) -> Bool {
        favorites.contains(entityId)
    }

    // MARK: - Notes

    func getNote(for entityId: String) -> String? {
        notes[entityId]
    }

    func saveNote(for entityId: String, text: String?) {
        if let text = text, !text.isEmpty {
            notes[entityId] = text
        } else {
            notes.removeValue(forKey: entityId)
        }
        Task {
            await storage.saveNote(for: entityId, text: text)
        }
    }

    // MARK: - Queue Management

    func startQueue(entity: Entity, queueType: QueueType) {
        guard let parkName = selectedPark?.name else { return }
        let queue = ActiveQueue(
            id: entity.id,
            rideName: entity.name,
            parkName: parkName,
            startTime: Date(),
            queueType: queueType,
            expectedWaitMinutes: liveData[entity.id]?.waitMinutes
        )
        activeQueues[entity.id] = queue
        Task {
            await storage.startQueue(queue)
        }
    }

    func endQueue(entity: Entity) {
        guard let queue = activeQueues[entity.id] else { return }

        let entry = RideHistoryEntry(
            rideId: entity.id,
            rideName: entity.name,
            parkName: queue.parkName,
            timestamp: Date(),
            expectedWaitMinutes: queue.expectedWaitMinutes,
            actualWaitMinutes: queue.elapsedMinutes,
            queueType: queue.queueType
        )

        activeQueues.removeValue(forKey: entity.id)
        rideHistory.insert(entry, at: 0)

        Task {
            _ = await storage.endQueue(rideId: entity.id)
            await storage.addToHistory(entry)
        }
    }

    func cancelQueue(entityId: String) {
        activeQueues.removeValue(forKey: entityId)
        Task {
            _ = await storage.endQueue(rideId: entityId)
        }
    }

    func isInQueue(_ entityId: String) -> Bool {
        activeQueues[entityId] != nil
    }

    func getActiveQueue(_ entityId: String) -> ActiveQueue? {
        activeQueues[entityId]
    }

    private func startQueueTimer() {
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    // MARK: - History Management

    func removeFromHistory(_ entry: RideHistoryEntry) {
        rideHistory.removeAll { $0.id == entry.id }
        Task {
            await storage.removeFromHistory(id: entry.id)
        }
    }

    func toggleDayCollapsed(_ dayKey: String) {
        if collapsedDays.contains(dayKey) {
            collapsedDays.remove(dayKey)
        } else {
            collapsedDays.insert(dayKey)
        }
        Task {
            await storage.toggleDayCollapsed(dayKey)
        }
    }

    func isDayCollapsed(_ dayKey: String) -> Bool {
        collapsedDays.contains(dayKey)
    }

    var groupedHistory: [(key: String, date: Date, entries: [RideHistoryEntry])] {
        let grouped = Dictionary(grouping: rideHistory) { $0.dayKey }
        return grouped.map { key, entries in
            let date = entries.first?.timestamp ?? Date()
            return (key: key, date: date, entries: entries.sorted { $0.timestamp > $1.timestamp })
        }.sorted { $0.date > $1.date }
    }

    // MARK: - History Statistics

    var totalRides: Int {
        rideHistory.count
    }

    var totalWaitTime: Int {
        rideHistory.compactMap { $0.actualWaitMinutes }.reduce(0, +)
    }

    var averageWaitTime: Int {
        let waits = rideHistory.compactMap { $0.actualWaitMinutes }
        guard !waits.isEmpty else { return 0 }
        return waits.reduce(0, +) / waits.count
    }

    var uniqueRides: Int {
        Set(rideHistory.map { $0.rideId }).count
    }

    // MARK: - Import/Export (Compressed Format)

    /// Export history in compressed format compatible with web version
    func exportHistoryEncoded() -> String {
        return DataEncoder.encodeHistory(rideHistory) ?? ""
    }

    /// Export notes in compressed format compatible with web version
    func exportNotesEncoded() -> String {
        return DataEncoder.encodeNotes(notes) ?? ""
    }

    /// Import data from any supported format (compressed or JSON)
    /// Automatically detects the format and type of data
    func importData(from text: String, strategy: ImportStrategy) -> ImportResult {
        let dataType = DataEncoder.detectDataType(text)

        switch dataType {
        case .compressedHistory:
            if let entries = DataEncoder.decodeHistory(text) {
                applyHistoryImport(entries, strategy: strategy)
                return .success(type: .history, count: entries.count)
            }
            return .failure(message: "Failed to decode history data")

        case .compressedNotes:
            if let notesData = DataEncoder.decodeNotes(text) {
                applyNotesImport(notesData, strategy: strategy)
                return .success(type: .notes, count: notesData.count)
            }
            return .failure(message: "Failed to decode notes data")

        case .jsonHistory:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let data = text.data(using: .utf8),
               let entries = try? decoder.decode([RideHistoryEntry].self, from: data) {
                applyHistoryImport(entries, strategy: strategy)
                return .success(type: .history, count: entries.count)
            }
            return .failure(message: "Failed to parse JSON history")

        case .jsonNotes:
            if let data = text.data(using: .utf8),
               let notesData = try? JSONDecoder().decode([String: String].self, from: data) {
                applyNotesImport(notesData, strategy: strategy)
                return .success(type: .notes, count: notesData.count)
            }
            return .failure(message: "Failed to parse JSON notes")

        case .unknown:
            return .failure(message: "Unrecognized data format")
        }
    }

    private func applyHistoryImport(_ entries: [RideHistoryEntry], strategy: ImportStrategy) {
        switch strategy {
        case .replace:
            rideHistory = entries
        case .merge:
            let existingIds = Set(rideHistory.map { $0.id })
            let newEntries = entries.filter { !existingIds.contains($0.id) }
            rideHistory.append(contentsOf: newEntries)
            rideHistory.sort { $0.timestamp > $1.timestamp }
        }

        Task {
            await storage.saveRideHistory(rideHistory)
        }
    }

    private func applyNotesImport(_ notesData: [String: String], strategy: ImportStrategy) {
        switch strategy {
        case .replace:
            notes = notesData
        case .merge:
            for (key, value) in notesData {
                if notes[key] == nil {
                    notes[key] = value
                }
            }
        }

        Task {
            await storage.saveNotes(notes)
        }
    }

    // MARK: - Import/Export (JSON Format - Legacy)

    func exportHistory() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(rideHistory),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    func importHistory(from json: String, strategy: ImportStrategy) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = json.data(using: .utf8),
              let imported = try? decoder.decode([RideHistoryEntry].self, from: data) else {
            return
        }

        applyHistoryImport(imported, strategy: strategy)
    }

    func exportNotes() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(notes),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    func importNotes(from json: String, strategy: ImportStrategy) {
        guard let data = json.data(using: .utf8),
              let imported = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }

        applyNotesImport(imported, strategy: strategy)
    }
}

// MARK: - Import Result

enum ImportResult {
    case success(type: ImportDataType, count: Int)
    case failure(message: String)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

enum ImportDataType: String {
    case history = "history entries"
    case notes = "notes"
}

enum AppTab: String, CaseIterable {
    case rides = "Rides"
    case history = "History"

    var icon: String {
        switch self {
        case .rides: return "list.bullet"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

enum ImportStrategy {
    case replace
    case merge
}
