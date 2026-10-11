import Foundation
public struct Microphone: Equatable, Codable {
    public let uid: String
    public let name: String
    public init(uid: String, name: String) { self.uid = uid; self.name = name }
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
