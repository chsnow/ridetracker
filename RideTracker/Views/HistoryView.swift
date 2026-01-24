import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingExportSheet = false
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
                            Label("Import Data", systemImage: "square.and.arrow.down")
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
                            showingExportSheet = true
                        } label: {
                            Label("Export Data", systemImage: "doc.text")
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
            .sheet(isPresented: $showingExportSheet) {
                ExportSheet()
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
        return parks.sorted().map { parkShortName($0) }.joined(separator: ", ")
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
    @State private var isDraggingHorizontally = false

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
                                .background(Color(red: 0.173, green: 0.659, blue: 0.345))
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
            .simultaneousGesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onChanged { gesture in
                        let horizontal = abs(gesture.translation.width)
                        let vertical = abs(gesture.translation.height)

                        if !isDraggingHorizontally {
                            guard horizontal > vertical * 2 && horizontal > 30 else { return }
                            isDraggingHorizontally = true
                        }

                        offset = min(0, gesture.translation.width)
                    }
                    .onEnded { gesture in
                        if isDraggingHorizontally {
                            withAnimation(.spring()) {
                                if offset < -80 {
                                    appState.removeFromHistory(entry)
                                }
                                offset = 0
                            }
                        }
                        isDraggingHorizontally = false
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

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Present the activity view controller when the view appears
        if uiViewController.presentedViewController == nil {
            let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

            // For iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = uiViewController.view
                popover.sourceRect = CGRect(x: uiViewController.view.bounds.midX, y: uiViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }

            DispatchQueue.main.async {
                uiViewController.present(activityVC, animated: true)
            }
        }
    }
}

// MARK: - Import Sheet

struct ImportSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var importText = ""
    @State private var showingResult = false
    @State private var resultMessage = ""
    @State private var resultIsError = false

    private var detectedFormat: String {
        let dataType = DataEncoder.detectDataType(importText)
        switch dataType {
        case .compressedHistory: return "Compressed History"
        case .compressedNotes: return "Compressed Notes"
        case .jsonHistory: return "JSON History"
        case .jsonNotes: return "JSON Notes"
        case .unknown: return importText.isEmpty ? "Paste data below" : "Unknown format"
        }
    }

    private var canImport: Bool {
        let dataType = DataEncoder.detectDataType(importText)
        return dataType != .unknown
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: canImport ? "checkmark.circle.fill" : "questionmark.circle")
                            .foregroundColor(canImport ? .green : .secondary)
                        Text(detectedFormat)
                            .foregroundColor(canImport ? .primary : .secondary)
                    }
                } header: {
                    Text("Detected Format")
                } footer: {
                    Text("Supports both compressed format (DISNEY_H:/DISNEY_N:) and JSON")
                }

                Section("Paste Data") {
                    TextEditor(text: $importText)
                        .frame(minHeight: 200)
                        .font(.system(.body, design: .monospaced))
                }

                Section {
                    Button {
                        performImport(strategy: .replace)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Replace All")
                        }
                    }
                    .disabled(!canImport)

                    Button {
                        performImport(strategy: .merge)
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Merge with Existing")
                        }
                    }
                    .disabled(!canImport)
                } footer: {
                    Text("Replace removes existing data. Merge adds new entries only.")
                }
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Paste") {
                        if let clipboard = UIPasteboard.general.string {
                            importText = clipboard
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(resultIsError ? "Import Failed" : "Import Successful", isPresented: $showingResult) {
                Button("OK") {
                    if !resultIsError {
                        dismiss()
                    }
                }
            } message: {
                Text(resultMessage)
            }
        }
    }

    private func performImport(strategy: ImportStrategy) {
        let result = appState.importData(from: importText, strategy: strategy)

        switch result {
        case .success(let type, let count):
            resultMessage = "Imported \(count) \(type.rawValue)"
            resultIsError = false
            showingResult = true
        case .failure(let message):
            resultMessage = message
            resultIsError = true
            showingResult = true
        }
    }
}

// MARK: - Export Sheet

struct ExportSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var exportType: ExportDataType = .history
    @State private var exportFormat: ExportFormat = .compressed
    @State private var showingShareSheet = false
    @State private var copied = false

    enum ExportDataType: String, CaseIterable {
        case history = "History"
        case notes = "Notes"
    }

    enum ExportFormat: String, CaseIterable {
        case compressed = "Compact"
        case json = "JSON"

        var description: String {
            switch self {
            case .compressed: return "Smaller, works with web version"
            case .json: return "Human-readable, larger size"
            }
        }
    }

    private var exportedData: String {
        switch (exportType, exportFormat) {
        case (.history, .compressed):
            return appState.exportHistoryEncoded()
        case (.history, .json):
            return appState.exportHistory()
        case (.notes, .compressed):
            return appState.exportNotesEncoded()
        case (.notes, .json):
            return appState.exportNotes()
        }
    }

    private var dataSize: String {
        let bytes = exportedData.utf8.count
        if bytes < 1024 {
            return "\(bytes) bytes"
        } else {
            return String(format: "%.1f KB", Double(bytes) / 1024.0)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Data Type") {
                    Picker("Type", selection: $exportType) {
                        ForEach(ExportDataType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Export Format")
                } footer: {
                    Text(exportFormat.description)
                }

                Section {
                    HStack {
                        Text("Size")
                        Spacer()
                        Text(dataSize)
                            .foregroundColor(.secondary)
                    }

                    if exportType == .history {
                        HStack {
                            Text("Entries")
                            Spacer()
                            Text("\(appState.rideHistory.count)")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Notes")
                            Spacer()
                            Text("\(appState.notes.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Preview")
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(exportedData)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    .frame(height: 50)
                }

                Section {
                    Button {
                        UIPasteboard.general.string = exportedData
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copied = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied!" : "Copy to Clipboard")
                        }
                    }

                    Button {
                        showingShareSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                    }
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [exportedData])
            }
        }
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
