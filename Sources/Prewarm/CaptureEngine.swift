import AppKit
import AVFoundation
import CoreAudio
import PrewarmCore

struct CaptureState: Codable {
    let processID: Int32
    let updatedAt: Date
    let message: String
    let enabled: Bool
    let selection: String
    let targetUID: String?
    let targetName: String?
    let running: Bool
    let sampleAge: Double?
    let available: [Microphone]
}

/// All capture/session state and sample callbacks are confined to this queue.
final class CaptureEngine: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    private let queue = DispatchQueue(label: "com.ethan.Prewarm.capture", qos: .utility)
    private var session: AVCaptureSession?
    private var currentUID: String?
    private var currentName: String?
    private var lastSample: TimeInterval?
    private var startedAt: TimeInterval?
    private var enabled = false
    private var sleeping = false
    private var selection = ""
    private var timer: DispatchSourceTimer?
    private var message = "Off"
    var onState: ((CaptureState) -> Void)?

    override init() {
        super.init()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 2)
        timer.setEventHandler { [weak self] in self?.reconcile() }
        timer.resume()
        self.timer = timer
    }
    func configure(enabled: Bool, selection: String) {
        queue.async {
            self.enabled = enabled
            self.selection = selection
            self.reconcile()
        }
    }
    func setSleeping(_ sleeping: Bool) {
        queue.async {
            self.sleeping = sleeping
            self.reconcile()
        }
    }
    private func devices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified).devices
    }
    private func transport(_ device: AVCaptureDevice) -> Microphone.Transport {
        // AVFoundation defines transportType using IOAudioTypes.h FourCC constants,
        // which match CoreAudio transport codes; do not infer from product names.
        switch UInt32(bitPattern: device.transportType) {
        case kAudioDeviceTransportTypeBuiltIn: return .builtIn
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return .bluetooth
        case kAudioDeviceTransportTypeUSB: return .usb
        default: return .other
        }
    }
    private func defaultUID() -> String? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr else { return nil }
        address.mSelector = kAudioDevicePropertyDeviceUID
        var uid: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &uid) == noErr else { return nil }
        return uid?.takeRetainedValue() as String?
    }
    private func reconcile() {
        let inputs = devices()
        let microphones = inputs.map { Microphone(uid: $0.uniqueID, name: $0.localizedName, transport: transport($0)) }
        defer { publish(microphones) }
        guard enabled, !sleeping else {
            stop()
            message = sleeping && enabled ? "Paused during sleep" : "Off"
            return
        }
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            stop()
            message = "Microphone access required"
            return
        }
        guard let target = CapturePolicy.target(selection: selection, defaultUID: defaultUID(), available: microphones),
              let device = inputs.first(where: { $0.uniqueID == target.uid }) else {
            stop()
            message = selection.isEmpty ? "Waiting for system microphone" : "Waiting for selected microphone"
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        let age = (lastSample ?? startedAt).map { now - $0 }
        if CapturePolicy.needsRestart(currentUID: currentUID, targetUID: target.uid, running: session?.isRunning ?? false, lastSampleAge: age) {
            stop()
            start(device)
        } else {
            message = lastSample == nil ? "Starting \(target.name)…" : "Keeping \(target.name) warm"
        }
    }
    private func start(_ device: AVCaptureDevice) {
        let capture = AVCaptureSession()
        do {
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureAudioDataOutput()
            guard capture.canAddInput(input), capture.canAddOutput(output) else {
                message = "Cannot open selected microphone"
                return
            }
            capture.addInput(input)
            output.setSampleBufferDelegate(self, queue: queue)
            capture.addOutput(output)
            session = capture
            currentUID = device.uniqueID
            currentName = device.localizedName
            startedAt = ProcessInfo.processInfo.systemUptime
            capture.startRunning()
            // Capture must not prevent idle sleep. This is the upstream power fix.
            var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertySleepingIsAllowed, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var allowed: UInt32 = 1
            AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &allowed)
            message = capture.isRunning ? "Starting \(device.localizedName)…" : "Microphone unavailable; retrying"
        } catch {
            stop()
            message = "Cannot open microphone: \(error.localizedDescription)"
        }
    }
    private func stop() {
        guard let old = session else { return }
        session = nil
        currentUID = nil
        currentName = nil
        lastSample = nil
        startedAt = nil
        // Detach the graph before stopRunning, which can stall on dead Bluetooth inputs.
        for output in old.outputs {
            (output as? AVCaptureAudioDataOutput)?.setSampleBufferDelegate(nil, queue: nil)
            old.removeOutput(output)
        }
        for input in old.inputs { old.removeInput(input) }
        DispatchQueue.global(qos: .utility).async { old.stopRunning() }
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Never read, retain, encode, save, or transmit audio contents.
        guard enabled, !sleeping, session?.outputs.contains(where: { $0 === output }) == true else { return }
        lastSample = ProcessInfo.processInfo.systemUptime
    }
    private func publish(_ available: [Microphone]) {
        let state = CaptureState(processID: ProcessInfo.processInfo.processIdentifier, updatedAt: Date(), message: message, enabled: enabled, selection: selection, targetUID: currentUID, targetName: currentName, running: session?.isRunning ?? false, sampleAge: lastSample.map { ProcessInfo.processInfo.systemUptime - $0 }, available: available)
        DispatchQueue.main.async { [weak self] in self?.onState?(state) }
    }
}
