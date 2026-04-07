import Foundation

/// Defines how many times a specific event ID can be counted
public enum RepeatLimit: Codable, Equatable {
    /// Event can be counted unlimited times
    case infinite
    /// Event can be counted up to a maximum number of times
    case limited(Int)
    
    public var description: String {
        switch self {
        case .infinite:
            return "infinite"
        case .limited(let count):
            return "limited(\(count))"
        }
    }
}
