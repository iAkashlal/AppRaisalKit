import Foundation

/// Data model for persisting appraisal state
struct AppraisalDataModel: Codable, Equatable {
    var events: [ExperienceEvent]
    var eventCounts: [String: Int] // Track occurrences by ID
    var lastPromptDate: Date?
    var promptCount: Int
    var promptCountThisVersion: Int
    var appLaunchCount: Int
    var currentVersion: String
    var userSegment: UserSegment?
    var lastCleanExit: Bool
    
    init(currentVersion: String) {
        self.events = []
        self.eventCounts = [:]
        self.lastPromptDate = nil
        self.promptCount = 0
        self.promptCountThisVersion = 0
        self.appLaunchCount = 0
        self.currentVersion = currentVersion
        self.userSegment = nil
        self.lastCleanExit = true
    }
}
