# MacroTweak for LiveContainer (Jailed)

A **jailed** iOS tweak designed specifically for LiveContainer that records and replays touch macros with a 2-second cancellation delay overlay.

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
5. **CRITICAL**: Also copy `CydiaSubstrate.framework` to the same folder
6. Enable JIT if available (Settings → Enable JIT)
7. Launch the app

### Folder Structure
```
LiveContainer/Documents/Tweaks/com.yourapp.bundleid/
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

## License

MIT License
