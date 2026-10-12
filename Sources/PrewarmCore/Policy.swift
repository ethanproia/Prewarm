import Foundation
public struct Microphone: Equatable, Codable {
    public let uid: String
    public enum Transport: String, Codable { case builtIn, bluetooth, usb, virtual, aggregate, network, other }
    public let name: String
    public let transport: Transport
    public let modelID: String
    public let manufacturer: String
    public init(uid: String, name: String, transport: Transport = .other, modelID: String = "", manufacturer: String = "") {
        self.uid = uid; self.name = name; self.transport = transport; self.modelID = modelID; self.manufacturer = manufacturer
    }
    public enum Presentation: String { case builtIn, bluetooth, headphones, usb, microphone, interface, airpods, airpodspro, airpodsmax, virtual, aggregate, other }
    public var presentation: Presentation {
        let identity = "\(name) \(modelID)".lowercased()
        func matches(_ pattern: String) -> Bool { identity.range(of: pattern, options: .regularExpression) != nil }
        if transport == .virtual { return .virtual }
        if transport == .aggregate { return .aggregate }
        if transport == .builtIn { return .builtIn }
        if transport == .bluetooth {
            if matches(#"\bairpods\s*pro\b"#) { return .airpodspro }
            if matches(#"\bairpods\s*max\b"#) { return .airpodsmax }
            if matches(#"\bairpods\b"#) { return .airpods }
            return .bluetooth
        }
        if matches(#"\b(headphones?|headsets?)\b"#) { return .headphones }
        if matches(#"\b(microphone|mic)\b"#) { return .microphone }
        if matches(#"\baudio interface\b"#) || (manufacturer.lowercased().contains("focusrite") && identity.contains("scarlett")) { return .interface }
        return transport == .usb ? .usb : .other
    }
    public var iconKind: String { presentation.rawValue }

}
public enum CapturePolicy {
    public static func target(selection: String, defaultUID: String?, available: [Microphone]) -> Microphone? {
        let uid = selection.isEmpty ? defaultUID : selection
        return available.first { $0.uid == uid }
    }
    public static func needsRestart(currentUID: String?, targetUID: String?, running: Bool, lastSampleAge: TimeInterval?) -> Bool {
        guard let targetUID else { return currentUID != nil }
        return currentUID != targetUID || !running || (lastSampleAge ?? 0) > 10
    }
}
public enum StartupPolicy {
    public static func initialEnabled(isLoginLaunch: Bool, enableAtLogin: Bool, savedEnabled: Bool) -> Bool {
        isLoginLaunch ? enableAtLogin : savedEnabled
    }
}
