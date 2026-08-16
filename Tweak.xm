// =============================================================
//  ArtemisAutoQuit — 最终简化版
//  功能：猫爪浮窗（点击弹出退出确认，长按直接退出）
//       三指双击切换浮窗显示/隐藏
//  适配：横竖屏自适应，位置记忆
// =============================================================

#import <UIKit/UIKit.h>
#import <substrate.h>

// 全局变量
static UIWindow *floatWindow = nil;
static UIButton *floatButton = nil;
static BOOL isFloatingVisible = YES;

// 手势目标类（避免编译警告）
@interface GestureTarget : NSObject
+ (void)handleThreeFingerDoubleTap;
@end
@implementation GestureTarget
+ (void)handleThreeFingerDoubleTap {
    isFloatingVisible = !isFloatingVisible;
    floatWindow.hidden = !isFloatingVisible;
    [[NSUserDefaults standardUserDefaults] setBool:isFloatingVisible forKey:@"floatingVisible"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
@end

// 浮窗事件处理
@interface FloatHandler : NSObject
+ (void)buttonTapped;
+ (void)buttonLongPressed;
+ (void)handlePan:(UIPanGestureRecognizer *)pan;
+ (void)updateWindowFrame;
+ (UIViewController *)topViewController;
@end

@implementation FloatHandler

+ (UIViewController *)topViewController {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) return nil;
    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    return topVC;
}

+ (void)buttonTapped {
    UIViewController *topVC = [self topViewController];
    if (!topVC) {
        // 无视图控制器时直接退出
        exit(0);
        return;
    }
    
    // 使用UIAlertController，不会被遮挡（因为floatWindow层级高于游戏）
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"退出程序"
                                                                   message:@"确定要退出程序吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        exit(0);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    // 如果当前有presentedViewController，在它上面present
    UIViewController *presenter = topVC;
    while (presenter.presentedViewController) {
        presenter = presenter.presentedViewController;
    }
    [presenter presentViewController:alert animated:YES completion:nil];
}

+ (void)buttonLongPressed {
    // 长按直接退出（无需确认）
    exit(0);
}

+ (void)handlePan:(UIPanGestureRecognizer *)pan {
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

+ (void)updateWindowFrame {
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
        
        // 加载猫爪图标
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
        
        // 创建浮窗（40x40）
        floatWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
        floatWindow.windowLevel = UIWindowLevelStatusBar + 1; // 确保在最上层
        floatWindow.backgroundColor = [UIColor clearColor];
        floatWindow.userInteractionEnabled = YES;
        floatWindow.hidden = !isFloatingVisible;
        
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
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = floatButton.bounds;
        blurView.layer.cornerRadius = 20;
        blurView.clipsToBounds = YES;
        blurView.userInteractionEnabled = NO;
        [floatButton addSubview:blurView];
        
        // 半透明白色覆盖，增强玻璃感
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
        
        // 事件绑定（使用类方法）
        [floatButton addTarget:[FloatHandler class] action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
        
        // 长按手势（直接退出）
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:[FloatHandler class] action:@selector(buttonLongPressed)];
        longPress.minimumPressDuration = 0.8; // 0.8秒长按
        [floatButton addGestureRecognizer:longPress];
        
        // 拖动手势
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:[FloatHandler class] action:@selector(handlePan:)];
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
        
        // ---------- 三指双击手势（添加到主窗口） ----------
        UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
        if (mainWindow) {
            // 检查是否已存在相同手势，避免重复添加
            static BOOL gestureAdded = NO;
            if (!gestureAdded) {
                UITapGestureRecognizer *threeFingerDoubleTap = [[UITapGestureRecognizer alloc] initWithTarget:[GestureTarget class] action:@selector(handleThreeFingerDoubleTap)];
                threeFingerDoubleTap.numberOfTouchesRequired = 3;
                threeFingerDoubleTap.numberOfTapsRequired = 2;
                [mainWindow addGestureRecognizer:threeFingerDoubleTap];
                gestureAdded = YES;
                NSLog(@"[ArtemisAutoQuit] 三指双击手势已添加");
            }
        }
        
        // ---------- 屏幕旋转适配 ----------
        [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            // 延迟执行，等待旋转完成
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [FloatHandler updateWindowFrame];
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
