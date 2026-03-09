import Foundation

/// Prompt strategies for requesting reviews
public enum PromptStrategy {
    /// Show system StoreKit review prompt only
    case systemOnly
    
    /// Show custom UI first before system prompt
    case customFirst(() async -> Bool) // Returns true if should show system prompt
    
    /// Synchronous callback - app handles everything
    case callback((ReviewContext) -> Void)
    
    /// Asynchronous callback - app handles everything
    case callbackAsync((ReviewContext) async -> Void)
    
    /// Dynamic strategy selection based on context
    case conditional((ReviewContext) -> PromptStrategy)
}
