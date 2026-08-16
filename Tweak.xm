// =============================================================
//  ArtemisAutoQuit — 返回+退出抽屉菜单版
//  功能：猫爪浮窗，点击后弹出返回/退出按钮
//  适配：横竖屏自动适配，位置不跑偏
// =============================================================

#import <UIKit/UIKit.h>
#import <substrate.h>

static UIWindow *floatWindow = nil;
static UIButton *floatButton = nil;
static UIVisualEffectView *blurView = nil;
static UIImageView *pawImageView = nil;
static BOOL isDragging = NO;

// 抽屉相关
static UIWindow *drawerWindow = nil;
static UIButton *backButton = nil;     // 返回按钮
static UIButton *quitButton = nil;     // 退出按钮
static BOOL isDrawerVisible = NO;

// 按钮事件处理类
@interface FloatButtonTarget : NSObject
- (void)buttonTapped;
- (void)handlePan:(UIPanGestureRecognizer *)pan;
- (void)updateWindowFrame;
- (void)showDrawer;
- (void)hideDrawer;
- (void)triggerBack;
- (void)triggerQuit;
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
    
    // 创建抽屉窗口
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
    
    // 获取当前屏幕尺寸（支持横竖屏）
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGPoint floatCenter = floatWindow.center;
    CGFloat buttonSize = 36; // 比浮窗稍小 (浮窗40)
    CGFloat spacing = 12;
    
    // 计算两个按钮的位置（水平排列在浮窗上方）
    // 返回按钮在左，退出按钮在右
    BOOL showAbove = (floatCenter.y - 60 > 0);
    CGFloat yOffset = showAbove ? -(buttonSize + spacing) : (buttonSize + spacing);
    
    CGPoint backCenter = CGPointMake(floatCenter.x - buttonSize/2 - spacing/2, floatCenter.y + yOffset);
    CGPoint quitCenter = CGPointMake(floatCenter.x + buttonSize/2 + spacing/2, floatCenter.y + yOffset);
    
    // 确保按钮不超出屏幕边界（水平方向）
    CGFloat halfWidth = buttonSize/2;
    backCenter.x = MAX(halfWidth + 10, MIN(backCenter.x, screenBounds.size.width - halfWidth - 10));
    quitCenter.x = MAX(halfWidth + 10, MIN(quitCenter.x, screenBounds.size.width - halfWidth - 10));
    
    // 如果上方空间不足，下方空间也不足，强行放在浮窗上方（偏上）
    if (yOffset < 0 && floatCenter.y - 60 < 0) {
        backCenter.y = 50;
        quitCenter.y = 50;
    }
    
    // --- 返回按钮（←）---
    backButton = [UIButton buttonWithType:UIButtonTypeCustom];
    backButton.frame = CGRectMake(0, 0, buttonSize, buttonSize);
    backButton.center = backCenter;
    backButton.backgroundColor = [UIColor clearColor];
    backButton.layer.cornerRadius = buttonSize/2;
    backButton.clipsToBounds = YES;
    backButton.userInteractionEnabled = YES;
    [backButton addTarget:self action:@selector(triggerBack) forControlEvents:UIControlEventTouchUpInside];
    
    // 毛玻璃效果
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurViewBtn = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurViewBtn.frame = backButton.bounds;
    blurViewBtn.layer.cornerRadius = buttonSize/2;
    blurViewBtn.clipsToBounds = YES;
    blurViewBtn.userInteractionEnabled = NO;
    [backButton addSubview:blurViewBtn];
    
    // 蓝色遮罩
    UIView *tint = [[UIView alloc] initWithFrame:backButton.bounds];
    tint.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:1.0 alpha:0.4];
    tint.layer.cornerRadius = buttonSize/2;
    tint.clipsToBounds = YES;
    tint.userInteractionEnabled = NO;
    [backButton addSubview:tint];
    
    // ← 图标
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
    
    // --- 退出按钮（✓）---
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
    
    // 红色遮罩
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
    
    // 添加到抽屉窗口
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
    // 触发 iOS 系统的右滑返回手势
    UIViewController *topVC = [self getTopViewController];
    if (!topVC) {
        [self hideDrawer];
        return;
    }
    
    // 方法1：如果是在 NavigationController 中，直接 pop
    if (topVC.navigationController && topVC.navigationController.viewControllers.count > 1) {
        [topVC.navigationController popViewControllerAnimated:YES];
        [self hideDrawer];
        return;
    }
    
    // 方法2：模拟从右向左的滑动手势（从左边缘滑动）
    // 通过发送一个系统手势事件来触发返回
    // 利用运行时获取 interactivePopGestureRecognizer 并触发
    if (topVC.navigationController) {
        UIGestureRecognizer *gesture = topVC.navigationController.interactivePopGestureRecognizer;
        if (gesture) {
            // 模拟手势触发
            [topVC.navigationController popViewControllerAnimated:YES];
            [self hideDrawer];
            return;
        }
    }
    
    // 方法3：如果当前是 presented ViewController，则 dismiss
    if (topVC.presentingViewController) {
        [topVC dismissViewControllerAnimated:YES completion:nil];
        [self hideDrawer];
        return;
    }
    
    [self hideDrawer];
}

- (void)triggerQuit {
    // 显示退出确认对话框
    UIViewController *topVC = [self getTopViewController];
    if (!topVC) {
        exit(0);
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"退出游戏"
                                                                   message:@"确定要退出游戏吗？"
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

- (UIViewController *)getTopViewController {
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
        
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        frame.origin.x = MAX(0, MIN(frame.origin.x, screenWidth - frame.size.width));
        frame.origin.y = MAX(0, MIN(frame.origin.y, screenHeight - frame.size.height));
        
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
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    CGRect frame = floatWindow.frame;
    frame.origin.x = MAX(0, MIN(frame.origin.x, screenWidth - frame.size.width));
    frame.origin.y = MAX(0, MIN(frame.origin.y, screenHeight - frame.size.height));
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
        target = [[FloatButtonTarget alloc] init];
        
        // 加载本地猫爪图标
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
        
        // 创建浮窗
        floatWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        floatWindow.windowLevel = UIWindowLevelStatusBar + 1;
        floatWindow.backgroundColor = [UIColor clearColor];
        floatWindow.userInteractionEnabled = YES;
        floatWindow.hidden = NO;
        
        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        rootVC.view.userInteractionEnabled = NO;
        floatWindow.rootViewController = rootVC;
        
        // 按钮
        floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
        floatButton.frame = CGRectMake(0, 0, 40, 40);
        floatButton.backgroundColor = [UIColor clearColor];
        floatButton.userInteractionEnabled = YES;
        
        // 玻璃效果
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
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
        pawImageView = [[UIImageView alloc] initWithImage:pawImage];
        pawImageView.contentMode = UIViewContentModeScaleAspectFit;
        pawImageView.frame = CGRectMake(9, 9, 22, 22);
        pawImageView.userInteractionEnabled = NO;
        [floatButton addSubview:pawImageView];
        
        // 阴影
        floatButton.layer.shadowColor = [UIColor blackColor].CGColor;
        floatButton.layer.shadowOffset = CGSizeMake(0, 2);
        floatButton.layer.shadowRadius = 6;
        floatButton.layer.shadowOpacity = 0.25;
        
        // 事件
        [floatButton addTarget:target action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:target action:@selector(handlePan:)];
        [floatButton addGestureRecognizer:pan];
        
        [floatWindow addSubview:floatButton];
        
        // 恢复位置
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        CGFloat cx = [defaults floatForKey:@"pawButtonCenterX"];
        CGFloat cy = [defaults floatForKey:@"pawButtonCenterY"];
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
        if (cx != 0 && cy != 0) {
            cx = MAX(20, MIN(cx, screenW - 20));
            cy = MAX(20, MIN(cy, screenH - 20));
            floatWindow.center = CGPointMake(cx, cy);
        } else {
            floatWindow.center = CGPointMake(screenW - 60, 120);
        }
        
        floatWindow.hidden = NO;
        [floatWindow makeKeyAndVisible];
        
        // 监听旋转和前后台
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
            if (floatWindow) {
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
        
        NSLog(@"[ArtemisAutoQuit] 猫爪浮窗 + 返回/退出菜单已加载");
    });
}
