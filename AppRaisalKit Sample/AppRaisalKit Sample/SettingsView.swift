//
//  SettingsView.swift
//  AppRaisalKit Sample
//
//  AppRaisalKit Configuration Settings
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appRatingManager: AppRatingManager
    @Environment(\.dismiss) var dismiss
    
    // Local state for editing
    @State private var minimumPositiveEvents: Double
    @State private var recentNonNegativeStreak: Double
    @State private var cooldownSeconds: Double
    @State private var minimumAppLaunches: Double
    @State private var positiveWeight: Double
    @State private var negativeWeight: Double
    @State private var scoreThreshold: Double
    @State private var maxPromptsPerVersion: Double
    @State private var autoPrompt: Bool
    @State private var promptDelay: Double
    @State private var enableCrashDetection: Bool
    @State private var crashEventWeight: Double
    @State private var useCustomPrompt: Bool
    
    @State private var showSaveConfirmation = false
    @State private var isSaving = false
    
    init(config: ConfigSettings) {
        _minimumPositiveEvents = State(initialValue: Double(config.minimumPositiveEvents))
        _recentNonNegativeStreak = State(initialValue: Double(config.recentNonNegativeStreak))
        _cooldownSeconds = State(initialValue: config.cooldownSeconds)
        _minimumAppLaunches = State(initialValue: Double(config.minimumAppLaunches))
        _positiveWeight = State(initialValue: config.positiveWeight)
        _negativeWeight = State(initialValue: config.negativeWeight)
        _scoreThreshold = State(initialValue: config.scoreThreshold)
        _maxPromptsPerVersion = State(initialValue: Double(config.maxPromptsPerVersion))
        _autoPrompt = State(initialValue: config.autoPrompt)
        _promptDelay = State(initialValue: config.promptDelay)
        _enableCrashDetection = State(initialValue: config.enableCrashDetection)
        _crashEventWeight = State(initialValue: config.crashEventWeight)
        _useCustomPrompt = State(initialValue: config.useCustomPrompt)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Eligibility Thresholds
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Min Positive Events")
                            Spacer()
                            Text("\(Int(minimumPositiveEvents))")
                                .font(.body.monospacedDigit())
                                .foregroundColor(.accentColor)
                        }
                        Slider(value: $minimumPositiveEvents, in: 1...20, step: 1)
                        Text("User needs at least this many positive events before a prompt can appear.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Score Threshold")
                            Spacer()
                            Text(String(format: "%.1f", scoreThreshold))
                                .font(.body.monospacedDigit())
                                .foregroundColor(.accentColor)
                        }
                        Slider(value: $scoreThreshold, in: 1...50, step: 0.5)
                        Text("Weighted score needed to trigger a review prompt.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Non-Negative Streak")
                            Spacer()
                            Text(recentNonNegativeStreak == 0 ? "Off" : "\(Int(recentNonNegativeStreak))")
                                .font(.body.monospacedDigit())
                                .foregroundColor(recentNonNegativeStreak == 0 ? .secondary : .accentColor)
                        }
                        Slider(value: $recentNonNegativeStreak, in: 0...10, step: 1)
                        Text("Last N events must be positive or neutral. Set 0 to disable.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Min App Launches")
                            Spacer()
                            Text("\(Int(minimumAppLaunches))")
                                .font(.body.monospacedDigit())
                                .foregroundColor(.accentColor)
                        }
                        Slider(value: $minimumAppLaunches, in: 0...20, step: 1)
                        Text("User must launch the app this many times before prompting.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label("Eligibility", systemImage: "checkmark.shield")
                }
                
                // MARK: - Weights
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Positive Weight")
                            Spacer()
                            Text(String(format: "+%.1f", positiveWeight))
                                .font(.body.monospacedDigit())
                                .foregroundColor(.green)
                        }
                        Slider(value: $positiveWeight, in: 0.1...10, step: 0.1)
                        Text("Default score added per positive event.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Negative Weight")
                            Spacer()
                            Text(String(format: "%.1f", negativeWeight))
                                .font(.body.monospacedDigit())
                                .foregroundColor(.red)
                        }
                        Slider(value: $negativeWeight, in: -10...(-0.1), step: 0.1)
                        Text("Default score deducted per negative event.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label("Scoring Weights", systemImage: "scalemass")
                }
                
                // MARK: - Prompt Timing
                Section {
                    Toggle(isOn: $autoPrompt) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Prompt")
                            Text(autoPrompt ? "Triggers after positive experiences" : "Manual requestReview() only")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle(isOn: $useCustomPrompt) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Custom Prompt Dialog")
                            Text(useCustomPrompt
                                 ? "Shows \"Enjoying AppRaisalKit?\" before review"
                                 : "System StoreKit prompt only")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if autoPrompt {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Prompt Delay")
                                Spacer()
                                Text(promptDelay < 1 ? "Instant" : "\(String(format: "%.0f", promptDelay))s")
                                    .font(.body.monospacedDigit())
                                    .foregroundColor(.accentColor)
                            }
                            Slider(value: $promptDelay, in: 0...30, step: 1)
                            Text("Seconds to wait after the positive event before showing prompt.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Cooldown")
                            Spacer()
                            Text(cooldownFormatted)
                                .font(.body.monospacedDigit())
                                .foregroundColor(.accentColor)
                        }
                        Slider(value: $cooldownSeconds, in: 0...86400, step: cooldownStep)
                        HStack {
                            Text("Time between consecutive prompts.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            // Quick presets
                            Menu {
                                Button("10 sec") { cooldownSeconds = 10 }
                                Button("30 sec") { cooldownSeconds = 30 }
                                Button("1 min") { cooldownSeconds = 60 }
                                Button("5 min") { cooldownSeconds = 300 }
                                Button("1 hour") { cooldownSeconds = 3600 }
                                Button("1 day") { cooldownSeconds = 86400 }
                            } label: {
                                Text("Presets")
                                    .font(.caption)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max Prompts / Version")
                            Spacer()
                            Text("\(Int(maxPromptsPerVersion))")
                                .font(.body.monospacedDigit())
                                .foregroundColor(.accentColor)
                        }
                        Slider(value: $maxPromptsPerVersion, in: 1...10, step: 1)
                        Text("Maximum number of review prompts per app version.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label("Prompt Behavior", systemImage: "bell.badge")
                }
                
                // MARK: - Crash Detection
                Section {
                    Toggle(isOn: $enableCrashDetection) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Crash Detection")
                            Text("Logs a negative event on next launch after crash")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if enableCrashDetection {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Crash Weight")
                                Spacer()
                                Text(String(format: "%.1f", crashEventWeight))
                                    .font(.body.monospacedDigit())
                                    .foregroundColor(.red)
                            }
                            Slider(value: $crashEventWeight, in: -20...(-1), step: 0.5)
                            Text("Score impact when a crash is detected.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("Crash Detection", systemImage: "exclamationmark.triangle")
                }
                
                // MARK: - Actions
                Section {
                    Button {
                        loadDefaults()
                    } label: {
                        Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Label("Quick Actions", systemImage: "bolt")
                }
                
                // MARK: - Config Summary
                Section {
                    configSummaryView
                } header: {
                    Label("Config Preview", systemImage: "doc.text.magnifyingglass")
                }
            }
            .navigationTitle("Configuration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save & Reset")
                                .bold()
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Configuration Applied", isPresented: $showSaveConfirmation) {
                Button("OK") { dismiss() }
            } message: {
                Text("AppRaisalKit has been reinitialized with your new configuration. All previous events have been cleared.")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var cooldownStep: Double {
        if cooldownSeconds < 60 { return 5 }
        if cooldownSeconds < 3600 { return 60 }
        return 3600
    }
    
    private var cooldownFormatted: String {
        if cooldownSeconds == 0 { return "None" }
        if cooldownSeconds < 60 { return "\(Int(cooldownSeconds))s" }
        if cooldownSeconds < 3600 {
            let m = Int(cooldownSeconds / 60)
            let s = Int(cooldownSeconds) % 60
            return s > 0 ? "\(m)m \(s)s" : "\(m)m"
        }
        let h = Int(cooldownSeconds / 3600)
        let m = (Int(cooldownSeconds) % 3600) / 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
    
    private var configSummaryView: some View {
        VStack(alignment: .leading, spacing: 6) {
            summaryRow("Prompt after", "\(Int(minimumPositiveEvents)) positive events with score >= \(String(format: "%.1f", scoreThreshold))")
            
            if recentNonNegativeStreak > 0 {
                summaryRow("Streak", "Last \(Int(recentNonNegativeStreak)) events must be non-negative")
            }
            
            if autoPrompt {
                summaryRow("Auto-prompt", "\(String(format: "%.0f", promptDelay))s after positive event")
            } else {
                summaryRow("Auto-prompt", "Off (manual only)")
            }
            
            summaryRow("Prompt style", useCustomPrompt ? "Custom dialog → Review" : "System only")
            
            summaryRow("Cooldown", cooldownFormatted)
            summaryRow("Weights", "+\(String(format: "%.1f", positiveWeight)) / \(String(format: "%.1f", negativeWeight))")
            
            if enableCrashDetection {
                summaryRow("Crash impact", String(format: "%.1f", crashEventWeight))
            }
        }
        .font(.caption)
    }
    
    private func summaryRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .foregroundColor(.primary)
        }
    }
    
    // MARK: - Actions
    
    private func buildSettings() -> ConfigSettings {
        ConfigSettings(
            minimumPositiveEvents: Int(minimumPositiveEvents),
            recentNonNegativeStreak: Int(recentNonNegativeStreak),
            cooldownSeconds: cooldownSeconds,
            minimumAppLaunches: Int(minimumAppLaunches),
            positiveWeight: positiveWeight,
            negativeWeight: negativeWeight,
            scoreThreshold: scoreThreshold,
            maxPromptsPerVersion: Int(maxPromptsPerVersion),
            autoPrompt: autoPrompt,
            promptDelay: promptDelay,
            enableCrashDetection: enableCrashDetection,
            crashEventWeight: crashEventWeight,
            useCustomPrompt: useCustomPrompt
        )
    }
    
    private func save() {
        isSaving = true
        let settings = buildSettings()
        Task {
            await appRatingManager.reconfigure(with: settings)
            isSaving = false
            showSaveConfirmation = true
        }
    }
    
    private func loadDefaults() {
        let d = ConfigSettings.default
        minimumPositiveEvents = Double(d.minimumPositiveEvents)
        recentNonNegativeStreak = Double(d.recentNonNegativeStreak)
        cooldownSeconds = d.cooldownSeconds
        minimumAppLaunches = Double(d.minimumAppLaunches)
        positiveWeight = d.positiveWeight
        negativeWeight = d.negativeWeight
        scoreThreshold = d.scoreThreshold
        maxPromptsPerVersion = Double(d.maxPromptsPerVersion)
        autoPrompt = d.autoPrompt
        promptDelay = d.promptDelay
        enableCrashDetection = d.enableCrashDetection
        crashEventWeight = d.crashEventWeight
        useCustomPrompt = d.useCustomPrompt
    }
}

#Preview {
    SettingsView(config: .default)
        .environmentObject(AppRatingManager())
}
