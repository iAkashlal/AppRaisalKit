import Foundation

/// Time-to-live configuration for experience events.
///
/// Controls how long an event remains active before it is automatically
/// discarded from the history and scoring calculations.
public enum EventTTL: Codable, Equatable {
    case minutes(Int)
    case hours(Int)
    case days(Int)

    /// Convert the TTL into a concrete `TimeInterval`.
    var timeInterval: TimeInterval {
        switch self {
        case .minutes(let value):
            return TimeInterval(value * 60)
        case .hours(let value):
            return TimeInterval(value * 60 * 60)
        case .days(let value):
            return TimeInterval(value * 24 * 60 * 60)
        }
    }
}

