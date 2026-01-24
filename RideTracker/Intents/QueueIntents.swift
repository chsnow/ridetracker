import AppIntents
import ActivityKit

// MARK: - Cancel Queue Intent

struct CancelQueueIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Cancel Queue"
    static var description = IntentDescription("Cancel the queue timer without logging a ride")

    @Parameter(title: "Ride ID")
    var rideId: String

    init() {}

    init(rideId: String) {
        self.rideId = rideId
    }

    func perform() async throws -> some IntentResult {
        // Remove queue from storage
        _ = await StorageService.shared.endQueue(rideId: rideId)

        // End the Live Activity
        for activity in Activity<QueueTimerAttributes>.activities {
            if activity.attributes.rideId == rideId {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        return .result()
    }
}

// MARK: - Log Queue Intent

struct LogQueueIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log Ride"
    static var description = IntentDescription("Log the ride to history and end the queue timer")

    @Parameter(title: "Ride ID")
    var rideId: String

    init() {}

    init(rideId: String) {
        self.rideId = rideId
    }

    func perform() async throws -> some IntentResult {
        // Get queue data before removing it
        if let queue = await StorageService.shared.getActiveQueue(rideId: rideId) {
            // Create history entry
            let entry = RideHistoryEntry(
                rideId: rideId,
                rideName: queue.rideName,
                parkName: queue.parkName,
                timestamp: Date(),
                expectedWaitMinutes: queue.expectedWaitMinutes,
                actualWaitMinutes: queue.elapsedMinutes,
                queueType: queue.queueType
            )

            // Save to history
            await StorageService.shared.addToHistory(entry)
        }

        // Remove queue from storage
        _ = await StorageService.shared.endQueue(rideId: rideId)

        // End the Live Activity
        for activity in Activity<QueueTimerAttributes>.activities {
            if activity.attributes.rideId == rideId {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        return .result()
    }
}
