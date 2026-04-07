import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Detects app crashes using lifecycle observations
///
/// Uses a "clean exit" flag persisted synchronously to UserDefaults.
/// On startup the flag is `false`. When the app backgrounds or terminates
/// normally, the flag is set to `true` **synchronously** (no actor hop)
/// so the write completes before the process is killed.
/// If the flag is still `false` on next launch, a crash is assumed.
actor CrashDetector {
    private let tracker: ExperienceTracker
    private var isObserving = false
    
    /// Dedicated key for the synchronous clean-exit flag.
    /// Kept in sync with the tracker's data model on startup.
    private static let cleanExitKey = "com.appraisalkit.cleanExit"
    
    init(tracker: ExperienceTracker) {
        self.tracker = tracker
    }
    
    func startObserving() async throws {
        guard !isObserving else { return }
        isObserving = true
        
        // Check for crash on startup
        let didCrash = try await tracker.checkForCrash()
        
        if didCrash {
            print("[AppRaisalKit] Detected crash from previous session")
        }
        
        // Mark as not clean exit (app is now running)
        try await tracker.markCleanExit(false)
        CrashDetector.setCleanExitFlag(false)
        
        // Setup lifecycle observers
        await setupLifecycleObservers()
    }
    
    /// Synchronously writes the clean-exit flag to UserDefaults.
    /// Called from notification handlers where the process may be
    /// killed immediately after, so no async/actor work is safe.
    private static func setCleanExitFlag(_ clean: Bool) {
        UserDefaults.standard.set(clean, forKey: cleanExitKey)
        UserDefaults.standard.synchronize()   // force flush before process dies
    }
    
    private func setupLifecycleObservers() async {
        #if canImport(UIKit) && !os(watchOS)
        setupUIKitObservers()
        #elseif canImport(AppKit)
        setupAppKitObservers()
        #endif
    }
    
    #if canImport(UIKit) && !os(watchOS)
    private func setupUIKitObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            // Synchronous — guaranteed to finish before process suspends
            CrashDetector.setCleanExitFlag(true)
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            CrashDetector.setCleanExitFlag(true)
        }
    }
    #endif
    
    #if canImport(AppKit)
    private func setupAppKitObservers() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            CrashDetector.setCleanExitFlag(true)
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.willHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            CrashDetector.setCleanExitFlag(true)
        }
    }
    #endif
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
