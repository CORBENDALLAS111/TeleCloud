# MacroTweak Installation Guide

## Overview
MacroTweak is a jailed iOS tweak for LiveContainer that records and replays touch macros with a 2-second cancellation delay.

## Files Included
- `MacroTweak.dylib` - The compiled tweak (build from source or download from Releases)
- `Tweak.xm` - Source code
- `Makefile` - Build configuration
- `control` - Package metadata
- `MacroTweak.plist` - Filter configuration
- `.github/workflows/build.yml` - Automated build workflow

## Building from Source

### Prerequisites
1. macOS with Xcode Command Line Tools
2. Theos installed (https://theos.dev/docs/installation)
3. iOS 15.0+ SDK

### Build Steps
```bash
# Clone the repository
git clone <repo-url>
cd MacroTweak/MacroTweak

# Set Theos environment variable
export THEOS=~/theos

# Build for jailed environment
make JAILED=1

# The .dylib will be in .theos/obj/debug/arm64/
```

## Installation in LiveContainer

### Method 1: Manual Copy
1. Build or download `MacroTweak.dylib`
2. Open LiveContainer on your iOS device
3. Navigate to `Tweaks/[YourTargetAppBundleID]/`
4. Copy `MacroTweak.dylib` to that folder
5. Ensure `CydiaSubstrate.framework` is also present (LiveContainer bundles this)
6. Restart the app in LiveContainer

### Method 2: Using Filza (if available)
1. Place `MacroTweak.dylib` in `/var/mobile/Documents/`
2. Open Filza, copy to LiveContainer's tweak folder
3. Restart app

## Usage Instructions

### Recording a Macro
1. **Long-press** the floating blue button (top-right corner)
2. Button turns **red** and status shows "Recording..."
3. Perform your touch actions in the app
4. **Tap** the red button to stop recording
5. Macro is automatically saved

### Playing a Macro
1. **Tap** the blue button (shows ▶️ if macro exists)
2. Button turns **orange** with countdown "Starting in 2s..."
3. **Tap orange button** during countdown to **cancel**
4. After 2 seconds, macro plays automatically
5. Button returns to blue when finished

### States Reference
| Color | Icon | State | Action |
|-------|------|-------|--------|
| 🔵 Blue | ● or ▶️ | Ready | Tap=Play, Long-press=Record |
| 🔴 Red | ■ | Recording | Tap=Stop |
| 🟠 Orange | ✕ | Delay | Tap=Cancel |

## Troubleshooting

### "Library not loaded: CydiaSubstrate"
- Ensure CydiaSubstrate.framework is in the tweak folder
- Or use `install_name_tool` to fix rpath:
  ```bash
  install_name_tool -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @rpath/CydiaSubstrate.framework/CydiaSubstrate MacroTweak.dylib
  ```

### Tweak not appearing
- Check that the app's bundle ID matches the filter
- Restart the app completely in LiveContainer
- Check LiveContainer logs for injection errors

### Recording not working
- Ensure the app is the key window
- Some apps may block event interception
- Try recording in a simpler view first

## Technical Details

### How It Works
1. **Hooking**: Uses `MSHookMessage` to intercept `UIApplication sendEvent:`
2. **Recording**: Captures touch location, phase, timestamp, and target view
3. **Storage**: Serializes events to `Documents/macro.dat` using NSKeyedArchiver
4. **Playback**: Uses `dispatch_after` to replay events with original timing
5. **Overlay**: Creates a `UIWindow` with `UIWindowLevelAlert + 100` for the button

### Compatibility
- iOS 15.0 - 18.x
- arm64 and arm64e devices
- LiveContainer 3.0+
- Works with most UIKit-based apps

## GitHub Actions

The repository includes an automated workflow that:
1. Sets up Theos on macOS runner
2. Builds the tweak for jailed environment
3. Fixes rpath for LiveContainer compatibility
4. Uploads artifacts
5. Creates releases on tag push

### Triggering a Release
```bash
git tag v1.0.0
git push origin v1.0.0
```

## License
MIT License - See LICENSE file for details.
