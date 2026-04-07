import Foundation

/// Review context passed to prompt strategy callbacks
public struct ReviewContext {
    public let positiveCount: Int
    public let negativeCount: Int
    public let weightedScore: Double
    public let lastPromptDate: Date?
    public let appLaunchCount: Int
    public let currentVersion: String
    public let eventHistory: [ExperienceEvent]
    
    public init(
        positiveCount: Int,
        negativeCount: Int,
        weightedScore: Double,
        lastPromptDate: Date?,
        appLaunchCount: Int,
        currentVersion: String,
        eventHistory: [ExperienceEvent]
    ) {
        self.positiveCount = positiveCount
        self.negativeCount = negativeCount
        self.weightedScore = weightedScore
        self.lastPromptDate = lastPromptDate
        self.appLaunchCount = appLaunchCount
        self.currentVersion = currentVersion
        self.eventHistory = eventHistory
    }
}
