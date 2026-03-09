import Foundation

/// Caretaker - Manages memento history and persistence
actor MementoCaretaker {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let maxMementos: Int
    
    private let currentStateKey = "com.appraisalkit.memento.current"
    private let historyKey = "com.appraisalkit.memento.history"
    private let metadataKey = "com.appraisalkit.memento.metadata"
    
    init(userDefaults: UserDefaults = .standard, maxMementos: Int = 10) {
        self.userDefaults = userDefaults
        self.maxMementos = maxMementos
    }
    
    // MARK: - Current State Management
    
    /// Save current state as memento
    func saveCurrentState(_ state: AppraisalDataModel, tag: String? = nil) throws {
        let memento = AppRaisalMemento(state: state, tag: tag)
        let data = try encoder.encode(memento)
        userDefaults.set(data, forKey: currentStateKey)
    }
    
    /// Load current state
    func loadCurrentState() -> AppraisalDataModel? {
        guard let data = userDefaults.data(forKey: currentStateKey),
              let memento = try? decoder.decode(AppRaisalMemento.self, from: data) else {
            return nil
        }
        return memento.state
    }
    
    // MARK: - History Management
    
    /// Save a snapshot to history
    func saveSnapshot(_ state: AppraisalDataModel, tag: String? = nil) throws {
        let memento = AppRaisalMemento(state: state, tag: tag)
        var history = loadHistory()
        
        // Add new memento
        history.append(memento)
        
        // Keep only the last N mementos
        if history.count > maxMementos {
            history = Array(history.suffix(maxMementos))
        }
        
        // Save history
        let data = try encoder.encode(history)
        userDefaults.set(data, forKey: historyKey)
        
        // Update metadata
        try updateMetadata(from: history)
    }
    
    /// Load all mementos from history
    func loadHistory() -> [AppRaisalMemento] {
        guard let data = userDefaults.data(forKey: historyKey),
              let history = try? decoder.decode([AppRaisalMemento].self, from: data) else {
            return []
        }
        return history
    }
    
    /// Get metadata of all mementos (lightweight)
    func getMetadata() -> [MementoMetadata] {
        guard let data = userDefaults.data(forKey: metadataKey),
              let metadata = try? decoder.decode([MementoMetadata].self, from: data) else {
            return []
        }
        return metadata
    }
    
    /// Restore state from a specific snapshot
    func restoreSnapshot(at index: Int) throws -> AppraisalDataModel? {
        let history = loadHistory()
        guard index >= 0 && index < history.count else {
            return nil
        }
        
        let memento = history[index]
        try saveCurrentState(memento.state, tag: "restored")
        return memento.state
    }
    
    /// Restore state by tag
    func restoreSnapshot(withTag tag: String) throws -> AppraisalDataModel? {
        let history = loadHistory()
        guard let memento = history.first(where: { $0.tag == tag }) else {
            return nil
        }
        
        try saveCurrentState(memento.state, tag: "restored_from_\(tag)")
        return memento.state
    }
    
    /// Restore most recent snapshot
    func restoreMostRecent() throws -> AppraisalDataModel? {
        let history = loadHistory()
        guard let memento = history.last else {
            return nil
        }
        
        try saveCurrentState(memento.state, tag: "restored_recent")
        return memento.state
    }
    
    // MARK: - Cleanup
    
    /// Clear all history
    func clearHistory() {
        userDefaults.removeObject(forKey: historyKey)
        userDefaults.removeObject(forKey: metadataKey)
    }
    
    /// Clear current state
    func clearCurrentState() {
        userDefaults.removeObject(forKey: currentStateKey)
    }
    
    /// Clear everything
    func clearAll() {
        clearCurrentState()
        clearHistory()
    }
    
    // MARK: - Private Helpers
    
    private func updateMetadata(from history: [AppRaisalMemento]) throws {
        let metadata = history.map { MementoMetadata(from: $0) }
        let data = try encoder.encode(metadata)
        userDefaults.set(data, forKey: metadataKey)
    }
}
