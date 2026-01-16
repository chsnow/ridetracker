import Foundation
import UIKit
import FirebaseMessaging
import UserNotifications

class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var fcmToken: String?
    @Published var lastNotification: NotificationPayload?
    @Published var registrationStatus: DeviceRegistrationStatus = .unregistered
    @Published var lastRegistrationError: String?

    private var registrationTask: Task<Void, Never>?
    private let registeredTokenKey = "registeredFCMToken"

    private init() {}

    // MARK: - Device Registration

    /// Register the current FCM token with the ride-watch backend
    func registerDevice() {
        guard let token = fcmToken else {
            print("Cannot register device: No FCM token available")
            return
        }

        // Cancel any existing registration task
        registrationTask?.cancel()

        registrationTask = Task {
            await performRegistration(token: token)
        }
    }

    private func performRegistration(token: String) async {
        // Check if already registered with this token
        let storedToken = UserDefaults.standard.string(forKey: registeredTokenKey)
        if storedToken == token && registrationStatus == .registered {
            print("Device already registered with this token")
            return
        }

        await MainActor.run {
            self.registrationStatus = .registering
            self.lastRegistrationError = nil
        }

        do {
            let response = try await RideWatchAPI.shared.registerDeviceWithRetry(
                token: token,
                deviceName: UIDevice.current.name
            )

            if response.success {
                // Store the registered token
                UserDefaults.standard.set(token, forKey: registeredTokenKey)

                await MainActor.run {
                    self.registrationStatus = .registered
                    print("Device registered successfully: \(response.message)")
                }

                // Post notification for listeners
                NotificationCenter.default.post(
                    name: .deviceRegistered,
                    object: nil,
                    userInfo: ["token": token]
                )
            } else {
                await MainActor.run {
                    self.registrationStatus = .failed
                    self.lastRegistrationError = response.message
                }
            }
        } catch {
            await MainActor.run {
                self.registrationStatus = .failed
                self.lastRegistrationError = error.localizedDescription
                print("Device registration failed: \(error.localizedDescription)")
            }
        }
    }

    /// Unregister the device from push notifications
    func unregisterDevice() async {
        guard let token = fcmToken else {
            print("Cannot unregister device: No FCM token available")
            return
        }

        await MainActor.run {
            self.registrationStatus = .unregistering
        }

        do {
            try await RideWatchAPI.shared.unregisterDevice(token: token)

            // Clear stored token
            UserDefaults.standard.removeObject(forKey: registeredTokenKey)

            await MainActor.run {
                self.registrationStatus = .unregistered
                print("Device unregistered successfully")
            }

            NotificationCenter.default.post(
                name: .deviceUnregistered,
                object: nil
            )
        } catch {
            await MainActor.run {
                self.registrationStatus = .failed
                self.lastRegistrationError = error.localizedDescription
                print("Device unregistration failed: \(error.localizedDescription)")
            }
        }
    }

    /// Called when a new FCM token is received (initial or refresh)
    func handleTokenRefresh(_ token: String) {
        let previousToken = fcmToken

        DispatchQueue.main.async {
            self.fcmToken = token
        }

        // If token changed, re-register
        if previousToken != token {
            print("FCM token changed, re-registering device...")
            registerDevice()
        }
    }

    /// Check if the device needs registration (e.g., on app launch)
    func checkAndRegisterIfNeeded() {
        guard let token = fcmToken else { return }

        let storedToken = UserDefaults.standard.string(forKey: registeredTokenKey)

        // Register if token is new or different from stored
        if storedToken != token || registrationStatus != .registered {
            registerDevice()
        }
    }

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

        // Extract custom data - support both old and new field names
        let type = userInfo["type"] as? String

        // Ride-watch backend fields
        let rideId = userInfo["rideId"] as? String
        let rideName = userInfo["rideName"] as? String
        let oldStatus = userInfo["oldStatus"] as? String
        let newStatus = userInfo["newStatus"] as? String

        // Legacy fields (for backwards compatibility)
        let entityId = userInfo["entityId"] as? String ?? rideId
        let parkId = userInfo["parkId"] as? String

        return NotificationPayload(
            title: title,
            body: body,
            type: NotificationType(rawValue: type ?? ""),
            entityId: entityId,
            parkId: parkId,
            rideId: rideId,
            rideName: rideName,
            oldStatus: oldStatus,
            newStatus: newStatus,
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

    // Ride-watch backend specific fields
    let rideId: String?
    let rideName: String?
    let oldStatus: String?
    let newStatus: String?

    let rawData: [AnyHashable: Any]

    /// Check if this is a ride status change notification from ride-watch
    var isRideStatusChange: Bool {
        return type == .statusChange || type == .rideStatusChange
    }

    /// Check if this is a test notification
    var isTestNotification: Bool {
        return type == .test
    }
}

enum NotificationType: String {
    // Legacy notification types
    case waitTimeAlert = "wait_time_alert"
    case rideStatusChange = "ride_status_change"
    case lightningLaneUpdate = "lightning_lane_update"
    case general = "general"

    // Ride-watch backend notification types
    case statusChange = "status_change"
    case test = "test"
}

// MARK: - Device Registration Status

enum DeviceRegistrationStatus: String {
    case unregistered
    case registering
    case registered
    case unregistering
    case failed

    var displayText: String {
        switch self {
        case .unregistered:
            return "Not registered"
        case .registering:
            return "Registering..."
        case .registered:
            return "Registered for notifications"
        case .unregistering:
            return "Unregistering..."
        case .failed:
            return "Registration failed"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let pushNotificationReceived = Notification.Name("pushNotificationReceived")
    static let pushNotificationTapped = Notification.Name("pushNotificationTapped")
    static let deviceRegistered = Notification.Name("deviceRegistered")
    static let deviceUnregistered = Notification.Name("deviceUnregistered")
}
