//
//  ContentView.swift
//  AppRaisalKit Sample
//
//  Created by Akashlal Bathe on 09/03/26.
//

import SwiftUI
import UIKit
import AppRaisalKit

struct ContentView: View {
    @EnvironmentObject var appRatingManager: AppRatingManager
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showSettings = false
    @State private var lastAction: String?
    @State private var showCrashConfirm = false
    @State private var expandedChip: String?
    @State private var chipTimer: DispatchWorkItem?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        // Score ring + stats at top
                        scoreHeader
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                        
                        Divider()
                        
                        // Experience buttons
                        experienceButtons
                            .padding(.vertical, 20)
                    }
                    .padding(.horizontal)
                }
                
                // Pinned bottom actions
                Divider()
                bottomActions
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(Color(.systemBackground))
            }
            .navigationTitle("AppRaisalKit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(config: appRatingManager.activeConfig)
                .environmentObject(appRatingManager)
        }
        .alert("AppRaisalKit", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert("Simulate Crash", isPresented: $showCrashConfirm) {
            Button("Crash Now", role: .destructive) { fatalError("Simulated crash for AppRaisalKit testing") }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("The app will terminate immediately without marking a clean exit. On next launch, AppRaisalKit will detect this as a crash and log a negative event.")
        }
        // Custom review prompt dialog
        .sheet(isPresented: $appRatingManager.showCustomPrompt, onDismiss: {
            appRatingManager.customPromptDismiss()
        }) {
            CustomPromptView()
                .environmentObject(appRatingManager)
        }
    }
    
    // MARK: - Score Header
    
    private var scoreHeader: some View {
        Group {
            if let stats = appRatingManager.currentStats {
                VStack(spacing: 12) {
                    scoreCard(stats: stats)
                    
                    // Last action feedback
                    if let action = lastAction {
                        Text(action)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            } else if appRatingManager.isInitialized {
                Text("Loading...")
                    .foregroundColor(.secondary)
            } else {
                ProgressView()
            }
        }
    }
    
    private func scoreCard(stats: ExperienceStats) -> some View {
        let progress = scoreProgress(stats)
        let color = scoreColor(stats)
        let threshold = appRatingManager.activeConfig.scoreThreshold
        let eligible = progress >= 1.0
        let shape = RoundedRectangle(cornerRadius: 14)
        
        return ZStack {
            // Dark card background
            shape
                .fill(Color(.systemBackground))
            
            // Subtle inner fill with color tint
            shape
                .fill(color.opacity(0.04))
            
            // Track stroke
            shape
                .stroke(Color(.systemGray4), lineWidth: 3)
            
            // Progress stroke — thick, sporty
            shape
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [color, color.opacity(0.7), color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .animation(.spring(response: 0.45, dampingFraction: 0.65), value: stats.weightedScore)
            
            // Glow when eligible
            if eligible {
                shape
                    .stroke(color.opacity(0.35), lineWidth: 10)
                    .blur(radius: 8)
            }
            
            // Content
            VStack(spacing: 8) {
                // Score row
                HStack(spacing: 0) {
                    Text(String(format: "%.1f", stats.weightedScore))
                        .font(.system(size: 36, weight: .heavy, design: .rounded).monospacedDigit())
                        .foregroundStyle(color)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("SCORE")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(.secondary)
                        Text("of \(String(format: "%.0f", threshold))")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.leading, 6)
                    
                    Spacer()
                    
                    if eligible {
                        Text("READY")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(color, in: Capsule())
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                
                // Chips — scrollable, appearing from behind edges
                chipStrip(stats: stats)
                    
                    .mask(
                        HStack(spacing: 0) {
                            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                                .frame(width: 16)
                            Color.black
                            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: 16)
                        }
                    )
            }
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 115)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
    }
    
    private func chipStrip(stats: ExperienceStats) -> some View {
        let cfg = appRatingManager.activeConfig
        let streakReq = cfg.recentNonNegativeStreak
        let streakOk = streakReq == 0 || stats.currentNonNegativeStreak >= streakReq
        let streakText = streakReq > 0
            ? "\(stats.currentNonNegativeStreak)/\(streakReq)"
            : "\(stats.currentNonNegativeStreak)"
        
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(id: "positive", icon: "plus.circle.fill", label: "Positive", text: "\(stats.positiveCount)", color: .green)
                    chip(id: "neutral", icon: "circle.fill", label: "Neutral", text: "\(stats.neutralCount)", color: .gray)
                    chip(id: "negative", icon: "minus.circle.fill", label: "Negative", text: "\(stats.negativeCount)", color: .red)
                    chip(id: "streak", icon: "flame.fill", label: "Streak", text: streakText, color: streakOk ? .green : .orange)
                    chip(id: "total", icon: "number", label: "Total", text: "\(stats.totalEvents)", color: .blue)
                    chip(id: "prompts", icon: "star.bubble.fill", label: "Prompts", text: "\(stats.promptCount)", color: .orange)
                }
                .padding(.horizontal, 4)
                .animation(.easeInOut(duration: 0.25), value: expandedChip)
            }
            .onChange(of: expandedChip) { _, id in
                if let id = id {
                    withAnimation { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
    }
    
    private func chip(id: String, icon: String, label: String, text: String, color: Color) -> some View {
        let isExpanded = expandedChip == id
        
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            if isExpanded {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(color.opacity(0.8))
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
            Text(text)
                .font(.caption.bold().monospacedDigit())
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(isExpanded ? 0.18 : 0.1), in: Capsule())
        .id(id)
        .onTapGesture { toggleChip(id) }
    }
    
    private func toggleChip(_ id: String) {
        withAnimation {
            expandedChip = (expandedChip == id) ? nil : id
        }
        scheduleChipCollapse()
    }
    
    private func expandChipBriefly(_ id: String) {
        withAnimation { expandedChip = id }
        scheduleChipCollapse()
    }
    
    private func scheduleChipCollapse() {
        chipTimer?.cancel()
        let work = DispatchWorkItem {
            withAnimation { expandedChip = nil }
        }
        chipTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }
    
    private func scoreProgress(_ stats: ExperienceStats) -> CGFloat {
        let threshold = appRatingManager.activeConfig.scoreThreshold
        guard threshold > 0 else { return 0 }
        return min(max(CGFloat(stats.weightedScore / threshold), 0), 1)
    }
    
    private func scoreColor(_ stats: ExperienceStats) -> Color {
        let threshold = appRatingManager.activeConfig.scoreThreshold
        let ratio = stats.weightedScore / threshold
        if ratio >= 1.0 { return .green }
        if ratio >= 0.5 { return .orange }
        return .red
    }
    
    // MARK: - Experience Buttons
    
    private var experienceButtons: some View {
        VStack(spacing: 8) {
            // Section label
            HStack {
                Text("LOG EXPERIENCE")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.bottom, 2)
            
            // Positive
            experienceButton(
                icon: "star.fill", title: "Feature Used", badge: "+1.0", color: .green
            ) { trackPositive(id: "feature_used", weight: 1.0, description: "Feature Used") }
            
            experienceButton(
                icon: "checkmark.circle.fill", title: "Task Completed", badge: "+2.0", color: .green
            ) { trackPositive(id: "task_completed", weight: 2.0, description: "Task Completed") }
            
            experienceButton(
                icon: "trophy.fill", title: "Major Achievement", badge: "+5.0", color: .orange
            ) { trackPositive(id: "major_achievement", weight: 5.0, description: "Major Achievement") }
            
            Divider().padding(.vertical, 2)
            
            // Neutral
            experienceButton(
                icon: "hand.raised", title: "Neutral Event", badge: "0.0", color: .gray
            ) { trackNeutral(id: "neutral_event", description: "Neutral Event") }
            
            Divider().padding(.vertical, 2)
            
            // Negative
            experienceButton(
                icon: "exclamationmark.triangle.fill", title: "Minor Error", badge: "-2.0", color: .yellow
            ) { trackNegative(id: "minor_error", severity: "low", description: "Minor Error") }
            
            experienceButton(
                icon: "wifi.slash", title: "Network Failure", badge: "-2.0", color: .red
            ) { trackNegative(id: "network_failure", severity: "high", description: "Network Failure") }
            
            experienceButton(
                icon: "xmark.octagon.fill", title: "Critical Error", badge: "-5.0", color: .red
            ) { trackNegative(id: "critical_error", weight: -5.0, severity: "critical", description: "Critical Error") }
        }
    }
    
    private func experienceButton(icon: String, title: String, badge: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Color accent bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 4, height: 28)
                
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 22)
                
                // Title
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Weight badge
                Text(badge)
                    .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.1), in: Capsule())
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle(hapticStyle: .light))
    }
    
    // MARK: - Bottom Actions
    
    private var bottomActions: some View {
        VStack(spacing: 10) {
            // Request Review — hero button
            Button { checkForReview() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "star.bubble.fill")
                        .font(.subheadline)
                    Text("REQUEST REVIEW")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .shadow(color: .blue.opacity(0.25), radius: 8, y: 4)
            }
            .buttonStyle(PressableButtonStyle(hapticStyle: .medium))
            .disabled(!appRatingManager.isInitialized)
            .opacity(appRatingManager.isInitialized ? 1 : 0.5)
            
            // Reset & Crash row
            HStack(spacing: 10) {
                Button { resetData() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 12, weight: .bold))
                        Text("RESET")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.5)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
                .buttonStyle(PressableButtonStyle(hapticStyle: .medium))
                
                Button { showCrashConfirm = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("CRASH")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.5)
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .red.opacity(0.08), radius: 4, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(PressableButtonStyle(hapticStyle: .heavy))
            }
        }
    }
    
    // MARK: - Actions
    
    private func trackPositive(id: String, weight: Double? = nil, description: String) {
        Task {
            await appRatingManager.trackPositiveExperience(
                id: id,
                weight: weight,
                maxRepeat: .infinite,
                metadata: [
                    "description": AnyCodable(description),
                    "timestamp": AnyCodable(Date().timeIntervalSince1970)
                ]
            )
            withAnimation { lastAction = "+" + description }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { if lastAction == "+" + description { lastAction = nil } }
            }
        }
    }
    
    private func trackNeutral(id: String, description: String) {
        Task {
            await appRatingManager.trackNeutralExperience(
                id: id,
                metadata: [
                    "description": AnyCodable(description),
                    "timestamp": AnyCodable(Date().timeIntervalSince1970)
                ]
            )
            withAnimation { lastAction = "~" + description }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { if lastAction == "~" + description { lastAction = nil } }
            }
        }
    }
    
    private func trackNegative(id: String, weight: Double? = nil, severity: String, description: String) {
        Task {
            await appRatingManager.trackNegativeExperience(
                id: id,
                weight: weight,
                metadata: [
                    "description": AnyCodable(description),
                    "severity": AnyCodable(severity),
                    "timestamp": AnyCodable(Date().timeIntervalSince1970)
                ]
            )
            withAnimation { lastAction = "-" + description }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { if lastAction == "-" + description { lastAction = nil } }
            }
        }
    }
    
    private func checkForReview() {
        Task {
            guard let kit = appRatingManager.kit else { return }
            
            let result = await kit.checkEligibility()
            
            if result.eligible {
                await appRatingManager.checkAndRequestReview()
                presentAlert(message: "Review prompt triggered!")
            } else {
                presentAlert(message: "Not eligible:\n\(result.reason ?? "Unknown reason")")
            }
        }
    }
    
    private func resetData() {
        Task {
            await appRatingManager.resetAllData()
            withAnimation { lastAction = "Data reset" }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { if lastAction == "Data reset" { lastAction = nil } }
            }
        }
    }
    
    private func presentAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .light
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.65), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    let generator = UIImpactFeedbackGenerator(style: hapticStyle)
                    generator.impactOccurred()
                }
            }
    }
}

// MARK: - Custom Review Prompt

struct CustomPromptView: View {
    @EnvironmentObject var appRatingManager: AppRatingManager
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.15), .purple.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                // Title & subtitle
                VStack(spacing: 8) {
                    Text("Are you enjoying using\nAppRaisalKit?")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    
                    Text("Your feedback helps us improve the experience.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Buttons
                VStack(spacing: 12) {
                    // Leave a Review — primary
                    Button {
                        appRatingManager.customPromptReview()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.subheadline)
                            Text("Leave a Review")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .shadow(color: .blue.opacity(0.25), radius: 8, y: 4)
                    }
                    .buttonStyle(PressableButtonStyle(hapticStyle: .medium))
                    
                    // Leave Feedback — secondary
                    Button {
                        appRatingManager.customPromptFeedback()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.subheadline)
                            Text("Leave Feedback")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(.systemGray3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PressableButtonStyle(hapticStyle: .light))
                    
                    // Not now
                    Button {
                        appRatingManager.customPromptDismiss()
                    } label: {
                        Text("Not Now")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.12), radius: 20, y: 10)
            )
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .background(Color.black.opacity(0.001)) // Tap target for dismiss
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppRatingManager())
}
