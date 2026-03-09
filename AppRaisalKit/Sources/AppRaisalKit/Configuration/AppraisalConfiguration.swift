import Foundation

/// Configuration for AppRaisalKit behavior
///
/// ## Example Configurations
///
/// ### Conservative (Recommended)
/// ```swift
/// AppraisalConfiguration(
///     minimumPositiveEvents: 5,
///     cooldownPeriod: .days(30),
///     promptTiming: .afterPositiveExperience,
///     promptDelay: 2.0
/// )
/// ```
///
/// ### Aggressive (High Engagement)
/// ```swift
/// AppraisalConfiguration(
///     minimumPositiveEvents: 3,
///     cooldownPeriod: .days(14),
///     promptTiming: .afterPositiveExperience,
///     promptDelay: 3.0
/// )
/// ```
///
/// ### Manual Control Only
/// ```swift
/// AppraisalConfiguration(
///     promptTiming: .immediate  // No auto-triggering
/// )
/// ```
public struct AppraisalConfiguration {
    // MARK: - Core Tracking Settings
    
    /// Minimum positive events before prompting
    public let minimumPositiveEvents: Int
    
    /// Minimum recent non-negative streak (consecutive positive or neutral events)
    /// Checks if the last N events are all positive or neutral.
    /// Set to 0 to disable this check. Default: 0
    /// Example: If set to 3, the last 3 events must be positive or neutral to show prompt
    public let recentNonNegativeStreak: Int
    
    /// Number of recent events to track
    public let historySize: Int
    
    /// Default time-to-live for events.
    /// Individual events can override this via `ExperienceData.ttl`.
    public let defaultEventTTL: EventTTL
    
    // MARK: - Timing Controls
    
    /// Minimum time between prompts
    /// - `.minutes(Int)`: Minutes between prompts (e.g., `.minutes(30)`)
    /// - `.hours(Int)`: Hours between prompts (e.g., `.hours(24)`)
    /// - `.days(Int)`: Days between prompts (e.g., `.days(30)` - recommended)
    /// - `.custom(TimeInterval)`: Custom interval in seconds (e.g., `.custom(3600)`)
    public let cooldownPeriod: CooldownPeriod
    
    /// Minimum app launches before first prompt
    /// Prevents prompting brand new users. Default: 3
    public let minimumAppLaunches: Int
    
    // MARK: - Weighting System
    
    /// Default weight for positive events
    public let positiveWeight: Double
    
    /// Default weight for negative events
    public let negativeWeight: Double
    
    /// Default weight for neutral events
    public let neutralWeight: Double
    
    /// Weighted score needed to prompt (can be dynamic)
    public let scoreThreshold: ScoreThreshold
    
    // MARK: - Prompt Behavior
    
    /// Strategy for showing review prompts
    /// - `.systemOnly`: Show Apple's standard review prompt
    /// - `.callback`: Custom sync callback before showing prompt
    /// - `.callbackAsync`: Custom async callback
    /// - `.customFirst`: Show custom UI, then optionally system prompt
    public let promptStrategy: PromptStrategy
    
    /// Max prompts per app version
    public let maxPromptsPerVersion: Int
    
    /// Max prompts across all versions
    public let maxPromptsTotal: Int
    
    /// Timing for showing prompts - CONTROLS AUTO-TRIGGERING
    /// - `.immediate`: No auto-triggering. You must call `requestReview()` manually
    /// - `.afterPositiveExperience`: Auto-triggers after positive events (recommended)
    /// - `.afterNeutralExperience`: Auto-triggers after neutral events
    /// - `.custom`: Manual control with your own timing logic
    ///
    /// **IMPORTANT**: With `.afterPositiveExperience` or `.afterNeutralExperience`,
    /// prompts are **automatically shown** when eligible. Use `.immediate` for full control.
    public let promptTiming: PromptTiming
    
    /// Delay before showing prompt (in seconds)
    /// Used with `.afterPositiveExperience` and `.afterNeutralExperience`
    /// - `0.0`: Immediate (not recommended - feels rushed)
    /// - `2.0`: 2 seconds (good for quick actions)
    /// - `5.0`: 5 seconds (recommended - natural timing)
    /// - `10.0`: 10 seconds (good for complex workflows)
    public let promptDelay: TimeInterval
    
    // MARK: - Crash Detection
    
    /// Enable crash detection
    public let enableCrashDetection: Bool
    
    /// Weight for crash events (overrides negativeWeight)
    public let crashEventWeight: Double
    
    // MARK: - Storage
    
    /// Custom storage provider
    public let storageProvider: StorageProvider
    
    // MARK: - Debug & Testing
    
    /// Show logs and allow testing
    public let debugMode: Bool
    
    /// Simulate prompts instead of showing real ones
    public let simulatePrompt: Bool
    
    /// Override app version for testing
    public let overrideVersion: String?
    
    // MARK: - A/B Testing
    
    /// Variant identifier for A/B testing
    public let variant: String?
    
    /// Experiment identifier
    public let experimentId: String?
    
    // MARK: - Initialization
    
    public init(
        minimumPositiveEvents: Int = 5,
        recentNonNegativeStreak: Int = 0,
        historySize: Int = 50,
        defaultEventTTL: EventTTL = .days(365),
        cooldownPeriod: CooldownPeriod = .days(30),
        minimumAppLaunches: Int = 3,
        positiveWeight: Double = 1.0,
        negativeWeight: Double = -2.0,
        neutralWeight: Double = 0.0,
        scoreThreshold: ScoreThreshold = .fixed(5.0),
        promptStrategy: PromptStrategy = .systemOnly,
        maxPromptsPerVersion: Int = 3,
        maxPromptsTotal: Int = 10,
        promptTiming: PromptTiming = .immediate,
        promptDelay: TimeInterval = 0,
        enableCrashDetection: Bool = true,
        crashEventWeight: Double = -5.0,
        storageProvider: StorageProvider? = nil,
        debugMode: Bool = false,
        simulatePrompt: Bool = false,
        overrideVersion: String? = nil,
        variant: String? = nil,
        experimentId: String? = nil
    ) {
        self.minimumPositiveEvents = minimumPositiveEvents
        self.recentNonNegativeStreak = recentNonNegativeStreak
        self.historySize = historySize
        self.defaultEventTTL = defaultEventTTL
        self.cooldownPeriod = cooldownPeriod
        self.minimumAppLaunches = minimumAppLaunches
        self.positiveWeight = positiveWeight
        self.negativeWeight = negativeWeight
        self.neutralWeight = neutralWeight
        self.scoreThreshold = scoreThreshold
        self.promptStrategy = promptStrategy
        self.maxPromptsPerVersion = maxPromptsPerVersion
        self.maxPromptsTotal = maxPromptsTotal
        self.promptTiming = promptTiming
        self.promptDelay = promptDelay
        self.enableCrashDetection = enableCrashDetection
        self.crashEventWeight = crashEventWeight
        self.storageProvider = storageProvider ?? MementoStorage()
        self.debugMode = debugMode
        self.simulatePrompt = simulatePrompt
        self.overrideVersion = overrideVersion
        self.variant = variant
        self.experimentId = experimentId
    }
}

// MARK: - Supporting Types

/// Score threshold configuration
public enum ScoreThreshold {
    case fixed(Double)
    case dynamic((ReviewContext) -> Double)
    
    public func value(for context: ReviewContext) -> Double {
        switch self {
        case .fixed(let value):
            return value
        case .dynamic(let calculator):
            return calculator(context)
        }
    }
}

/// Timing for showing prompts - CONTROLS AUTO-TRIGGERING
///
/// ## Options
///
/// ### `.immediate`
/// No auto-triggering. You must manually call `requestReview()`.
/// Use when you want full control over prompt timing.
/// ```swift
/// promptTiming: .immediate
/// ```
///
/// ### `.afterPositiveExperience` (Recommended)
/// Auto-triggers prompts after positive events if eligible.
/// ```swift
/// promptTiming: .afterPositiveExperience
/// promptDelay: 5.0  // Wait 5 seconds after positive event
/// ```
///
/// ### `.afterNeutralExperience`
/// Auto-triggers prompts after neutral events if eligible.
/// ```swift
/// promptTiming: .afterNeutralExperience
/// promptDelay: 2.0
/// ```
///
/// ### `.custom`
/// Manual control with your own timing logic.
/// ```swift
/// promptTiming: .custom
/// // Handle timing yourself
/// ```
///
/// **IMPORTANT**: With `.afterPositiveExperience` or `.afterNeutralExperience`,
/// prompts are **automatically shown** when eligible. The delay gives users time
/// to appreciate their success before being prompted.
public enum PromptTiming {
    case immediate
    case afterPositiveExperience
    case afterNeutralExperience
    case custom
}
