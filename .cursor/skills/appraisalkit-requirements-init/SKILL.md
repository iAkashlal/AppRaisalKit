---
name: appraisalkit-requirements-init
description: Guides developers and product teams through gathering AppRaisalKit rating-prompt requirements (events, weights, eligibility thresholds, cooldown, prompt timing/style, limits, crash handling, handlers), then generates correct client-side SDK initialization and wiring for the app (SwiftUI/UIKit), following the SDK design. Use when the user asks to integrate AppRaisalKit and describes their app behavior or rating-prompt needs.
---

# AppRaisalKit Requirements-to-Initialization Agent

This agent runs a requirement-gathering conversation until it has enough information to:
1) Build an explicit `AppraisalConfiguration` for the SDK, and
2) Generate the client-side code needed to initialize `AppRaisalKit`, set handlers, and wire experience tracking/prompt triggering.

It MUST NOT assume event mapping, prompt style, prompt timing, handlers, or which client lifecycle points should be used.

## Conversation Flow

Follow these phases in order. Complete each phase before moving to the next.

### Phase 0: Intake (app context, no code)

Ask the developer/product team:
1. Platform: `iOS`, `macOS`, `both`, `other`?
2. UI stack: `SwiftUI` or `UIKit`?
3. Where does the app initialize global dependencies today? (e.g. `@main App`, Scene delegate, DI container)
4. Do they already have rating UX / support UX that should be triggered by the SDK handlers? (support chat, feedback email, help center, etc.)

If they’re unsure, recommend a SwiftUI pattern: create an `ObservableObject` manager and inject it via `.environmentObject`.

### Phase 1: Prompt requirements (MUST ask)

Ask until you can select exact SDK values for prompt behavior and limits:

1. Auto-trigger vs manual control (`promptTiming`)
   - Do they want the SDK to auto-request review after eligibility?
   - Options:
     - `.immediate` = manual only (client calls `requestReview()` when eligible)
     - `.afterPositiveExperience`
     - `.afterNeutralExperience`
     - `.custom` = client decides when to call `requestReview()`

2. Prompt strategy / UI ownership (`promptStrategy`)
   - `systemOnly`
   - `customFirst` (custom UI first, then optionally system prompt)
   - `callback` / `callbackAsync`

3. Prompt delay (`promptDelay`)
   - If auto-triggering is enabled, how many seconds after the triggering experience should the prompt appear?

4. Limits
   - `maxPromptsPerVersion`
   - `maxPromptsTotal`

5. Crash handling
   - Should crash detection be enabled? (`enableCrashDetection`)
   - If enabled, what crash weight should be used? (`crashEventWeight`)

### Phase 2: Eligibility + scoring requirements (MUST ask)

Ask until the agent can set the SDK’s eligibility/score inputs:

1. `minimumPositiveEvents`
2. `recentNonNegativeStreak` (0 disables)
3. Scoring weights
   - `positiveWeight`
   - `negativeWeight`
   - `neutralWeight` (ask explicitly; if unknown, propose `0.0` and ask approval)
4. `scoreThreshold`
   - `.fixed(Double)` or `.dynamic { context in ... }`
   - If dynamic, collect the rule inputs (often tiers based on `context.appLaunchCount`)
5. Cooldown (`cooldownPeriod`): `.minutes(Int)`, `.hours(Int)`, `.days(Int)`, `.custom(seconds)`
6. `minimumAppLaunches`

If they request “use defaults”, still present the defaults you will apply and ask for confirmation.

### Phase 3: Experience mapping requirements (MUST ask)

The SDK’s behavior is driven by the app’s mapping of Positive/Negative/Neutral actions.

1. Positive experiences
   - Ask for 3–5 positive actions.
   - For each: `id`, optional weight override, `maxRepeat` (`.infinite` / `.limited(n)`), and any metadata.

2. Negative experiences
   - Ask for 3–6 failure/frustration actions.
   - For each: `id`, optional weight override, and required metadata (commonly `severity`, `error_code`, `context`).

3. Neutral experiences
   - Ask if neutral actions should be tracked.

4. Placement in code
   - Positive: after confirmed success flows
   - Negative: inside error/failure handlers
   - Neutral: during non-failure informational flows

When unsure, suggest mapping guidelines consistent with `EXPERIENCE_PATTERNS.md`.

### Phase 4: Debug/test + A/B requirements (MUST ask)

1. `debugMode` (Yes/No)
2. `simulatePrompt` (Yes/No, recommended for development)
3. `overrideVersion` (optional)
4. A/B testing inputs
   - `variant` (optional)
   - `experimentId` (optional)

### Phase 5: Handlers + state observation (MUST ask if applicable)

Ask what should happen when experiences are logged and when the SDK is about to prompt:

1. Negative experience handler
   - Should the app show support UI or open feedback?
   - Should it log analytics?
   - sync vs async behavior preference

2. Positive experience handler (optional)
3. State observer (`onStateChange`)
   - Should the app show live stats/score updates?

If `promptStrategy` is `customFirst`:
- Ask for the custom UI decisions:
  - “Leave a Review” → what boolean should the custom handler return?
  - “Leave Feedback” → what boolean should the custom handler return?
  - “Not now” → what boolean should the custom handler return?
- Remember: the custom handler closure must return `true` when the SDK should proceed to the system prompt.

### Phase 6: Configuration draft + explicit approval

Generate a complete `AppraisalConfiguration(...)` draft using the exact values collected.

Rules:
- Present explicit values for everything the team chose.
- If they approved defaults, still show them.

Template:

```swift
let config = AppraisalConfiguration(
    minimumPositiveEvents: <Int>,
    recentNonNegativeStreak: <Int>,
    cooldownPeriod: <CooldownPeriod>,
    minimumAppLaunches: <Int>,
    positiveWeight: <Double>,
    negativeWeight: <Double>,
    neutralWeight: <Double>,
    scoreThreshold: <ScoreThreshold>,
    promptStrategy: <PromptStrategy>,
    maxPromptsPerVersion: <Int>,
    maxPromptsTotal: <Int>,
    promptTiming: <PromptTiming>,
    promptDelay: <TimeInterval>,
    enableCrashDetection: <Bool>,
    crashEventWeight: <Double>,
    debugMode: <Bool>,
    simulatePrompt: <Bool>,
    overrideVersion: <String?>,
    variant: <String?>,
    experimentId: <String?>
    // storageProvider omitted if default MementoStorage is desired
)
```

Ask: “Confirm this configuration? Any changes before I implement client code?”

### Phase 7: Client integration implementation (code)

Implement the client-side wiring according to their app stack.

SwiftUI deliverables:
1. Create an app-side manager (recommended name: `AppRatingManager`)
   - `ObservableObject`
   - `@Published var kit: AppRaisalKit?`
   - Initialize once: `kit = try await AppRaisalKit(configuration: config)`
   - Configure handlers:
     - `await kit.setNegativeExperienceHandler { event async in ... }`
     - `await kit.setPositiveExperienceHandler { event async in ... }` (optional)
   - Register state observer (if requested): `await kit.onStateChange { stats in ... }`
2. App entry point wiring
   - Create `@StateObject` manager in `@main` `App` struct
   - inject via `.environmentObject(manager)`
3. Experience tracking wrappers
   - Positive/Negative/Neutral wrappers that call:
     - `try await kit.addPositiveExperience(ExperienceData(...))`
     - `try await kit.addNegativeExperience(ExperienceData(...))`
     - `try await kit.addNeutralExperience(ExperienceData(...))`
4. Manual prompt triggering for manual/custom timing
   - `let eligible = await kit.shouldRequestReview()`
   - `try await kit.requestReview()` when eligible

If `promptStrategy` is `customFirst`, implement the custom UI and wire the async decision flow.

### Phase 8: Verify + test plan

After implementation:
1. Build succeeds
2. Debug behavior works (`debugMode` and `simulatePrompt`)
3. Eligibility gating works (`shouldRequestReview()` / `checkEligibility()`)
4. Prompt strategy works (`systemOnly` vs `customFirst` vs callbacks)

## Key Rules

- Do not assume any requirement values; keep asking until you have a complete configuration.
- Do not proceed to code until Phase 6 explicit approval.
- Respect the SDK’s actor-based API: treat `AppRaisalKit` calls as requiring `await`.
