// =============================================================
//  ArtemisAutoQuit — 最终修复版
//  功能：猫爪浮窗（点击 -> 弹出确认框，长按 -> 直接退出）
//       三指双击切换浮窗显示/隐藏
//  修复：弹窗不再被遮挡，三指双击手势稳定有效
// =============================================================

#import <UIKit/UIKit.h>
#import <substrate.h>

// 全局变量
static UIWindow *floatWindow = nil;
static UIButton *floatButton = nil;
static BOOL isFloatingVisible = YES;

// 用于显示弹窗的专用窗口
static UIWindow *alertWindow = nil;

// 手势目标类（使用单例模式，避免对象被释放）
@interface GestureHandler : NSObject
+ (instancetype)sharedInstance;
- (void)handleThreeFingerDoubleTap;
@end

@implementation GestureHandler

+ (instancetype)sharedInstance {
    static GestureHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[GestureHandler alloc] init];
    });
    return instance;
}

- (void)handleThreeFingerDoubleTap {
    isFloatingVisible = !isFloatingVisible;
    floatWindow.hidden = !isFloatingVisible;
    [[NSUserDefaults standardUserDefaults] setBool:isFloatingVisible forKey:@"floatingVisible"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

// 浮窗事件处理
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

// 使用专用窗口显示弹窗，确保不被遮挡
- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    // 如果已有弹窗窗口，先清理
    if (alertWindow) {
        alertWindow.hidden = YES;
        alertWindow.rootViewController = nil;
        alertWindow = nil;
    }

    // 1. 创建一个新的 UIWindow，层级最高
    alertWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    alertWindow.windowLevel = UIWindowLevelAlert + 1; // 高于所有
    alertWindow.backgroundColor = [UIColor clearColor];
    alertWindow.hidden = NO;

    // 2. 设置一个空的 rootViewController
    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor clearColor];
    alertWindow.rootViewController = rootVC;

    // 3. 创建 UIAlertController
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        // 清理弹窗窗口
        alertWindow.hidden = YES;
        alertWindow.rootViewController = nil;
        alertWindow = nil;
        exit(0);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        // 清理弹窗窗口
        alertWindow.hidden = YES;
        alertWindow.rootViewController = nil;
        alertWindow = nil;
    }]];

    // 4. 在专用窗口上 present 弹窗
    [rootVC presentViewController:alert animated:YES completion:nil];
    [alertWindow makeKeyAndVisible];
}

- (void)buttonTapped {
    // 点击浮窗 -> 弹出确认框
    [self showAlertWithTitle:@"退出程序" message:@"确定要退出程序吗？"];
}

- (void)buttonLongPressed {
    // 长按浮窗 -> 直接退出
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
        // 恢复显示状态
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults objectForKey:@"floatingVisible"]) {
            isFloatingVisible = [defaults boolForKey:@"floatingVisible"];
        } else {
            isFloatingVisible = YES;
            [defaults setBool:YES forKey:@"floatingVisible"];
            [defaults synchronize];
        }

        // 加载猫爪图标 (请确保 catpaw.png 在 Resources 目录下)
        UIImage *pawImage = [UIImage imageNamed:@"catpaw"];
        if (!pawImage) {
            pawImage = [UIImage systemImageNamed:@"paw.fill"];
        }

        // 创建浮窗 (40x40)
        floatWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        floatWindow.windowLevel = UIWindowLevelStatusBar + 1;
        floatWindow.backgroundColor = [UIColor clearColor];
        floatWindow.userInteractionEnabled = YES;
        floatWindow.hidden = !isFloatingVisible;

        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        rootVC.view.userInteractionEnabled = NO;
        floatWindow.rootViewController = rootVC;

        // 创建浮窗按钮
        floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
        floatButton.frame = CGRectMake(0, 0, 40, 40);
        floatButton.backgroundColor = [UIColor clearColor];
        floatButton.userInteractionEnabled = YES;

        // 玻璃效果
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = floatButton.bounds;
        blurView.layer.cornerRadius = 20;
        blurView.clipsToBounds = YES;
        blurView.userInteractionEnabled = NO;
        [floatButton addSubview:blurView];

        // 半透明白色覆盖
        UIView *tintView = [[UIView alloc] initWithFrame:floatButton.bounds];
        tintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
        tintView.layer.cornerRadius = 20;
        tintView.clipsToBounds = YES;
        tintView.userInteractionEnabled = NO;
        [floatButton addSubview:tintView];

        // 猫爪图标
        UIImageView *pawImageView = [[UIImageView alloc] initWithImage:pawImage];
        pawImageView.contentMode = UIViewContentModeScaleAspectFit;
        pawImageView.frame = CGRectMake(9, 9, 22, 22);
        pawImageView.userInteractionEnabled = NO;
        [floatButton addSubview:pawImageView];

        // 阴影
        floatButton.layer.shadowColor = [UIColor blackColor].CGColor;
        floatButton.layer.shadowOffset = CGSizeMake(0, 2);
        floatButton.layer.shadowRadius = 6;
        floatButton.layer.shadowOpacity = 0.25;

        // 获取单例对象作为事件目标
        FloatHandler *floatHandler = [FloatHandler sharedInstance];

        // 点击事件
        [floatButton addTarget:floatHandler action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];

        // 长按手势 (0.8秒)
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:floatHandler action:@selector(buttonLongPressed)];
        longPress.minimumPressDuration = 0.8;
        [floatButton addGestureRecognizer:longPress];

        // 拖动手势
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:floatHandler action:@selector(handlePan:)];
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

        // ---------- 三指双击手势 (添加到主窗口) ----------
        UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
        if (mainWindow) {
            static BOOL gestureAdded = NO;
            if (!gestureAdded) {
                // 使用单例对象作为手势目标
                GestureHandler *handler = [GestureHandler sharedInstance];
                UITapGestureRecognizer *threeFingerDoubleTap = [[UITapGestureRecognizer alloc] initWithTarget:handler action:@selector(handleThreeFingerDoubleTap)];
                threeFingerDoubleTap.numberOfTouchesRequired = 3;
                threeFingerDoubleTap.numberOfTapsRequired = 2;
                [mainWindow addGestureRecognizer:threeFingerDoubleTap];
                gestureAdded = YES;
                NSLog(@"[ArtemisAutoQuit] 三指双击手势已成功添加");
            }
        } else {
            // 如果主窗口暂时不存在，延迟重试
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIWindow *retryWindow = [UIApplication sharedApplication].keyWindow;
                if (retryWindow) {
                    static BOOL retryGestureAdded = NO;
                    if (!retryGestureAdded) {
                        GestureHandler *handler = [GestureHandler sharedInstance];
                        UITapGestureRecognizer *threeFingerDoubleTap = [[UITapGestureRecognizer alloc] initWithTarget:handler action:@selector(handleThreeFingerDoubleTap)];
                        threeFingerDoubleTap.numberOfTouchesRequired = 3;
                        threeFingerDoubleTap.numberOfTapsRequired = 2;
                        [retryWindow addGestureRecognizer:threeFingerDoubleTap];
                        retryGestureAdded = YES;
                        NSLog(@"[ArtemisAutoQuit] 三指双击手势已成功添加 (延迟)");
                    }
                }
            });
        }

        // ---------- 屏幕旋转适配 ----------
        [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[FloatHandler sharedInstance] updateWindowFrame];
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

        NSLog(@"[ArtemisAutoQuit] 猫爪浮窗加载完成 (点击确认退出，长按直接退出，三指双击切换)");
    });
}
