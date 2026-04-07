import Foundation

/// Tracks and manages user experience events
actor ExperienceTracker {
    private let config: AppraisalConfiguration
    private let storage: StorageProvider
    private let storageKey = "com.appraisalkit.data"
    
    private var dataModel: AppraisalDataModel
    private var userSegment: UserSegment?
    /// In-memory delayed experiences that have been started but not yet committed.
    /// These are never persisted and are lost on process restart.
    private var delayedExperiences: [String: DelayedExperience] = [:]
    
    init(config: AppraisalConfiguration, storage: StorageProvider) {
        self.config = config
        self.storage = storage
        
        let currentVersion = AppVersionProvider.currentVersion(override: config.overrideVersion)
        
        // Load existing data or create new
        if let loaded: AppraisalDataModel = storage.load(forKey: storageKey) {
            self.dataModel = loaded
            
            // Check if version changed
            if loaded.currentVersion != currentVersion {
                self.dataModel.currentVersion = currentVersion
                self.dataModel.promptCountThisVersion = 0
            }
        } else {
            self.dataModel = AppraisalDataModel(currentVersion: currentVersion)
        }
        
        self.userSegment = dataModel.userSegment

        // Prune any expired events on startup (in-memory; persisted on next save).
        pruneExpiredEvents()
    }
    
    // MARK: - Event Tracking
    
    func logExperience(_ type: ExperienceType) throws {
        let data = type.data
        let weight = data.weight ?? defaultWeight(for: type)
        let now = Date()
        let ttl = data.ttl ?? config.defaultEventTTL
        let expiry = now.addingTimeInterval(ttl.timeInterval)
        
        // Check maxRepeat limit
        if let id = data.id {
            let currentCount = dataModel.eventCounts[id] ?? 0
            
            if let maxRepeat = data.maxRepeat {
                switch maxRepeat {
                case .limited(let limit):
                    if currentCount >= limit {
                        // When we've reached the per-ID limit, drop the oldest
                        // event with this ID to make room for the new one.
                        if let index = dataModel.events.firstIndex(where: { $0.id == id }) {
                            dataModel.events.remove(at: index)
                        }
                        // Keep the counter in sync with the actual stored events.
                        dataModel.eventCounts[id] = max(currentCount - 1, 0)
                    }
                case .infinite:
                    break // No limit
                }
            }
            
            // Update count
            dataModel.eventCounts[id] = currentCount + 1
        }
        
        // Create event
        let event = ExperienceEvent(
            id: data.id,
            type: type.name,
            weight: weight,
            metadata: data.metadata,
            timestamp: now,
            maxRepeat: data.maxRepeat,
            expiryDate: expiry
        )
        
        // Add to history
        dataModel.events.append(event)
        
        // Trim history to configured size
        if dataModel.events.count > config.historySize {
            dataModel.events = Array(dataModel.events.suffix(config.historySize))
        }
        
        try save()
    }

    /// Start tracking a delayed experience that may or may not complete later.
    /// The event is not persisted or counted until `completeDelayedExperience` is called.
    func beginDelayedExperience(
        id: String,
        weight: Double,
        metadata: [String: AnyCodable]? = nil,
        ttl: EventTTL? = nil
    ) {
        delayedExperiences[id] = DelayedExperience(
            id: id,
            weight: weight,
            metadata: metadata,
            ttl: ttl
        )
    }

    /// Commit a previously started delayed experience.
    /// If no delayed experience exists for the ID, this is a no-op.
    func completeDelayedExperience(id: String) throws {
        guard let pending = delayedExperiences.removeValue(forKey: id) else { return }

        let data = ExperienceData(
            id: pending.id,
            weight: pending.weight,
            maxRepeat: nil,
            metadata: pending.metadata,
            ttl: pending.ttl
        )

        // Map weight sign to event polarity
        let type: ExperienceType
        if pending.weight > 0 {
            type = .positive(data)
        } else if pending.weight < 0 {
            type = .negative(data)
        } else {
            type = .neutral(data)
        }

        try logExperience(type)
    }

    /// Cancel and forget a delayed experience without logging it.
    func cancelDelayedExperience(id: String) {
        delayedExperiences.removeValue(forKey: id)
    }
    
    // MARK: - Statistics
    
    func getStatistics() -> ExperienceStats {
        let positiveCount = dataModel.events.filter { $0.type == "positive" }.count
        let negativeCount = dataModel.events.filter { $0.type == "negative" }.count
        let neutralCount = dataModel.events.filter { $0.type == "neutral" }.count
        
        let weightedScore = dataModel.events.reduce(0.0) { $0 + $1.weight }
        
        // Compute current non-negative streak from most recent backwards
        var streak = 0
        for event in dataModel.events.reversed() {
            if event.type == "positive" || event.type == "neutral" {
                streak += 1
            } else {
                break
            }
        }
        
        return ExperienceStats(
            positiveCount: positiveCount,
            negativeCount: negativeCount,
            neutralCount: neutralCount,
            weightedScore: weightedScore,
            totalEvents: dataModel.events.count,
            appLaunchCount: dataModel.appLaunchCount,
            lastPromptDate: dataModel.lastPromptDate,
            promptCount: dataModel.promptCount,
            promptCountThisVersion: dataModel.promptCountThisVersion,
            currentNonNegativeStreak: streak
        )
    }
    
    func getEventHistory(limit: Int? = nil) -> [ExperienceEvent] {
        if let limit = limit {
            return Array(dataModel.events.suffix(limit))
        }
        return dataModel.events
    }
    
    func getReviewContext() -> ReviewContext {
        let stats = getStatistics()
        
        return ReviewContext(
            positiveCount: stats.positiveCount,
            negativeCount: stats.negativeCount,
            weightedScore: stats.weightedScore,
            lastPromptDate: dataModel.lastPromptDate,
            appLaunchCount: dataModel.appLaunchCount,
            currentVersion: dataModel.currentVersion,
            eventHistory: dataModel.events
        )
    }
    
    // MARK: - User Segment
    
    func setUserSegment(_ segment: UserSegment) throws {
        self.userSegment = segment
        self.dataModel.userSegment = segment
        try save()
    }
    
    func getUserSegment() -> UserSegment? {
        return userSegment
    }
    
    // MARK: - Prompt Tracking
    
    func recordPromptShown() throws {
        dataModel.lastPromptDate = Date()
        dataModel.promptCount += 1
        dataModel.promptCountThisVersion += 1
        try save()
    }
    
    func getCooldownStatus() -> CooldownStatus {
        guard let lastPrompt = dataModel.lastPromptDate else {
            return CooldownStatus(canPromptNow: true, remainingTime: 0, reason: nil)
        }
        
        let elapsed = Date().timeIntervalSince(lastPrompt)
        let cooldown = config.cooldownPeriod.timeInterval
        
        if elapsed < cooldown {
            return CooldownStatus(
                canPromptNow: false,
                remainingTime: cooldown - elapsed,
                reason: "Cooldown period not elapsed"
            )
        }
        
        return CooldownStatus(canPromptNow: true, remainingTime: 0, reason: nil)
    }
    
    // MARK: - App Launch
    
    func incrementAppLaunch() throws {
        dataModel.appLaunchCount += 1
        try save()
    }
    
    func getAppLaunchCount() -> Int {
        return dataModel.appLaunchCount
    }
    
    // MARK: - Reset
    
    func resetEventTracking(for id: String) throws {
        dataModel.eventCounts[id] = 0
        dataModel.events.removeAll { $0.id == id }
        try save()
    }
    
    func resetAll() throws {
        let currentVersion = AppVersionProvider.currentVersion(override: config.overrideVersion)
        dataModel = AppraisalDataModel(currentVersion: currentVersion)
        try save()
    }
    
    // MARK: - Crash Detection
    
    func checkForCrash() async throws -> Bool {
        // Check both the data model flag AND the synchronous UserDefaults flag.
        // The sync flag is the authoritative source because it's written
        // synchronously in the notification handler (no actor hop).
        let syncCleanExit = UserDefaults.standard.bool(forKey: "com.appraisalkit.cleanExit")
        let wasCleanExit = dataModel.lastCleanExit || syncCleanExit
        
        if config.enableCrashDetection && !wasCleanExit {
            // Previous session crashed
            let crashData = ExperienceData(
                id: "app_crash",
                weight: config.crashEventWeight,
                metadata: [
                    "type": AnyCodable("app_crash"),
                    "last_version": AnyCodable(dataModel.currentVersion)
                ]
            )
            
            try logExperience(.negative(crashData))
            return true
        }
        
        return false
    }
    
    func markCleanExit(_ clean: Bool) throws {
        dataModel.lastCleanExit = clean
        try save()
    }
    
    // MARK: - Private Helpers
    
    private func defaultWeight(for type: ExperienceType) -> Double {
        switch type {
        case .positive:
            return config.positiveWeight
        case .negative:
            return config.negativeWeight
        case .neutral:
            return config.neutralWeight
        }
    }
    
    /// Remove events whose TTL has expired, based on either their explicit
    /// `expiryDate` or, for legacy events, the current `defaultEventTTL`.
    private func pruneExpiredEvents(now: Date = Date()) {
        if dataModel.events.isEmpty { return }
        
        let defaultInterval = config.defaultEventTTL.timeInterval
        
        dataModel.events = dataModel.events.filter { event in
            if let expiry = event.expiryDate {
                return expiry > now
            } else {
                // Legacy events (before TTL support): treat them as using the
                // current default TTL from their timestamp.
                return event.timestamp.addingTimeInterval(defaultInterval) > now
            }
        }
    }
    
    private func save() throws {
        try storage.save(dataModel, forKey: storageKey)
    }
}

// MARK: - Supporting Types

public struct ExperienceStats {
    public let positiveCount: Int
    public let negativeCount: Int
    public let neutralCount: Int
    public let weightedScore: Double
    public let totalEvents: Int
    public let appLaunchCount: Int
    public let lastPromptDate: Date?
    public let promptCount: Int
    public let promptCountThisVersion: Int
    /// Number of consecutive non-negative (positive or neutral) events from the most recent backwards
    public let currentNonNegativeStreak: Int
}

public struct CooldownStatus {
    public let canPromptNow: Bool
    public let remainingTime: TimeInterval
    public let reason: String?
}

/// In-memory representation of a delayed experience that has not yet been logged.
struct DelayedExperience {
    let id: String
    let weight: Double
    let metadata: [String: AnyCodable]?
    let ttl: EventTTL?
}
