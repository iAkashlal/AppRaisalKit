import Foundation

/// Main facade for AppRaisalKit
@available(iOS 15.0, macOS 12.0, tvOS 15.0, visionOS 1.0, *)
public actor AppRaisalKit {
    
    internal let config: AppraisalConfiguration
    private let tracker: ExperienceTracker
    private let ratingStrategy: RatingStrategy
    private let crashDetector: CrashDetector
    private let storeKit: StoreKitIntegration
    private let handlers: ExperienceHandlers
    internal let logger: DebugLogger
    
    private var stateChangeObservers: [(ExperienceStats) -> Void] = []
    private var pendingAutoTrigger: Task<Void, Never>?
    private var isShowingReview = false
    
    // MARK: - Initialization
    
    public init(configuration: AppraisalConfiguration? = nil) async throws {
        self.config = configuration ?? AppraisalConfiguration()
        self.logger = DebugLogger(isEnabled: self.config.debugMode)
        
        self.tracker = ExperienceTracker(
            config: self.config,
            storage: self.config.storageProvider
        )
        
        self.ratingStrategy = RatingStrategy(
            config: self.config,
            tracker: self.tracker
        )
        
        self.crashDetector = CrashDetector(tracker: self.tracker)
        self.storeKit = StoreKitIntegration(config: self.config)
        self.handlers = ExperienceHandlers()
        
        // Start crash detection
        if self.config.enableCrashDetection {
            try await crashDetector.startObserving()
        }
        
        // Increment app launch count
        try await tracker.incrementAppLaunch()
        
        logger.log("AppRaisalKit initialized")
    }
    
    // MARK: - Core API
    
    /// Log an experience (positive, negative, or neutral)
    public func logExperience(_ type: ExperienceType) async throws {
        try await tracker.logExperience(type)
        
        // Create event for handlers
        let event = ExperienceEvent(
            id: type.data.id,
            type: type.name,
            weight: type.data.weight ?? defaultWeight(for: type),
            metadata: type.data.metadata,
            timestamp: Date(),
            maxRepeat: type.data.maxRepeat
        )
        
        // Call type-specific handlers
        switch type {
        case .negative:
            let negEvent = NegativeExperienceEvent(
                id: event.id,
                weight: event.weight,
                metadata: event.metadata,
                timestamp: event.timestamp
            )
            await handlers.callNegativeHandler(event: negEvent)
            
        case .positive:
            let posEvent = NegativeExperienceEvent(
                id: event.id,
                weight: event.weight,
                metadata: event.metadata,
                timestamp: event.timestamp
            )
            await handlers.callPositiveHandler(event: posEvent)
            
            // Auto-trigger review if configured
            if config.promptTiming == .afterPositiveExperience {
                // Cancel any previous pending auto-trigger
                pendingAutoTrigger?.cancel()
                pendingAutoTrigger = Task {
                    try? await Task.sleep(nanoseconds: UInt64(config.promptDelay * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    try? await self.requestReview(fromAutoTrigger: true)
                }
            }
            
        case .neutral:
            break
        }
        
        // Call generic handler
        await handlers.callGenericHandler(type: type, event: event)
        
        // Notify observers
        await notifyStateChange()
        
        logger.log("Logged \(type.name) experience", data: type.data.id ?? "unnamed")
    }

    // MARK: - Delayed Experiences

    /// Begin a delayed experience which will only be logged if later completed.
    /// Until completion, the event is held in-memory and not included in stats.
    public func beginDelayedExperience(
        id: String,
        weight: Double,
        metadata: [String: AnyCodable]? = nil,
        ttl: EventTTL? = nil
    ) async {
        await tracker.beginDelayedExperience(
            id: id,
            weight: weight,
            metadata: metadata,
            ttl: ttl
        )
        logger.log("Begin delayed experience", data: id)
    }

    /// Complete a previously started delayed experience and persist it.
    public func completeDelayedExperience(id: String) async throws {
        try await tracker.completeDelayedExperience(id: id)
        await notifyStateChange()
        logger.log("Complete delayed experience", data: id)
    }

    /// Cancel a previously started delayed experience without logging it.
    public func cancelDelayedExperience(id: String) async {
        await tracker.cancelDelayedExperience(id: id)
        logger.log("Cancel delayed experience", data: id)
    }
    
    // MARK: - Convenience Helpers
    
    /// Add a positive experience
    public func addPositiveExperience(_ data: ExperienceData = ExperienceData()) async throws {
        try await logExperience(.positive(data))
    }
    
    /// Add a positive experience with just an ID
    public func addPositiveExperience(id: String, maxRepeat: RepeatLimit? = nil) async throws {
        let data = ExperienceData(id: id, maxRepeat: maxRepeat)
        try await logExperience(.positive(data))
    }
    
    /// Add a negative experience
    public func addNegativeExperience(_ data: ExperienceData = ExperienceData()) async throws {
        try await logExperience(.negative(data))
    }
    
    /// Add a negative experience with just an ID
    public func addNegativeExperience(id: String, metadata: [String: AnyCodable]? = nil) async throws {
        let data = ExperienceData(id: id, metadata: metadata)
        try await logExperience(.negative(data))
    }
    
    /// Add a neutral experience
    public func addNeutralExperience(_ data: ExperienceData = ExperienceData()) async throws {
        try await logExperience(.neutral(data))
    }
    
    // MARK: - Review Request
    
    /// Check if ready to request review
    public func shouldRequestReview() async -> Bool {
        let result = await ratingStrategy.shouldRequestReview()
        
        if !result.eligible {
            logger.log("Not eligible for review", data: result.reason ?? "unknown")
        }
        
        return result.eligible
    }
    
    /// Check eligibility with a detailed reason when not eligible
    public func checkEligibility() async -> (eligible: Bool, reason: String?) {
        return await ratingStrategy.shouldRequestReview()
    }
    
    /// Request a review (async)
    public func requestReview(force: Bool = false) async throws {
        try await requestReview(force: force, fromAutoTrigger: false)
    }
    
    /// Internal review request with auto-trigger awareness
    private func requestReview(force: Bool = false, fromAutoTrigger: Bool) async throws {
        // Prevent concurrent review attempts
        guard !isShowingReview else {
            logger.log("Review request skipped - already showing")
            return
        }
        
        let eligible = await shouldRequestReview()
        guard force || eligible else {
            logger.log("Review request skipped - not eligible")
            return
        }
        
        isShowingReview = true
        defer { isShowingReview = false }
        
        let context = await tracker.getReviewContext()
        
        // Handle based on strategy
        switch config.promptStrategy {
        case .systemOnly:
            try await handleSystemPrompt(skipDelay: fromAutoTrigger)
            
        case .callback(let handler):
            handler(context)
            try await tracker.recordPromptShown()
            
        case .callbackAsync(let handler):
            await handler(context)
            try await tracker.recordPromptShown()
            
        case .customFirst(let customHandler):
            let shouldShowSystem = await customHandler()
            if shouldShowSystem {
                try await handleSystemPrompt(skipDelay: fromAutoTrigger)
            } else {
                try await tracker.recordPromptShown()
            }
            
        case .conditional(let strategySelector):
            let selectedStrategy = strategySelector(context)
            try await handleSystemPrompt(skipDelay: fromAutoTrigger)
        }
        
        logger.log("Review requested")
    }
    
    private func handleSystemPrompt(skipDelay: Bool = false) async throws {
        // Only delay if not already delayed by auto-trigger
        if !skipDelay && config.promptDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(config.promptDelay * 1_000_000_000))
        }
        
        await storeKit.requestReview()
        try await tracker.recordPromptShown()
    }
    
    // MARK: - Handlers
    
    /// Set negative experience handler (sync)
    public func setNegativeExperienceHandler(_ handler: @escaping SyncExperienceHandler) async {
        await handlers.setNegativeHandler(sync: handler)
    }
    
    /// Set negative experience handler (async)
    public func setNegativeExperienceHandler(_ handler: @escaping AsyncExperienceHandler) async {
        await handlers.setNegativeHandler(async: handler)
    }
    
    /// Remove negative experience handler
    public func removeNegativeExperienceHandler() async {
        await handlers.removeNegativeHandler()
    }
    
    /// Set positive experience handler (async)
    public func setPositiveExperienceHandler(_ handler: @escaping AsyncExperienceHandler) async {
        await handlers.setPositiveHandler(async: handler)
    }
    
    /// Remove positive experience handler
    public func removePositiveExperienceHandler() async {
        await handlers.removePositiveHandler()
    }
    
    /// Set generic experience handler (catches all types)
    public func setExperienceHandler(_ handler: @escaping GenericExperienceHandler) async {
        await handlers.setGenericHandler(handler)
    }
    
    /// Remove generic experience handler
    public func removeExperienceHandler() async {
        await handlers.removeGenericHandler()
    }
    
    // MARK: - User Segment
    
    /// Set user segment
    public func setUserSegment(_ segment: UserSegment) async throws {
        try await tracker.setUserSegment(segment)
        logger.log("User segment set", data: segment.rawValue)
    }
    
    /// Get current user segment
    public func getUserSegment() async -> UserSegment? {
        return await tracker.getUserSegment()
    }
    
    // MARK: - Statistics & Monitoring
    
    /// Get current statistics
    public func getStatistics() async -> ExperienceStats {
        return await tracker.getStatistics()
    }
    
    /// Get event history
    public func getEventHistory(limit: Int? = nil) async -> [ExperienceEvent] {
        return await tracker.getEventHistory(limit: limit)
    }
    
    /// Get cooldown status
    public func getCooldownStatus() async -> CooldownStatus {
        return await tracker.getCooldownStatus()
    }
    
    /// Get debug information
    public func getDebugInfo() async -> DebugInfo {
        let stats = await tracker.getStatistics()
        let events = await tracker.getEventHistory()
        let cooldown = await tracker.getCooldownStatus()
        
        return DebugInfo(
            score: stats.weightedScore,
            eventLog: events,
            stats: stats,
            cooldownStatus: cooldown
        )
    }
    
    // MARK: - State Observers
    
    /// Observe state changes
    public func onStateChange(_ observer: @escaping (ExperienceStats) -> Void) {
        stateChangeObservers.append(observer)
    }
    
    private func notifyStateChange() async {
        let stats = await tracker.getStatistics()
        for observer in stateChangeObservers {
            observer(stats)
        }
    }
    
    // MARK: - Reset
    
    /// Reset tracking for a specific event ID
    public func resetEventTracking(for id: String) async throws {
        try await tracker.resetEventTracking(for: id)
        logger.log("Reset event tracking", data: id)
    }
    
    /// Reset all data
    public func resetAll() async throws {
        try await tracker.resetAll()
        logger.log("Reset all data")
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
}
