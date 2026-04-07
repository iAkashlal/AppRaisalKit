import Foundation

/// Provides app version information
public struct AppVersionProvider {
    /// Get the current app version from Bundle
    public static func currentVersion(override: String? = nil) -> String {
        if let override = override {
            return override
        }
        
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }
}
