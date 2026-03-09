# AppRaisalKit Configuration Guide

Complete reference for configuring AppRaisalKit behavior.

## Quick Reference

```swift
let config = AppraisalConfiguration(
    // Core Requirements
    minimumPositiveEvents: 5,           // Min positive events needed
    minimumAppLaunches: 3,              // Min app launches needed
    
    // Scoring
    positiveWeight: 1.0,                // Default positive weight
    negativeWeight: -2.0,               // Default negative weight
    scoreThreshold: .fixed(5.0),        // Min score to show prompt
    
    // Timing & Frequency
    cooldownPeriod: .days(30),          // Time between prompts
    promptTiming: .afterPositiveExperience,  // When to auto-trigger
    promptDelay: 5.0,                   // Delay in seconds
    
    // Limits
    maxPromptsPerVersion: 3,            // Max per version
    maxPromptsTotal: 10,                // Max ever
    
    // Features
    enableCrashDetection: true,         // Auto-log crashes
    debugMode: false                    // Testing mode
)
```

## Cooldown Period

Controls how often users can be prompted.

### Options

```swift
// Minutes (testing only)
cooldownPeriod: .minutes(30)

// Hours
cooldownPeriod: .hours(24)

// Days (recommended for production)
cooldownPeriod: .days(30)

// Custom (in seconds)
cooldownPeriod: .custom(3600)  // 1 hour
```

### Recommendations

- **Production**: `.days(30)` or `.days(60)`
- **High engagement apps**: `.days(14)`
- **Testing**: `.minutes(5)` or `.custom(10)`

## Prompt Timing ⭐ IMPORTANT

Controls **when** prompts are automatically triggered.

### `.immediate` - Manual Control

No auto-triggering. You control everything.

```swift
promptTiming: .immediate

// Later in code:
if await kit.shouldRequestReview() {
    try await kit.requestReview()
}
```

**Use when:**
- You need precise control over timing
- Prompts should only show at specific app states
- Complex workflows with multiple decision points

### `.afterPositiveExperience` - Auto-Trigger (Recommended)

Prompts automatically show after positive events.

```swift
promptTiming: .afterPositiveExperience
promptDelay: 5.0  // Wait 5 seconds

// When you log positive experience:
try await kit.addPositiveExperience(...)
// ↑ Prompt auto-triggers in 5 seconds if eligible
```

**Use when:**
- You want seamless automatic prompting
- Right after user success moments
- E-commerce apps (after purchase)
- Games (after level completion)

**Best practices:**
- Use 2-5 second delay for most cases
- Use 5-10 seconds for complex achievements
- Never use 0 seconds (feels too rushed)

### `.afterNeutralExperience` - After Neutral Events

Similar to `.afterPositiveExperience` but for neutral events.

```swift
promptTiming: .afterNeutralExperience
promptDelay: 2.0
```

**Use when:**
- Prompting after navigation or exploration
- After users finish reading content
- Session endings

### `.custom` - Manual Timing

You handle timing logic yourself.

```swift
promptTiming: .custom

// Your custom logic
```

## Prompt Delay

Time to wait before showing auto-triggered prompt (in seconds).

```swift
promptDelay: 0.0   // Immediate - NOT RECOMMENDED
promptDelay: 2.0   // Quick actions (small purchases, simple tasks)
promptDelay: 5.0   // ⭐ RECOMMENDED - natural timing
promptDelay: 10.0  // Complex workflows (large purchases, big achievements)
```

**Why delay matters:**
- Gives users time to appreciate their success
- Feels less intrusive
- Higher acceptance rates

## Score Threshold

Minimum weighted score needed to show prompt.

### Fixed Threshold

```swift
scoreThreshold: .fixed(5.0)  // Default and recommended
```

### Dynamic Threshold

Adjust based on context:

```swift
scoreThreshold: .dynamic { context in
    // New users need higher score
    if context.appLaunchCount < 5 {
        return 10.0
    }
    // Regular users
    else if context.appLaunchCount < 20 {
        return 5.0
    }
    // Power users
    else {
        return 3.0
    }
}
```

## Configuration Presets

### Conservative (Default)

Best for most apps. Prevents prompt fatigue.

```swift
AppraisalConfiguration(
    minimumPositiveEvents: 5,
    cooldownPeriod: .days(30),
    positiveWeight: 1.0,
    negativeWeight: -2.0,
    promptTiming: .afterPositiveExperience,
    promptDelay: 5.0,
    maxPromptsPerVersion: 3,
    enableCrashDetection: true
)
```

### Aggressive

For high-engagement apps with frequent sessions.

```swift
AppraisalConfiguration(
    minimumPositiveEvents: 3,
    cooldownPeriod: .days(14),
    positiveWeight: 1.0,
    negativeWeight: -1.5,
    promptTiming: .afterPositiveExperience,
    promptDelay: 3.0,
    maxPromptsPerVersion: 5
)
```

### Very Conservative

For critical apps (banking, health, enterprise).

```swift
AppraisalConfiguration(
    minimumPositiveEvents: 10,
    cooldownPeriod: .days(60),
    positiveWeight: 1.0,
    negativeWeight: -3.0,
    promptTiming: .afterPositiveExperience,
    promptDelay: 10.0,
    maxPromptsPerVersion: 2
)
```

### Manual Control Only

Full control, no auto-triggering.

```swift
AppraisalConfiguration(
    minimumPositiveEvents: 5,
    cooldownPeriod: .days(30),
    promptTiming: .immediate  // ⭐ No auto-triggering
)
```

### Testing/Debug

Quick iterations during development.

```swift
AppraisalConfiguration(
    minimumPositiveEvents: 2,
    minimumAppLaunches: 1,
    cooldownPeriod: .custom(10),  // 10 seconds
    promptTiming: .afterPositiveExperience,
    promptDelay: 2.0,
    debugMode: true,
    simulatePrompt: true  // Don't show real prompts
)
```

## Common Patterns

### E-commerce

```swift
AppraisalConfiguration(
    minimumPositiveEvents: 2,  // Low - purchases are valuable
    cooldownPeriod: .days(30),
    promptTiming: .afterPositiveExperience,
    promptDelay: 3.0,  // After purchase success
    positiveWeight: 1.0,
    negativeWeight: -2.0
)

// Log purchase
try await kit.addPositiveExperience(
    ExperienceData(
        id: "purchase_completed",
        weight: 5.0,  // High weight
        maxRepeat: .limited(3)
    )
)
```

### Game

```swift
AppraisalConfiguration(
    minimumPositiveEvents: 5,  // Multiple level completions
    cooldownPeriod: .days(14),  // Shorter for high engagement
    promptTiming: .afterPositiveExperience,
    promptDelay: 3.0,
    negativeWeight: -1.0  // Lighter - failures are normal
)

// Every win counts
try await kit.addPositiveExperience(
    ExperienceData(
        id: "level_complete",
        weight: 1.5,
        maxRepeat: .infinite  // All wins count
    )
)
```

### Productivity

```swift
AppraisalConfiguration(
    minimumPositiveEvents: 10,  // Higher - frequent small actions
    cooldownPeriod: .days(30),
    promptTiming: .afterPositiveExperience,
    promptDelay: 5.0,
    positiveWeight: 1.0,
    negativeWeight: -2.0
)

// Small frequent wins
try await kit.addPositiveExperience(
    ExperienceData(
        id: "task_completed",
        weight: 1.0,
        maxRepeat: .limited(20)  // Limit repetition
    )
)
```

## Key Takeaways

1. **Use `.afterPositiveExperience`** for automatic intelligent prompting
2. **Set `promptDelay` to 5.0 seconds** for most cases
3. **Use `.days(30)` cooldown** to prevent fatigue
4. **Balance weights** - negatives slightly heavier than positives
5. **Test with `debugMode: true`** and `simulatePrompt: true`
6. **Start conservative** - you can always make it more aggressive
7. **Monitor with observers** to tune configuration

## Testing Your Configuration

```swift
#if DEBUG
let config = AppraisalConfiguration(
    minimumPositiveEvents: 2,
    cooldownPeriod: .custom(10),
    debugMode: true,
    simulatePrompt: true
)
#else
let config = AppraisalConfiguration(
    minimumPositiveEvents: 5,
    cooldownPeriod: .days(30),
    debugMode: false
)
#endif
```

## Documentation Links

- **Main README**: [README.md](README.md)
- **API Reference**: Full method documentation in source files
- **Examples**: [Examples/EXAMPLE.md](Examples/EXAMPLE.md)
- **Memento Pattern**: [MEMENTO_PATTERN.md](MEMENTO_PATTERN.md)
