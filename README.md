# MacroTweak — Jailed Touch Macro Recorder for LiveContainer

Records and replays any sequence of touch gestures with a visual floating overlay.
Works in **jailed** environments (LiveContainer) using **CydiaSubstrate / MSHookMessageEx**.

---

## Feature Overview

| State | Button colour | Label | How to trigger |
|-------|--------------|-------|----------------|
| Ready (no macro) | 🔵 Blue | "Hold to Record" | Long-press → start recording |
| Ready (macro exists) | 🔵 Blue | "▶ Tap \| Hold=Rec" | Tap → play, Long-press → record new |
| Recording | 🔴 Red | "● REC — Tap to Stop" | Tap → stop & save |
| Countdown (2 s) | 🟠 Orange | "Play in Xs — Tap✕" | Tap ✕ → cancel |
| Playing | 🟢 Green | "▶ Playing — Tap✕" | Tap ✕ → abort |

Watermark **🔥 MACRO TWEAK LOADED 🔥** appears bottom-left immediately at launch — proves the dylib injected.

---

## File Layout in LiveContainer

```
LiveContainer/Documents/Tweaks/<AppBundleID>/
├── MacroTweak.dylib          ← built by this project
└── CydiaSubstrate.framework/
    └── CydiaSubstrate        ← required at runtime
```

> **CydiaSubstrate.framework** must be the real one from Dopamine/Cydia.  
> The dylib uses `@loader_path` as its rpath, so both files **must be in the same folder**.

---

## Build Requirements

| Tool | Minimum version | Install |
|------|----------------|---------|
| Xcode | 14.3 (iOS 16 SDK) | Mac App Store |
| ldid | any | `brew install ldid` |
| clang | bundled with Xcode | — |

---

## Local Build

```bash
# One-shot: compile + sign
make release

# Step by step
make build          # → MacroTweak.dylib
make sign           # → signed with ldid -S

# Verify rpaths / code signature
otool -l MacroTweak.dylib | grep -A 3 LC_RPATH
otool -l MacroTweak.dylib | grep -A 4 LC_CODE_SIGNATURE
```

### If you have an entitlements-aware ldid build

```bash
ldid -Sentitlements.plist MacroTweak.dylib
```

---

## GitHub Actions (CI/CD)

Push to `main` → workflow builds and uploads `MacroTweak.dylib` as an artifact.

1. Push your fork to GitHub
2. **Actions** tab → latest run → **Artifacts** section → download `MacroTweak-dylib-<sha>.zip`
3. Unzip → place `MacroTweak.dylib` in the LiveContainer Tweaks folder

To create a versioned release:

```bash
git tag v1.0.0 && git push --tags
```

---

## LiveContainer Checklist

Before opening the target app, verify every item:

- [ ] `MacroTweak.dylib` copied to `Tweaks/<BundleID>/`
- [ ] `CydiaSubstrate.framework/CydiaSubstrate` in the same folder
- [ ] **Sign Tweaks** button pressed in LiveContainer (re-sign after every copy)
- [ ] **"Hide LiveContainer from Dyld API"** → **OFF**
- [ ] **"Don't Inject TweakLoader"** → **OFF**
- [ ] Open the target app — wait 1–2 seconds for the overlay

---

## Debugging

### Check logs (macOS Console or `idevicesyslog`)

Filter on `MacroTweak`:

```
log stream --predicate 'subsystem == "com.macrotweak.livecontainer"' --level debug
```

Expected output on successful injection:

```
[MacroTweak] ╔══════════════════════════════════════╗
[MacroTweak] ║  MacroTweak  CONSTRUCTOR  CALLED     ║
[MacroTweak] ✓ Hooked UIApplication -sendEvent:
[MacroTweak] ✓ Scene & active observers installed
[MacroTweak] Overlay window is live. Watermark visible.
```

### Common failure modes

| Symptom | Cause | Fix |
|---------|-------|-----|
| No `[MacroTweak]` log lines | Dylib not injected | Check TweakLoader settings; re-sign |
| `code signature invalid` | Missing ldid | Run `make sign` / press "Sign Tweaks" |
| `Library not loaded: CydiaSubstrate` | Framework missing | Place framework next to dylib |
| Button invisible | Window level issue | Rare — check for `alpha=0` in logs |
| Overlay appears but touches not recorded | `sendEvent:` hook missed | Check log for `✓ Hooked` line |
| Replay does nothing | Private UITouch API changed | iOS version delta; check DBG logs |

---

## Architecture Notes

```
Constructor ──► MSHookMessageEx(UIApplication, sendEvent:)
             ├─ NSNotificationCenter: UISceneDidActivateNotification
             │    └─ setupOverlayInScene:       (iOS 13+ scene-based apps)
             └─ dispatch_async main            
                  ├─ Hook AppDelegate           (legacy apps)
                  └─ setupOverlayFallback       (connected-scenes scan)

sendEvent: hook ──► MacroTweakManager.handleTouchEvent:
                     └─ appends MacroTouchEvent to recordingBuffer

Replay ──► dispatch_after chain with original inter-event delays
           └─ UITouch private API → UIEvent → UIApplication.sendEvent:
```

### Why `MSHookMessageEx` and not `%hook`

`%hook` is a Theos/Logos preprocessor macro that compiles to `MSHookMessageEx` anyway, but requires the Logos preprocessor.  LiveContainer loads plain dylibs — no Logos runtime — so we call `MSHookMessageEx` directly.

### Why `-undefined dynamic_lookup`

We don't have a CydiaSubstrate stub library in the build environment, and we don't want to bundle one.  The linker flag tells clang "leave undefined symbols unresolved at link time; they will be resolved at load time."  At runtime the `@rpath` entries point to the real framework.

---

## Macro Storage

Macros are saved to:

```
<App Documents>/SavedMacro.macro   (NSKeyedArchiver, not secure-coded)
```

To delete a saved macro, remove this file (or long-press to overwrite with a new recording).

---

## License

MIT — use freely for personal automation.
