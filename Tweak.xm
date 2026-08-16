// =============================================================
//  ArtemisAutoQuit — 猫爪悬浮按钮版
//  功能：在游戏界面上添加一个可拖动的玻璃质感猫爪按钮，点击后弹出确认框退出 App
//  特性：支持横屏、自动适应屏幕、位置记忆、无文字、美观
// =============================================================

#import <UIKit/UIKit.h>
#import <substrate.h>

static UIWindow *floatWindow = nil;
static UIButton *floatButton = nil;
static UIVisualEffectView *visualEffectView = nil;
static BOOL isDragging = NO;

// 按钮事件处理类
@interface FloatButtonTarget : NSObject
- (void)buttonTapped;
- (void)handlePan:(UIPanGestureRecognizer *)pan;
- (void)updateWindowFrame;
@end

@implementation FloatButtonTarget

- (void)buttonTapped {
    // 显示退出确认对话框
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"退出游戏"
                                                                   message:@"确定要退出游戏吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        exit(0);
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    if (root) {
        [root presentViewController:alert animated:YES completion:nil];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (pan.state == UIGestureRecognizerStateBegan) {
        isDragging = YES;
        // 稍微放大按钮以提供反馈
        [UIView animateWithDuration:0.2 animations:^{
            floatButton.transform = CGAffineTransformMakeScale(1.2, 1.2);
        }];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [pan translationInView:floatWindow];
        CGRect frame = floatWindow.frame;
        frame.origin.x += translation.x;
        frame.origin.y += translation.y;
        
        // 限制在屏幕范围内
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        frame.origin.x = MAX(0, MIN(frame.origin.x, screenWidth - frame.size.width));
        frame.origin.y = MAX(0, MIN(frame.origin.y, screenHeight - frame.size.height));
        
        floatWindow.frame = frame;
        [pan setTranslation:CGPointZero inView:floatWindow];
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        isDragging = NO;
        // 恢复原始大小
        [UIView animateWithDuration:0.2 animations:^{
            floatButton.transform = CGAffineTransformIdentity;
        }];
        // 保存位置（以中心点保存）
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setFloat:floatWindow.center.x forKey:@"floatButtonCenterX"];
        [defaults setFloat:floatWindow.center.y forKey:@"floatButtonCenterY"];
        [defaults synchronize];
    }
}

- (void)updateWindowFrame {
    if (!floatWindow) return;
    // 当屏幕旋转时，调整窗口位置，确保按钮不超出屏幕
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
    CGRect frame = floatWindow.frame;
    frame.origin.x = MAX(0, MIN(frame.origin.x, screenWidth - frame.size.width));
    frame.origin.y = MAX(0, MIN(frame.origin.y, screenHeight - frame.size.height));
    floatWindow.frame = frame;
}

@end

static FloatButtonTarget *target = nil;

// 保存位置函数（以中心点保存）
static void saveFloatButtonPosition(void) {
    if (floatWindow) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setFloat:floatWindow.center.x forKey:@"floatButtonCenterX"];
        [defaults setFloat:floatWindow.center.y forKey:@"floatButtonCenterY"];
        [defaults synchronize];
    }
}

// 初始化
__attribute__((constructor))
static void initialize() {
    // 延迟执行，确保 App 已完全启动
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        target = [[FloatButtonTarget alloc] init];
        
        // 创建浮动窗口
        floatWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 70, 70)];
        floatWindow.windowLevel = UIWindowLevelAlert + 1;
        floatWindow.backgroundColor = [UIColor clearColor];
        floatWindow.userInteractionEnabled = YES;
        floatWindow.hidden = NO;
        
        // 设置 rootViewController 以支持横屏
        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view.backgroundColor = [UIColor clearColor];
        rootVC.view.userInteractionEnabled = NO; // 让事件穿透
        floatWindow.rootViewController = rootVC;
        
        // 创建按钮
        floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
        floatButton.frame = CGRectMake(0, 0, 70, 70);
        floatButton.backgroundColor = [UIColor clearColor];
        floatButton.userInteractionEnabled = YES;
        
        // 添加玻璃效果 (UIVisualEffectView)
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        visualEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        visualEffectView.frame = floatButton.bounds;
        visualEffectView.layer.cornerRadius = 35;
        visualEffectView.clipsToBounds = YES;
        visualEffectView.userInteractionEnabled = NO;
        [floatButton addSubview:visualEffectView];
        
        // 添加猫爪图标 (SF Symbols)
        UIImage *pawImage = [UIImage systemImageNamed:@"paw.fill"];
        UIImageView *iconView = [[UIImageView alloc] initWithImage:pawImage];
        iconView.tintColor = [UIColor colorWithRed:0.8 green:0.3 blue:0.3 alpha:1.0]; // 淡粉色
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.frame = CGRectMake(12, 12, 46, 46);
        iconView.userInteractionEnabled = NO;
        [floatButton addSubview:iconView];
        
        // 添加阴影
        floatButton.layer.shadowColor = [UIColor blackColor].CGColor;
        floatButton.layer.shadowOffset = CGSizeMake(0, 2);
        floatButton.layer.shadowRadius = 8;
        floatButton.layer.shadowOpacity = 0.3;
        
        // 按钮点击事件
        [floatButton addTarget:target action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
        
        // 添加拖动手势
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:target action:@selector(handlePan:)];
        [floatButton addGestureRecognizer:pan];
        
        [floatWindow addSubview:floatButton];
        
        // 恢复保存的位置（以中心点）
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        CGFloat centerX = [defaults floatForKey:@"floatButtonCenterX"];
        CGFloat centerY = [defaults floatForKey:@"floatButtonCenterY"];
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        if (centerX != 0 && centerY != 0) {
            // 确保在屏幕内
            centerX = MAX(35, MIN(centerX, screenWidth - 35));
            centerY = MAX(35, MIN(centerY, screenHeight - 35));
            floatWindow.center = CGPointMake(centerX, centerY);
        } else {
            // 默认在右上角
            floatWindow.center = CGPointMake(screenWidth - 50, 120);
        }
        
        // 显示
        floatWindow.hidden = NO;
        [floatWindow makeKeyAndVisible];
        
        // 监听屏幕旋转，调整位置
        [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceOrientationDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            [target updateWindowFrame];
        }];
        
        // 监听应用回到前台，确保浮窗在最上层
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            if (floatWindow) {
                floatWindow.windowLevel = UIWindowLevelAlert + 1;
                [floatWindow makeKeyAndVisible];
            }
        }];
        
        // 监听进入后台时保存位置
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            saveFloatButtonPosition();
        }];
        
        NSLog(@"[ArtemisAutoQuit] 猫爪悬浮按钮已加载");
    });
}
