// =============================================================================
// MacroTweak.m — Jailed Touch Macro Recorder for LiveContainer
// Target: iOS 16.2+ | arm64 | CydiaSubstrate (MSHookMessageEx)
//
// File layout in LiveContainer:
//   Documents/Tweaks/<BundleID>/
//     MacroTweak.dylib
//     CydiaSubstrate.framework/CydiaSubstrate
// =============================================================================

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <os/log.h>
#import <Foundation/Foundation.h>

// =============================================================================
// MARK: - CydiaSubstrate extern (resolved at runtime via @rpath)
// =============================================================================
extern void MSHookMessageEx(Class _class, SEL message, IMP hook, IMP *old);

// =============================================================================
// MARK: - Logging
// =============================================================================
static os_log_t g_log;

#define MLOG(fmt, ...)     os_log       (g_log, "[MacroTweak] " fmt, ##__VA_ARGS__)
#define MLOG_ERR(fmt, ...) os_log_error (g_log, "[MacroTweak][ERROR] " fmt, ##__VA_ARGS__)
#define MLOG_DBG(fmt, ...) os_log_debug (g_log, "[MacroTweak][DBG] "   fmt, ##__VA_ARGS__)

// =============================================================================
// MARK: - Private UIKit APIs for synthetic touch replay
// =============================================================================
@interface UITouch (MacroPrivate)
- (instancetype)_initWithTapCount:(NSUInteger)tapCount touchType:(NSInteger)type;
- (void)_setLocationInWindow:(CGPoint)location resetPrevious:(BOOL)reset;
- (void)_setPhase:(UITouchPhase)phase;
- (void)_setView:(UIView *)view;
- (void)_setWindow:(UIWindow *)window;
- (void)_setTimestamp:(NSTimeInterval)timestamp;
- (void)_setSentTouchesForEvent:(UIEvent *)event;
@end

@interface UIEvent (MacroPrivate)
+ (instancetype)_eventRelativeToWindow;
- (void)_setTimestamp:(NSTimeInterval)timestamp;
- (void)_addTouch:(UITouch *)touch forDelayedDelivery:(BOOL)delayed;
- (void)_clearTouches;
@end

// =============================================================================
// MARK: - MacroTouchEvent (recorded data model)
// =============================================================================
@interface MacroTouchEvent : NSObject <NSCoding>
@property (nonatomic) CGPoint          locationInWindow;
@property (nonatomic) UITouchPhase     phase;
@property (nonatomic) NSTimeInterval   timestamp;
@property (nonatomic) NSTimeInterval   delay;   ///< seconds since previous event
@end

@implementation MacroTouchEvent

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _locationInWindow = [coder decodeCGPointForKey:@"loc"];
        _phase            = (UITouchPhase)[coder decodeIntegerForKey:@"phase"];
        _timestamp        = [coder decodeDoubleForKey:@"ts"];
        _delay            = [coder decodeDoubleForKey:@"delay"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeCGPoint:_locationInWindow forKey:@"loc"];
    [coder encodeInteger:(NSInteger)_phase  forKey:@"phase"];
    [coder encodeDouble:_timestamp          forKey:@"ts"];
    [coder encodeDouble:_delay              forKey:@"delay"];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<MacroTouchEvent phase=%ld loc=(%.1f,%.1f) delay=%.3fs>",
            (long)_phase, _locationInWindow.x, _locationInWindow.y, _delay];
}

@end

// =============================================================================
// MARK: - MacroState enum
// =============================================================================
typedef NS_ENUM(NSInteger, MacroState) {
    MacroStateReady      = 0,   ///< Blue  — idle, macro may or may not exist
    MacroStateRecording  = 1,   ///< Red   — actively recording touches
    MacroStateCountdown  = 2,   ///< Orange — 2-second cancel window before playback
    MacroStatePlaying    = 3,   ///< Green — replaying
};

// =============================================================================
// MARK: - MacroTweakManager (full interface declared early so MacroOverlayWindow
//         can call [MacroTweakManager sharedManager] and access its properties)
// =============================================================================
@class MacroOverlayWindow;   // forward-declare the window instead

@interface MacroTweakManager : NSObject {
    BOOL _overlayReady;
}

@property (nonatomic, strong) MacroOverlayWindow              *overlayWindow;
@property (nonatomic, strong) NSMutableArray<MacroTouchEvent *> *recordingBuffer;
@property (nonatomic, strong) NSArray<MacroTouchEvent *>       *savedMacro;
@property (nonatomic)         MacroState                        state;

@property (nonatomic) NSTimeInterval  recordingStart;
@property (nonatomic) NSTimeInterval  lastEventTime;
@property (nonatomic, strong) NSTimer *autoStopTimer;

@property (nonatomic) NSInteger        countdownValue;
@property (nonatomic, strong) NSTimer *countdownTimer;

+ (instancetype)sharedManager;

- (void)setupOverlayInScene:(UIWindowScene *)scene;
- (void)setupOverlayFallback;
- (void)handleTouchEvent:(UIEvent *)event;
- (void)startRecording;
- (void)stopRecording;
- (void)startPlayback;
- (void)cancelPlayback;
- (void)_replayNow;
- (void)_dispatchEvents:(NSArray<MacroTouchEvent *> *)events atIndex:(NSUInteger)idx;

@end

// =============================================================================
// MARK: - MacroOverlayWindow
// =============================================================================
@interface MacroOverlayWindow : UIWindow
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UILabel  *statusLabel;
@property (nonatomic, strong) UILabel  *watermarkLabel;
- (void)updateForState:(MacroState)state countdownValue:(NSInteger)countdown;
@end

@implementation MacroOverlayWindow

// ─── Designated initialiser for scenes (iOS 13+) ───────────────────────────
- (instancetype)initWithWindowScene:(UIWindowScene *)scene {
    self = [super initWithWindowScene:scene];
    if (self) [self _buildUI];
    return self;
}

// ─── Fallback initialiser (no scene) ───────────────────────────────────────
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) [self _buildUI];
    return self;
}

- (void)_buildUI {
    // Window-level config
    self.windowLevel          = CGFLOAT_MAX;
    self.backgroundColor      = [UIColor clearColor];
    self.userInteractionEnabled = YES;
    self.alpha                = 1.0;

    // Transparent root view controller
    UIViewController *root    = [[UIViewController alloc] init];
    root.view.backgroundColor = [UIColor clearColor];
    root.view.userInteractionEnabled = YES;
    self.rootViewController   = root;

    // ─── Floating Action Button ─────────────────────────────────────────────
    _actionButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _actionButton.frame = CGRectMake(0, 0, 50, 50);
    _actionButton.layer.cornerRadius  = 25;
    _actionButton.layer.masksToBounds = NO;   // allow shadow outside clip
    _actionButton.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    _actionButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    [_actionButton setTitle:@"●" forState:UIControlStateNormal];
    [_actionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _actionButton.backgroundColor = [UIColor systemBlueColor];

    // Drop shadow
    _actionButton.layer.shadowColor   = [UIColor blackColor].CGColor;
    _actionButton.layer.shadowOffset  = CGSizeMake(0, 3);
    _actionButton.layer.shadowOpacity = 0.45f;
    _actionButton.layer.shadowRadius  = 5;

    [_actionButton addTarget:self
                      action:@selector(_buttonTapped:)
            forControlEvents:UIControlEventTouchUpInside];

    UILongPressGestureRecognizer *lp =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(_longPressed:)];
    lp.minimumPressDuration = 0.6;
    [_actionButton addGestureRecognizer:lp];

    // ─── Status Label ───────────────────────────────────────────────────────
    _statusLabel                 = [[UILabel alloc] initWithFrame:CGRectZero];
    _statusLabel.text            = @"Hold to Record";
    _statusLabel.textColor       = [UIColor whiteColor];
    _statusLabel.font            = [UIFont boldSystemFontOfSize:11];
    _statusLabel.textAlignment   = NSTextAlignmentCenter;
    _statusLabel.numberOfLines   = 1;
    _statusLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.65];
    _statusLabel.layer.cornerRadius  = 7;
    _statusLabel.layer.masksToBounds = YES;

    // ─── Watermark ──────────────────────────────────────────────────────────
    _watermarkLabel                 = [[UILabel alloc] initWithFrame:CGRectZero];
    _watermarkLabel.text            = @"🔥 MACRO TWEAK LOADED 🔥";
    _watermarkLabel.textColor       = [[UIColor systemOrangeColor] colorWithAlphaComponent:0.9];
    _watermarkLabel.font            = [UIFont boldSystemFontOfSize:11];
    _watermarkLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    _watermarkLabel.textAlignment   = NSTextAlignmentCenter;
    _watermarkLabel.layer.cornerRadius  = 7;
    _watermarkLabel.layer.masksToBounds = YES;

    [root.view addSubview:_actionButton];
    [root.view addSubview:_statusLabel];
    [root.view addSubview:_watermarkLabel];

    [self _relayout];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(_deviceRotated:)
               name:UIDeviceOrientationDidChangeNotification
             object:nil];
}

- (void)_relayout {
    CGRect screen = UIScreen.mainScreen.bounds;
    CGFloat W = screen.size.width;
    CGFloat H = screen.size.height;
    CGFloat margin = 16;

    // Button: top-right, respect safe area (status bar ~44pt + extra 36)
    _actionButton.frame = CGRectMake(W - 50 - margin, 80, 50, 50);

    // Status label: 130×22, centred below button
    _statusLabel.frame  = CGRectMake(W - 130 - margin + 40, 135, 130, 22);

    // Watermark: bottom-left above home indicator
    CGSize wSz = [_watermarkLabel sizeThatFits:CGSizeMake(320, 26)];
    _watermarkLabel.frame = CGRectMake(margin, H - 70, wSz.width + 20, 26);
}

- (void)_deviceRotated:(NSNotification *)note {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self _relayout]; });
}

// ─── State appearance ───────────────────────────────────────────────────────
- (void)updateForState:(MacroState)state countdownValue:(NSInteger)countdown {
    dispatch_async(dispatch_get_main_queue(), ^{
        switch (state) {
            case MacroStateReady: {
                BOOL hasMacro = [MacroTweakManager sharedManager].savedMacro.count > 0;
                self.actionButton.backgroundColor = [UIColor systemBlueColor];
                [self.actionButton setTitle:@"●" forState:UIControlStateNormal];
                self.statusLabel.text = hasMacro ? @"▶ Tap | Hold=Rec" : @"Hold to Record";
                break;
            }
            case MacroStateRecording:
                self.actionButton.backgroundColor = [UIColor systemRedColor];
                [self.actionButton setTitle:@"■" forState:UIControlStateNormal];
                self.statusLabel.text = @"● REC — Tap to Stop";
                break;

            case MacroStateCountdown:
                self.actionButton.backgroundColor = [UIColor systemOrangeColor];
                [self.actionButton setTitle:@"✕" forState:UIControlStateNormal];
                self.statusLabel.text = [NSString stringWithFormat:@"Play in %lds — Tap✕", (long)countdown];
                break;

            case MacroStatePlaying:
                self.actionButton.backgroundColor = [UIColor systemGreenColor];
                [self.actionButton setTitle:@"▶" forState:UIControlStateNormal];
                self.statusLabel.text = @"▶ Playing — Tap✕";
                break;
        }

        // Subtle scale-pop animation
        [UIView animateWithDuration:0.12 animations:^{
            self.actionButton.transform = CGAffineTransformMakeScale(1.15, 1.15);
        } completion:^(BOOL done) {
            [UIView animateWithDuration:0.10 animations:^{
                self.actionButton.transform = CGAffineTransformIdentity;
            }];
        }];
    });
}

// ─── Button handlers ────────────────────────────────────────────────────────
- (void)_buttonTapped:(UIButton *)sender {
    MacroTweakManager *mgr = [MacroTweakManager sharedManager];
    switch (mgr.state) {
        case MacroStateReady:
            if (mgr.savedMacro.count > 0) [mgr startPlayback];
            break;
        case MacroStateRecording:
            [mgr stopRecording];
            break;
        case MacroStateCountdown:
        case MacroStatePlaying:
            [mgr cancelPlayback];
            break;
    }
}

- (void)_longPressed:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        MacroTweakManager *mgr = [MacroTweakManager sharedManager];
        if (mgr.state == MacroStateReady) [mgr startRecording];
    }
}

// ─── Pass-through hit-test ───────────────────────────────────────────────────
// Taps on the transparent background fall through to the app below.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    // Pass through if hit is our root/background, not the button or labels
    if (hit == self.rootViewController.view || hit == self) return nil;
    return hit;
}

@end   // MacroOverlayWindow

// =============================================================================
// MARK: - MacroTweakManager @implementation
// =============================================================================
@implementation MacroTweakManager

+ (instancetype)sharedManager {
    static MacroTweakManager *sInstance;
    static dispatch_once_t token;
    dispatch_once(&token, ^{ sInstance = [[self alloc] init]; });
    return sInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _state           = MacroStateReady;
        _recordingBuffer = [NSMutableArray array];
        _overlayReady    = NO;
        [self _loadMacroFromDisk];
    }
    return self;
}

// =============================================================================
// MARK: - Overlay bootstrap
// =============================================================================
- (void)setupOverlayInScene:(UIWindowScene *)scene {
    if (_overlayReady) {
        MLOG("Overlay already set up, skipping");
        return;
    }

    MLOG("Creating overlay in UIWindowScene: %{public}@", NSStringFromClass([scene class]));
    dispatch_async(dispatch_get_main_queue(), ^{
        MacroOverlayWindow *win = [[MacroOverlayWindow alloc] initWithWindowScene:scene];
        [self _activateWindow:win];
    });
}

- (void)setupOverlayFallback {
    if (_overlayReady) return;

    // Try to find an active scene first
    if (@available(iOS 13, *)) {
        NSSet *scenes = [UIApplication sharedApplication].connectedScenes;
        UIWindowScene *best = nil;

        for (UIScene *s in scenes) {
            if (![s isKindOfClass:[UIWindowScene class]]) continue;
            if (s.activationState == UISceneActivationStateForegroundActive) {
                best = (UIWindowScene *)s;
                break;
            }
            if (!best) best = (UIWindowScene *)s;
        }

        if (best) {
            MLOG("Fallback: found scene %{public}@", NSStringFromClass([best class]));
            [self setupOverlayInScene:best];
            return;
        }
    }

    // Pure fallback — old-style init with screen bounds
    MLOG("Fallback: creating UIWindow with screen bounds");
    dispatch_async(dispatch_get_main_queue(), ^{
        MacroOverlayWindow *win =
            [[MacroOverlayWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        [self _activateWindow:win];
    });
}

- (void)_activateWindow:(MacroOverlayWindow *)win {
    win.windowLevel = CGFLOAT_MAX;
    win.hidden      = NO;
    win.alpha       = 1.0;
    [win makeKeyAndVisible];
    self.overlayWindow = win;
    _overlayReady      = YES;
    [win updateForState:MacroStateReady countdownValue:0];

    MLOG("Overlay window is live. Watermark visible.");
}

// =============================================================================
// MARK: - Touch interception (called from hooked sendEvent:)
// =============================================================================
- (void)handleTouchEvent:(UIEvent *)event {
    if (_state != MacroStateRecording) return;

    NSTimeInterval now = CACurrentMediaTime();
    if (now - _recordingStart >= 30.0) {
        MLOG("30-second auto-stop triggered");
        [self stopRecording];
        return;
    }

    for (UITouch *touch in [event allTouches]) {
        // Never record touches on our own overlay
        if (touch.window == _overlayWindow) continue;

        MacroTouchEvent *evt = [[MacroTouchEvent alloc] init];
        evt.phase            = touch.phase;
        evt.timestamp        = touch.timestamp;

        UIWindow *appWin = [self _appWindow];
        if (appWin) {
            evt.locationInWindow = [touch locationInView:appWin];
        } else {
            evt.locationInWindow = [touch locationInView:nil];
        }

        if (_recordingBuffer.count == 0) {
            evt.delay = 0.0;
        } else {
            evt.delay = MAX(0, evt.timestamp - _lastEventTime);
        }
        _lastEventTime = evt.timestamp;

        [_recordingBuffer addObject:evt];
        MLOG_DBG("Captured: %{public}@", evt);
    }
}

// =============================================================================
// MARK: - Recording control
// =============================================================================
- (void)startRecording {
    MLOG("=== START RECORDING ===");
    [_recordingBuffer removeAllObjects];
    _recordingStart = CACurrentMediaTime();
    _lastEventTime  = _recordingStart;
    _state          = MacroStateRecording;
    [_overlayWindow updateForState:MacroStateRecording countdownValue:0];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.autoStopTimer invalidate];
        self.autoStopTimer = [NSTimer scheduledTimerWithTimeInterval:30.0
                                                              target:self
                                                            selector:@selector(_autoStop:)
                                                            userInfo:nil
                                                             repeats:NO];
    });
}

- (void)_autoStop:(NSTimer *)t {
    if (_state == MacroStateRecording) {
        MLOG("Auto-stop fired (30s limit)");
        [self stopRecording];
    }
}

- (void)stopRecording {
    [_autoStopTimer invalidate];
    _autoStopTimer = nil;

    MLOG("=== STOP RECORDING — %lu events ===", (unsigned long)_recordingBuffer.count);

    if (_recordingBuffer.count > 0) {
        _savedMacro = [_recordingBuffer copy];
        [self _saveMacroToDisk];
    } else {
        MLOG("Nothing recorded, ignoring");
    }

    _state = MacroStateReady;
    [_overlayWindow updateForState:MacroStateReady countdownValue:0];
}

// =============================================================================
// MARK: - Playback control
// =============================================================================
- (void)startPlayback {
    if (!_savedMacro || _savedMacro.count == 0) {
        MLOG("No macro to play back");
        return;
    }
    MLOG("=== START COUNTDOWN (2s) ===");
    _state          = MacroStateCountdown;
    _countdownValue = 2;
    [_overlayWindow updateForState:MacroStateCountdown countdownValue:_countdownValue];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.countdownTimer invalidate];
        self.countdownTimer =
            [NSTimer scheduledTimerWithTimeInterval:1.0
                                             target:self
                                           selector:@selector(_countdownTick:)
                                           userInfo:nil
                                            repeats:YES];
    });
}

- (void)_countdownTick:(NSTimer *)timer {
    _countdownValue--;
    MLOG("Countdown: %ld", (long)_countdownValue);

    if (_countdownValue <= 0) {
        [timer invalidate];
        _countdownTimer = nil;
        [self _replayNow];
    } else {
        [_overlayWindow updateForState:MacroStateCountdown countdownValue:_countdownValue];
    }
}

- (void)cancelPlayback {
    MLOG("Playback cancelled by user");
    [_countdownTimer invalidate];
    _countdownTimer = nil;
    _state = MacroStateReady;
    [_overlayWindow updateForState:MacroStateReady countdownValue:0];
}

- (void)_replayNow {
    MLOG("=== START REPLAY — %lu events ===", (unsigned long)_savedMacro.count);
    _state = MacroStatePlaying;
    [_overlayWindow updateForState:MacroStatePlaying countdownValue:0];

    NSArray<MacroTouchEvent *> *events = [_savedMacro copy];
    [self _dispatchEvents:events atIndex:0];
}

// ─── Recursive event dispatcher (preserves original timing) ─────────────────
- (void)_dispatchEvents:(NSArray<MacroTouchEvent *> *)events atIndex:(NSUInteger)idx {
    if (_state != MacroStatePlaying) {
        MLOG("Replay interrupted at index %lu", (unsigned long)idx);
        return;
    }
    if (idx >= events.count) {
        MLOG("=== REPLAY COMPLETE ===");
        _state = MacroStateReady;
        [_overlayWindow updateForState:MacroStateReady countdownValue:0];
        return;
    }

    MacroTouchEvent *evt   = events[idx];
    NSTimeInterval   delay = MAX(0.0, evt.delay);

    __weak typeof(self) weak = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weak) self = weak;
        if (!self || self.state != MacroStatePlaying) return;
        [self _simulateEvent:evt];
        [self _dispatchEvents:events atIndex:idx + 1];
    });
}

// =============================================================================
// MARK: - Touch simulation
// =============================================================================
- (void)_simulateEvent:(MacroTouchEvent *)event {
    UIWindow *appWin = [self _appWindow];
    if (!appWin) {
        MLOG_ERR("No app window found for simulation");
        return;
    }

    CGPoint pt = event.locationInWindow;
    MLOG_DBG("Simulating phase=%ld at (%.1f,%.1f)", (long)event.phase, pt.x, pt.y);

    // ── Primary path: private UITouch/UIEvent API ─────────────────────────
    BOOL privateAPIAvailable =
        [UITouch instancesRespondToSelector:NSSelectorFromString(@"_setLocationInWindow:resetPrevious:")] &&
        [UIEvent  respondsToSelector:NSSelectorFromString(@"_eventRelativeToWindow")];

    if (privateAPIAvailable) {
        @try {
            // Create a synthetic UITouch
            UITouch *touch = [[UITouch alloc] init];
            [touch _setLocationInWindow:pt resetPrevious:YES];
            [touch _setPhase:event.phase];
            [touch _setWindow:appWin];
            [touch _setTimestamp:event.timestamp];

            UIView *hitView = [appWin hitTest:pt withEvent:nil];
            if (hitView) [touch _setView:hitView];

            // Create a synthetic UIEvent and inject
            UIEvent *synEvent = [UIEvent _eventRelativeToWindow];
            [synEvent _addTouch:touch forDelayedDelivery:NO];
            [[UIApplication sharedApplication] sendEvent:synEvent];
            [synEvent _clearTouches];

            MLOG_DBG("Injected via private UITouch API");
            return;
        }
        @catch (NSException *ex) {
            MLOG_ERR("Private API exception: %{public}@", ex.reason);
        }
    }

    // ── Fallback: responder-chain dispatch ────────────────────────────────
    MLOG("Using responder-chain fallback for simulation");
    UIView *target = [appWin hitTest:pt withEvent:nil] ?: appWin;

    switch (event.phase) {
        case UITouchPhaseBegan:
            [target touchesBegan:[NSSet set] withEvent:nil];
            break;
        case UITouchPhaseMoved:
            [target touchesMoved:[NSSet set] withEvent:nil];
            break;
        case UITouchPhaseEnded:
            [target touchesEnded:[NSSet set] withEvent:nil];
            // Also send primary action for UIControl targets
            if ([target isKindOfClass:[UIControl class]]) {
                [(UIControl *)target sendActionsForControlEvents:UIControlEventTouchUpInside];
            }
            break;
        case UITouchPhaseCancelled:
            [target touchesCancelled:[NSSet set] withEvent:nil];
            break;
        default:
            break;
    }
}

// =============================================================================
// MARK: - Helpers
// =============================================================================
- (UIWindow *)_appWindow {
    // Prefer the foreground scene's first non-overlay window
    if (@available(iOS 13, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            for (UIWindow *w in ws.windows) {
                if (w == _overlayWindow) continue;
                if (w.isHidden || w.alpha < 0.01) continue;
                return w;
            }
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    // iOS 12 fallback — suppressed deprecation: scene path above handles iOS 13+
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w == _overlayWindow) continue;
        if (!w.isHidden) return w;
    }
#pragma clang diagnostic pop
    return nil;
}

// =============================================================================
// MARK: - Persistence (Documents/SavedMacro.macro)
// =============================================================================
- (NSString *)_macroPath {
    NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [paths.firstObject stringByAppendingPathComponent:@"SavedMacro.macro"];
}

- (void)_saveMacroToDisk {
    NSError *err = nil;

    // Modern API (iOS 11+) — no deprecation warning
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_savedMacro
                                        requiringSecureCoding:NO
                                                        error:&err];
    if (!data || err) {
        MLOG_ERR("Failed to archive macro: %{public}@", err.localizedDescription);
        return;
    }

    BOOL ok = [data writeToFile:[self _macroPath]
                        options:NSDataWritingAtomic
                          error:&err];
    if (err || !ok) {
        MLOG_ERR("Failed to save macro: %{public}@", err.localizedDescription);
    } else {
        MLOG("Macro saved: %lu events → %{public}@",
             (unsigned long)_savedMacro.count, [self _macroPath]);
    }
}

- (void)_loadMacroFromDisk {
    NSString *path = [self _macroPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        MLOG("No saved macro found at %{public}@", path);
        return;
    }

    NSError *err  = nil;
    NSData  *data = [NSData dataWithContentsOfFile:path options:0 error:&err];
    if (!data || err) {
        MLOG_ERR("Failed to read macro file: %{public}@", err.localizedDescription);
        return;
    }

    @try {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data
                                                                                    error:&err];
        if (err) {
            MLOG_ERR("Unarchiver init error: %{public}@", err.localizedDescription);
            return;
        }
        unarchiver.requiresSecureCoding = NO;
        NSArray *loaded = [unarchiver decodeObjectForKey:NSKeyedArchiveRootObjectKey];
        [unarchiver finishDecoding];

        if ([loaded isKindOfClass:[NSArray class]] && loaded.count > 0) {
            _savedMacro = loaded;
            MLOG("Loaded saved macro: %lu events", (unsigned long)_savedMacro.count);
        }
    }
    @catch (NSException *ex) {
        MLOG_ERR("Exception while unarchiving: %{public}@", ex.reason);
    }
}

@end   // MacroTweakManager

// =============================================================================
// MARK: - Hooked IMP pointers (file-scope)
// =============================================================================
static IMP orig_sendEvent        = NULL;
static IMP orig_didFinishLaunch  = NULL;

// =============================================================================
// MARK: - Hook: UIApplication -sendEvent:
// =============================================================================
static void hook_sendEvent(UIApplication *self, SEL _cmd, UIEvent *event) {
    // Always call the original first so the app gets its touches
    ((void (*)(id, SEL, UIEvent *))orig_sendEvent)(self, _cmd, event);

    // Then let the manager inspect them
    if (event.type == UIEventTypeTouches) {
        [[MacroTweakManager sharedManager] handleTouchEvent:event];
    }
}

// =============================================================================
// MARK: - Hook: AppDelegate -application:didFinishLaunchingWithOptions:
// Called lazily after the delegate class is known.
// =============================================================================
static BOOL hook_didFinishLaunch(id<UIApplicationDelegate> self,
                                  SEL _cmd,
                                  UIApplication *app,
                                  NSDictionary  *options)
{
    BOOL result = ((BOOL (*)(id, SEL, UIApplication *, NSDictionary *))orig_didFinishLaunch)
                  (self, _cmd, app, options);

    MLOG("AppDelegate -application:didFinishLaunchingWithOptions: — setting up overlay");

    dispatch_async(dispatch_get_main_queue(), ^{
        [[MacroTweakManager sharedManager] setupOverlayFallback];
    });

    return result;
}

// =============================================================================
// MARK: - Scene connection observer helper
// =============================================================================
@interface MacroSceneObserver : NSObject
+ (void)install;
@end

@implementation MacroSceneObserver

+ (void)install {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    // UISceneDidActivateNotification fires when a scene becomes foreground-active
    [nc addObserverForName:UISceneDidActivateNotification
                   object:nil
                    queue:[NSOperationQueue mainQueue]
               usingBlock:^(NSNotification *note) {
        UIScene *scene = note.object;
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            MLOG("UISceneDidActivateNotification → %{public}@", NSStringFromClass([scene class]));
            [[MacroTweakManager sharedManager] setupOverlayInScene:(UIWindowScene *)scene];
        }
    }];

    // Fallback: UIApplicationDidBecomeActiveNotification
    [nc addObserverForName:UIApplicationDidBecomeActiveNotification
                   object:nil
                    queue:[NSOperationQueue mainQueue]
               usingBlock:^(NSNotification *note) {
        MLOG("UIApplicationDidBecomeActiveNotification — checking overlay");
        [[MacroTweakManager sharedManager] setupOverlayFallback];
    }];
}

@end

// =============================================================================
// MARK: - Constructor (dylib entry point — called by dyld when loaded)
// =============================================================================
__attribute__((constructor))
static void MacroTweakInit(void) {
    // ── Logging setup ────────────────────────────────────────────────────────
    g_log = os_log_create("com.macrotweak.livecontainer", "tweak");
    MLOG("╔══════════════════════════════════════╗");
    MLOG("║  MacroTweak  CONSTRUCTOR  CALLED     ║");
    MLOG("║  iOS %{public}@ | %{public}@       ║",
         UIDevice.currentDevice.systemVersion,
         UIDevice.currentDevice.model);
    MLOG("╚══════════════════════════════════════╝");

    // ── Hook UIApplication -sendEvent: ───────────────────────────────────────
    Class appClass = objc_getClass("UIApplication");
    if (appClass) {
        MSHookMessageEx(appClass,
                        @selector(sendEvent:),
                        (IMP)hook_sendEvent,
                        &orig_sendEvent);
        MLOG("✓ Hooked UIApplication -sendEvent:");
    } else {
        MLOG_ERR("✗ Could not find UIApplication class");
    }

    // ── Install scene/active observers ───────────────────────────────────────
    [MacroSceneObserver install];
    MLOG("✓ Scene & active observers installed");

    // ── Lazy delegate hook + initial overlay attempt ─────────────────────────
    dispatch_async(dispatch_get_main_queue(), ^{
        // Hook the delegate class now that the app has a delegate
        id<UIApplicationDelegate> delegate = [UIApplication sharedApplication].delegate;
        if (delegate) {
            Class cls = [delegate class];
            MLOG("Delegate class: %{public}s", class_getName(cls));

            SEL sel = @selector(application:didFinishLaunchingWithOptions:);
            if ([cls instancesRespondToSelector:sel]) {
                MSHookMessageEx(cls, sel,
                                (IMP)hook_didFinishLaunch,
                                &orig_didFinishLaunch);
                MLOG("✓ Hooked %{public}s -application:didFinishLaunchingWithOptions:",
                     class_getName(cls));
            } else {
                MLOG("Delegate does not implement didFinishLaunchingWithOptions: "
                     "(SceneDelegate pattern?) — overlay via notification only");
            }
        }

        // The app may already be running, so try the overlay right now too
        [[MacroTweakManager sharedManager] setupOverlayFallback];
    });

    MLOG("MacroTweak constructor complete — watching for overlay opportunity");
}
