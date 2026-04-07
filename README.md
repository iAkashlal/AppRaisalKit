# AppRaisalKit

A powerful Swift package for intelligently managing App Store rating prompts based on user experience tracking.

## Features

### V0 (Current)

- ✅ **Smart Experience Tracking** - Track positive, negative, and neutral user experiences
- ✅ **Weighted Scoring System** - Events have configurable weights
- ✅ **Event Deduplication** - Limit repetitions with `.infinite` or `.limited(count)`
- ✅ **Flexible Metadata** - Attach any data with `AnyCodable`
- ✅ **Crash Detection** - Automatically detect and log app crashes
- ✅ **Multiple Prompt Strategies** - System, custom, sync/async callbacks
- ✅ **User Segments** - Adjust behavior for different user types
- ✅ **A/B Testing** - Built-in variant tracking
- ✅ **Debug Mode** - Simulate prompts and view detailed logs
- ✅ **State Observers** - Monitor score changes in real-time
- ✅ **Async/Await** - Full Swift concurrency support
- ✅ **Memento Pattern** - Built-in snapshot/restore (default storage)
- ✅ **Multi-Platform** - iOS, macOS, tvOS, visionOS

## Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / visionOS 1.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add AppRaisalKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AppRaisalKit.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Packages...
2. Enter the repository URL
3. Select the version

## Quick Start

```swift
import AppRaisalKit

// Initialize with configuration
let config = AppraisalConfiguration(
    minimumPositiveEvents: 5,
    cooldownPeriod: .hours(24),
    enableCrashDetection: true,
    debugMode: false
)

let kit = try await AppRaisalKit(configuration: config)

// Track positive experiences
try await kit.addPositiveExperience(
    ExperienceData(
        id: "purchase_completed",
        weight: 5.0,
        maxRepeat: .limited(3),
        metadata: ["amount": AnyCodable(99.99)]
    )
)

// Track negative experiences
try await kit.addNegativeExperience(
    ExperienceData(
        id: "sync_failed",
        metadata: ["error": AnyCodable("NETWORK_TIMEOUT")]
    )
)

// Set async handler for negative events
await kit.setNegativeExperienceHandler { event async in
    await analytics.logError(event)
}

// Request review when appropriate
if await kit.shouldRequestReview() {
    try await kit.requestReview()
}
```

## Configuration Options

```swift
AppraisalConfiguration(
    // Core tracking
    minimumPositiveEvents: 5,           // Min positive events before prompting
    historySize: 50,                    // Number of events to keep
    
    // Timing
    cooldownPeriod: .days(30),          // Time between prompts (.minutes, .hours, .days, .custom)
    minimumAppLaunches: 3,              // Min launches before first prompt
    
    // Weights
    positiveWeight: 1.0,                // Default positive weight
    negativeWeight: -2.0,               // Default negative weight
    neutralWeight: 0.0,                 // Default neutral weight
    scoreThreshold: .fixed(5.0),        // Or .dynamic { context in ... }
    
    // Prompt behavior
    promptStrategy: .systemOnly,        // .callback, .callbackAsync, .customFirst
    maxPromptsPerVersion: 3,
    maxPromptsTotal: 10,
    promptTiming: .afterPositiveExperience,  // When to auto-show prompts
    promptDelay: 2.0,                   // Delay in seconds before showing prompt
    
    // Crash detection
    enableCrashDetection: true,
    crashEventWeight: -5.0,
    
    // A/B testing
    variant: "experiment_v1",
    experimentId: "rating_prompt_test",
    
    // Debug
    debugMode: false,
    simulatePrompt: false,
    
    // Custom storage
    storageProvider: CustomStorageProvider()
)
```

### Cooldown Period Options

```swift
// Time between prompts - prevents prompt fatigue
cooldownPeriod: .minutes(30)     // 30 minutes
cooldownPeriod: .hours(24)       // 24 hours  
cooldownPeriod: .days(30)        // 30 days (recommended)
cooldownPeriod: .custom(3600)    // Custom TimeInterval (1 hour in seconds)
```

### Prompt Timing Options

Controls **when** prompts are automatically triggered:

```swift
// Never auto-trigger (manual only via requestReview())
promptTiming: .immediate

// Auto-trigger after positive experiences (recommended)
promptTiming: .afterPositiveExperience
promptDelay: 5.0  // Wait 5 seconds after positive event

// Auto-trigger after neutral experiences  
promptTiming: .afterNeutralExperience
promptDelay: 2.0

// Custom timing control
promptTiming: .custom
// Then manually call requestReview() when appropriate
```

**Important:** When using `.afterPositiveExperience` or `.afterNeutralExperience`, prompts are **automatically shown** after the specified delay if eligible. Set `promptTiming: .immediate` if you want full manual control.

## Usage Examples

### Game App

```swift
let config = AppraisalConfiguration(
    minimumPositiveEvents: 3,
    negativeWeight: -1.0
)

let kit = try await AppRaisalKit(configuration: config)

// Every level completion counts
try await kit.addPositiveExperience(
    ExperienceData(
        id: "level_complete",
        weight: 1.5,
        maxRepeat: .infinite
    )
)

// Level failures don't hurt as much
try await kit.addNegativeExperience(
    ExperienceData(
        id: "level_failed",
        weight: -0.5
    )
)
```

### E-commerce App

```swift
let config = AppraisalConfiguration(
    minimumPositiveEvents: 2,
    cooldownPeriod: .days(30),
    promptTiming: .afterPositiveExperience,  // Auto-show after purchase
    promptDelay: 3.0  // Wait 3 seconds after purchase success
)

let kit = try await AppRaisalKit(configuration: config)

await kit.setNegativeExperienceHandler { event async in
    if event.id == "checkout_error" {
        await showSupportChat()
    }
}

// After successful purchase, prompt auto-shows in 3 seconds
try await kit.addPositiveExperience(
    ExperienceData(
        id: "purchase",
        weight: 5.0,
        maxRepeat: .limited(3),
        metadata: ["amount": AnyCodable(149.99)]
    )
)
```

### User Segments

```swift
// Adjust behavior based on user type
try await kit.setUserSegment(.powerUser)

// Different thresholds for different users
let config = AppraisalConfiguration(
    scoreThreshold: .dynamic { context in
        context.appLaunchCount < 5 ? 10.0 : 5.0
    }
)
```

### State Observation

```swift
await kit.onStateChange { stats in
    print("Score: \(stats.weightedScore)")
    print("Positive: \(stats.positiveCount)")
    print("Negative: \(stats.negativeCount)")
}
```

### Custom Prompt Strategy

```swift
let config = AppraisalConfiguration(
    promptStrategy: .customFirst {
        // Show custom dialog
        let result = await showCustomDialog()
        return result == .positive // true to show system prompt
    }
)
```

### Debug Mode

```swift
let config = AppraisalConfiguration(
    debugMode: true,
    simulatePrompt: true
)

let kit = try await AppRaisalKit(configuration: config)

// Get detailed debug info
let debugInfo = await kit.getDebugInfo()
print("Score: \(debugInfo.score)")
print("Events: \(debugInfo.eventLog)")
```

## API Reference

### Core Methods

- `logExperience(_ type: ExperienceType)` - Log an experience
- `addPositiveExperience(_ data:)` - Convenience for positive events
- `addNegativeExperience(_ data:)` - Convenience for negative events
- `addNeutralExperience(_ data:)` - Convenience for neutral events
- `shouldRequestReview()` - Check if eligible for review
- `requestReview(force:)` - Request a review

### Handlers

- `setNegativeExperienceHandler(_:)` - Sync or async handler
- `setPositiveExperienceHandler(_:)` - Async handler
- `setExperienceHandler(_:)` - Generic handler for all types

### Statistics & Monitoring

- `getStatistics()` - Get current stats
- `getEventHistory(limit:)` - Get event history
- `getCooldownStatus()` - Check cooldown status
- `getDebugInfo()` - Get debug information

### User Management

- `setUserSegment(_:)` - Set user segment
- `getUserSegment()` - Get current segment

### Reset

- `resetEventTracking(for:)` - Reset specific event
- `resetAll()` - Reset all data

## Best Practices

1. **Track Meaningful Events** - Focus on events that indicate genuine satisfaction
2. **Balance Weights** - Make negative events slightly heavier than positive
3. **Use Metadata** - Add context to events for better analytics
4. **Test Thoroughly** - Use debug mode and simulatePrompt for testing
5. **Respect Cooldowns** - Don't prompt too frequently
6. **Handle Negatives** - Use handlers to offer support
7. **Monitor State** - Use observers to track user sentiment

## Crash Detection

AppRaisalKit can automatically detect app crashes and log them as negative events:

```swift
AppraisalConfiguration(
    enableCrashDetection: true,
    crashEventWeight: -5.0
)
```

**How it works:**
- Uses "clean exit" flag with app lifecycle observers
- Detects crashes between sessions
- Cannot distinguish crashes from force quits

**Limitations:**
- May produce false positives if device loses power
- Debugger stops may appear as crashes in development

## Storage

By default, AppRaisalKit uses `MementoStorage` which implements the Memento design pattern for state management with automatic snapshots and history.

### Default Memento Storage

The Memento pattern allows you to capture and restore application state:

```swift
let kit = try await AppRaisalKit() // Uses MementoStorage by default

// Automatic snapshots are created every 5 saves
// Manual snapshot
try await kit.createSnapshot(tag: "before_major_update")

// View snapshot history
let snapshots = try await kit.getSnapshots()
for snapshot in snapshots {
    print("Snapshot: \(snapshot.tag ?? "unnamed")")
    print("  Score: \(snapshot.score)")
    print("  Events: \(snapshot.eventCount)")
    print("  Date: \(snapshot.timestamp)")
}

// Restore from snapshot
try await kit.restoreSnapshot(withTag: "before_major_update")

// Or restore most recent
try await kit.restoreMostRecentSnapshot()

// Clear history but keep current state
try await kit.clearSnapshotHistory()
```

### Configure Memento Storage

```swift
let mementoStorage = MementoStorage(
    userDefaults: .standard,
    maxHistory: 20,              // Keep up to 20 snapshots
    autoSnapshot: true,          // Auto-create snapshots
    snapshotInterval: 10         // Snapshot every 10 saves
)

let config = AppraisalConfiguration(
    storageProvider: mementoStorage
)
```

### Benefits of Memento Pattern

1. **Undo/Redo Support** - Restore previous states
2. **A/B Testing** - Easily switch between configurations
3. **Debugging** - Examine historical states
4. **Recovery** - Rollback from bad states
5. **Automatic Backups** - Regular state snapshots

### Custom Storage (Alternative)

You can still provide your own storage implementation:

```swift
class CustomStorage: StorageProvider {
    func save<T: Codable>(_ value: T, forKey key: String) throws {
        // Your implementation (Keychain, CoreData, SQLite, etc.)
    }
    
    func load<T: Codable>(forKey key: String) -> T? {
        // Your implementation
    }
    
    func remove(forKey key: String) {
        // Your implementation
    }
}

let config = AppraisalConfiguration(
    storageProvider: CustomStorage()
)
```

### Simple UserDefaults Storage

If you don't need Memento features:

```swift
let config = AppraisalConfiguration(
    storageProvider: UserDefaultsStorage()
)
```

## Thread Safety

All operations are thread-safe using Swift actors. The main facade (`AppRaisalKit`) is an actor, ensuring safe concurrent access.

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Roadmap (V1)

- [ ] Event chains for multi-step journeys
- [ ] Time-based decay for old events
- [ ] Milestone tracking
- [ ] Batch operations
- [ ] Conditional strategies
- [ ] Adaptive cooldown
- [ ] Regional configurations
- [ ] Export/Import for cloud sync
- [ ] Custom UI components

## Support

For issues, questions, or feature requests, please open an issue on GitHub.
