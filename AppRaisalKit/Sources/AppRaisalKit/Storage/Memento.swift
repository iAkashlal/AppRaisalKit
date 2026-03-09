import Foundation

/// Memento - Captures the state of AppRaisalKit at a point in time
public struct AppRaisalMemento: Codable, Equatable {
    let state: AppraisalDataModel
    let timestamp: Date
    let tag: String?
    
    init(state: AppraisalDataModel, tag: String? = nil) {
        self.state = state
        self.timestamp = Date()
        self.tag = tag
    }
    
    /// Description of the memento
    public var description: String {
        let tagInfo = tag.map { " [\($0)]" } ?? ""
        return "Memento\(tagInfo) - Score: \(calculateScore()), Events: \(state.events.count), \(timestamp)"
    }
    
    private func calculateScore() -> Double {
        return state.events.reduce(0.0) { $0 + $1.weight }
    }
}

/// Memento metadata for listing without loading full state
public struct MementoMetadata: Codable {
    public let timestamp: Date
    public let tag: String?
    public let eventCount: Int
    public let score: Double
    public let version: String
    
    init(from memento: AppRaisalMemento) {
        self.timestamp = memento.timestamp
        self.tag = memento.tag
        self.eventCount = memento.state.events.count
        self.score = memento.state.events.reduce(0.0) { $0 + $1.weight }
        self.version = memento.state.currentVersion
    }
}
