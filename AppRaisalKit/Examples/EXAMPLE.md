# AppRaisalKit Example

This is a simple example demonstrating how to use AppRaisalKit in your iOS app.

## Basic Usage

```swift
import SwiftUI
import AppRaisalKit

@main
struct ExampleApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

class AppState: ObservableObject {
    var appraisalKit: AppRaisalKit?
    
    init() {
        Task {
            await setupAppRaisalKit()
        }
    }
    
    @MainActor
    func setupAppRaisalKit() async {
        let config = AppraisalConfiguration(
            minimumPositiveEvents: 5,
            cooldownPeriod: .hours(24),
            positiveWeight: 1.0,
            negativeWeight: -2.0,
            enableCrashDetection: true,
            debugMode: true,
            variant: "v1"
        )
        
        do {
            appraisalKit = try await AppRaisalKit(configuration: config)
            
            // Set negative handler
            await appraisalKit?.setNegativeExperienceHandler { event async in
                print("Negative experience: \(event.id ?? "unknown")")
                // Could show support chat here
            }
            
            // Set positive handler
            await appraisalKit?.setPositiveExperienceHandler { event async in
                print("Positive experience: \(event.id ?? "unknown")")
            }
            
            // Observe state changes
            await appraisalKit?.onStateChange { stats in
                print("Score updated: \(stats.weightedScore)")
            }
            
        } catch {
            print("Failed to initialize AppRaisalKit: \(error)")
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var stats: ExperienceStats?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("AppRaisalKit Example")
                .font(.title)
            
            if let stats = stats {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Statistics:")
                        .font(.headline)
                    
                    Text("Positive: \(stats.positiveCount)")
                    Text("Negative: \(stats.negativeCount)")
                    Text("Score: \(String(format: "%.1f", stats.weightedScore))")
                    Text("App Launches: \(stats.appLaunchCount)")
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            }
            
            VStack(spacing: 10) {
                Button("Add Positive Experience") {
                    Task {
                        try? await appState.appraisalKit?.addPositiveExperience(
                            ExperienceData(
                                id: "button_tap",
                                weight: 1.0,
                                maxRepeat: .infinite,
                                metadata: ["action": AnyCodable("positive_button")]
                            )
                        )
                        await updateStats()
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("Add Negative Experience") {
                    Task {
                        try? await appState.appraisalKit?.addNegativeExperience(
                            ExperienceData(
                                id: "error",
                                metadata: ["type": AnyCodable("user_initiated")]
                            )
                        )
                        await updateStats()
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)
                
                Button("Request Review") {
                    Task {
                        let shouldShow = await appState.appraisalKit?.shouldRequestReview() ?? false
                        if shouldShow {
                            try? await appState.appraisalKit?.requestReview()
                        } else {
                            print("Not eligible for review yet")
                        }
                    }
                }
                .buttonStyle(.bordered)
                .tint(.green)
                
                Button("Reset All") {
                    Task {
                        try? await appState.appraisalKit?.resetAll()
                        await updateStats()
                    }
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
            
            Spacer()
        }
        .padding()
        .task {
            await updateStats()
        }
    }
    
    func updateStats() async {
        guard let kit = appState.appraisalKit else { return }
        stats = await kit.getStatistics()
    }
}
```

## Advanced Usage

### User Segmentation

```swift
// Set user segment based on behavior
Task {
    let launches = await appraisalKit.getStatistics().appLaunchCount
    
    if launches > 50 {
        try await appraisalKit.setUserSegment(.powerUser)
    } else if launches > 10 {
        try await appraisalKit.setUserSegment(.regularUser)
    } else {
        try await appraisalKit.setUserSegment(.newUser)
    }
}
```

### Custom Prompt Strategy

```swift
let config = AppraisalConfiguration(
    promptStrategy: .customFirst {
        // Show your custom dialog
        let result = await showCustomReviewDialog()
        return result == .wantsToRate // true to show system prompt
    }
)
```

### Monitoring

```swift
// Get debug information
let debugInfo = await appraisalKit.getDebugInfo()
print("Current score: \(debugInfo.score)")
print("Event log: \(debugInfo.eventLog)")

// Check cooldown
let cooldown = await appraisalKit.getCooldownStatus()
if !cooldown.canPromptNow {
    print("Cooldown remaining: \(cooldown.remainingTime) seconds")
}
```

## Testing

When testing, use debug mode:

```swift
let config = AppraisalConfiguration(
    debugMode: true,
    simulatePrompt: true,
    overrideVersion: "1.0.0-test"
)
```

This will:
- Print detailed logs
- Simulate review prompts instead of showing real ones
- Use a specific version for testing
