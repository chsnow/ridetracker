import Foundation

actor StorageService {
    static let shared = StorageService()

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let rideHistory = "disneyRideHistory"
        static let activeQueues = "disneyActiveQueues"
        static let favorites = "disneyFavorites"
        static let notes = "disneyNotes"
        static let collapsedDays = "disneyCollapsedDays"
        static let sortOrder = "disneySortOrder"
        static let lastParkId = "disneyLastParkId"
    }

    private init() {}

    // MARK: - Ride History

    func getRideHistory() -> [RideHistoryEntry] {
        guard let data = defaults.data(forKey: Keys.rideHistory) else { return [] }
        return (try? decoder.decode([RideHistoryEntry].self, from: data)) ?? []
    }

    func saveRideHistory(_ history: [RideHistoryEntry]) {
        if let data = try? encoder.encode(history) {
            defaults.set(data, forKey: Keys.rideHistory)
        }
    }

    func addToHistory(_ entry: RideHistoryEntry) {
        var history = getRideHistory()
        history.insert(entry, at: 0)
        saveRideHistory(history)
    }

    func removeFromHistory(at index: Int) {
        var history = getRideHistory()
        guard index >= 0 && index < history.count else { return }
        history.remove(at: index)
        saveRideHistory(history)
    }

    func removeFromHistory(id: UUID) {
        var history = getRideHistory()
        history.removeAll { $0.id == id }
        saveRideHistory(history)
    }

    // MARK: - Active Queues

    func getActiveQueues() -> [String: ActiveQueue] {
        guard let data = defaults.data(forKey: Keys.activeQueues) else { return [:] }
        return (try? decoder.decode([String: ActiveQueue].self, from: data)) ?? [:]
    }

    func saveActiveQueues(_ queues: [String: ActiveQueue]) {
        if let data = try? encoder.encode(queues) {
            defaults.set(data, forKey: Keys.activeQueues)
        }
    }

    func startQueue(_ queue: ActiveQueue) {
        var queues = getActiveQueues()
        queues[queue.id] = queue
        saveActiveQueues(queues)
    }

    func endQueue(rideId: String) -> ActiveQueue? {
        var queues = getActiveQueues()
        let queue = queues.removeValue(forKey: rideId)
        saveActiveQueues(queues)
        return queue
    }

    func isInQueue(rideId: String) -> Bool {
        getActiveQueues()[rideId] != nil
    }

    func getActiveQueue(rideId: String) -> ActiveQueue? {
        getActiveQueues()[rideId]
    }

    // MARK: - Favorites

    func getFavorites() -> Set<String> {
        guard let data = defaults.data(forKey: Keys.favorites) else { return [] }
        return (try? decoder.decode(Set<String>.self, from: data)) ?? []
    }

    func saveFavorites(_ favorites: Set<String>) {
        if let data = try? encoder.encode(favorites) {
            defaults.set(data, forKey: Keys.favorites)
        }
    }

    func isFavorite(_ entityId: String) -> Bool {
        getFavorites().contains(entityId)
    }

    func toggleFavorite(_ entityId: String) -> Bool {
        var favorites = getFavorites()
        if favorites.contains(entityId) {
            favorites.remove(entityId)
        } else {
            favorites.insert(entityId)
        }
        saveFavorites(favorites)
        return favorites.contains(entityId)
    }

    // MARK: - Notes

    func getNotes() -> [String: String] {
        guard let data = defaults.data(forKey: Keys.notes) else { return [:] }
        return (try? decoder.decode([String: String].self, from: data)) ?? [:]
    }

    func saveNotes(_ notes: [String: String]) {
        if let data = try? encoder.encode(notes) {
            defaults.set(data, forKey: Keys.notes)
        }
    }

    func getNote(for entityId: String) -> String? {
        getNotes()[entityId]
    }

    func saveNote(for entityId: String, text: String?) {
        var notes = getNotes()
        if let text = text, !text.isEmpty {
            notes[entityId] = text
        } else {
            notes.removeValue(forKey: entityId)
        }
        saveNotes(notes)
    }

    // MARK: - Collapsed Days

    func getCollapsedDays() -> Set<String> {
        guard let data = defaults.data(forKey: Keys.collapsedDays) else { return [] }
        return (try? decoder.decode(Set<String>.self, from: data)) ?? []
    }

    func saveCollapsedDays(_ days: Set<String>) {
        if let data = try? encoder.encode(days) {
            defaults.set(data, forKey: Keys.collapsedDays)
        }
    }

    func isDayCollapsed(_ dayKey: String) -> Bool {
        getCollapsedDays().contains(dayKey)
    }

    func toggleDayCollapsed(_ dayKey: String) {
        var collapsed = getCollapsedDays()
        if collapsed.contains(dayKey) {
            collapsed.remove(dayKey)
        } else {
            collapsed.insert(dayKey)
        }
        saveCollapsedDays(collapsed)
    }

    // MARK: - Sort Order

    func getSortOrder() -> SortOrder {
        guard let rawValue = defaults.string(forKey: Keys.sortOrder),
              let order = SortOrder(rawValue: rawValue) else {
            return .waitTime
        }
        return order
    }

    func saveSortOrder(_ order: SortOrder) {
        defaults.set(order.rawValue, forKey: Keys.sortOrder)
    }

    // MARK: - Last Park

    func getLastParkId() -> String? {
        defaults.string(forKey: Keys.lastParkId)
    }

    func saveLastParkId(_ parkId: String) {
        defaults.set(parkId, forKey: Keys.lastParkId)
    }
}

enum SortOrder: String, CaseIterable {
    case waitTime = "waitTime"
    case name = "name"
    case distance = "distance"

    var displayName: String {
        switch self {
        case .waitTime: return "Wait Time"
        case .name: return "Name"
        case .distance: return "Distance"
        }
    }

    var icon: String {
        switch self {
        case .waitTime: return "clock"
        case .name: return "textformat.abc"
        case .distance: return "location"
        }
    }
}
