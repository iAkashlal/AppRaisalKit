# Memento Design Pattern Implementation

## Overview

AppRaisalKit now includes a **Memento design pattern** based storage implementation that provides automatic state snapshots, history management, and restoration capabilities - all without requiring the client app to provide custom storage.

## Architecture

The implementation follows the classic Memento pattern with three main components:

### 1. **Memento** (`Memento.swift`)
- `AppRaisalMemento` - Immutable snapshot of state at a point in time
- `MementoMetadata` - Lightweight metadata for listing snapshots without loading full state

### 2. **Caretaker** (`MementoCaretaker.swift`)
- `MementoCaretaker` - Actor-based manager for memento history
- Handles saving, loading, and managing snapshot history
- Enforces maximum history limit (FIFO)
- Thread-safe using Swift actors

### 3. **Originator** (`MementoStorage.swift` + `AppRaisalKit+Memento.swift`)
- `MementoStorage` - StorageProvider implementation with Memento capabilities
- `AppRaisalKit` extension - Public API for snapshot operations
- Automatic snapshot creation every N saves (configurable)

## Files Created

1. **Storage/Memento.swift** - Memento and metadata structures
2. **Storage/MementoCaretaker.swift** - History management
3. **Storage/MementoStorage.swift** - StorageProvider implementation
4. **AppRaisalKit+Memento.swift** - Public API extension
5. **Tests/MementoStorageTests.swift** - Comprehensive tests (10 tests)

## Features

### Automatic Snapshots
```swift
let storage = MementoStorage(
    autoSnapshot: true,
    snapshotInterval: 5  // Snapshot every 5 saves
)
```

### Manual Snapshots
```swift
try await kit.createSnapshot(tag: "before_feature_x")
```

### Browse History
```swift
let snapshots = try await kit.getSnapshots()
// Returns lightweight metadata without loading full state
```

### Restore State
```swift
// By index
try await kit.restoreSnapshot(at: 0)

// By tag
try await kit.restoreSnapshot(withTag: "before_feature_x")

// Most recent
try await kit.restoreMostRecentSnapshot()
```

### History Management
```swift
// Get count
let count = try await kit.getSnapshotCount()

// Clear history (keeps current state)
try await kit.clearSnapshotHistory()
```

## Benefits

1. **Undo/Redo Capability**
   - Restore previous states easily
   - Perfect for A/B testing scenarios

2. **Debugging**
   - Examine historical states
   - Understand how score evolved over time

3. **Recovery**
   - Rollback from problematic states
   - Restore after bugs or errors

4. **No Client Implementation Required**
   - Works out of the box
   - Default storage uses Memento pattern

5. **Configurable**
   - Control max history size
   - Configure auto-snapshot frequency
   - Optional tagging for identification

## Default Behavior

**MementoStorage is now the default** storage provider:

```swift
// Automatically uses MementoStorage
let kit = try await AppRaisalKit()

// Check if using Memento
print(await kit.isUsingMementoStorage) // true
```

## Configuration Options

```swift
let mementoStorage = MementoStorage(
    userDefaults: .standard,      // Storage backend
    maxHistory: 10,               // Max snapshots to keep
    autoSnapshot: true,           // Auto-create snapshots
    snapshotInterval: 5           // Snapshot every N saves
)
```

## Use Cases

### A/B Testing
```swift
// Test variant A
try await kit.createSnapshot(tag: "variant_a_start")
// ... track experiences with variant A ...
let statsA = await kit.getStatistics()

// Test variant B
try await kit.restoreSnapshot(withTag: "variant_a_start")
// ... track experiences with variant B ...
let statsB = await kit.getStatistics()

// Compare results
```

### Debug Mode
```swift
#if DEBUG
// Take snapshot before tests
try await kit.createSnapshot(tag: "pre_test")

// Run tests...

// Restore if needed
try await kit.restoreSnapshot(withTag: "pre_test")
#endif
```

### Feature Flags
```swift
// Before enabling experimental feature
try await kit.createSnapshot(tag: "before_experiment")

// Enable feature...

// Rollback if issues
if hasIssues {
    try await kit.restoreSnapshot(withTag: "before_experiment")
}
```

### Onboarding States
```swift
// Track different onboarding flows
try await kit.createSnapshot(tag: "onboarding_step_1")
try await kit.createSnapshot(tag: "onboarding_step_2")
try await kit.createSnapshot(tag: "onboarding_complete")

// Analyze which steps lead to better ratings
```

## Testing

10 comprehensive tests cover:
- Memento creation and loading
- Snapshot creation and metadata
- Snapshot restoration by index and tag
- Maximum history limit enforcement
- History clearing
- Integration with AppRaisalKit
- Metadata accuracy

## Performance

- **Lightweight metadata** - Browse snapshots without loading full state
- **Automatic cleanup** - Old snapshots removed when limit reached
- **Async operations** - Non-blocking with Swift actors
- **Efficient encoding** - JSON-based with Codable

## Backward Compatibility

Existing apps can still use:
- `UserDefaultsStorage` - Simple UserDefaults storage
- Custom `StorageProvider` implementations

## Thread Safety

- All operations use Swift actors
- Thread-safe concurrent access
- No race conditions

## Storage Format

Data stored in UserDefaults with keys:
- `com.appraisalkit.memento.current` - Current state
- `com.appraisalkit.memento.history` - Snapshot history (array)
- `com.appraisalkit.memento.metadata` - Lightweight metadata (array)

## Error Handling

```swift
public enum MementoStorageError: Error {
    case unsupportedType
    case noCurrentState
    case snapshotNotFound
    case noHistory
}

public enum MementoError: Error {
    case notUsingMementoStorage
}
```

## Design Pattern Compliance

✅ **Encapsulation** - State stored in Memento objects  
✅ **Single Responsibility** - Caretaker manages history only  
✅ **Open/Closed** - Extensible without modification  
✅ **Immutability** - Mementos are immutable snapshots  
✅ **Actor Isolation** - Thread-safe with Swift concurrency  

## API Summary

### MementoStorage Methods
- `createSnapshot(tag:)` - Create manual snapshot
- `getSnapshotMetadata()` - Get all snapshot metadata
- `restoreSnapshot(at:)` - Restore by index
- `restoreSnapshot(withTag:)` - Restore by tag
- `restoreMostRecent()` - Restore latest
- `getSnapshotCount()` - Get count
- `clearHistory()` - Clear snapshots
- `clearAll()` - Clear everything

### AppRaisalKit Extension Methods
- `createSnapshot(tag:)` - Create snapshot
- `getSnapshots()` - Get metadata
- `restoreSnapshot(at:)` - Restore by index
- `restoreSnapshot(withTag:)` - Restore by tag
- `restoreMostRecentSnapshot()` - Restore latest
- `getSnapshotCount()` - Get count
- `clearSnapshotHistory()` - Clear history
- `isUsingMementoStorage` - Check storage type

---

**Status**: ✅ Fully Implemented and Tested  
**Pattern**: Memento (GoF Design Pattern)  
**Date**: February 2024  
**Files**: 5 (4 implementation + 1 test)  
**Tests**: 10  
**Default**: Yes (MementoStorage is default)
