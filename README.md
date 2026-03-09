# MacroTweak for LiveContainer

A jailed iOS tweak designed for LiveContainer that enables recording and replaying touch macros with a 2-second cancellation delay overlay.

## Features

- **Touch Recording**: Records all touch events (location, phase, timestamp) within the app
- **Macro Replay**: Replays recorded touch sequences automatically
- **2-Second Cancel Window**: Tap the overlay button during the 2-second delay to cancel playback
- **Persistent Storage**: Macros are saved to disk and persist between app launches
- **Visual Overlay**: Floating button with color-coded status indicators
- **Auto-Stop**: Recording automatically stops after 30 seconds to prevent huge recordings

## Installation

### Prerequisites
- iOS 15.0+ device
- LiveContainer installed
- CydiaSubstrate.framework (bundled with LiveContainer or from a jailbreak tweak)

### Steps
1. Build or download `MacroTweak.dylib` from Releases
2. In LiveContainer, navigate to `Tweaks/[YourAppBundleID]/`
3. Copy `MacroTweak.dylib` to that folder
4. Ensure `CydiaSubstrate.framework` is also in that folder (or @rpath linked)
5. Restart the app in LiveContainer

## Usage

1. **Start Recording**: Long-press the floating blue button (turns red)
2. **Stop Recording**: Tap the red button
3. **Playback**: Tap the blue button (shows ▶️ if macro exists)
4. **Cancel Playback**: During the 2-second orange delay window, tap to cancel

The overlay button shows:
- 🔵 Blue: Ready (tap to play, long-press to record)
- 🔴 Red: Recording (tap to stop)
- 🟠 Orange: Delay countdown (tap to cancel)
- ▶️ Play icon: Macro loaded and ready

## Building

### Local Build
```bash
export THEOS=~/theos
cd MacroTweak
make JAILED=1
```

### GitHub Actions
The included workflow automatically builds on push and creates releases on tags.

## Technical Details

- Hooks `UIApplication` to intercept touch events
- Uses `UIWindow` overlay for the floating button
- Stores events as serialized objects in app Documents
- Compatible with jailed environments via rpath linking

## Limitations

- Requires app to be running in LiveContainer
- Touch simulation uses public APIs where possible (some apps may not respond)
- 30-second recording limit to prevent memory issues
- Macros are app-specific (not shared between different apps)

## License

MIT License - See LICENSE file
