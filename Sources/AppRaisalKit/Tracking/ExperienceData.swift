import Foundation

/// Data structure for tracking user experiences
public struct ExperienceData: Codable, Equatable {
    /// Optional unique identifier for the event
    public var id: String?
    
    /// Optional weight (uses config default if nil)
    public var weight: Double?
    
    /// Only respected when id is provided
    public var maxRepeat: RepeatLimit?
    
    /// Optional metadata dictionary
    public var metadata: [String: AnyCodable]?

    /// Optional time-to-live for this specific event.
    /// If nil, `AppraisalConfiguration.defaultEventTTL` is used.
    public var ttl: EventTTL?
    
    public init(
        id: String? = nil,
        weight: Double? = nil,
        maxRepeat: RepeatLimit? = nil,
        metadata: [String: AnyCodable]? = nil,
        ttl: EventTTL? = nil
    ) {
        self.id = id
        self.weight = weight
        self.maxRepeat = maxRepeat
        self.metadata = metadata
        self.ttl = ttl
    }
}
