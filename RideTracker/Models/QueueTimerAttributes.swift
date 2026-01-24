import Foundation
import ActivityKit

struct QueueTimerAttributes: ActivityAttributes {
    let rideId: String
    let rideName: String
    let parkName: String
    let queueType: String  // "standby" or "lightningLane"
    let expectedWaitMinutes: Int?

    struct ContentState: Codable, Hashable {
        let startTime: Date
    }
}
