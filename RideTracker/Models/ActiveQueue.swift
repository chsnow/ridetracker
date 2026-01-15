import Foundation

struct ActiveQueue: Codable, Identifiable {
    let id: String // rideId
    let rideName: String
    let parkName: String
    let startTime: Date
    let queueType: QueueType
    let expectedWaitMinutes: Int?

    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    var elapsedMinutes: Int {
        Int(elapsedTime / 60)
    }

    var formattedElapsedTime: String {
        let minutes = Int(elapsedTime / 60)
        let seconds = Int(elapsedTime.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
}
