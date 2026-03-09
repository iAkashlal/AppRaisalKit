import Foundation
import StoreKit

/// Handles StoreKit review prompt requests
actor StoreKitIntegration {
    private let config: AppraisalConfiguration
    
    init(config: AppraisalConfiguration) {
        self.config = config
    }
    
    /// Request review using StoreKit
    func requestReview() async {
        guard !config.simulatePrompt else {
            if config.debugMode {
                print("[AppRaisalKit] Simulated review prompt (debug mode)")
            }
            return
        }
        
        #if canImport(UIKit) && !os(watchOS)
        await requestReviewUIKit()
        #elseif canImport(AppKit)
        await requestReviewAppKit()
        #endif
    }
    
    #if canImport(UIKit) && !os(watchOS)
    @MainActor
    private func requestReviewUIKit() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }
    #endif
    
    #if canImport(AppKit)
    @MainActor
    private func requestReviewAppKit() {
        SKStoreReviewController.requestReview()
    }
    #endif
}
