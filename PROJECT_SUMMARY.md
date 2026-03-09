# MacroTweak Project Summary

## What This Is
A complete iOS tweak development project for LiveContainer that records and replays touch macros.

## Key Features Implemented

### 1. Macro Recording
- Intercepts touch events via `UIApplication sendEvent:` hook
- Records: timestamp, location (x,y), touch phase, tap count, target view class
- 30-second auto-stop to prevent memory issues
- Saves to `Documents/macro.dat` using NSKeyedArchiver

### 2. Macro Playback
- Replays events with original timing intervals
- 2-second delay before playback with cancel option
- Visual countdown during delay period
- Can cancel during playback

### 3. User Interface
- Floating circular button (top-right corner)
- Color-coded states:
  - Blue: Ready/Idle
  - Red: Recording
  - Orange: Delay/Playing
- Status label showing current state and event count
- Long-press to record, tap to play

### 4. LiveContainer Compatibility
- Jailed environment support (no jailbreak required)
- Uses `@rpath` for CydiaSubstrate linking
- GitHub Actions workflow for automated building
- `install_name_tool` rpath fixing

## File Breakdown

### Tweak.xm (Main Code)
- **MacroEvent class**: Data model for touch events
- **UIApplication hook**: Intercepts all touch events when recording
- **UIWindow hook**: Adds floating button overlay
- **Recording logic**: Saves events with timestamps
- **Playback logic**: Dispatches events with original timing
- **UI management**: Button states, colors, labels

### Makefile
- Targets iOS 15.0+ (arm64/arm64e)
- Jailed build configuration
- CydiaSubstrate linking
- Post-build rpath fixing

### GitHub Actions Workflow
- Runs on macOS latest
- Uses `Randomblock1/theos-action@v1` for Theos setup
- Builds with `JAILED=1` flag
- Fixes rpath automatically
- Creates artifacts and releases

## Usage Flow

```
App Launch
    ↓
Overlay Appears (Blue Button)
    ↓
User Long-Presses → Recording Starts (Red)
    ↓
User Performs Actions → Events Recorded
    ↓
User Taps Red Button → Recording Stops (Blue with ▶️)
    ↓
User Taps Blue Button → 2s Delay Starts (Orange)
    ↓
User Can Cancel (Tap Orange) or Wait
    ↓
Playback Starts → Events Replayed
    ↓
Playback Ends → Returns to Blue
```

## Technical Implementation Notes

### Event Recording
Uses `%hook UIApplication` to intercept `sendEvent:`
- Checks if event type is `UIEventTypeTouches`
- Iterates through all touches in the event
- Creates `MacroEvent` objects with all relevant data
- Adds to `recordedEvents` array

### Event Playback
Uses `dispatch_after` with calculated delays:
- First event plays immediately
- Subsequent events use `timestamp - previousTimestamp`
- Creates synthetic `UITouch` and `UIEvent` objects
- Sends via `[UIApplication sendEvent:]`

### UI Overlay
Creates separate `UIWindow` with high window level:
- `UIWindowLevelAlert + 100` ensures visibility
- 50x50 circular button with corner radius
- Long-press gesture recognizer for recording
- Status label positioned below button

## Building

### Local
```bash
cd MacroTweak
export THEOS=~/theos
make JAILED=1
```

### GitHub Actions
- Push to main: builds and uploads artifact
- Push tag: creates release with dylib

## Installation in LiveContainer

1. Build or download `MacroTweak.dylib`
2. Place in `LiveContainer/Tweaks/[BundleID]/`
3. Include `CydiaSubstrate.framework`
4. Restart app

## Limitations & Considerations

1. **Touch Simulation**: Uses public APIs, some apps may not respond
2. **Security**: Records all touches including sensitive input
3. **Timing**: Backgrounding app during playback may cause timing issues
4. **View Hierarchy**: Playback relies on views being in same position
5. **30s Limit**: Hard limit to prevent excessive memory use

## Future Enhancements

- Multiple macro slots
- Export/import macros
- Adjustable playback speed
- Gesture support (swipes, pinches)
- Coordinate relative to specific views
- Accessibility integration

## Credits

- Theos: https://theos.dev
- LiveContainer: https://github.com/khanhduytran0/LiveContainer
- CydiaSubstrate: saurik
