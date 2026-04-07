import Foundation

/// User segment types for behavior adjustment
public enum UserSegment: String, Codable {
    case newUser
    case regularUser
    case powerUser
    case champion
}
