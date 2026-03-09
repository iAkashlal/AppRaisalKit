import Foundation

/// Time-based cooldown periods to prevent prompt fatigue
///
/// ## Usage
/// ```swift
/// cooldownPeriod: .minutes(30)   // 30 minutes (testing only)
/// cooldownPeriod: .hours(24)     // 24 hours
/// cooldownPeriod: .days(30)      // 30 days (recommended)
/// cooldownPeriod: .custom(3600)  // Custom seconds (1 hour)
/// ```
public enum CooldownPeriod: Codable, Equatable {
    case minutes(Int)
    case hours(Int)
    case days(Int)
    case custom(TimeInterval)
    
    /// Convert to TimeInterval
    public var timeInterval: TimeInterval {
        switch self {
        case .minutes(let minutes):
            return TimeInterval(minutes * 60)
        case .hours(let hours):
            return TimeInterval(hours * 3600)
        case .days(let days):
            return TimeInterval(days * 86400)
        case .custom(let interval):
            return interval
        }
    }
}
