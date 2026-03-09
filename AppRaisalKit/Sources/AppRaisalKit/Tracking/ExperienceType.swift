import Foundation

/// Represents the type of experience event
public enum ExperienceType: Equatable {
    case positive(ExperienceData)
    case negative(ExperienceData)
    case neutral(ExperienceData)
    
    /// Extract the data from the experience type
    public var data: ExperienceData {
        switch self {
        case .positive(let data), .negative(let data), .neutral(let data):
            return data
        }
    }
    
    /// The name of the experience type
    public var name: String {
        switch self {
        case .positive:
            return "positive"
        case .negative:
            return "negative"
        case .neutral:
            return "neutral"
        }
    }
}
