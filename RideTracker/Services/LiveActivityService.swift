import Foundation
import ActivityKit

@MainActor
class LiveActivityService {
    static let shared = LiveActivityService()

    private var activities: [String: Activity<QueueTimerAttributes>] = [:]

    private init() {}

    func startActivity(for queue: ActiveQueue) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }

        let attributes = QueueTimerAttributes(
            rideId: queue.id,
            rideName: queue.rideName,
            parkName: queue.parkName,
            queueType: queue.queueType.rawValue,
            expectedWaitMinutes: queue.expectedWaitMinutes
        )

        let contentState = QueueTimerAttributes.ContentState(
            startTime: queue.startTime
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            activities[queue.id] = activity
            print("Started Live Activity for \(queue.rideName)")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    func endActivity(for rideId: String) {
        Task {
            if let activity = activities[rideId] {
                await activity.end(nil, dismissalPolicy: .immediate)
                activities.removeValue(forKey: rideId)
                print("Ended Live Activity for rideId: \(rideId)")
            } else {
                // Try to find and end any activity with matching rideId
                for activity in Activity<QueueTimerAttributes>.activities {
                    if activity.attributes.rideId == rideId {
                        await activity.end(nil, dismissalPolicy: .immediate)
                        print("Ended orphaned Live Activity for rideId: \(rideId)")
                    }
                }
            }
        }
    }

    func restoreActivities(activeQueues: [String: ActiveQueue]) {
        // End any orphaned activities that don't have corresponding active queues
        for activity in Activity<QueueTimerAttributes>.activities {
            let rideId = activity.attributes.rideId
            if activeQueues[rideId] != nil {
                // Activity matches an active queue, track it
                activities[rideId] = activity
                print("Restored Live Activity for rideId: \(rideId)")
            } else {
                // Orphaned activity, end it
                Task {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    print("Ended orphaned Live Activity for rideId: \(rideId)")
                }
            }
        }

        // Start activities for any active queues that don't have activities
        for (rideId, queue) in activeQueues {
            if activities[rideId] == nil {
                startActivity(for: queue)
            }
        }
    }

    func endAllActivities() {
        Task {
            for activity in Activity<QueueTimerAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            activities.removeAll()
            print("Ended all Live Activities")
        }
    }
}
