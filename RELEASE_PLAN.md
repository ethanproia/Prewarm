# Prewarm 1.0.0 release plan

Status: accepted by parent and independent source reviewer; bounded implementation in progress.
Accepted baseline: `0ffd08655a548ac2999845f168e05abe58ed49a8`, installed 0.1.2 (16).
The accepted UI, capture behavior and preferences are locked. Homebrew is a later project.

## Audit and bounded remedies

Read every production source, policy, test, package manifest, build/render script,
README, license and retained upstream source. Independent audits review the same
baseline. Resolve only confirmed defects or demonstrable reader cost; no redesign,
dependency additions or speculative capture rewrites.

Proposed confirmed fixes, subject to mediation:

- Mask only Command/Option/Control/Shift for About Command-W, allowing Caps Lock.
- Prevent a duplicate instance rejected at launch from overwriting the active
  instance's diagnostic cache during termination.
- Remove the retired default-device icon helper and its obsolete assertions;
  System default remains the accepted plain microphone icon.
- State the actual build prerequisite: Xcode/macOS 27 SDK and its asset compiler;
  macOS 14 remains the deployment target, with older runtime paths not yet tested.
- Build into fresh app staging so removed resources cannot survive from a prior
  build; validate metadata, icon resources, executable architecture and signature.
- Use one version/build metadata source for 1.0.0 (17), bundle, documentation and
  review fixtures; package a version/architecture-named archive with SHA-256.

Parent-observed programmatic reopening on macOS 27 needs a bounded runtime check:
`performClick` may not begin the new expanded-interface session. Do not invent
events, private APIs or a new host. Mediate a public fallback only if confirmed.
Control Center's placeholder icon is unresolved despite a valid compiled icon
catalog and ICNS. Inspect packaging without cache/security resets; record this
limitation unless an actual live check proves a fix.

## Behavior and validation gates

Preserve pinned UID selection, no fallback on disconnect, opt-in System default
following, retry after failed/stale capture, sleep/wake and immediate normal Off
release. Keep login warming separate from normal saved enabled state; OS login
registration happens only on a user's menu action. Preserve public native session
ownership, dynamic appearance, accepted panel geometry and movement lock.

Run focused Swift policy tests and one lightweight native release build. Add a
regression only for changed behavior whose failure matters (shortcut modifiers,
diagnostic ownership or reopening), not copy/layout mirrors. Synthetic login and
appearance fixtures must not register login items, alter global preferences,
request microphone access or open capture. Do not run retained upstream installers
or integration scripts: they are provenance, not Prewarm's supported workflow.

Independent reviewers bind approval to the exact final source head and bundle
hash/signature. Parent owns installation and native UI/hardware smoke checks:
Scarlett continuous fresh samples with QuickTime closed; Off release; pinned vs
default selection; relaunch; no UI regression. Previously tested behavior need not
be repeatedly exercised unless changes or evidence justify it. Real login and
older macOS behavior must remain explicitly unverified if not exercised.

## Packaging, history and publication

Preserve the accepted head and installed build16 as rollback before any owned
branch/history cleanup. Keep independently buildable conventional commits, each
one idea and at most 400 authored changed lines (generated artwork excluded).
Fold review repairs into their logical units; preserve backup refs and verify
tree parity whenever rearranging already accepted changes. Never force-push.

Produce a clean fresh app and `Prewarm-1.0.0-<architecture>.zip`, checksum and
release receipt (exact source, SDK/toolchain, architecture, version, executable
hash and signing identity). Reproducible means the documented build/archive
procedure can be repeated; do not promise byte-identical output across Xcode,
asset compiler, signing identity or archive timestamps. Verify extraction and
strict signature. Ship dual MIT notices and bundled README; retain upstream
provenance without activating its workflows. Do not publish local caches, real
device UIDs, user emails, diagnostics or private support artifacts.

The available signing identity is ad hoc, not Developer ID; this release is not
notarized. Document manual installation and macOS permission/Gatekeeper behavior
honestly. Never change TCC, trust, certificates or security settings. Publish only
the architecture actually built and inspected, not an untested universal claim.

Parent owns reviewed main integration, the 1.0.0 tag, tracker/Hub updates and
publication through the admitted GitHub route. That route currently rejects the
caller; no alternate authentication/provider route is allowed. The About GitHub
action stays disabled until an actual owned repository URL exists. Route failure
must be reported as a publication blocker, not hidden by a local tag/archive.

## Stop condition

All accepted audit defects fixed and independently closed; meaningful checks
passed; exact 1.0.0 (17) artifact reviewed and parent smoke-tested; clean logical
history and worktree; rollback preserved; archive/license/install docs truthful.
Public release completion additionally requires admitted-route push/tag/archive
publication and live tracker links. If that route remains blocked, deliver the
complete local candidate and exact unresolved blocker without claiming release.

Commit map: `9cccf44` fixes diagnostic ownership, native close modifiers and retired presentation state; the next release-packaging unit owns shared metadata, fresh staging, archive validation, truthful docs and fixture checks. Each unit stays below 400 authored changed lines; generated About PNGs are excluded. Accepted baseline backup: `backup/accepted-build16-0ffd086`.
