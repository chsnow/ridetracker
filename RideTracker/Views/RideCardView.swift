import SwiftUI

struct RideCardView: View {
    @EnvironmentObject var appState: AppState
    let entity: Entity

    @State private var offset: CGFloat = 0
    @State private var isDraggingHorizontally = false
    @State private var showingQueueTypeSheet = false
    @State private var showingNoteEditor = false
    @State private var noteText: String = ""

    private var liveData: LiveData? {
        appState.liveData[entity.id]
    }

    private var activeQueue: ActiveQueue? {
        appState.getActiveQueue(entity.id)
    }

    private var isInQueue: Bool {
        appState.isInQueue(entity.id)
    }

    private var isFavorite: Bool {
        appState.isFavorite(entity.id)
    }

    private var note: String? {
        appState.getNote(for: entity.id)
    }

    private var hasLightningLane: Bool {
        liveData?.lightningLaneInfo != nil
    }

    var body: some View {
        ZStack {
            // Swipe Actions Background
            HStack(spacing: 0) {
                // Left side - revealed when swiping RIGHT (cancel queue)
                if isInQueue {
                    ZStack {
                        Color.red
                        VStack {
                            Image(systemName: "xmark.circle")
                                .font(.title)
                            Text("Cancel")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(.white)
                    }
                    .frame(width: 80)
                }

                Spacer()

                // Right side - revealed when swiping LEFT (start/log)
                ZStack {
                    Color.green
                    VStack {
                        Image(systemName: isInQueue ? "checkmark.circle" : "play.circle")
                            .font(.title)
                        Text(isInQueue ? "Log" : "Start")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(.white)
                }
                .frame(width: 80)
            }
            .cornerRadius(12)

            // Main Card
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack {
                    Text(entity.name)
                        .font(.headline)
                        .lineLimit(2)

                    Spacer()

                    // Note Button
                    Button {
                        noteText = note ?? ""
                        showingNoteEditor = true
                    } label: {
                        Image(systemName: note != nil ? "note.text" : "note.text.badge.plus")
                            .foregroundColor(note != nil ? .blue : .secondary)
                    }
                    .buttonStyle(.plain)

                    // Favorite Button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.toggleFavorite(entity.id)
                        }
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .foregroundColor(isFavorite ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Note Display
                if let note = note {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Status and Wait Time
                HStack {
                    if let status = liveData?.status {
                        StatusBadge(status: status)
                    }

                    Spacer()

                    // Wait Time
                    if let waitTime = liveData?.waitMinutes {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text("\(waitTime) min")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(.primary)
                    }

                    // Lightning Lane
                    if let ll = liveData?.lightningLaneInfo {
                        if ll.isSoldOut {
                            Text("LL Sold Out")
                                .font(.caption)
                                .foregroundColor(.red)
                        } else if let time = ll.formattedReturnTime {
                            HStack(spacing: 4) {
                                Image(systemName: "bolt.fill")
                                    .font(.caption)
                                Text(time)
                                    .font(.caption)
                                if liveData?.hasPaidLightningLane == true {
                                    if let price = ll.price?.formatted {
                                        Text(price)
                                            .font(.caption)
                                    }
                                }
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }

                // Distance
                if let coordinate = entity.coordinate,
                   let distance = appState.locationService.formattedDistance(to: coordinate) {
                    HStack {
                        Image(systemName: "location")
                            .font(.caption)
                        Text(distance)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                // Showtimes (for shows)
                if let showtimes = liveData?.showtimes, !showtimes.isEmpty {
                    ShowtimesView(showtimes: showtimes)
                }

                // Active Queue Timer
                if let queue = activeQueue {
                    QueueTimerView(queue: queue)
                }

                // Stale Data Warning
                if liveData?.isDataStale == true {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text("Data may be outdated")
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .offset(x: offset)
            .simultaneousGesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onChanged { gesture in
                        let horizontal = abs(gesture.translation.width)
                        let vertical = abs(gesture.translation.height)

                        // Once committed to horizontal, stay horizontal
                        if !isDraggingHorizontally {
                            // Only start horizontal drag if clearly horizontal (2:1 ratio)
                            guard horizontal > vertical * 2 && horizontal > 30 else { return }
                            isDraggingHorizontally = true
                        }

                        let translation = gesture.translation.width
                        if isInQueue {
                            offset = translation
                        } else {
                            offset = min(0, translation)
                        }
                    }
                    .onEnded { gesture in
                        if isDraggingHorizontally {
                            withAnimation(.spring()) {
                                if offset < -60 {
                                    if isInQueue {
                                        appState.endQueue(entity: entity)
                                    } else if hasLightningLane {
                                        showingQueueTypeSheet = true
                                    } else {
                                        appState.startQueue(entity: entity, queueType: .standby)
                                    }
                                } else if offset > 60 && isInQueue {
                                    appState.cancelQueue(entityId: entity.id)
                                }
                                offset = 0
                            }
                        }
                        isDraggingHorizontally = false
                    }
            )
        }
        .sheet(isPresented: $showingQueueTypeSheet) {
            QueueTypeSheet(entity: entity)
        }
        .sheet(isPresented: $showingNoteEditor) {
            NoteEditorSheet(
                entityName: entity.name,
                noteText: $noteText,
                onSave: { text in
                    appState.saveNote(for: entity.id, text: text.isEmpty ? nil : text)
                }
            )
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: RideStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(4)
    }

    private var statusColor: Color {
        switch status {
        case .operating: return .green
        case .closed: return .red
        case .down: return .orange
        case .refurbishment: return .purple
        }
    }
}

// MARK: - Showtimes View

struct ShowtimesView: View {
    let showtimes: [Showtime]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Showtimes")
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(showtimes) { showtime in
                        if let time = showtime.formattedTime {
                            Text(time)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    showtime.isPast
                                        ? Color(.systemGray5)
                                        : showtime.isNext
                                            ? Color.blue.opacity(0.2)
                                            : Color(.systemGray6)
                                )
                                .foregroundColor(
                                    showtime.isPast
                                        ? .secondary
                                        : showtime.isNext
                                            ? .blue
                                            : .primary
                                )
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Queue Timer View

struct QueueTimerView: View {
    let queue: ActiveQueue

    var body: some View {
        TimelineView(.periodic(from: queue.startTime, by: 1)) { context in
            HStack {
                Image(systemName: queue.queueType.icon)
                Text("In queue:")
                Text(formattedTime(at: context.date))
                    .font(.headline.monospacedDigit())

                Spacer()

                if let expected = queue.expectedWaitMinutes {
                    Text("Est: \(expected) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(queue.queueType == .lightningLane ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
            .cornerRadius(8)
        }
    }

    private func formattedTime(at date: Date) -> String {
        let elapsed = date.timeIntervalSince(queue.startTime)
        let minutes = Int(elapsed / 60)
        let seconds = Int(elapsed.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Queue Type Sheet

struct QueueTypeSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    let entity: Entity

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Select Queue Type")
                    .font(.headline)

                Button {
                    appState.startQueue(entity: entity, queueType: .standby)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "person.3")
                        Text("Standby")
                        Spacer()
                        if let wait = appState.liveData[entity.id]?.waitMinutes {
                            Text("\(wait) min")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button {
                    appState.startQueue(entity: entity, queueType: .lightningLane)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("Lightning Lane")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding()
            .navigationTitle(entity.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Note Editor Sheet

struct NoteEditorSheet: View {
    @Environment(\.dismiss) var dismiss
    let entityName: String
    @Binding var noteText: String
    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $noteText)
                    .padding()
            }
            .navigationTitle("Note for \(entityName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(noteText)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
