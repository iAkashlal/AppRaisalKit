//
//  AppRatingManager.swift
//  AppRaisalKit Sample
//
//  AppRaisalKit Integration Manager
//

import Foundation
import Combine
import AppRaisalKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

final class AppRatingManager: ObservableObject {
    @Published var kit: AppRaisalKit?
    @Published var currentStats: ExperienceStats?
    @Published var isInitialized = false
    @Published var activeConfig: ConfigSettings = .default
    
    // Custom prompt dialog state
    @Published var showCustomPrompt = false
    private var customPromptContinuation: CheckedContinuation<Bool, Never>?
    
    init() {
        let saved = ConfigSettings.loadPersisted() ?? .default
        _activeConfig = Published(initialValue: saved)
        Task { @MainActor in
            await setupAppRaisalKit(with: saved)
        }
    }
    
    @MainActor
    func setupAppRaisalKit(with settings: ConfigSettings) async {
        isInitialized = false
        kit = nil
        currentStats = nil
        activeConfig = settings
        
        // Build prompt strategy
        let promptStrategy: PromptStrategy
        if settings.useCustomPrompt {
            promptStrategy = .customFirst { [weak self] in
                guard let self = self else { return false }
                return await self.presentCustomPrompt()
            }
        } else {
            promptStrategy = .systemOnly
        }
        
        let config = AppraisalConfiguration(
            minimumPositiveEvents: settings.minimumPositiveEvents,
            recentNonNegativeStreak: settings.recentNonNegativeStreak,
            cooldownPeriod: .custom(settings.cooldownSeconds),
            minimumAppLaunches: settings.minimumAppLaunches,
            positiveWeight: settings.positiveWeight,
            negativeWeight: settings.negativeWeight,
            scoreThreshold: .fixed(settings.scoreThreshold),
            promptStrategy: promptStrategy,
            maxPromptsPerVersion: settings.maxPromptsPerVersion,
            promptTiming: settings.autoPrompt ? .afterPositiveExperience : .immediate,
            promptDelay: settings.promptDelay,
            enableCrashDetection: settings.enableCrashDetection,
            crashEventWeight: settings.crashEventWeight,
            debugMode: true,
            simulatePrompt: false
        )
        
        do {
            kit = try await AppRaisalKit(configuration: config)
            isInitialized = true
            
            await kit?.setNegativeExperienceHandler { [weak self] event async in
                await self?.handleNegativeExperience(event)
            }
            
            await kit?.setPositiveExperienceHandler { event async in
                print("[AppRating] Positive experience: \(event.id ?? "unnamed")")
            }
            
            await kit?.onStateChange { [weak self] stats in
                Task { @MainActor in
                    self?.currentStats = stats
                }
            }
            
            await refreshStats()
            print("[AppRating] Initialized with custom config")
        } catch {
            print("[AppRating] Failed to initialize: \(error)")
        }
    }
    
    @MainActor
    func reconfigure(with settings: ConfigSettings) async {
        // Persist for next launch
        settings.persist()
        // Reset existing data
        if let kit = kit {
            try? await kit.resetAll()
        }
        // Reinitialize with new config
        await setupAppRaisalKit(with: settings)
    }
    
    private func handleNegativeExperience(_ event: NegativeExperienceEvent) async {
        print("[AppRating] Negative experience: \(event.id ?? "unnamed")")
        
        if let severity = event.metadata?["severity"] as? String,
           severity == "high" {
            print("[AppRating] High severity error - should show support option")
            // In real app: show support chat or feedback form
        }
    }
    
    @MainActor
    func refreshStats() async {
        guard let kit = kit else { return }
        currentStats = await kit.getStatistics()
    }
    
    // MARK: - Custom Prompt
    
    /// Called by AppRaisalKit's .customFirst strategy.
    /// Shows a dialog and waits for the user's choice.
    private func presentCustomPrompt() async -> Bool {
        return await withCheckedContinuation { continuation in
            self.customPromptContinuation = continuation
            self.showCustomPrompt = true
        }
    }
    
    /// User tapped "Leave a Review" → show StoreKit prompt
    @MainActor
    func customPromptReview() {
        showCustomPrompt = false
        customPromptContinuation?.resume(returning: true)
        customPromptContinuation = nil
    }
    
    /// User tapped "Leave Feedback" → open email
    @MainActor
    func customPromptFeedback() {
        showCustomPrompt = false
        customPromptContinuation?.resume(returning: false)
        customPromptContinuation = nil
        openFeedbackEmail()
    }
    
    /// User dismissed without choosing
    @MainActor
    func customPromptDismiss() {
        showCustomPrompt = false
        customPromptContinuation?.resume(returning: false)
        customPromptContinuation = nil
    }
    
    private func openFeedbackEmail() {
        let email = "hi@akashlal.com"
        let subject = "AppRaisalKit Feedback"
        let urlString = "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)"
        guard let url = URL(string: urlString) else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }
    
    // MARK: - Convenience Methods
    
    @MainActor
    func trackPositiveExperience(
        id: String,
        weight: Double? = nil,
        maxRepeat: RepeatLimit? = nil,
        metadata: [String: AnyCodable]? = nil
    ) async {
        guard let kit = kit else { return }
        
        let data = ExperienceData(
            id: id,
            weight: weight,
            maxRepeat: maxRepeat,
            metadata: metadata
        )
        
        do {
            try await kit.addPositiveExperience(data)
            await refreshStats()
        } catch {
            print("[AppRating] Error tracking positive: \(error)")
        }
    }
    
    @MainActor
    func trackNegativeExperience(
        id: String,
        weight: Double? = nil,
        metadata: [String: AnyCodable]? = nil
    ) async {
        guard let kit = kit else { return }
        
        let data = ExperienceData(
            id: id,
            weight: weight,
            metadata: metadata
        )
        
        do {
            try await kit.addNegativeExperience(data)
            await refreshStats()
        } catch {
            print("[AppRating] Error tracking negative: \(error)")
        }
    }
    
    @MainActor
    func trackNeutralExperience(
        id: String,
        metadata: [String: AnyCodable]? = nil
    ) async {
        guard let kit = kit else { return }
        
        let data = ExperienceData(
            id: id,
            metadata: metadata
        )
        
        do {
            try await kit.addNeutralExperience(data)
            await refreshStats()
        } catch {
            print("[AppRating] Error tracking neutral: \(error)")
        }
    }
    
    @MainActor
    func checkAndRequestReview() async {
        guard let kit = kit else { return }
        
        let eligible = await kit.shouldRequestReview()
        
        if eligible {
            do {
                try await kit.requestReview()
                await refreshStats()
                print("[AppRating] Review requested!")
            } catch {
                print("[AppRating] Error requesting review: \(error)")
            }
        } else {
            print("[AppRating] Not eligible for review yet")
            
            // Show why not eligible
            if let debugInfo = await kit.getDebugInfo() as? DebugInfo {
                print("[AppRating] Stats: \(debugInfo.stats)")
            }
        }
    }
    
    @MainActor
    func resetAllData() async {
        guard let kit = kit else { return }
        
        do {
            try await kit.resetAll()
            await refreshStats()
            print("[AppRating] All data reset")
        } catch {
            print("[AppRating] Error resetting: \(error)")
        }
    }
}

// MARK: - Config Settings Model

struct ConfigSettings: Codable {
    var minimumPositiveEvents: Int = 3
    var recentNonNegativeStreak: Int = 2
    var cooldownSeconds: Double = 10
    var minimumAppLaunches: Int = 1
    var positiveWeight: Double = 1.0
    var negativeWeight: Double = -2.0
    var scoreThreshold: Double = 5.0
    var maxPromptsPerVersion: Int = 3
    var autoPrompt: Bool = true
    var promptDelay: Double = 5.0
    var enableCrashDetection: Bool = true
    var crashEventWeight: Double = -5.0
    var useCustomPrompt: Bool = false
    
    static let `default` = ConfigSettings()
    
    // MARK: - Persistence
    
    private static let storageKey = "com.appraisalkit.demo.configSettings"
    
    func persist() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
    
    static func loadPersisted() -> ConfigSettings? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(ConfigSettings.self, from: data) else {
            return nil
        }
        return settings
    }
}
