import SwiftUI

struct DriverVoiceLoggerView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM

    let onStartTripRequested: () -> Void
    let onEndTripRequested: () -> Void
    let onRefuelRequested: () -> Void
    let onLiveMapRequested: () -> Void
    let onDashboardRequested: () -> Void
    let onTripsRequested: () -> Void

    @State private var speech = SpeechTranscriptionService(locale: Locale(identifier: "en_IN"))
    @State private var mode: VoiceLoggerMode = .idle
    @State private var statusText = "Tap, then say \"Hey Fleet\""
    @State private var commandText = ""
    @State private var lastHeardText = ""
    @State private var showSpeechError = false
    @State private var commandTask: Task<Void, Never>?
    @State private var commandTimeoutTask: Task<Void, Never>?
    @State private var ignoredTranscriptPrefix = ""

    var body: some View {
        HStack(spacing: 12) {
            if mode != .idle {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode == .processing ? "Processing..." : (mode == .commandListening ? "Listening..." : "Voice Logger"))
                        .font(.system(.caption2, design: .rounded).bold())
                        .foregroundStyle(DriverTheme.accent)
                    
                    Text(statusText)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(DriverTheme.textPrimary)
                        .lineLimit(1)
                    
                    if !lastHeardText.isEmpty {
                        Text(lastHeardText)
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundStyle(DriverTheme.textPrimary)
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, 4)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
                
                if mode == .commandListening {
                    Button("Done") {
                        processCurrentCommand()
                    }
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(DriverTheme.accent)
                    .padding(.trailing, 4)
                    .transition(.opacity)
                }
            }
            
            Button {
                Task { await toggleListening() }
            } label: {
                ZStack {
                    Circle()
                        .fill(mode.tint)
                        .frame(width: 56, height: 56)
                        .shadow(color: mode.tint.opacity(0.3), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: mode.iconName)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse, isActive: speech.isRecording)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("VOICE_LOGGER_FAB")
        }
        .padding(mode != .idle ? 6 : 0)
        .background(
            Group {
                if mode != .idle {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                }
            }
        )
        .overlay(
            Group {
                if mode != .idle {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(mode.tint.opacity(0.2), lineWidth: 1)
                }
            }
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: mode)
        .onChange(of: speech.partialTranscript) { _, transcript in
            handleTranscript(transcript)
        }
        .onChange(of: speech.finalTranscriptToken) { _, _ in
            handleFinalTranscript(speech.finalTranscript)
        }
        .alert("Voice Logger", isPresented: $showSpeechError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(speech.errorMessage ?? "Voice logging is unavailable right now.")
        }
        .onDisappear {
            commandTask?.cancel()
            commandTimeoutTask?.cancel()
            speech.cancelRecording()
            mode = .idle
        }
    }

    private func toggleListening() async {
        if speech.isRecording {
            commandTask?.cancel()
            commandTimeoutTask?.cancel()
            speech.cancelRecording()
            withAnimation {
                mode = .idle
                commandText = ""
                lastHeardText = ""
                ignoredTranscriptPrefix = ""
                statusText = "Tap, then say \"Hey Fleet\""
            }
            return
        }

        guard await speech.requestPermissions() else {
            showSpeechError = true
            return
        }

        guard speech.isAvailable else {
            speech.errorMessage = SpeechTranscriptionError.recognizerUnavailable.errorDescription
            showSpeechError = true
            return
        }

        do {
            withAnimation {
                mode = .wakeListening
                commandText = ""
                lastHeardText = ""
                ignoredTranscriptPrefix = ""
                statusText = "Listening for \"Hey Fleet\""
            }
            try await speech.startRecording()
        } catch {
            withAnimation {
                mode = .idle
            }
            speech.errorMessage = error.localizedDescription
            showSpeechError = true
        }
    }

    private func handleTranscript(_ transcript: String) {
        let normalized = activeTranscript(from: transcript)
        if !normalized.isEmpty {
            lastHeardText = normalized
        }

        switch mode {
        case .idle, .processing:
            return
        case .wakeListening:
            guard let command = commandAfterWakePhrase(in: normalized) else { return }
            if command.isEmpty {
                activateCommandListening()
            } else {
                withAnimation {
                    mode = .commandListening
                    commandText = command
                    lastHeardText = command
                    statusText = "Command captured"
                }
                scheduleCommandProcessingIfNeeded()
            }
        case .commandListening:
            commandText = commandAfterWakePhrase(in: normalized) ?? normalized
            lastHeardText = commandText
            statusText = commandText.isEmpty ? "Go ahead, I am listening" : "Command captured"
            scheduleCommandProcessingIfNeeded()
        }
    }

    private func handleFinalTranscript(_ transcript: String) {
        let normalized = activeTranscript(from: transcript)
        guard !normalized.isEmpty else { return }

        switch mode {
        case .wakeListening:
            guard let command = commandAfterWakePhrase(in: normalized) else { return }
            if command.isEmpty {
                activateCommandListening()
            } else {
                commandText = command
                lastHeardText = command
                processCurrentCommand()
            }
        case .commandListening:
            commandText = commandAfterWakePhrase(in: normalized) ?? normalized
            lastHeardText = commandText
            processCurrentCommand()
        case .idle, .processing:
            return
        }
    }

    private func activeTranscript(from transcript: String) -> String {
        let normalized = transcript.normalizedVoiceText
        guard !ignoredTranscriptPrefix.isEmpty else { return normalized }
        guard normalized.hasPrefix(ignoredTranscriptPrefix) else {
            ignoredTranscriptPrefix = ""
            return normalized
        }
        return String(normalized.dropFirst(ignoredTranscriptPrefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commandAfterWakePhrase(in text: String) -> String? {
        for phrase in ["hey fleet", "hey feet", "hey feat", "hay fleet", "hay feet", "hi fleet", "hi feet"] {
            if let range = text.range(of: phrase) {
                return String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func activateCommandListening() {
        commandTask?.cancel()
        commandTimeoutTask?.cancel()
        withAnimation {
            mode = .commandListening
            commandText = ""
            lastHeardText = "hey fleet"
            statusText = "Listening now. Say your command."
        }
        startCommandTimeout()
    }

    private func scheduleCommandProcessingIfNeeded() {
        commandTask?.cancel()
        guard !commandText.isEmpty else { return }
        commandTask = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                processCurrentCommand()
            }
        }
    }

    private func startCommandTimeout() {
        commandTimeoutTask?.cancel()
        commandTimeoutTask = Task {
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                let current = activeTranscript(from: speech.partialTranscript)
                let candidate = commandAfterWakePhrase(in: current) ?? current
                if !candidate.isEmpty {
                    commandText = candidate
                    lastHeardText = candidate
                    processCurrentCommand()
                } else if mode == .commandListening {
                    withAnimation {
                        commandText = ""
                        statusText = "No command heard. Listening for \"Hey Fleet\""
                        mode = .wakeListening
                    }
                }
            }
        }
    }

    private func processCurrentCommand() {
        let command = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            statusText = "Listening now. Say your command."
            return
        }

        commandTask?.cancel()
        commandTimeoutTask?.cancel()
        withAnimation {
            mode = .processing
        }

        let result = execute(command)
        statusText = result
        driverVM.showToastMessage(result)
        lastHeardText = command
        commandText = ""
        ignoredTranscriptPrefix = speech.partialTranscript.normalizedVoiceText
        scheduleWakeListeningAfterResult()
    }

    private func scheduleWakeListeningAfterResult() {
        commandTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation {
                    if speech.isRecording {
                        mode = .wakeListening
                        statusText = "Listening for \"Hey Fleet\""
                    } else {
                        mode = .idle
                        statusText = "Tap, then say \"Hey Fleet\""
                    }
                }
            }
        }
    }

    private func execute(_ command: String) -> String {
        guard let user = appViewModel.currentUser else {
            return "Please sign in before using voice logging."
        }

        let text = command.normalizedVoiceText

        if text.containsAny(["sos", "emergency", "accident"]) {
            driverVM.startSOSCountdown(service: appViewModel.service, user: user)
            return "SOS countdown started."
        }

        if text.matchesVoiceCommand(["go on duty", "switch to on duty", "on duty", "start duty", "go online"]) {
            appViewModel.service.setDutyStatus(.onDuty, for: user.id)
            appViewModel.refreshCurrentUser()
            return "You are now on duty."
        }

        if text.matchesVoiceCommand(["switch to off duty", "off duty", "end duty", "go offline"]) {
            appViewModel.service.setDutyStatus(.offDuty, for: user.id)
            appViewModel.refreshCurrentUser()
            return "You are now off duty."
        }

        if text.matchesVoiceCommand(["start trip", "begin trip"]) {
            onStartTripRequested()
            return "Opening the trip start flow."
        }

        if text.matchesVoiceCommand(["end trip", "finish trip", "complete trip"]) {
            onEndTripRequested()
            return "Opening the trip end flow."
        }

        if text.matchesVoiceCommand(["open refuel", "refuel", "fuel receipt", "fuel bill"]) {
            onRefuelRequested()
            return "Opening fuel logging."
        }

        if text.matchesVoiceCommand(["open dashboard", "show dashboard", "dashboard", "home tab", "go home"]) {
            onDashboardRequested()
            return "Opening dashboard."
        }

        if text.matchesVoiceCommand(["open trips", "show trips", "trips tab", "trip tab", "open trip tab", "go to trips"]) {
            onTripsRequested()
            return "Opening trips."
        }

        if text.matchesVoiceCommand(["view live map", "live map", "show live map", "open live map", "view map", "open map"]) {
            onLiveMapRequested()
            return "Opening live map."
        }

        if text.contains("inspection") {
            guard let vehicle = driverVehicle(for: user) else {
                return "No assigned vehicle found for inspection logging."
            }
            let type: InspectionType = text.containsAny(["post trip", "post-trip", "after trip"]) ? .postTrip : .preTrip
            let notes = strippedCommand(text, removing: ["log", "record", "inspection", "pre trip", "pre-trip", "post trip", "post-trip"])
            let items = DriverViewModel.defaultInspectionItems().map {
                InspectionItem(id: UUID(), title: $0.title, isChecked: true)
            }
            appViewModel.service.addInspection(
                driverID: user.id,
                vehicleID: vehicle.id,
                type: type,
                notes: notes.isEmpty ? "Voice logged inspection. All items passed." : "Voice logged: \(notes)",
                items: items
            )
            return "\(type.rawValue) inspection logged."
        }

        if text.matchesVoiceCommand(["report brake issue", "report defect", "defect", "issue", "problem", "damage", "fault"]) {
            guard let vehicle = driverVehicle(for: user) else {
                return "No assigned vehicle found for defect reporting."
            }
            let severity = severityFrom(text)
            let title = defectTitle(from: text)
            appViewModel.service.addDefect(
                driverID: user.id,
                vehicleID: vehicle.id,
                severity: severity,
                description: "[Voice] \(command)",
                title: title
            )
            return "Defect report logged."
        }

        if text.matchesVoiceCommand(["log lunch break", "lunch break", "break", "tea", "lunch", "rest", "fuel stop"]) {
            let breakType = breakTypeFrom(text)
            appViewModel.service.addBreakLog(
                driverID: user.id,
                breakType: breakType,
                durationMinutes: durationMinutes(from: text)
            )
            return "\(breakType) logged."
        }

        return "I heard you, but could not match that to a driver action."
    }

    private func breakTypeFrom(_ text: String) -> String {
        if text.contains("fuel") { return "Fuel Stop" }
        if text.contains("lunch") { return "Lunch Break" }
        if text.contains("tea") { return "Tea Break" }
        if text.contains("rest") { return "Rest Break" }
        if text.contains("personal") { return "Personal Break" }
        return "Rest Break"
    }

    private func severityFrom(_ text: String) -> WorkOrderPriority {
        if text.contains("critical") || text.contains("urgent") || text.contains("danger") { return .critical }
        if text.contains("high") || text.contains("major") { return .high }
        if text.contains("low") || text.contains("minor") { return .low }
        return .medium
    }

    private func defectTitle(from text: String) -> String {
        if text.contains("brake") { return "Brake Issue" }
        if text.contains("engine") { return "Engine Issue" }
        if text.contains("tyre") || text.contains("tire") { return "Tire Issue" }
        if text.contains("light") { return "Light Issue" }
        if text.contains("battery") { return "Battery Issue" }
        if text.contains("fuel") { return "Fuel System Issue" }
        return "Voice Reported Defect"
    }

    private func driverVehicle(for user: User) -> Vehicle? {
        if let assigned = appViewModel.assignedVehicle {
            return assigned
        }
        if let activeTrip = appViewModel.service.activeTrip(for: user.id) {
            return appViewModel.service.vehicle(for: activeTrip.vehicleID)
        }
        return nil
    }

    private func durationMinutes(from text: String) -> Int? {
        let words = text.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        for index in words.indices {
            guard let value = Int(words[index]) else { continue }
            let nextIndex = words.index(after: index)
            guard nextIndex < words.endIndex else { return value }
            let unit = words[nextIndex]
            if unit.hasPrefix("hour") { return value * 60 }
            if unit.hasPrefix("minute") || unit == "min" || unit == "mins" { return value }
        }
        return nil
    }

    private func strippedCommand(_ text: String, removing removals: [String]) -> String {
        var result = text
        for removal in removals {
            result = result.replacingOccurrences(of: removal, with: "")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum VoiceLoggerMode: Equatable {
    case idle
    case wakeListening
    case commandListening
    case processing

    var iconName: String {
        switch self {
        case .idle: "waveform.circle.fill"
        case .wakeListening: "ear.fill"
        case .commandListening: "mic.fill"
        case .processing: "checkmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .idle: DriverTheme.accent
        case .wakeListening: DriverTheme.warningAmber
        case .commandListening: DriverTheme.successGreen
        case .processing: DriverTheme.accent
        }
    }
}

private extension String {
    var normalizedVoiceText: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func containsAny(_ needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }

    func matchesVoiceCommand(_ phrases: [String]) -> Bool {
        containsAny(phrases)
    }
}
