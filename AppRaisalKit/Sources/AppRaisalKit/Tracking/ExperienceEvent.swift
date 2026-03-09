import Foundation

/// Represents a tracked experience event with full details
public struct ExperienceEvent: Codable, Equatable {
    public let id: String?
    public let type: String // "positive", "negative", "neutral"
    public let weight: Double
    public let metadata: [String: AnyCodable]?
    public let timestamp: Date
    public let maxRepeat: RepeatLimit?
    /// Absolute expiry date after which this event is ignored and pruned.
    /// For events created before TTL support, this will be nil.
    public let expiryDate: Date?
    
    public init(
        id: String?,
        type: String,
        weight: Double,
        metadata: [String: AnyCodable]?,
        timestamp: Date,
        maxRepeat: RepeatLimit?,
        expiryDate: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.weight = weight
        self.metadata = metadata
        self.timestamp = timestamp
        self.maxRepeat = maxRepeat
        self.expiryDate = expiryDate
    }
}
