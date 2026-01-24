import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents

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

// MARK: - App Intents for Live Activity Buttons
// Note: These are stub definitions for the widget to reference.
// The actual implementation runs in the main app target.

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
        // Implementation is in the main app target
        return .result()
    }
}

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
        // Implementation is in the main app target
        return .result()
    }
}

struct QueueTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QueueTimerAttributes.self) { context in
            // Lock Screen / Notification presentation
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded region
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: queueTypeIcon(context.attributes.queueType))
                            .font(.title2)
                            .foregroundStyle(queueTypeColor(context.attributes.queueType))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(context.attributes.rideName)
                                .font(.headline)
                                .lineLimit(1)
                            Text(queueTypeDisplayName(context.attributes.queueType))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.startTime, style: .timer)
                            .font(.title2.monospacedDigit())
                            .foregroundStyle(.primary)

                        if let expected = context.attributes.expectedWaitMinutes {
                            Text("Est: \(expected)m")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.trailing, 4)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        Button(intent: CancelQueueIntent(rideId: context.attributes.rideId)) {
                            Label("Cancel", systemImage: "xmark.circle")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(intent: LogQueueIntent(rideId: context.attributes.rideId)) {
                            Label("Log", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(queueTypeColor(context.attributes.queueType))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: queueTypeIcon(context.attributes.queueType))
                    .foregroundStyle(queueTypeColor(context.attributes.queueType))
            } compactTrailing: {
                Text(context.state.startTime, style: .timer)
                    .monospacedDigit()
                    .frame(minWidth: 40)
            } minimal: {
                Image(systemName: "clock")
                    .foregroundStyle(queueTypeColor(context.attributes.queueType))
            }
        }
    }

    private func queueTypeIcon(_ queueType: String) -> String {
        queueType == "lightningLane" ? "bolt.fill" : "person.3"
    }

    private func queueTypeDisplayName(_ queueType: String) -> String {
        queueType == "lightningLane" ? "Lightning Lane" : "Standby"
    }

    private func queueTypeColor(_ queueType: String) -> Color {
        queueType == "lightningLane" ? Color(red: 0.173, green: 0.659, blue: 0.345) : Color(red: 0.149, green: 0.376, blue: 0.659)
    }
}

struct LockScreenView: View {
    let context: ActivityViewContext<QueueTimerAttributes>

    var body: some View {
        VStack(spacing: 12) {
            // Top row: Ride info and timer
            HStack {
                // Left side: Icon and ride info
                HStack(spacing: 12) {
                    Image(systemName: queueTypeIcon)
                        .font(.title)
                        .foregroundStyle(queueTypeColor)
                        .frame(width: 44, height: 44)
                        .background(queueTypeColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.rideName)
                            .font(.headline)
                            .lineLimit(1)

                        Text(queueTypeDisplayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Right side: Timer and expected wait
                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.startTime, style: .timer)
                        .font(.title2.monospacedDigit().weight(.semibold))

                    if let expected = context.attributes.expectedWaitMinutes {
                        Text("Est: \(expected) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Bottom row: Action buttons
            HStack(spacing: 12) {
                Button(intent: CancelQueueIntent(rideId: context.attributes.rideId)) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Cancel")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.15))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button(intent: LogQueueIntent(rideId: context.attributes.rideId)) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Log Ride")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(queueTypeColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.8))
        .activitySystemActionForegroundColor(.white)
    }

    private var queueTypeIcon: String {
        context.attributes.queueType == "lightningLane" ? "bolt.fill" : "person.3"
    }

    private var queueTypeDisplayName: String {
        context.attributes.queueType == "lightningLane" ? "Lightning Lane" : "Standby"
    }

    private var queueTypeColor: Color {
        context.attributes.queueType == "lightningLane" ? Color(red: 0.173, green: 0.659, blue: 0.345) : Color(red: 0.149, green: 0.376, blue: 0.659)
    }
}

#Preview("Lock Screen", as: .content, using: QueueTimerAttributes(
    rideId: "preview-1",
    rideName: "Space Mountain",
    parkName: "Disneyland",
    queueType: "standby",
    expectedWaitMinutes: 45
)) {
    QueueTimerLiveActivity()
} contentStates: {
    QueueTimerAttributes.ContentState(startTime: Date().addingTimeInterval(-754))
}
