# MacroTweak for LiveContainer (Jailed)

A **jailed** iOS tweak designed specifically for LiveContainer that records and replays touch macros with a 2-second cancellation delay overlay.

## ⚠️ Important: This is a JAILED Tweak

This tweak is designed to work **without jailbreak** using LiveContainer's tweak injection system. It uses `MSHookMessageEx` directly instead of `%hook` for better compatibility with jailed environments.

## What You Should See

When you open an app in LiveContainer with this tweak injected:
- A **floating blue button** (●) in the top-right corner
- **Status label** below the button showing "Tap to Play/Long Press to Record"
- **Long-press** the button to start recording (turns red ■)
- **Tap** the button to playback (2s orange delay, then plays)

## Installation

### Prerequisites
- iOS 15.0+ device
- LiveContainer installed (v3.0+)
- **CydiaSubstrate.framework** (must be bundled with the tweak)

### Steps
1. Build or download `MacroTweak.dylib` from Releases
2. In LiveContainer, go to **Tweaks** tab
3. Select your app, then **Import Tweak**
4. Choose `MacroTweak.dylib`
5. **CRITICAL**: Also copy `CydiaSubstrate.framework` to the same folder:
   - `LiveContainer/Documents/Tweaks/[YourAppBundleID]/CydiaSubstrate.framework`
6. Enable JIT if available (Settings → Enable JIT)
7. Launch the app

### Folder Structure
```
LiveContainer/Documents/
└── Tweaks/
    └── com.yourapp.bundleid/
        ├── MacroTweak.dylib
        └── CydiaSubstrate.framework/
            └── CydiaSubstrate
```

## Troubleshooting

### "No visible button appears"
- Check that `CydiaSubstrate.framework` is in the same folder as the `.dylib`
- Check LiveContainer logs: Settings → View Logs
- Try enabling JIT mode
- Ensure the app is using UIKit (some SwiftUI apps may not work)

### "Library not loaded: CydiaSubstrate"
- The rpath isn't set correctly. The dylib needs to find CydiaSubstrate at `@rpath/CydiaSubstrate.framework/CydiaSubstrate`
- Use `install_name_tool` to fix:
  ```bash
  install_name_tool -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @rpath/CydiaSubstrate.framework/CydiaSubstrate MacroTweak.dylib
  ```

### "Tweak not working"
- Some apps detect and block tweak injection. Try:
  - Enabling "Hide LiveContainer from Dyld API" in app settings
  - Using a different app

## Building

### Local Build
```bash
export THEOS=~/theos
cd MacroTweak
make JAILED=1
```

### GitHub Actions
The workflow automatically builds with proper rpath settings for LiveContainer.

## Technical Details

- Uses `MSHookMessageEx` for direct method swizzling (more reliable in jailed env)
- Uses `@rpath` linking for CydiaSubstrate (required for LiveContainer)
- Creates overlay window with `UIWindowLevelAlert + 100`
- Stores macros in app's Documents directory

## Differences from Jailbroken Version

| Feature | Jailbroken | LiveContainer (Jailed) |
|---------|-----------|----------------------|
| Hook Method | `%hook` (Logos) | `MSHookMessageEx` |
| Substrate Path | `/Library/Frameworks/...` | `@rpath/...` |
| Installation | Cydia/Sileo | Manual copy to Tweaks folder |
| JIT Required | No | Recommended |

## License

MIT License
