import Foundation

/// Determines eligibility for showing review prompts
actor RatingStrategy {
    private let config: AppraisalConfiguration
    private let tracker: ExperienceTracker
    
    init(config: AppraisalConfiguration, tracker: ExperienceTracker) {
        self.config = config
        self.tracker = tracker
    }
    
    /// Check if the app should request a review
    func shouldRequestReview() async -> (eligible: Bool, reason: String?) {
        let stats = await tracker.getStatistics()
        let context = await tracker.getReviewContext()
        
        // Check app launch minimum
        if stats.appLaunchCount < config.minimumAppLaunches {
            return (false, "Minimum app launches not met (\(stats.appLaunchCount)/\(config.minimumAppLaunches))")
        }
        
        // Check minimum positive events
        if stats.positiveCount < config.minimumPositiveEvents {
            return (false, "Minimum positive events not met (\(stats.positiveCount)/\(config.minimumPositiveEvents))")
        }
        
        // Check recent non-negative streak
        if config.recentNonNegativeStreak > 0 {
            let recentEvents = Array(context.eventHistory.suffix(config.recentNonNegativeStreak))
            let nonNegativeCount = recentEvents.filter { $0.type == "positive" || $0.type == "neutral" }.count
            
            if nonNegativeCount < config.recentNonNegativeStreak {
                return (false, "Recent experiences contain negative events (\(nonNegativeCount)/\(config.recentNonNegativeStreak) non-negative)")
            }
        }
        
        // Check score threshold
        let threshold = config.scoreThreshold.value(for: context)
        if stats.weightedScore < threshold {
            return (false, "Score threshold not met (\(stats.weightedScore)/\(threshold))")
        }
        
        // Check cooldown
        let cooldownStatus = await tracker.getCooldownStatus()
        if !cooldownStatus.canPromptNow {
            return (false, cooldownStatus.reason ?? "In cooldown period")
        }
        
        // Check max prompts per version
        if stats.promptCountThisVersion >= config.maxPromptsPerVersion {
            return (false, "Max prompts per version reached (\(stats.promptCountThisVersion)/\(config.maxPromptsPerVersion))")
        }
        
        // Check max prompts total
        if stats.promptCount >= config.maxPromptsTotal {
            return (false, "Max total prompts reached (\(stats.promptCount)/\(config.maxPromptsTotal))")
        }
        
        return (true, nil)
    }
}
