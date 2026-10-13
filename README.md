# Prewarm

Prewarm, by Ethan Proia. The release version/build is defined in `version.env` and displayed in About.

A tiny macOS menu-bar utility that keeps your microphone warm by keeping its input stream active. It immediately discards audio samples; it does not record, analyze, save, or transmit audio. No third-party dependencies or network calls.

Click the menu-bar icon and select **System default** under Microphone to follow the current macOS input, or choose a specific microphone. Device icons distinguish known AirPods models, headsets, microphones, interfaces, virtual/aggregate devices and generic inputs using detected transport plus explicit product/model hints. Ambiguous USB devices use a connector; USB transport cannot identify the downstream XLR microphone. An explicit choice is pinned by device UID: reconnecting AirPods or changing the system default does not switch it. If the selected microphone disconnects, Prewarm waits instead of opening another mic. The native switch opposite **Prewarm** enables or disables warming; disabling releases the input. Its accessible label is Keep microphone ready. System default uses a plain microphone icon; real devices retain their detected icons. State and selection persist across relaunches; first launch is off. A native floating NSPanel opens below the menu-bar icon or by reopening the app, and dismisses on an outside click or Escape. It has no popover pointer or close control. The system window owns its corners and one public native material hosts the prior controls; device-row hover remains minimal AppKit drawing. Sound Settings is directly accessible; the native More menu contains About, Microphone Privacy and Quit.

Runs on macOS 14 or later. Building requires full Xcode with the macOS 27 SDK selected (`xcode-select`), including Swift and `actool`. The current release is built and tested on Apple Silicon/macOS 27; older macOS fallback paths and Intel are not verified.

```sh
swift test
./scripts/build-app.sh
open build/Prewarm.app
```

For a permanent local installation, quit Prewarm, copy `build/Prewarm.app` to `~/Applications/Prewarm.app`, and launch that copy. Enable warming and allow the macOS microphone permission prompt. macOS displays its microphone privacy indicator while warming. Select the Scarlett explicitly before enabling if the system default could be AirPods: keeping a Bluetooth mic active can affect its audio mode and battery.

The local build is ad-hoc signed because no signing identity is available. The current ad-hoc designated requirement is tied to the executable code-directory hash (verified with `codesign -d -r-`). Changing and re-signing the app changes that identity, so macOS may ask for microphone permission again. The stable bundle ID alone does not prevent this. No permission bypass or TCC modification is attempted. `PREWARM_SIGNING_IDENTITY` can supply a real signing identity; Developer ID signing and notarization are unavailable. Prewarm 1.0.0 (17) is published in the [GitHub release](https://github.com/ethanproia/Prewarm/releases/tag/v1.0.0), with the Apple Silicon ZIP, checksum and build receipt. Homebrew submission is deferred. A privately maintained local self-signed identity could give development builds a certificate-based identity, but creating/importing its certificate and private key or changing trust is a separate Keychain/security operation; this project has not done so. It would not substitute for Developer ID signing or notarization for distribution.

## Recovery and privacy

On macOS27+, the public [expanded-interface delegate](https://developer.apple.com/documentation/appkit/nsstatusitem/expandedinterfacedelegate) owns status-item tracking, menu-bar selection and keyboard participation while the native panel is open. Outside clicks, Escape and panel actions cancel its session; the native end callback hides the panel. macOS14–26 retains the prior manual fallback. Native tracking ownership is source-verified; selected-background rendering and exact external placement require live inspection and are not established by offscreen state tests.

More contains separate **Open at Login** and **Enable at Login** settings, initially off. Open at Login uses macOS ServiceManagement and changes registration only when clicked; its checkmark reflects the actual system status. Enable at Login is available only while opening at login is active. A confirmed login launch uses this warming preference for that session, preserving the saved normal/manual enabled preference. Manual relaunches still restore the saved warming state. Registration failures and required approval offer a native route to Login Items settings. No login registration is performed at installation or startup.

Login launch detection reads Apple's documented [launch Apple event marker](https://developer.apple.com/documentation/coreservices/apple_events/1556410-launch_apple_event_constants) synchronously in applicationDidFinishLaunching; this lifecycle use is also demonstrated by the maintained [LaunchAtLogin implementation](https://github.com/sindresorhus/LaunchAtLogin-Modern/blob/main/Sources/LaunchAtLogin/LaunchAtLogin.swift) and [Electron delegate](https://github.com/electron/electron/blob/main/shell/browser/mac/electron_application_delegate.mm). Registration uses [SMAppService.mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp). Synthetic launch descriptors and startup-policy tests do not perform a real login or change OS registration; actual login behavior remains a runtime acceptance check.

Capture setup, callbacks, and teardown run off the UI thread. A lightweight two-second check detects device/default changes and stale capture. It restarts only when the actual selected input changes, stops, or fails to deliver samples for ten seconds. Failed starts stay retryable. If a macOS capture API itself hangs indefinitely, that serial queue cannot process recovery or off until the API returns; quitting the process releases its audio resources. Recovery is not hang-proof. Warming pauses for system sleep and resumes after wake; the upstream idle-sleep allowance is retained. The app does not change the device's sample rate or system default.

Status metadata only (device names/UIDs, state and latest sample age) is written to `~/Library/Caches/com.ethan.Prewarm/status.json` to aid verification. There are no audio bytes or transcripts in it. Preferences are in the standard `com.ethan.Prewarm` defaults domain. Quit releases capture through process exit. No PID files, process killing, login daemon, or signal-handler object destruction.

## Verify with the actual microphone

1. Close QuickTime's audio preview and other continuously capturing apps. Select Scarlett in Prewarm and in dictation, then enable warming. Confirm the switch is on; the metadata should show `running: true` with a recent `sampleAge`.
2. Trigger Wispr and Willow and speak immediately. Compare opening audio against Prewarm off, using the same device and sample rate. Repeat at 48 and 192 kHz.
3. Reconnect AirPods or change the system default while Scarlett is explicitly selected. Prewarm must remain on Scarlett. Selecting System default should follow macOS instead.
4. Disconnect Scarlett: Prewarm must wait without opening another mic. Reconnect: warming must recover. Test sleep/wake, persisted selection after relaunch, and off releasing capture.

Automated policy tests cover explicit selection through default changes, no fallback during disconnection, reconnect recovery, System default following, failed-start retry and stale-stream recovery. They do not establish hardware latency or microphone permission behavior.

## Icon

Original deterministic vector artwork combines a flame-shaped microphone with its cradle. The menu-bar mark is an AppKit template, with filled and outlined states for on/off; the app icon uses the same mark on a warm amber/orange tile. Vector source: `Sources/Prewarm/IconArtwork.swift`; `./scripts/render-icons.sh` regenerates all PNG sizes, `assets/Prewarm.icns`, and the light/dark size review sheet. No external icon artwork or font glyphs are used.

## Provenance

Local derivative of [Drew Burchfield's macos-mic-keepwarm](https://github.com/drewburchfield/macos-mic-keepwarm) at upstream commit `20aa116e03dc2ae4b47a1d15a6134507947c9093`, imported from its public GitHub archive. Original MIT license and copyright are preserved in `LICENSE`. The original CLI and installer are retained under `upstream/` for provenance, outside the build targets. The app rewrites lifecycle and UI around that capture/discard approach. `APPLE_FEEDBACK.md` is an upstream hypothesis, not a confirmed root cause for this setup.

The owned [Prewarm repository](https://github.com/ethanproia/Prewarm) is a GitHub fork of the upstream project. The upstream `master` history remains preserved; Prewarm uses `main`. No upstream release workflow is active for this derivative.

## Release archive

`./scripts/package-release.sh` builds a fresh bundle, verifies it, creates a version/architecture-named ZIP under `build/releases/`, verifies the extracted app and writes SHA-256 checksums plus a receipt. It requires a clean Git worktree so the receipt identifies the actual source. It ships the architecture built by the selected Swift toolchain; no universal binary is claimed. The process is repeatable, not a guarantee of identical bytes across toolchains, signing identities or timestamps.

Extract the archive, place Prewarm.app in `~/Applications`, and open it. This local release is ad-hoc signed and not notarized; a downloaded copy may be blocked by macOS Gatekeeper. Do not disable security controls. A publicly distributable Developer ID/notarized release is a separate future step. Microphone consent is still required and may recur after code changes. The Control Center microphone-mode placeholder icon remains unresolved despite valid bundle icon resources. Real login behavior has not been exercised; login registration is optional and defaults off.
