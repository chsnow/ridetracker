import Foundation
import FirebaseMessaging
import UserNotifications

class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var fcmToken: String?
    @Published var lastNotification: NotificationPayload?

    private init() {}

    // MARK: - Topic Subscription

    func subscribeToTopic(_ topic: String) {
        Messaging.messaging().subscribe(toTopic: topic) { error in
            if let error = error {
                print("Error subscribing to topic \(topic): \(error.localizedDescription)")
            } else {
                print("Subscribed to topic: \(topic)")
            }
        }
    }

    func unsubscribeFromTopic(_ topic: String) {
        Messaging.messaging().unsubscribe(fromTopic: topic) { error in
            if let error = error {
                print("Error unsubscribing from topic \(topic): \(error.localizedDescription)")
            } else {
                print("Unsubscribed from topic: \(topic)")
            }
        }
    }

    // MARK: - Notification Handling

    func handleNotification(userInfo: [AnyHashable: Any]) {
        guard let payload = parseNotificationPayload(userInfo) else { return }

        DispatchQueue.main.async {
            self.lastNotification = payload
        }

        // Post notification for any listeners
        NotificationCenter.default.post(
            name: .pushNotificationReceived,
            object: nil,
            userInfo: ["payload": payload]
        )
    }

    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let payload = parseNotificationPayload(userInfo) else { return }

        // Post notification for navigation handling
        NotificationCenter.default.post(
            name: .pushNotificationTapped,
            object: nil,
            userInfo: ["payload": payload]
        )
    }

    private func parseNotificationPayload(_ userInfo: [AnyHashable: Any]) -> NotificationPayload? {
        // Extract standard notification fields
        let aps = userInfo["aps"] as? [String: Any]
        let alert = aps?["alert"] as? [String: Any]

        let title = alert?["title"] as? String
        let body = alert?["body"] as? String

        // Extract custom data
        let type = userInfo["type"] as? String
        let entityId = userInfo["entityId"] as? String
        let parkId = userInfo["parkId"] as? String

        return NotificationPayload(
            title: title,
            body: body,
            type: NotificationType(rawValue: type ?? ""),
            entityId: entityId,
            parkId: parkId,
            rawData: userInfo
        )
    }

    // MARK: - Permission Status

    func checkNotificationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            print("Notification permission error: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Notification Payload

struct NotificationPayload {
    let title: String?
    let body: String?
    let type: NotificationType?
    let entityId: String?
    let parkId: String?
    let rawData: [AnyHashable: Any]
}

enum NotificationType: String {
    case waitTimeAlert = "wait_time_alert"
    case rideStatusChange = "ride_status_change"
    case lightningLaneUpdate = "lightning_lane_update"
    case general = "general"
}

// MARK: - Notification Names

extension Notification.Name {
    static let pushNotificationReceived = Notification.Name("pushNotificationReceived")
    static let pushNotificationTapped = Notification.Name("pushNotificationTapped")
}
