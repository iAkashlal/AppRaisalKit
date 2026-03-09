import XCTest
@testable import AppRaisalKit

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
final class MementoStorageTests: XCTestCase {
    
    var storage: MementoStorage!
    
    override func setUp() async throws {
        storage = MementoStorage(
            userDefaults: UserDefaults(suiteName: "test")!,
            maxHistory: 5,
            autoSnapshot: false
        )
        await storage.clearAll()
    }
    
    override func tearDown() async throws {
        await storage.clearAll()
    }
    
    func testMementoCreation() async throws {
        let dataModel = AppraisalDataModel(currentVersion: "1.0.0")
        
        try storage.save(dataModel, forKey: "test")
        
        let loaded: AppraisalDataModel? = storage.load(forKey: "test")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.currentVersion, "1.0.0")
    }
    
    func testSnapshotCreation() async throws {
        var dataModel = AppraisalDataModel(currentVersion: "1.0.0")
        dataModel.appLaunchCount = 5
        
        try storage.save(dataModel, forKey: "test")
        try await storage.createSnapshot(tag: "initial")
        
        let metadata = await storage.getSnapshotMetadata()
        XCTAssertEqual(metadata.count, 1)
        XCTAssertEqual(metadata.first?.tag, "initial")
    }
    
    func testSnapshotRestore() async throws {
        // Save initial state
        var dataModel = AppraisalDataModel(currentVersion: "1.0.0")
        dataModel.appLaunchCount = 5
        try storage.save(dataModel, forKey: "test")
        try await storage.createSnapshot(tag: "snapshot1")
        
        // Modify state
        dataModel.appLaunchCount = 10
        try storage.save(dataModel, forKey: "test")
        
        // Verify modified
        let modified: AppraisalDataModel? = storage.load(forKey: "test")
        XCTAssertEqual(modified?.appLaunchCount, 10)
        
        // Restore snapshot
        try await storage.restoreSnapshot(at: 0)
        
        // Verify restored
        let restored: AppraisalDataModel? = storage.load(forKey: "test")
        XCTAssertEqual(restored?.appLaunchCount, 5)
    }
    
    func testRestoreByTag() async throws {
        var dataModel = AppraisalDataModel(currentVersion: "1.0.0")
        
        dataModel.appLaunchCount = 1
        try storage.save(dataModel, forKey: "test")
        try await storage.createSnapshot(tag: "first")
        
        dataModel.appLaunchCount = 2
        try storage.save(dataModel, forKey: "test")
        try await storage.createSnapshot(tag: "second")
        
        dataModel.appLaunchCount = 3
        try storage.save(dataModel, forKey: "test")
        
        // Restore "first"
        try await storage.restoreSnapshot(withTag: "first")
        
        let restored: AppraisalDataModel? = storage.load(forKey: "test")
        XCTAssertEqual(restored?.appLaunchCount, 1)
    }
    
    func testMaxHistoryLimit() async throws {
        var dataModel = AppraisalDataModel(currentVersion: "1.0.0")
        
        // Create 7 snapshots (limit is 5)
        for i in 1...7 {
            dataModel.appLaunchCount = i
            try storage.save(dataModel, forKey: "test")
            try await storage.createSnapshot(tag: "snapshot_\(i)")
        }
        
        let count = await storage.getSnapshotCount()
        XCTAssertEqual(count, 5, "Should only keep 5 snapshots")
        
        let metadata = await storage.getSnapshotMetadata()
        // Should have snapshots 3-7 (latest 5)
        XCTAssertEqual(metadata.first?.tag, "snapshot_3")
        XCTAssertEqual(metadata.last?.tag, "snapshot_7")
    }
    
    func testClearHistory() async throws {
        var dataModel = AppraisalDataModel(currentVersion: "1.0.0")
        dataModel.appLaunchCount = 5
        
        try storage.save(dataModel, forKey: "test")
        try await storage.createSnapshot(tag: "test")
        
        XCTAssertEqual(await storage.getSnapshotCount(), 1)
        
        await storage.clearHistory()
        
        XCTAssertEqual(await storage.getSnapshotCount(), 0)
        
        // Current state should still exist
        let current: AppraisalDataModel? = storage.load(forKey: "test")
        XCTAssertNotNil(current)
        XCTAssertEqual(current?.appLaunchCount, 5)
    }
    
    func testAppRaisalKitWithMemento() async throws {
        let config = AppraisalConfiguration(
            enableCrashDetection: false,
            storageProvider: MementoStorage(
                userDefaults: UserDefaults(suiteName: "test")!
            ),
            debugMode: true
        )
        
        let kit = try await AppRaisalKit(configuration: config)
        
        XCTAssertTrue(await kit.isUsingMementoStorage)
        
        // Add some experiences
        try await kit.addPositiveExperience()
        try await kit.addPositiveExperience()
        
        // Create snapshot
        try await kit.createSnapshot(tag: "two_positive")
        
        // Add more
        try await kit.addNegativeExperience()
        
        let statsAfter = await kit.getStatistics()
        XCTAssertEqual(statsAfter.positiveCount, 2)
        XCTAssertEqual(statsAfter.negativeCount, 1)
        
        // Restore snapshot
        try await kit.restoreSnapshot(withTag: "two_positive")
        
        // Verify restored state
        let statsRestored = await kit.getStatistics()
        XCTAssertEqual(statsRestored.positiveCount, 2)
        XCTAssertEqual(statsRestored.negativeCount, 0)
    }
    
    func testMementoMetadata() async throws {
        var dataModel = AppraisalDataModel(currentVersion: "1.0.0")
        
        let event = ExperienceEvent(
            id: "test",
            type: "positive",
            weight: 5.0,
            metadata: nil,
            timestamp: Date(),
            maxRepeat: nil
        )
        dataModel.events = [event]
        
        try storage.save(dataModel, forKey: "test")
        try await storage.createSnapshot(tag: "with_event")
        
        let metadata = await storage.getSnapshotMetadata()
        XCTAssertEqual(metadata.count, 1)
        XCTAssertEqual(metadata.first?.eventCount, 1)
        XCTAssertEqual(metadata.first?.score, 5.0)
        XCTAssertEqual(metadata.first?.version, "1.0.0")
    }
}
