import Foundation

struct RideHistoryEntry: Codable, Identifiable {
    let id: UUID
    let rideId: String
    let rideName: String
    let parkName: String
    let timestamp: Date
    let expectedWaitMinutes: Int?
    let actualWaitMinutes: Int?
    let queueType: QueueType

    init(
        id: UUID = UUID(),
        rideId: String,
        rideName: String,
        parkName: String,
        timestamp: Date = Date(),
        expectedWaitMinutes: Int? = nil,
        actualWaitMinutes: Int? = nil,
        queueType: QueueType = .standby
    ) {
        self.id = id
        self.rideId = rideId
        self.rideName = rideName
        self.parkName = parkName
        self.timestamp = timestamp
        self.expectedWaitMinutes = expectedWaitMinutes
        self.actualWaitMinutes = actualWaitMinutes
        self.queueType = queueType
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: timestamp)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: timestamp)
    }

    var dayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: timestamp)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(timestamp)
    }
}

enum QueueType: String, Codable {
    case standby = "standby"
    case lightningLane = "lightningLane"

    var displayName: String {
        switch self {
        case .standby: return "Standby"
        case .lightningLane: return "Lightning Lane"
        }
    }

    var shortName: String {
        switch self {
        case .standby: return "SB"
        case .lightningLane: return "LL"
        }
    }

    var icon: String {
        switch self {
        case .standby: return "person.3"
        case .lightningLane: return "bolt.fill"
        }
    }
}
