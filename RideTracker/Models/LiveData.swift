import Foundation

struct LiveDataResponse: Codable {
    let id: String
    let name: String
    let liveData: [LiveData]
}

struct LiveData: Codable, Identifiable {
    let id: String
    let name: String
    let status: RideStatus?
    let queue: QueueInfo?
    let showtimes: [Showtime]?
    let lastUpdated: String?

    var waitMinutes: Int? {
        queue?.standby?.waitTime
    }

    var lightningLaneInfo: LightningLane? {
        queue?.lightningLane
    }

    var isDataStale: Bool {
        guard let lastUpdated = lastUpdated,
              let date = ISO8601DateFormatter().date(from: lastUpdated) else {
            return false
        }
        return Date().timeIntervalSince(date) > 3600 // 1 hour
    }
}

struct QueueInfo: Codable {
    let standby: StandbyQueue?
    let lightningLane: LightningLane?

    enum CodingKeys: String, CodingKey {
        case standby = "STANDBY"
        case lightningLane = "PAID_RETURN_TIME"
    }
}

struct StandbyQueue: Codable {
    let waitTime: Int?
}

struct LightningLane: Codable {
    let returnStart: String?
    let returnEnd: String?
    let price: PriceInfo?
    let state: String?

    var isSoldOut: Bool {
        state == "FINISHED"
    }

    var formattedReturnTime: String? {
        guard let returnStart = returnStart else { return nil }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: returnStart) else { return nil }
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return timeFormatter.string(from: date)
    }
}

struct PriceInfo: Codable {
    let amount: Double?
    let currency: String?

    var formatted: String? {
        guard let amount = amount else { return nil }
        return String(format: "$%.0f", amount)
    }
}

struct Showtime: Codable, Identifiable {
    let type: String?
    let startTime: String?
    let endTime: String?

    var id: String {
        startTime ?? UUID().uuidString
    }

    var formattedTime: String? {
        guard let startTime = startTime else { return nil }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: startTime) else { return nil }
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return timeFormatter.string(from: date)
    }

    var isPast: Bool {
        guard let startTime = startTime else { return false }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: startTime) else { return false }
        return date < Date()
    }

    var isNext: Bool {
        guard let startTime = startTime else { return false }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: startTime) else { return false }
        let now = Date()
        return date > now && date.timeIntervalSince(now) < 1800 // within 30 min
    }
}

enum RideStatus: String, Codable {
    case operating = "OPERATING"
    case closed = "CLOSED"
    case down = "DOWN"
    case refurbishment = "REFURBISHMENT"

    var displayName: String {
        switch self {
        case .operating: return "Operating"
        case .closed: return "Closed"
        case .down: return "Temporarily Closed"
        case .refurbishment: return "Refurbishment"
        }
    }

    var color: String {
        switch self {
        case .operating: return "StatusGreen"
        case .closed: return "StatusRed"
        case .down: return "StatusOrange"
        case .refurbishment: return "StatusPurple"
        }
    }
}
