import Foundation

/// Debug logger for AppRaisalKit
struct DebugLogger {
    private let isEnabled: Bool
    
    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
    
    func log(_ message: String) {
        guard isEnabled else { return }
        print("[AppRaisalKit] \(message)")
    }
    
    func log(_ message: String, data: Any) {
        guard isEnabled else { return }
        print("[AppRaisalKit] \(message): \(data)")
    }
}

/// Debug information for testing
public struct DebugInfo {
    public let score: Double
    public let eventLog: [ExperienceEvent]
    public let stats: ExperienceStats
    public let cooldownStatus: CooldownStatus
}
