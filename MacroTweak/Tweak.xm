#import <UIKit/UIKit.h>
#import <substrate.h>
#import <objc/runtime.h>

// Macro recording state
typedef enum {
    MacroStateIdle,
    MacroStateRecording,
    MacroStatePlaying
} MacroState;

static MacroState currentState = MacroStateIdle;
static NSMutableArray *recordedEvents = nil;
static NSDate *recordingStartTime = nil;
static NSInteger playbackIndex = 0;
static BOOL shouldCancelPlayback = NO;

// UI Elements
static UIButton *macroButton = nil;
static UIWindow *overlayWindow = nil;
static UILabel *statusLabel = nil;

// Touch event structure
@interface MacroEvent : NSObject
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, assign) CGPoint location;
@property (nonatomic, assign) UITouchPhase phase;
@property (nonatomic, assign) NSUInteger tapCount;
@property (nonatomic, strong) NSString *viewClass;
@end

@implementation MacroEvent
@end

// Helper class to handle button actions - avoids static function issues
@interface MacroTweakHelper : NSObject
+ (instancetype)sharedInstance;
- (void)macroButtonTapped:(UIButton *)sender;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;
- (void)startRecording;
- (void)stopRecording;
- (void)startPlaybackWithDelay;
- (void)startPlayback;
- (void)playNextEvent;
- (void)simulateTouch:(MacroEvent *)event;
- (void)stopPlayback;
- (void)showStatus:(NSString *)message;
- (void)saveMacro;
- (void)loadSavedMacro;
@end

@implementation MacroTweakHelper

+ (instancetype)sharedInstance {
    static MacroTweakHelper *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)macroButtonTapped:(UIButton *)sender {
    if (currentState == MacroStateRecording) {
        [self stopRecording];
    } else if (currentState == MacroStateIdle) {
        if (recordedEvents.count > 0) {
            [self startPlaybackWithDelay];
        } else {
            [self showStatus:@"No macro recorded! Long press to record"];
        }
    } else if (currentState == MacroStatePlaying) {
        shouldCancelPlayback = YES;
        [self showStatus:@"Playback cancelled"];
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        if (currentState == MacroStateIdle) {
            [self startRecording];
        }
    }
}

- (void)startRecording {
    currentState = MacroStateRecording;
    [recordedEvents removeAllObjects];
    recordingStartTime = [NSDate date];

    dispatch_async(dispatch_get_main_queue(), ^{
        macroButton.backgroundColor = [UIColor redColor];
        [macroButton setTitle:@"■" forState:UIControlStateNormal];
        statusLabel.text = @"Recording... Tap to stop";
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (currentState == MacroStateRecording) {
            [self stopRecording];
            [self showStatus:@"Auto-stopped (30s max)"];
        }
    });
}

- (void)stopRecording {
    currentState = MacroStateIdle;

    dispatch_async(dispatch_get_main_queue(), ^{
        macroButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.9];
        [macroButton setTitle:@"▶" forState:UIControlStateNormal];
        statusLabel.text = [NSString stringWithFormat:@"Recorded %lu events", (unsigned long)recordedEvents.count];
    });

    [self saveMacro];
}

- (void)startPlaybackWithDelay {
    if (recordedEvents.count == 0) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        macroButton.backgroundColor = [UIColor orangeColor];
        [macroButton setTitle:@"✕" forState:UIControlStateNormal];
        statusLabel.text = @"Starting in 2s... Tap to cancel";
    });

    shouldCancelPlayback = NO;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!shouldCancelPlayback) {
            [self startPlayback];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                macroButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.9];
                [macroButton setTitle:@"▶" forState:UIControlStateNormal];
                statusLabel.text = @"Ready";
            });
        }
    });
}

- (void)startPlayback {
    currentState = MacroStatePlaying;
    playbackIndex = 0;

    dispatch_async(dispatch_get_main_queue(), ^{
        statusLabel.text = @"Playing... Tap to cancel";
    });

    [self playNextEvent];
}

- (void)playNextEvent {
    if (shouldCancelPlayback || playbackIndex >= recordedEvents.count) {
        [self stopPlayback];
        return;
    }

    MacroEvent *event = recordedEvents[playbackIndex];

    NSTimeInterval delay = event.timestamp;
    if (playbackIndex > 0) {
        MacroEvent *prevEvent = recordedEvents[playbackIndex - 1];
        delay = event.timestamp - prevEvent.timestamp;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!shouldCancelPlayback && currentState == MacroStatePlaying) {
            [self simulateTouch:event];
            playbackIndex++;
            [self playNextEvent];
        }
    });
}

- (void)simulateTouch:(MacroEvent *)event {
    NSLog(@"[MacroTweak] Simulating touch at (%.1f, %.1f) phase: %ld", event.location.x, event.location.y, (long)event.phase);

    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    UIView *targetView = [keyWindow hitTest:event.location withEvent:nil];

    if (targetView) {
        UITouch *touch = [[UITouch alloc] init];
        [touch setValue:[NSValue valueWithCGPoint:event.location] forKey:@"_locationInWindow"];
        [touch setValue:@(event.phase) forKey:@"_phase"];
        [touch setValue:targetView forKey:@"_view"];
        [touch setValue:keyWindow forKey:@"_window"];

        UIEvent *uiEvent = [[UIEvent alloc] init];
        [uiEvent setValue:[NSSet setWithObject:touch] forKey:@"_touches"];

        [[UIApplication sharedApplication] sendEvent:uiEvent];
    }
}

- (void)stopPlayback {
    currentState = MacroStateIdle;

    dispatch_async(dispatch_get_main_queue(), ^{
        macroButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.9];
        [macroButton setTitle:@"▶" forState:UIControlStateNormal];
        statusLabel.text = [NSString stringWithFormat:@"Finished (%lu events)", (unsigned long)recordedEvents.count];
    });
}

- (void)showStatus:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        statusLabel.text = message;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (![statusLabel.text isEqualToString:message]) return;
            statusLabel.text = @"Ready";
        });
    });
}

- (void)saveMacro {
    if (recordedEvents.count == 0) return;

    NSString *docsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *path = [docsDir stringByAppendingPathComponent:@"macro.dat"];

    NSMutableArray *saveData = [NSMutableArray array];
    for (MacroEvent *event in recordedEvents) {
        NSDictionary *dict = @{
            @"timestamp": @(event.timestamp),
            @"x": @(event.location.x),
            @"y": @(event.location.y),
            @"phase": @(event.phase),
            @"tapCount": @(event.tapCount),
            @"viewClass": event.viewClass ?: @""
        };
        [saveData addObject:dict];
    }

    [NSKeyedArchiver archiveRootObject:saveData toFile:path];
}

- (void)loadSavedMacro {
    NSString *docsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *path = [docsDir stringByAppendingPathComponent:@"macro.dat"];

    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSArray *saveData = [NSKeyedUnarchiver unarchiveObjectWithFile:path];

        [recordedEvents removeAllObjects];
        for (NSDictionary *dict in saveData) {
            MacroEvent *event = [[MacroEvent alloc] init];
            event.timestamp = [dict[@"timestamp"] doubleValue];
            event.location = CGPointMake([dict[@"x"] floatValue], [dict[@"y"] floatValue]);
            event.phase = (UITouchPhase)[dict[@"phase"] integerValue];
            event.tapCount = [dict[@"tapCount"] unsignedIntegerValue];
            event.viewClass = dict[@"viewClass"];
            [recordedEvents addObject:event];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (recordedEvents.count > 0) {
                [macroButton setTitle:@"▶" forState:UIControlStateNormal];
                statusLabel.text = [NSString stringWithFormat:@"Loaded: %lu events", (unsigned long)recordedEvents.count];
            }
        });
    }
}

@end

// Original method pointers
static void (*orig_UIApplication_sendEvent)(UIApplication *self, SEL _cmd, UIEvent *event);
static void (*orig_UIWindow_makeKeyAndVisible)(UIWindow *self, SEL _cmd);
static void (*orig_UIWindow_becomeKeyWindow)(UIWindow *self, SEL _cmd);

// Hook for UIApplication sendEvent
static void hook_UIApplication_sendEvent(UIApplication *self, SEL _cmd, UIEvent *event) {
    if (currentState == MacroStateRecording) {
        if (event.type == UIEventTypeTouches) {
            NSSet *touches = [event allTouches];
            for (UITouch *touch in touches) {
                MacroEvent *macroEvent = [[MacroEvent alloc] init];
                macroEvent.timestamp = [[NSDate date] timeIntervalSinceDate:recordingStartTime];
                macroEvent.location = [touch locationInView:nil];
                macroEvent.phase = touch.phase;
                macroEvent.tapCount = touch.tapCount;

                UIView *targetView = touch.view;
                macroEvent.viewClass = NSStringFromClass([targetView class]);

                [recordedEvents addObject:macroEvent];

                dispatch_async(dispatch_get_main_queue(), ^{
                    if (statusLabel) {
                        statusLabel.text = [NSString stringWithFormat:@"Recording: %lu events", (unsigned long)recordedEvents.count];
                    }
                });
            }
        }
    }
    orig_UIApplication_sendEvent(self, _cmd, event);
}

// Setup the macro overlay UI
static void setupMacroOverlay() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"[MacroTweak] Setting up overlay");

        // Create overlay window for the button
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        overlayWindow = [[UIWindow alloc] initWithFrame:CGRectMake(screenWidth - 70, 100, 60, 60)];
        overlayWindow.windowLevel = UIWindowLevelAlert + 100;
        overlayWindow.backgroundColor = [UIColor clearColor];
        overlayWindow.userInteractionEnabled = YES;
        overlayWindow.hidden = NO;

        // Create circular button
        macroButton = [UIButton buttonWithType:UIButtonTypeCustom];
        macroButton.frame = CGRectMake(0, 0, 50, 50);
        macroButton.layer.cornerRadius = 25;
        macroButton.layer.masksToBounds = YES;
        macroButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.9];
        [macroButton setTitle:@"●" forState:UIControlStateNormal];
        macroButton.titleLabel.font = [UIFont systemFontOfSize:24];

        // Use the helper class for actions
        MacroTweakHelper *helper = [MacroTweakHelper sharedInstance];
        [macroButton addTarget:helper action:@selector(macroButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

        // Add long press gesture
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:helper action:@selector(handleLongPress:)];
        [macroButton addGestureRecognizer:longPress];

        [overlayWindow addSubview:macroButton];

        // Status label
        statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(-100, 60, 200, 20)];
        statusLabel.textColor = [UIColor whiteColor];
        statusLabel.font = [UIFont systemFontOfSize:12];
        statusLabel.textAlignment = NSTextAlignmentCenter;
        statusLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
        statusLabel.layer.cornerRadius = 5;
        statusLabel.clipsToBounds = YES;
        statusLabel.text = @"Tap to Play/Long Press to Record";
        [overlayWindow addSubview:statusLabel];

        // Initialize events array
        recordedEvents = [NSMutableArray array];

        // Load saved macro
        [helper loadSavedMacro];

        NSLog(@"[MacroTweak] Overlay setup complete");
    });
}

// Hook for UIWindow makeKeyAndVisible
static void hook_UIWindow_makeKeyAndVisible(UIWindow *self, SEL _cmd) {
    orig_UIWindow_makeKeyAndVisible(self, _cmd);
    setupMacroOverlay();
}

// Hook for UIWindow becomeKeyWindow
static void hook_UIWindow_becomeKeyWindow(UIWindow *self, SEL _cmd) {
    orig_UIWindow_becomeKeyWindow(self, _cmd);
    setupMacroOverlay();
}

// Constructor - runs when tweak is loaded
__attribute__((constructor))
static void init() {
    NSLog(@"[MacroTweak] Loading...");

    @autoreleasepool {
        // Hook UIApplication sendEvent
        MSHookMessageEx(
            [UIApplication class],
            @selector(sendEvent:),
            (IMP)hook_UIApplication_sendEvent,
            (IMP *)&orig_UIApplication_sendEvent
        );

        // Hook UIWindow makeKeyAndVisible
        MSHookMessageEx(
            [UIWindow class],
            @selector(makeKeyAndVisible),
            (IMP)hook_UIWindow_makeKeyAndVisible,
            (IMP *)&orig_UIWindow_makeKeyAndVisible
        );

        // Hook UIWindow becomeKeyWindow
        MSHookMessageEx(
            [UIWindow class],
            @selector(becomeKeyWindow),
            (IMP)hook_UIWindow_becomeKeyWindow,
            (IMP *)&orig_UIWindow_becomeKeyWindow
        );

        NSLog(@"[MacroTweak] Hooks installed successfully");
    }
}
