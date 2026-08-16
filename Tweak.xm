// =============================================================
//  ArtemisAutoQuit — 最终版（三指双击切换）
//  功能：猫爪浮窗 + 抽屉菜单（返回/退出）+ 三指双击切换
//  适配：横竖屏自适应，位置记忆
// =============================================================

#import <UIKit/UIKit.h>
#import <substrate.h>

static UIWindow *floatWindow = nil;
static UIButton *floatButton = nil;
static UIVisualEffectView *blurView = nil;
static UIImageView *pawImageView = nil;
static BOOL isDragging = NO;
static BOOL isFloatingVisible = YES;

static UIWindow *drawerWindow = nil;
static UIButton *backButton = nil;
static UIButton *quitButton = nil;
static BOOL isDrawerVisible = NO;

// 手势处理类
@interface GestureHandler : NSObject
+ (void)handleThreeFingerDoubleTap;
@end
@implementation GestureHandler
+ (void)handleThreeFingerDoubleTap {
    isFloatingVisible = !isFloatingVisible;
    floatWindow.hidden = !isFloatingVisible;
    if (isDrawerVisible) {
        isDrawerVisible = NO;
        drawerWindow.hidden = YES;
        [backButton removeFromSuperview];
        [quitButton removeFromSuperview];
        backButton = nil;
        quitButton = nil;
    }
    [[NSUserDefaults standardUserDefaults] setBool:isFloatingVisible forKey:@"floatingVisible"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
@end

// 按钮事件处理类
@interface FloatButtonTarget : NSObject
- (void)buttonTapped;
- (void)handlePan:(UIPanGestureRecognizer *)pan;
- (void)updateWindowFrame;
- (void)showDrawer;
- (void)hideDrawer;
- (void)triggerBack;
- (void)triggerQuit;
- (UIViewController *)topViewController;
@end

@implementation FloatButtonTarget

- (void)buttonTapped {
    if (isDrawerVisible) {
        [self hideDrawer];
    } else {
        [self showDrawer];
    }
}

- (void)showDrawer {
    if (isDrawerVisible) return;
    isDrawerVisible = YES;
    
    if (!drawerWindow) {
        drawerWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        drawerWindow.windowLevel = UIWindowLevelAlert + 1;
        drawerWindow.backgroundColor = [UIColor clearColor];
        drawerWindow.userInteractionEnabled = YES;
        drawerWindow.hidden = NO;
        
        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        drawerWindow.rootViewController = rootVC;
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideDrawer)];
        [rootVC.view addGestureRecognizer:tap];
    }
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGPoint floatCenter = floatWindow.center;
    CGFloat buttonSize = 36;
    CGFloat spacing = 12;
    
    BOOL showAbove = (floatCenter.y - 60 > 0);
    CGFloat yOffset = showAbove ? -(buttonSize + spacing) : (buttonSize + spacing);
    
    CGPoint backCenter = CGPointMake(floatCenter.x - buttonSize/2 - spacing/2, floatCenter.y + yOffset);
    CGPoint quitCenter = CGPointMake(floatCenter.x + buttonSize/2 + spacing/2, floatCenter.y + yOffset);
    
    CGFloat half = buttonSize/2;
    backCenter.x = MAX(half + 10, MIN(backCenter.x, screenBounds.size.width - half - 10));
    quitCenter.x = MAX(half + 10, MIN(quitCenter.x, screenBounds.size.width - half - 10));
    CGFloat topMargin = 40;
    CGFloat bottomMargin = 40;
    backCenter.y = MAX(topMargin + half, MIN(backCenter.y, screenBounds.size.height - bottomMargin - half));
    quitCenter.y = MAX(topMargin + half, MIN(quitCenter.y, screenBounds.size.height - bottomMargin - half));
    
    if (floatCenter.y - topMargin < buttonSize + spacing && floatCenter.y + buttonSize + spacing > screenBounds.size.height - bottomMargin) {
        backCenter.y = topMargin + half;
        quitCenter.y = topMargin + half;
    }
    
    // 返回按钮
    backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    backButton.frame = CGRectMake(0, 0, buttonSize, buttonSize);
    backButton.center = backCenter;
    backButton.backgroundColor = [UIColor clearColor];
    backButton.layer.cornerRadius = buttonSize/2;
    backButton.clipsToBounds = YES;
    backButton.userInteractionEnabled = YES;
    [backButton addTarget:self action:@selector(triggerBack) forControlEvents:UIControlEventTouchUpInside];
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurViewBtn = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurViewBtn.frame = backButton.bounds;
    blurViewBtn.layer.cornerRadius = buttonSize/2;
    blurViewBtn.clipsToBounds = YES;
    blurViewBtn.userInteractionEnabled = NO;
    [backButton addSubview:blurViewBtn];
    
    UIView *tint = [[UIView alloc] initWithFrame:backButton.bounds];
    tint.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:0.4];
    tint.layer.cornerRadius = buttonSize/2;
    tint.clipsToBounds = YES;
    tint.userInteractionEnabled = NO;
    [backButton addSubview:tint];
    
    UILabel *label = [[UILabel alloc] initWithFrame:backButton.bounds];
    label.text = @"←";
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    label.textAlignment = NSTextAlignmentCenter;
    label.userInteractionEnabled = NO;
    [backButton addSubview:label];
    
    backButton.layer.shadowColor = [UIColor blackColor].CGColor;
    backButton.layer.shadowOffset = CGSizeMake(0, 2);
    backButton.layer.shadowRadius = 6;
    backButton.layer.shadowOpacity = 0.3;
    
    // 退出按钮
    quitButton = [UIButton buttonWithType:UIButtonTypeCustom];
    quitButton.frame = CGRectMake(0, 0, buttonSize, buttonSize);
    quitButton.center = quitCenter;
    quitButton.backgroundColor = [UIColor clearColor];
    quitButton.layer.cornerRadius = buttonSize/2;
    quitButton.clipsToBounds = YES;
    quitButton.userInteractionEnabled = YES;
    [quitButton addTarget:self action:@selector(triggerQuit) forControlEvents:UIControlEventTouchUpInside];
    
    UIBlurEffect *blur2 = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurViewBtn2 = [[UIVisualEffectView alloc] initWithEffect:blur2];
    blurViewBtn2.frame = quitButton.bounds;
    blurViewBtn2.layer.cornerRadius = buttonSize/2;
    blurViewBtn2.clipsToBounds = YES;
    blurViewBtn2.userInteractionEnabled = NO;
    [quitButton addSubview:blurViewBtn2];
    
    UIView *tint2 = [[UIView alloc] initWithFrame:quitButton.bounds];
    tint2.backgroundColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:0.4];
    tint2.layer.cornerRadius = buttonSize/2;
    tint2.clipsToBounds = YES;
    tint2.userInteractionEnabled = NO;
    [quitButton addSubview:tint2];
    
    UILabel *label2 = [[UILabel alloc] initWithFrame:quitButton.bounds];
    label2.text = @"✓";
    label2.textColor = [UIColor whiteColor];
    label2.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    label2.textAlignment = NSTextAlignmentCenter;
    label2.userInteractionEnabled = NO;
    [quitButton addSubview:label2];
    
    quitButton.layer.shadowColor = [UIColor blackColor].CGColor;
    quitButton.layer.shadowOffset = CGSizeMake(0, 2);
    quitButton.layer.shadowRadius = 6;
    quitButton.layer.shadowOpacity = 0.3;
    
    [drawerWindow.rootViewController.view addSubview:backButton];
    [drawerWindow.rootViewController.view addSubview:quitButton];
    drawerWindow.hidden = NO;
}

- (void)hideDrawer {
    isDrawerVisible = NO;
    if (drawerWindow) {
        drawerWindow.hidden = YES;
        [backButton removeFromSuperview];
        [quitButton removeFromSuperview];
        backButton = nil;
        quitButton = nil;
    }
}

- (void)triggerBack {
    UIViewController *topVC = [self topViewController];
    if (!topVC) {
        [self hideDrawer];
        return;
    }
    
    if (topVC.navigationController && topVC.navigationController.viewControllers.count > 1) {
        [topVC.navigationController popViewControllerAnimated:YES];
        [self hideDrawer];
        return;
    }
    
    if (topVC.presentingViewController) {
        [topVC dismissViewControllerAnimated:YES completion:nil];
        [self hideDrawer];
        return;
    }
    
    [self hideDrawer];
}

- (void)triggerQuit {
    UIViewController *topVC = [self topViewController];
    if (!topVC) {
        exit(0);
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"退出程序"
                                                                   message:@"确定要退出程序吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self hideDrawer];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            exit(0);
        });
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [topVC presentViewController:alert animated:YES completion:nil];
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

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) {
        isDragging = YES;
        if (isDrawerVisible) [self hideDrawer];
        [UIView animateWithDuration:0.2 animations:^{
            floatButton.transform = CGAffineTransformMakeScale(1.2, 1.2);
        }];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [pan translationInView:floatWindow];
        CGRect frame = floatWindow.frame;
        frame.origin.x += translation.x;
        frame.origin.y += translation.y;
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        frame.origin.x = MAX(0, MIN(frame.origin.x, screenBounds.size.width - frame.size.width));
        frame.origin.y = MAX(0, MIN(frame.origin.y, screenBounds.size.height - frame.size.height));
        floatWindow.frame = frame;
        [pan setTranslation:CGPointZero inView:floatWindow];
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        isDragging = NO;
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
    CGRect frame = floatWindow.frame;
    frame.origin.x = MAX(0, MIN(frame.origin.x, screenBounds.size.width - frame.size.width));
    frame.origin.y = MAX(0, MIN(frame.origin.y, screenBounds.size.height - frame.size.height));
    floatWindow.frame = frame;
    if (isDrawerVisible) [self hideDrawer];
}

@end

static FloatButtonTarget *target = nil;

static void saveButtonPosition(void) {
    if (floatWindow) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setFloat:floatWindow.center.x forKey:@"pawButtonCenterX"];
        [defaults setFloat:floatWindow.center.y forKey:@"pawButtonCenterY"];
        [defaults synchronize];
    }
}

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
        
        target = [[FloatButtonTarget alloc] init];
        
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
        blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
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
        
        pawImageView = [[UIImageView alloc] initWithImage:pawImage];
        pawImageView.contentMode = UIViewContentModeScaleAspectFit;
        pawImageView.frame = CGRectMake(9, 9, 22, 22);
        pawImageView.userInteractionEnabled = NO;
        [floatButton addSubview:pawImageView];
        
        floatButton.layer.shadowColor = [UIColor blackColor].CGColor;
        floatButton.layer.shadowOffset = CGSizeMake(0, 2);
        floatButton.layer.shadowRadius = 6;
        floatButton.layer.shadowOpacity = 0.25;
        
        [floatButton addTarget:target action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:target action:@selector(handlePan:)];
        [floatButton addGestureRecognizer:pan];
        
        [floatWindow addSubview:floatButton];
        
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
        
        // 添加三指双击手势
        UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
        if (mainWindow) {
            UITapGestureRecognizer *threeFingerDoubleTap = [[UITapGestureRecognizer alloc] initWithTarget:[GestureHandler class] action:@selector(handleThreeFingerDoubleTap)];
            threeFingerDoubleTap.numberOfTouchesRequired = 3;
            threeFingerDoubleTap.numberOfTapsRequired = 2;
            [mainWindow addGestureRecognizer:threeFingerDoubleTap];
        }
        
        // 监听旋转
        [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            [target updateWindowFrame];
            if (isDrawerVisible) [target hideDrawer];
        }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            if (floatWindow && isFloatingVisible) {
                floatWindow.windowLevel = UIWindowLevelStatusBar + 1;
                [floatWindow makeKeyAndVisible];
            }
        }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            saveButtonPosition();
            if (isDrawerVisible) [target hideDrawer];
        }];
        
        NSLog(@"[ArtemisAutoQuit] 加载完成，三指双击切换浮窗");
    });
}
