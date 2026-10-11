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
    func testAirPodsProductIconsRequireBluetoothAndExplicitProductIdentity() {
        XCTAssertEqual(Microphone(uid: "pro", name: "Ethan's AirPods Pro", transport: .bluetooth, modelID: "2024 4c", manufacturer: "Apple Inc.").iconKind, "airpodspro")
        XCTAssertEqual(Microphone(uid: "buds", name: "AirPods", transport: .bluetooth).iconKind, "airpods")
        XCTAssertEqual(Microphone(uid: "other", name: "Wireless Headset", transport: .bluetooth).iconKind, "bluetooth")
        XCTAssertEqual(Microphone(uid: "wired", name: "AirPods Pro", transport: .usb).iconKind, "usb")
    }
    func testPresentationSeparatesTransportFromSupportedDeviceIdentity() {
        XCTAssertEqual(Microphone(uid: "max", name: "AirPods Max", transport: .bluetooth).presentation, .airpodsmax)
        XCTAssertEqual(Microphone(uid: "mic", name: "Studio USB Microphone", transport: .usb).presentation, .microphone)
        XCTAssertEqual(Microphone(uid: "unknown", name: "USB Audio", transport: .usb).presentation, .usb)
        XCTAssertEqual(Microphone(uid: "scarlett", name: "Scarlett Solo USB", transport: .usb, manufacturer: "Focusrite").presentation, .interface)
        XCTAssertEqual(Microphone(uid: "wired", name: "Wired Headset", transport: .usb).presentation, .headphones)
        XCTAssertEqual(Microphone(uid: "virtual", name: "AirPods Pro", transport: .virtual).presentation, .virtual)
        XCTAssertEqual(Microphone(uid: "aggregate", name: "Aggregate microphone", transport: .aggregate).presentation, .aggregate)
    }
    func testFailureAndStalledCaptureRemainRetryable() {
        for _ in 0..<3 { XCTAssertTrue(CapturePolicy.needsRestart(currentUID: nil, targetUID: "scarlett", running: false, lastSampleAge: nil)) }
        XCTAssertTrue(CapturePolicy.needsRestart(currentUID: "scarlett", targetUID: "scarlett", running: true, lastSampleAge: 11))
    }
}
