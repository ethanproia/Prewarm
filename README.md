# Prewarm

Prewarm 0.1.2 (build 7), by Ethan Proia.

A tiny macOS menu-bar utility that keeps your microphone warm by keeping its input stream active. It immediately discards audio samples; it does not record, analyze, save, or transmit audio. No third-party dependencies or network calls.

Click the menu-bar icon and select **System default** under Microphone to follow the current macOS input, or choose a specific microphone. Device icons distinguish known AirPods models, headsets, microphones, interfaces, virtual/aggregate devices and generic inputs using detected transport plus explicit product/model hints. Ambiguous USB devices use a connector; USB transport cannot identify the downstream XLR microphone. An explicit choice is pinned by device UID: reconnecting AirPods or changing the system default does not switch it. If the selected microphone disconnects, Prewarm waits instead of opening another mic. **Keep microphone ready** enables or disables warming, with explicit On/Off state; disabling releases the input. State and selection persist across relaunches; first launch is off. A native floating NSPanel opens below the menu-bar icon or by reopening the app, and dismisses on an outside click or Escape. It has no popover pointer or close control. The system window owns its corners and one public native material hosts the prior controls; device-row hover remains minimal AppKit drawing. Sound Settings is directly accessible; the native More menu contains About, Microphone Privacy and Quit.

macOS 14 or later; Xcode command-line tools with Swift 5.9 or later.

```sh
swift test
./scripts/build-app.sh
open build/Prewarm.app
```

For a permanent local installation, quit Prewarm, copy `build/Prewarm.app` to `~/Applications/Prewarm.app`, and launch that copy. Enable warming and allow the macOS microphone permission prompt. macOS displays its microphone privacy indicator while warming. Select the Scarlett explicitly before enabling if the system default could be AirPods: keeping a Bluetooth mic active can affect its audio mode and battery.

The local build is ad-hoc signed because no signing identity is available. The current ad-hoc designated requirement is tied to the executable code-directory hash (verified with `codesign -d -r-`). Changing and re-signing the app changes that identity, so macOS may ask for microphone permission again. The stable bundle ID alone does not prevent this. No permission bypass or TCC modification is attempted. `PREWARM_SIGNING_IDENTITY` can supply a real signing identity; distribution, notarization, remote publication, and Homebrew submission are deferred. A privately maintained local self-signed identity could give development builds a certificate-based identity, but creating/importing its certificate and private key or changing trust is a separate Keychain/security operation; this project has not done so. It would not substitute for Developer ID signing or notarization for distribution.

## Recovery and privacy

Capture setup, callbacks, and teardown run off the UI thread. A lightweight two-second check detects device/default changes and stale capture. It restarts only when the actual selected input changes, stops, or fails to deliver samples for ten seconds. Failed starts stay retryable. If a macOS capture API itself hangs indefinitely, that serial queue cannot process recovery or off until the API returns; quitting the process releases its audio resources. Recovery is not hang-proof. Warming pauses for system sleep and resumes after wake; the upstream idle-sleep allowance is retained. The app does not change the device's sample rate or system default.

Status metadata only (device names/UIDs, state and latest sample age) is written to `~/Library/Caches/com.ethan.Prewarm/status.json` to aid verification. There are no audio bytes or transcripts in it. Preferences are in the standard `com.ethan.Prewarm` defaults domain. Quit releases capture through process exit. No PID files, process killing, login daemon, or signal-handler object destruction.

## Verify with the actual microphone

1. Close QuickTime's audio preview and other continuously capturing apps. Select Scarlett in Prewarm and in dictation, then enable warming. Confirm On is shown; the metadata should show `running: true` with a recent `sampleAge`.
2. Trigger Wispr and Willow and speak immediately. Compare opening audio against Prewarm off, using the same device and sample rate. Repeat at 48 and 192 kHz.
3. Reconnect AirPods or change the system default while Scarlett is explicitly selected. Prewarm must remain on Scarlett. Selecting System default should follow macOS instead.
4. Disconnect Scarlett: Prewarm must wait without opening another mic. Reconnect: warming must recover. Test sleep/wake, persisted selection after relaunch, and off releasing capture.

Automated policy tests cover explicit selection through default changes, no fallback during disconnection, reconnect recovery, System default following, failed-start retry and stale-stream recovery. They do not establish hardware latency or microphone permission behavior.

## Icon

Original deterministic vector artwork combines a flame-shaped microphone with its cradle. The menu-bar mark is an AppKit template, with filled and outlined states for on/off; the app icon uses the same mark on a warm amber/orange tile. Vector source: `Sources/Prewarm/IconArtwork.swift`; `./scripts/render-icons.sh` regenerates all PNG sizes, `assets/Prewarm.icns`, and the light/dark size review sheet. No external icon artwork or font glyphs are used.

## Provenance

Local derivative of [Drew Burchfield's macos-mic-keepwarm](https://github.com/drewburchfield/macos-mic-keepwarm) at upstream commit `20aa116e03dc2ae4b47a1d15a6134507947c9093`, imported from its public GitHub archive. Original MIT license and copyright are preserved in `LICENSE`. The original CLI and installer are retained under `upstream/` for provenance, outside the build targets. The app rewrites lifecycle and UI around that capture/discard approach. `APPLE_FEEDBACK.md` is an upstream hypothesis, not a confirmed root cause for this setup.

Remote fork creation is pending the approved Hub GitHub route. No upstream release workflow is active for this local fork.
