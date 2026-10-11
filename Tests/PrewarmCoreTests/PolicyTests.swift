import XCTest
@testable import PrewarmCore
final class PolicyTests: XCTestCase {
    let scarlett = Microphone(uid: "scarlett", name: "Scarlett Solo")
    let airpods = Microphone(uid: "airpods", name: "AirPods")
    func testPinnedInputSurvivesDefaultChangeAndUnrelatedConnection() {
        XCTAssertEqual(CapturePolicy.target(selection: "scarlett", defaultUID: "airpods", available: [scarlett, airpods]), scarlett)
        XCTAssertFalse(CapturePolicy.needsRestart(currentUID: "scarlett", targetUID: "scarlett", running: true, lastSampleAge: 0.1))
    }
    func testDisconnectedOverrideWaitsThenRecoversWithoutFallback() {
        XCTAssertNil(CapturePolicy.target(selection: "scarlett", defaultUID: "airpods", available: [airpods]))
        XCTAssertTrue(CapturePolicy.needsRestart(currentUID: "scarlett", targetUID: nil, running: true, lastSampleAge: 0))
        XCTAssertEqual(CapturePolicy.target(selection: "scarlett", defaultUID: "airpods", available: [airpods, scarlett]), scarlett)
        XCTAssertTrue(CapturePolicy.needsRestart(currentUID: nil, targetUID: "scarlett", running: false, lastSampleAge: nil))
    }
    func testSystemDefaultFollowsChanges() {
        XCTAssertEqual(CapturePolicy.target(selection: "", defaultUID: "airpods", available: [scarlett, airpods]), airpods)
        XCTAssertTrue(CapturePolicy.needsRestart(currentUID: "scarlett", targetUID: "airpods", running: true, lastSampleAge: 0))
    }
    func testFailureAndStalledCaptureRemainRetryable() {
        for _ in 0..<3 { XCTAssertTrue(CapturePolicy.needsRestart(currentUID: nil, targetUID: "scarlett", running: false, lastSampleAge: nil)) }
        XCTAssertTrue(CapturePolicy.needsRestart(currentUID: "scarlett", targetUID: "scarlett", running: true, lastSampleAge: 11))
    }
}
