import Foundation

/// Type alias for sync experience handlers
public typealias SyncExperienceHandler = (NegativeExperienceEvent) -> Void

/// Type alias for async experience handlers
public typealias AsyncExperienceHandler = (NegativeExperienceEvent) async -> Void

/// Type alias for generic experience handlers
public typealias GenericExperienceHandler = (ExperienceType, ExperienceEvent) async -> Void

/// Wrapper for experience handlers
actor ExperienceHandlers {
    private var negativeHandlerSync: SyncExperienceHandler?
    private var negativeHandlerAsync: AsyncExperienceHandler?
    private var positiveHandlerAsync: AsyncExperienceHandler?
    private var genericHandler: GenericExperienceHandler?
    
    // MARK: - Negative Experience Handlers
    
    func setNegativeHandler(sync handler: @escaping SyncExperienceHandler) {
        self.negativeHandlerSync = handler
        self.negativeHandlerAsync = nil
    }
    
    func setNegativeHandler(async handler: @escaping AsyncExperienceHandler) {
        self.negativeHandlerAsync = handler
        self.negativeHandlerSync = nil
    }
    
    func removeNegativeHandler() {
        self.negativeHandlerSync = nil
        self.negativeHandlerAsync = nil
    }
    
    func callNegativeHandler(event: NegativeExperienceEvent) async {
        if let asyncHandler = negativeHandlerAsync {
            await asyncHandler(event)
        } else if let syncHandler = negativeHandlerSync {
            syncHandler(event)
        }
    }
    
    // MARK: - Positive Experience Handlers
    
    func setPositiveHandler(async handler: @escaping AsyncExperienceHandler) {
        self.positiveHandlerAsync = handler
    }
    
    func removePositiveHandler() {
        self.positiveHandlerAsync = nil
    }
    
    func callPositiveHandler(event: NegativeExperienceEvent) async {
        await positiveHandlerAsync?(event)
    }
    
    // MARK: - Generic Handler
    
    func setGenericHandler(_ handler: @escaping GenericExperienceHandler) {
        self.genericHandler = handler
    }
    
    func removeGenericHandler() {
        self.genericHandler = nil
    }
    
    func callGenericHandler(type: ExperienceType, event: ExperienceEvent) async {
        await genericHandler?(type, event)
    }
}
