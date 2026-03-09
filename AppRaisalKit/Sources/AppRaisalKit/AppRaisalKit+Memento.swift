import Foundation

/// Extension to AppRaisalKit for Memento pattern support
@available(iOS 15.0, macOS 12.0, tvOS 15.0, visionOS 1.0, *)
extension AppRaisalKit {
    
    // MARK: - Snapshot Management
    
    /// Create a manual snapshot of current state
    /// - Parameter tag: Optional tag to identify this snapshot
    public func createSnapshot(tag: String? = nil) async throws {
        guard let mementoStorage = config.storageProvider as? MementoStorage else {
            throw MementoError.notUsingMementoStorage
        }
        try await mementoStorage.createSnapshot(tag: tag)
        logger.log("Snapshot created", data: tag ?? "untagged")
    }
    
    /// Get all snapshot metadata
    public func getSnapshots() async throws -> [MementoMetadata] {
        guard let mementoStorage = config.storageProvider as? MementoStorage else {
            throw MementoError.notUsingMementoStorage
        }
        return await mementoStorage.getSnapshotMetadata()
    }
    
    /// Restore state from a specific snapshot
    /// - Parameter index: Index of snapshot in history (0 = oldest)
    public func restoreSnapshot(at index: Int) async throws {
        guard let mementoStorage = config.storageProvider as? MementoStorage else {
            throw MementoError.notUsingMementoStorage
        }
        try await mementoStorage.restoreSnapshot(at: index)
        logger.log("Snapshot restored", data: "index \(index)")
    }
    
    /// Restore state from snapshot with specific tag
    /// - Parameter tag: Tag of the snapshot to restore
    public func restoreSnapshot(withTag tag: String) async throws {
        guard let mementoStorage = config.storageProvider as? MementoStorage else {
            throw MementoError.notUsingMementoStorage
        }
        try await mementoStorage.restoreSnapshot(withTag: tag)
        logger.log("Snapshot restored", data: "tag: \(tag)")
    }
    
    /// Restore the most recent snapshot
    public func restoreMostRecentSnapshot() async throws {
        guard let mementoStorage = config.storageProvider as? MementoStorage else {
            throw MementoError.notUsingMementoStorage
        }
        try await mementoStorage.restoreMostRecent()
        logger.log("Most recent snapshot restored")
    }
    
    /// Get count of available snapshots
    public func getSnapshotCount() async throws -> Int {
        guard let mementoStorage = config.storageProvider as? MementoStorage else {
            throw MementoError.notUsingMementoStorage
        }
        return await mementoStorage.getSnapshotCount()
    }
    
    /// Clear all snapshot history (keeps current state)
    public func clearSnapshotHistory() async throws {
        guard let mementoStorage = config.storageProvider as? MementoStorage else {
            throw MementoError.notUsingMementoStorage
        }
        await mementoStorage.clearHistory()
        logger.log("Snapshot history cleared")
    }
    
    /// Check if using Memento storage
    public var isUsingMementoStorage: Bool {
        return config.storageProvider is MementoStorage
    }
}

// MARK: - Errors

public enum MementoError: Error, LocalizedError {
    case notUsingMementoStorage
    
    public var errorDescription: String? {
        switch self {
        case .notUsingMementoStorage:
            return "Memento operations require MementoStorage. Current storage provider does not support snapshots."
        }
    }
}
