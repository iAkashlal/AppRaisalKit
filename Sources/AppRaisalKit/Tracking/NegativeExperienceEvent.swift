import Foundation

/// Event data passed to negative experience handlers
public struct NegativeExperienceEvent: Codable, Equatable {
    public let id: String?
    public let weight: Double
    public let metadata: [String: AnyCodable]?
    public let timestamp: Date
    
    public init(
        id: String?,
        weight: Double,
        metadata: [String: AnyCodable]?,
        timestamp: Date
    ) {
        self.id = id
        self.weight = weight
        self.metadata = metadata
        self.timestamp = timestamp
    }
}
