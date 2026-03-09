import Foundation

/// Memento-based storage implementation (default if none provided)
public class MementoStorage: StorageProvider {
    private let caretaker: MementoCaretaker
    private let autoSnapshot: Bool
    private var saveCount: Int = 0
    private let snapshotInterval: Int
    
    /// Initialize with optional configuration
    /// - Parameters:
    ///   - userDefaults: UserDefaults instance (default: .standard)
    ///   - maxHistory: Maximum number of snapshots to keep (default: 10)
    ///   - autoSnapshot: Automatically create snapshots periodically (default: true)
    ///   - snapshotInterval: Create snapshot every N saves (default: 5)
    public init(
        userDefaults: UserDefaults = .standard,
        maxHistory: Int = 10,
        autoSnapshot: Bool = true,
        snapshotInterval: Int = 5
    ) {
        self.caretaker = MementoCaretaker(userDefaults: userDefaults, maxMementos: maxHistory)
        self.autoSnapshot = autoSnapshot
        self.snapshotInterval = snapshotInterval
    }
    
    // MARK: - StorageProvider Implementation
    
    public func save<T: Codable>(_ value: T, forKey key: String) throws {
        // We only handle AppraisalDataModel
        guard let dataModel = value as? AppraisalDataModel else {
            throw MementoStorageError.unsupportedType
        }
        
        // Save current state synchronously using semaphore
        let semaphore = DispatchSemaphore(value: 0)
        var saveError: Error?
        
        Task {
            do {
                try await caretaker.saveCurrentState(dataModel)
            } catch {
                saveError = error
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = saveError {
            throw error
        }
        
        // Auto-snapshot if enabled (fire and forget)
        if autoSnapshot {
            saveCount += 1
            if saveCount % snapshotInterval == 0 {
                Task {
                    try? await caretaker.saveSnapshot(dataModel, tag: "auto_\(saveCount)")
                }
            }
        }
    }
    
    public func load<T: Codable>(forKey key: String) -> T? {
        // Load synchronously using semaphore
        let semaphore = DispatchSemaphore(value: 0)
        var result: T?
        
        Task {
            if let dataModel = await caretaker.loadCurrentState() {
                result = dataModel as? T
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    public func remove(forKey key: String) {
        Task {
            await caretaker.clearCurrentState()
        }
    }
    
    // MARK: - Memento-Specific Methods
    
    /// Create a manual snapshot with optional tag
    public func createSnapshot(tag: String? = nil) async throws {
        guard let state = await caretaker.loadCurrentState() else {
            throw MementoStorageError.noCurrentState
        }
        try await caretaker.saveSnapshot(state, tag: tag)
    }
    
    /// Get all snapshot metadata (lightweight)
    public func getSnapshotMetadata() async -> [MementoMetadata] {
        return await caretaker.getMetadata()
    }
    
    /// Restore from snapshot at index
    public func restoreSnapshot(at index: Int) async throws {
        guard let restored = try await caretaker.restoreSnapshot(at: index) else {
            throw MementoStorageError.snapshotNotFound
        }
        // State is automatically saved as current by caretaker
    }
    
    /// Restore from snapshot with specific tag
    public func restoreSnapshot(withTag tag: String) async throws {
        guard let restored = try await caretaker.restoreSnapshot(withTag: tag) else {
            throw MementoStorageError.snapshotNotFound
        }
        // State is automatically saved as current by caretaker
    }
    
    /// Restore most recent snapshot
    public func restoreMostRecent() async throws {
        guard let restored = try await caretaker.restoreMostRecent() else {
            throw MementoStorageError.noHistory
        }
        // State is automatically saved as current by caretaker
    }
    
    /// Get count of snapshots in history
    public func getSnapshotCount() async -> Int {
        let metadata = await caretaker.getMetadata()
        return metadata.count
    }
    
    /// Clear all snapshot history (keeps current state)
    public func clearHistory() async {
        await caretaker.clearHistory()
    }
    
    /// Clear all data including current state
    public func clearAll() async {
        await caretaker.clearAll()
    }
}

// MARK: - Errors

public enum MementoStorageError: Error, LocalizedError {
    case unsupportedType
    case noCurrentState
    case snapshotNotFound
    case noHistory
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedType:
            return "MementoStorage only supports AppraisalDataModel"
        case .noCurrentState:
            return "No current state to snapshot"
        case .snapshotNotFound:
            return "Snapshot not found"
        case .noHistory:
            return "No snapshot history available"
        }
    }
}
