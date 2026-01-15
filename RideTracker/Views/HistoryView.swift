import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingShareSheet = false
    @State private var showingImportSheet = false
    @State private var showingTripReportSheet = false
    @State private var showingQRShareSheet = false
    @State private var showingQRScanner = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Statistics Header
                if !appState.rideHistory.isEmpty {
                    HistoryStatsView()
                }

                // History List
                if appState.rideHistory.isEmpty {
                    EmptyHistoryView()
                } else {
                    HistoryListView()
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            showingImportSheet = true
                        } label: {
                            Label("Import Text/JSON", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            showingQRScanner = true
                        } label: {
                            Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingShareSheet = true
                        } label: {
                            Label("Share as Text", systemImage: "doc.text")
                        }

                        Button {
                            showingQRShareSheet = true
                        } label: {
                            Label("Share QR Code", systemImage: "qrcode")
                        }

                        Divider()

                        Button {
                            showingTripReportSheet = true
                        } label: {
                            Label("Trip Report", systemImage: "list.bullet.clipboard")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(appState.rideHistory.isEmpty)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [appState.exportHistory()])
            }
            .sheet(isPresented: $showingImportSheet) {
                ImportSheet()
            }
            .sheet(isPresented: $showingTripReportSheet) {
                TripReportSheet()
            }
            .sheet(isPresented: $showingQRShareSheet) {
                QRCodeShareSheet()
            }
            .sheet(isPresented: $showingQRScanner) {
                QRScannerSheet()
            }
        }
    }
}

// MARK: - Statistics View

struct HistoryStatsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            StatItem(value: "\(appState.totalRides)", label: "Rides")
            Divider()
            StatItem(value: "\(appState.uniqueRides)", label: "Unique")
            Divider()
            StatItem(value: "\(appState.totalWaitTime)", label: "Total Min")
            Divider()
            StatItem(value: "\(appState.averageWaitTime)", label: "Avg Min")
        }
        .frame(height: 60)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
}

struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - History List

struct HistoryListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(appState.groupedHistory, id: \.key) { group in
                    HistoryDaySection(
                        dayKey: group.key,
                        date: group.date,
                        entries: group.entries
                    )
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Day Section

struct HistoryDaySection: View {
    @EnvironmentObject var appState: AppState
    let dayKey: String
    let date: Date
    let entries: [RideHistoryEntry]

    private var isCollapsed: Bool {
        appState.isDayCollapsed(dayKey)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    private var parkSummary: String {
        let parks = Set(entries.map { $0.parkName })
        return parks.map { parkShortName($0) }.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Day Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.toggleDayCollapsed(dayKey)
                }
            } label: {
                HStack {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isToday ? "Today" : formatDate(date))
                            .font(.subheadline.weight(.semibold))
                        Text(parkSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("\(entries.count)")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .buttonStyle(.plain)

            // Entries
            if !isCollapsed {
                ForEach(entries) { entry in
                    HistoryItemView(entry: entry)
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func parkShortName(_ name: String) -> String {
        if name.contains("California Adventure") {
            return "DCA"
        } else if name.contains("Disneyland") {
            return "DL"
        }
        return name
    }
}

// MARK: - History Item

struct HistoryItemView: View {
    @EnvironmentObject var appState: AppState
    let entry: RideHistoryEntry
    @State private var offset: CGFloat = 0

    var body: some View {
        ZStack {
            // Delete action
            HStack {
                Spacer()
                ZStack {
                    Color.red
                    VStack {
                        Image(systemName: "trash")
                        Text("Delete")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                }
                .frame(width: 80)
            }

            // Main Content
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.rideName)
                            .font(.subheadline.weight(.medium))

                        if entry.queueType == .lightningLane {
                            Text("LL")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 8) {
                        Text(parkShortName(entry.parkName))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(entry.formattedTime)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Wait Times
                VStack(alignment: .trailing, spacing: 2) {
                    if let actual = entry.actualWaitMinutes {
                        Text("\(actual) min")
                            .font(.subheadline.weight(.semibold))
                    }
                    if let expected = entry.expectedWaitMinutes {
                        Text("Posted: \(expected)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onChanged { gesture in
                        // Only respond to horizontal swipes
                        let horizontal = abs(gesture.translation.width)
                        let vertical = abs(gesture.translation.height)
                        guard horizontal > vertical else { return }
                        offset = min(0, gesture.translation.width)
                    }
                    .onEnded { gesture in
                        withAnimation(.spring()) {
                            if offset < -80 {
                                appState.removeFromHistory(entry)
                            }
                            offset = 0
                        }
                    }
            )
        }
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }

    private func parkShortName(_ name: String) -> String {
        if name.contains("California Adventure") {
            return "DCA"
        } else if name.contains("Disneyland") {
            return "DL"
        }
        return name
    }
}

// MARK: - Empty State

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No ride history yet")
                .font(.headline)

            Text("Swipe left on a ride to start tracking your queue time")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Import Sheet

struct ImportSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var importText = ""
    @State private var importType: ImportType = .history

    enum ImportType: String, CaseIterable {
        case history = "History"
        case notes = "Notes"
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Import Type", selection: $importType) {
                    ForEach(ImportType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)

                Section("Paste JSON Data") {
                    TextEditor(text: $importText)
                        .frame(minHeight: 200)
                }

                Section {
                    Button("Replace All") {
                        performImport(strategy: .replace)
                    }
                    .disabled(importText.isEmpty)

                    Button("Merge") {
                        performImport(strategy: .merge)
                    }
                    .disabled(importText.isEmpty)
                }
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func performImport(strategy: ImportStrategy) {
        switch importType {
        case .history:
            appState.importHistory(from: importText, strategy: strategy)
        case .notes:
            appState.importNotes(from: importText, strategy: strategy)
        }
        dismiss()
    }
}

// MARK: - Trip Report Sheet

struct TripReportSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var selectedDays: Set<String> = []
    @State private var showingReport = false
    @State private var reportText = ""

    var body: some View {
        NavigationStack {
            VStack {
                // Day Selection
                List {
                    Section("Select Days") {
                        ForEach(appState.groupedHistory, id: \.key) { group in
                            Button {
                                if selectedDays.contains(group.key) {
                                    selectedDays.remove(group.key)
                                } else {
                                    selectedDays.insert(group.key)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: selectedDays.contains(group.key) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedDays.contains(group.key) ? .blue : .secondary)

                                    VStack(alignment: .leading) {
                                        Text(formatDate(group.date))
                                        Text("\(group.entries.count) rides")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Generate Button
                Button {
                    generateReport()
                } label: {
                    Text("Generate Report")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedDays.isEmpty)
                .padding()
            }
            .navigationTitle("Trip Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Select All") {
                        selectedDays = Set(appState.groupedHistory.map { $0.key })
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingReport) {
                TripReportPreview(reportText: reportText)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func generateReport() {
        var report = "Trip Report\n"
        report += "===========\n\n"

        let selectedHistory = appState.groupedHistory.filter { selectedDays.contains($0.key) }

        for group in selectedHistory {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d, yyyy"
            report += "\(formatter.string(from: group.date))\n"
            report += String(repeating: "-", count: 40) + "\n"

            for entry in group.entries {
                let time = entry.formattedTime
                let queue = entry.queueType == .lightningLane ? " (LL)" : ""
                var line = "\(time) - \(entry.rideName)\(queue)"

                if let actual = entry.actualWaitMinutes {
                    line += " - \(actual) min wait"
                }

                report += line + "\n"
            }

            let totalRides = group.entries.count
            let totalWait = group.entries.compactMap { $0.actualWaitMinutes }.reduce(0, +)
            report += "\nTotal: \(totalRides) rides, \(totalWait) minutes in queues\n\n"
        }

        reportText = report
        showingReport = true
    }
}

// MARK: - Trip Report Preview

struct TripReportPreview: View {
    @Environment(\.dismiss) var dismiss
    let reportText: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(reportText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Trip Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: reportText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
