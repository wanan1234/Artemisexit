// =============================================================
//  ArtemisAutoQuit — 最终版（无额外窗口，原生弹窗）
//  功能：猫爪浮窗 + 三指双击切换 + 原生 UIAlertController
// =============================================================

#import <UIKit/UIKit.h>
#import <substrate.h>

// 全局变量
static UIWindow *floatWindow = nil;
static UIButton *floatButton = nil;
static BOOL isFloatingVisible = YES;

// =============================================================
// 三指双击手势
// =============================================================
static void toggleFloatingVisibility(void) {
    isFloatingVisible = !isFloatingVisible;
    floatWindow.hidden = !isFloatingVisible;
    [[NSUserDefaults standardUserDefaults] setBool:isFloatingVisible forKey:@"floatingVisible"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

%hook UIWindow
- (instancetype)initWithFrame:(CGRect)frame {
    self = %orig;
    if (self) {
        UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(artemis_handleTripleTap:)];
        gesture.numberOfTouchesRequired = 3;
        gesture.numberOfTapsRequired = 2;
        [self addGestureRecognizer:gesture];
        NSLog(@"[ArtemisAutoQuit] 三指双击手势已添加");
    }
    return self;
}
%new
- (void)artemis_handleTripleTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateRecognized) {
        if (@available(iOS 10.0, *)) {
            [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
        }
        NSLog(@"[ArtemisAutoQuit] 用户触发三指双击，切换浮窗");
        toggleFloatingVisibility();
    }
}
%end

// =============================================================
// 浮窗事件处理
// =============================================================
@interface FloatHandler : NSObject
+ (instancetype)sharedInstance;
- (void)buttonTapped;
- (void)buttonLongPressed;
- (void)handlePan:(UIPanGestureRecognizer *)pan;
- (void)updateWindowFrame;
- (UIViewController *)topViewController;
@end

@implementation FloatHandler

+ (instancetype)sharedInstance {
    static FloatHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[FloatHandler alloc] init];
    });
    return instance;
}

- (UIViewController *)topViewController {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) return nil;
    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    return topVC;
}

- (void)buttonTapped {
    // 先隐藏浮窗，防止遮挡弹窗
    floatWindow.hidden = YES;
    
    UIViewController *topVC = [self topViewController];
    if (!topVC) {
        // 无视图控制器则直接退出
        exit(0);
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"退出程序"
                                                                   message:@"确定要退出程序吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        // 取消时恢复浮窗
        floatWindow.hidden = !isFloatingVisible;
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        // 退出前恢复浮窗（其实没意义，但保持状态）
        floatWindow.hidden = NO;
        exit(0);
    }]];
    
    [topVC presentViewController:alert animated:YES completion:nil];
}

- (void)buttonLongPressed {
    exit(0);
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    static CGPoint startCenter;
    if (pan.state == UIGestureRecognizerStateBegan) {
        startCenter = floatWindow.center;
        [UIView animateWithDuration:0.2 animations:^{
            floatButton.transform = CGAffineTransformMakeScale(1.2, 1.2);
        }];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [pan translationInView:floatWindow.superview];
        CGPoint newCenter = CGPointMake(startCenter.x + translation.x, startCenter.y + translation.y);
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        CGFloat halfWidth = floatWindow.frame.size.width / 2;
        CGFloat halfHeight = floatWindow.frame.size.height / 2;
        newCenter.x = MAX(halfWidth, MIN(newCenter.x, screenBounds.size.width - halfWidth));
        newCenter.y = MAX(halfHeight, MIN(newCenter.y, screenBounds.size.height - halfHeight));
        floatWindow.center = newCenter;
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        [UIView animateWithDuration:0.2 animations:^{
            floatButton.transform = CGAffineTransformIdentity;
        }];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setFloat:floatWindow.center.x forKey:@"pawButtonCenterX"];
        [defaults setFloat:floatWindow.center.y forKey:@"pawButtonCenterY"];
        [defaults synchronize];
    }
}

- (void)updateWindowFrame {
    if (!floatWindow) return;
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGPoint center = floatWindow.center;
    CGFloat halfWidth = floatWindow.frame.size.width / 2;
    CGFloat halfHeight = floatWindow.frame.size.height / 2;
    center.x = MAX(halfWidth, MIN(center.x, screenBounds.size.width - halfWidth));
    center.y = MAX(halfHeight, MIN(center.y, screenBounds.size.height - halfHeight));
    floatWindow.center = center;
}

@end

__attribute__((constructor))
static void initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults objectForKey:@"floatingVisible"]) {
            isFloatingVisible = [defaults boolForKey:@"floatingVisible"];
        } else {
            isFloatingVisible = YES;
            [defaults setBool:YES forKey:@"floatingVisible"];
            [defaults synchronize];
        }
        
        UIImage *pawImage = [UIImage imageNamed:@"catpaw"];
        if (!pawImage) {
            pawImage = [UIImage systemImageNamed:@"paw.fill"];
            if (!pawImage) {
                UIGraphicsBeginImageContext(CGSizeMake(22, 22));
                [[UIColor colorWithRed:1.0 green:0.6 blue:0.6 alpha:1.0] setFill];
                UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, 22, 22)];
                [path fill];
                pawImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
            }
        }
        
        floatWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        floatWindow.windowLevel = UIWindowLevelStatusBar + 1;
        floatWindow.backgroundColor = [UIColor clearColor];
        floatWindow.userInteractionEnabled = YES;
        floatWindow.hidden = !isFloatingVisible;
        
        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        rootVC.view.userInteractionEnabled = NO;
        floatWindow.rootViewController = rootVC;
        
        floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
        floatButton.frame = CGRectMake(0, 0, 40, 40);
        floatButton.backgroundColor = [UIColor clearColor];
        floatButton.userInteractionEnabled = YES;
        
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = floatButton.bounds;
        blurView.layer.cornerRadius = 20;
        blurView.clipsToBounds = YES;
        blurView.userInteractionEnabled = NO;
        [floatButton addSubview:blurView];
        
        UIView *tintView = [[UIView alloc] initWithFrame:floatButton.bounds];
        tintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
        tintView.layer.cornerRadius = 20;
        tintView.clipsToBounds = YES;
        tintView.userInteractionEnabled = NO;
        [floatButton addSubview:tintView];
        
        UIImageView *pawImageView = [[UIImageView alloc] initWithImage:pawImage];
        pawImageView.contentMode = UIViewContentModeScaleAspectFit;
        pawImageView.frame = CGRectMake(9, 9, 22, 22);
        pawImageView.userInteractionEnabled = NO;
        [floatButton addSubview:pawImageView];
        
        floatButton.layer.shadowColor = [UIColor blackColor].CGColor;
        floatButton.layer.shadowOffset = CGSizeMake(0, 2);
        floatButton.layer.shadowRadius = 6;
        floatButton.layer.shadowOpacity = 0.25;
        
        FloatHandler *handler = [FloatHandler sharedInstance];
        [floatButton addTarget:handler action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
        
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:handler action:@selector(buttonLongPressed)];
        longPress.minimumPressDuration = 0.8;
        [floatButton addGestureRecognizer:longPress];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:handler action:@selector(handlePan:)];
        [floatButton addGestureRecognizer:pan];
        
        [floatWindow addSubview:floatButton];
        
        // 恢复位置
        CGFloat cx = [defaults floatForKey:@"pawButtonCenterX"];
        CGFloat cy = [defaults floatForKey:@"pawButtonCenterY"];
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        if (cx != 0 && cy != 0) {
            cx = MAX(20, MIN(cx, screenBounds.size.width - 20));
            cy = MAX(20, MIN(cy, screenBounds.size.height - 20));
            floatWindow.center = CGPointMake(cx, cy);
        } else {
            floatWindow.center = CGPointMake(screenBounds.size.width - 60, 120);
        }
        
        floatWindow.hidden = !isFloatingVisible;
        if (isFloatingVisible) {
            [floatWindow makeKeyAndVisible];
        }
        
        // 屏幕旋转适配
        [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [handler updateWindowFrame];
            });
        }];
        
        // 后台保存位置
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            if (floatWindow) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setFloat:floatWindow.center.x forKey:@"pawButtonCenterX"];
                [defaults setFloat:floatWindow.center.y forKey:@"pawButtonCenterY"];
                [defaults synchronize];
            }
        }];
        
        NSLog(@"[ArtemisAutoQuit] 猫爪浮窗加载完成 (三指双击切换浮窗)");
    });
}
