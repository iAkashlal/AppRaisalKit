import XCTest
@testable import AppRaisalKit

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
final class AppRaisalKitTests: XCTestCase {
    
    func testAnyCodableString() throws {
        let value = AnyCodable("test")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(AnyCodable.self, from: data)
        
        XCTAssertEqual(value, decoded)
    }
    
    func testAnyCodableInt() throws {
        let value = AnyCodable(42)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(value)
        let decoded = try decoder.decode(AnyCodable.self, from: data)
        
        XCTAssertEqual(value, decoded)
    }
    
    func testRepeatLimitInfinite() {
        let limit = RepeatLimit.infinite
        XCTAssertEqual(limit, .infinite)
    }
    
    func testRepeatLimitLimited() {
        let limit = RepeatLimit.limited(5)
        if case .limited(let count) = limit {
            XCTAssertEqual(count, 5)
        } else {
            XCTFail("Expected limited case")
        }
    }
    
    func testExperienceData() {
        let data = ExperienceData(
            id: "test",
            weight: 2.0,
            maxRepeat: .limited(3),
            metadata: ["key": AnyCodable("value")]
        )
        
        XCTAssertEqual(data.id, "test")
        XCTAssertEqual(data.weight, 2.0)
        XCTAssertEqual(data.maxRepeat, .limited(3))
    }
    
    func testExperienceType() {
        let data = ExperienceData(id: "test")
        let type = ExperienceType.positive(data)
        
        XCTAssertEqual(type.name, "positive")
        XCTAssertEqual(type.data.id, "test")
    }
    
    func testCooldownPeriod() {
        let minutes = CooldownPeriod.minutes(30)
        XCTAssertEqual(minutes.timeInterval, 1800)
        
        let hours = CooldownPeriod.hours(2)
        XCTAssertEqual(hours.timeInterval, 7200)
        
        let days = CooldownPeriod.days(1)
        XCTAssertEqual(days.timeInterval, 86400)
    }
    
    func testAppraisalConfiguration() {
        let config = AppraisalConfiguration(
            minimumPositiveEvents: 3,
            cooldownPeriod: .hours(12),
            debugMode: true
        )
        
        XCTAssertEqual(config.minimumPositiveEvents, 3)
        XCTAssertEqual(config.cooldownPeriod.timeInterval, 43200)
        XCTAssertTrue(config.debugMode)
    }
    
    func testUserSegments() {
        let segment = UserSegment.powerUser
        XCTAssertEqual(segment.rawValue, "powerUser")
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
    func testAppRaisalKitInit() async throws {
        let config = AppraisalConfiguration(
            enableCrashDetection: false,
            debugMode: true
        )
        
        let kit = try await AppRaisalKit(configuration: config)
        
        let stats = await kit.getStatistics()
        XCTAssertEqual(stats.positiveCount, 0)
        XCTAssertEqual(stats.negativeCount, 0)
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
    func testAddPositiveExperience() async throws {
        let config = AppraisalConfiguration(
            enableCrashDetection: false,
            debugMode: true
        )
        
        let kit = try await AppRaisalKit(configuration: config)
        
        try await kit.addPositiveExperience()
        
        let stats = await kit.getStatistics()
        XCTAssertEqual(stats.positiveCount, 1)
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
    func testAddNegativeExperience() async throws {
        let config = AppraisalConfiguration(
            enableCrashDetection: false,
            debugMode: true
        )
        
        let kit = try await AppRaisalKit(configuration: config)
        
        try await kit.addNegativeExperience()
        
        let stats = await kit.getStatistics()
        XCTAssertEqual(stats.negativeCount, 1)
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
    func testWeightedScore() async throws {
        let config = AppraisalConfiguration(
            enableCrashDetection: false,
            positiveWeight: 1.0,
            negativeWeight: -2.0,
            debugMode: true
        )
        
        let kit = try await AppRaisalKit(configuration: config)
        
        try await kit.addPositiveExperience()
        try await kit.addPositiveExperience()
        try await kit.addNegativeExperience()
        
        let stats = await kit.getStatistics()
        XCTAssertEqual(stats.weightedScore, 0.0) // 2 * 1.0 + 1 * -2.0 = 0
    }
}
