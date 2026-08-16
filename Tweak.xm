// =============================================================
//  ArtemisAutoQuit — 极简可靠版
//  功能：在屏幕固定位置显示猫爪浮窗，点击弹出退出确认框
//  附加：三指双击可隐藏/显示浮窗（状态保存）
//  特点：不依赖方向检测，不尝试系统返回，稳定可靠
// =============================================================

#import <UIKit/UIKit.h>
#import <substrate.h>

static UIWindow *floatWindow = nil;
static UIButton *floatButton = nil;
static UIImageView *pawImageView = nil;
static BOOL isFloatingVisible = YES;

// 手势回调函数（C函数，避免self问题）
static void handleThreeFingerDoubleTap(id self, SEL _cmd) {
    isFloatingVisible = !isFloatingVisible;
    floatWindow.hidden = !isFloatingVisible;
    [[NSUserDefaults standardUserDefaults] setBool:isFloatingVisible forKey:@"floatingVisible"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// 按钮点击回调
static void buttonTapped(id self, SEL _cmd) {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) return;
    UIViewController *topVC = keyWindow.rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    if (!topVC) return;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"退出程序"
                                                                   message:@"确定要退出程序吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        exit(0);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [topVC presentViewController:alert animated:YES completion:nil];
}

// 拖拽回调
static void handlePan(UIPanGestureRecognizer *pan) {
    static CGPoint offset;
    if (pan.state == UIGestureRecognizerStateBegan) {
        offset = [pan locationInView:floatWindow];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint newCenter = [pan locationInView:floatWindow.superview];
        newCenter.x -= offset.x;
        newCenter.y -= offset.y;
        // 限制在屏幕内（使用主屏幕bounds）
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        newCenter.x = MAX(floatWindow.frame.size.width/2, MIN(newCenter.x, screenBounds.size.width - floatWindow.frame.size.width/2));
        newCenter.y = MAX(floatWindow.frame.size.height/2, MIN(newCenter.y, screenBounds.size.height - floatWindow.frame.size.height/2));
        floatWindow.center = newCenter;
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        // 保存位置
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setFloat:floatWindow.center.x forKey:@"floatCenterX"];
        [defaults setFloat:floatWindow.center.y forKey:@"floatCenterY"];
        [defaults synchronize];
    }
}

__attribute__((constructor))
static void initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        isFloatingVisible = [defaults boolForKey:@"floatingVisible"];
        if (![defaults objectForKey:@"floatingVisible"]) {
            isFloatingVisible = YES;
            [defaults setBool:YES forKey:@"floatingVisible"];
            [defaults synchronize];
        }
        
        // 创建浮窗
        floatWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
        floatWindow.windowLevel = UIWindowLevelStatusBar + 1;
        floatWindow.backgroundColor = [UIColor clearColor];
        floatWindow.userInteractionEnabled = YES;
        floatWindow.hidden = !isFloatingVisible;
        
        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        rootVC.view.userInteractionEnabled = NO;
        floatWindow.rootViewController = rootVC;
        
        // 按钮
        floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
        floatButton.frame = CGRectMake(0, 0, 44, 44);
        floatButton.backgroundColor = [UIColor clearColor];
        floatButton.userInteractionEnabled = YES;
        
        // 玻璃效果
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.frame = floatButton.bounds;
        blurView.layer.cornerRadius = 22;
        blurView.clipsToBounds = YES;
        blurView.userInteractionEnabled = NO;
        [floatButton addSubview:blurView];
        
        // 半透明白色覆盖
        UIView *tintView = [[UIView alloc] initWithFrame:floatButton.bounds];
        tintView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
        tintView.layer.cornerRadius = 22;
        tintView.clipsToBounds = YES;
        tintView.userInteractionEnabled = NO;
        [floatButton addSubview:tintView];
        
        // 猫爪图标
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
        pawImageView = [[UIImageView alloc] initWithImage:pawImage];
        pawImageView.contentMode = UIViewContentModeScaleAspectFit;
        pawImageView.frame = CGRectMake(11, 11, 22, 22);
        pawImageView.userInteractionEnabled = NO;
        [floatButton addSubview:pawImageView];
        
        // 阴影
        floatButton.layer.shadowColor = [UIColor blackColor].CGColor;
        floatButton.layer.shadowOffset = CGSizeMake(0, 2);
        floatButton.layer.shadowRadius = 6;
        floatButton.layer.shadowOpacity = 0.25;
        
        // 添加点击事件（使用关联对象方式）
        [floatButton addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
        
        // 拖拽手势
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [floatButton addGestureRecognizer:pan];
        
        [floatWindow addSubview:floatButton];
        
        // 恢复位置
        CGFloat cx = [defaults floatForKey:@"floatCenterX"];
        CGFloat cy = [defaults floatForKey:@"floatCenterY"];
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        if (cx != 0 && cy != 0) {
            cx = MAX(22, MIN(cx, screenBounds.size.width - 22));
            cy = MAX(22, MIN(cy, screenBounds.size.height - 22));
            floatWindow.center = CGPointMake(cx, cy);
        } else {
            floatWindow.center = CGPointMake(screenBounds.size.width - 60, 120);
        }
        
        floatWindow.hidden = !isFloatingVisible;
        if (isFloatingVisible) {
            [floatWindow makeKeyAndVisible];
        }
        
        // 添加三指双击手势到主窗口（使用C函数作为回调）
        UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
        if (mainWindow) {
            UITapGestureRecognizer *threeFingerDoubleTap = [[UITapGestureRecognizer alloc] initWithTarget:[NSObject new] action:@selector(handleThreeFingerDoubleTap)];
            // 不能直接给NSObject添加方法，需要动态添加
            // 改用block方式：使用一个对象作为target，动态添加方法
            // 更简单的方法：使用dispatch_once创建一个单例对象
            static dispatch_once_t onceToken;
            static id gestureTarget = nil;
            dispatch_once(&onceToken, ^{
                gestureTarget = [[NSObject alloc] init];
                // 动态添加方法
                class_addMethod([gestureTarget class], @selector(handleThreeFingerDoubleTap), (IMP)handleThreeFingerDoubleTap, "v@:");
            });
            UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:gestureTarget action:@selector(handleThreeFingerDoubleTap)];
            gesture.numberOfTouchesRequired = 3;
            gesture.numberOfTapsRequired = 2;
            [mainWindow addGestureRecognizer:gesture];
        }
        
        // 监听后台保存状态
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            if (floatWindow) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setFloat:floatWindow.center.x forKey:@"floatCenterX"];
                [defaults setFloat:floatWindow.center.y forKey:@"floatCenterY"];
                [defaults synchronize];
            }
        }];
        
        NSLog(@"[ArtemisAutoQuit] 极简版加载完成，三指双击切换浮窗");
    });
}
