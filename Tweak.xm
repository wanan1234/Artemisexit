// =============================================================
//  ArtemisAutoQuit — 猫爪浮窗 + 抽屉菜单版（修正编译错误）
//  功能：玻璃质感猫爪浮窗，点击后弹出圆形确定/取消按钮
//  图标：使用本地 catpaw.png
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
static UIView *drawerBackground = nil;
static UIButton *confirmButton = nil;
static UIButton *cancelButton = nil;
static BOOL isDrawerVisible = NO;

// 按钮事件处理类
@interface FloatButtonTarget : NSObject
- (void)buttonTapped;
- (void)handlePan:(UIPanGestureRecognizer *)pan;
- (void)updateWindowFrame;
- (void)showDrawer;
- (void)hideDrawer;
- (void)confirmQuit;
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
    
    CGPoint floatCenter = floatWindow.center;
    CGFloat buttonSize = 50;
    CGFloat spacing = 20;
    
    // 决定按钮显示在浮窗上方还是下方
    BOOL showAbove = (floatCenter.y - 80 > 0);
    CGFloat yOffset = showAbove ? - (buttonSize + spacing) : (buttonSize + spacing);
    
    CGPoint confirmCenter = CGPointMake(floatCenter.x, floatCenter.y + yOffset);
    CGPoint cancelCenter = CGPointMake(floatCenter.x, floatCenter.y + yOffset + (showAbove ? -(buttonSize + spacing) : (buttonSize + spacing)));
    
    // 确认按钮（红色 ✓）
    confirmButton = [UIButton buttonWithType:UIButtonTypeCustom];
    confirmButton.frame = CGRectMake(0, 0, buttonSize, buttonSize);
    confirmButton.center = confirmCenter;
    confirmButton.backgroundColor = [UIColor clearColor];
    confirmButton.layer.cornerRadius = buttonSize/2;
    confirmButton.clipsToBounds = YES;
    confirmButton.userInteractionEnabled = YES;
    [confirmButton addTarget:self action:@selector(confirmQuit) forControlEvents:UIControlEventTouchUpInside];
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurViewBtn = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurViewBtn.frame = confirmButton.bounds;
    blurViewBtn.layer.cornerRadius = buttonSize/2;
    blurViewBtn.clipsToBounds = YES;
    blurViewBtn.userInteractionEnabled = NO;
    [confirmButton addSubview:blurViewBtn];
    
    UIView *tint = [[UIView alloc] initWithFrame:confirmButton.bounds];
    tint.backgroundColor = [UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:0.4];
    tint.layer.cornerRadius = buttonSize/2;
    tint.clipsToBounds = YES;
    tint.userInteractionEnabled = NO;
    [confirmButton addSubview:tint];
    
    UILabel *label = [[UILabel alloc] initWithFrame:confirmButton.bounds];
    label.text = @"✓";
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    label.textAlignment = NSTextAlignmentCenter;
    label.userInteractionEnabled = NO;
    [confirmButton addSubview:label];
    
    confirmButton.layer.shadowColor = [UIColor blackColor].CGColor;
    confirmButton.layer.shadowOffset = CGSizeMake(0, 2);
    confirmButton.layer.shadowRadius = 8;
    confirmButton.layer.shadowOpacity = 0.3;
    
    // 取消按钮（灰色 ✕）
    cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelButton.frame = CGRectMake(0, 0, buttonSize, buttonSize);
    cancelButton.center = cancelCenter;
    cancelButton.backgroundColor = [UIColor clearColor];
    cancelButton.layer.cornerRadius = buttonSize/2;
    cancelButton.clipsToBounds = YES;
    cancelButton.userInteractionEnabled = YES;
    [cancelButton addTarget:self action:@selector(hideDrawer) forControlEvents:UIControlEventTouchUpInside];
    
    UIBlurEffect *blur2 = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurViewBtn2 = [[UIVisualEffectView alloc] initWithEffect:blur2];
    blurViewBtn2.frame = cancelButton.bounds;
    blurViewBtn2.layer.cornerRadius = buttonSize/2;
    blurViewBtn2.clipsToBounds = YES;
    blurViewBtn2.userInteractionEnabled = NO;
    [cancelButton addSubview:blurViewBtn2];
    
    UIView *tint2 = [[UIView alloc] initWithFrame:cancelButton.bounds];
    tint2.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.3];
    tint2.layer.cornerRadius = buttonSize/2;
    tint2.clipsToBounds = YES;
    tint2.userInteractionEnabled = NO;
    [cancelButton addSubview:tint2];
    
    UILabel *label2 = [[UILabel alloc] initWithFrame:cancelButton.bounds];
    label2.text = @"✕";
    label2.textColor = [UIColor whiteColor];
    label2.font = [UIFont systemFontOfSize:24 weight:UIFontWeightBold];
    label2.textAlignment = NSTextAlignmentCenter;
    label2.userInteractionEnabled = NO;
    [cancelButton addSubview:label2];
    
    cancelButton.layer.shadowColor = [UIColor blackColor].CGColor;
    cancelButton.layer.shadowOffset = CGSizeMake(0, 2);
    cancelButton.layer.shadowRadius = 8;
    cancelButton.layer.shadowOpacity = 0.3;
    
    [drawerWindow.rootViewController.view addSubview:confirmButton];
    [drawerWindow.rootViewController.view addSubview:cancelButton];
    drawerWindow.hidden = NO;
}

- (void)hideDrawer {
    isDrawerVisible = NO;
    if (drawerWindow) {
        drawerWindow.hidden = YES;
        [confirmButton removeFromSuperview];
        [cancelButton removeFromSuperview];
        confirmButton = nil;
        cancelButton = nil;
    }
}

- (void)confirmQuit {
    [self hideDrawer];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        exit(0);
    });
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
        
        NSLog(@"[ArtemisAutoQuit] 猫爪浮窗 + 抽屉菜单已加载");
    });
}
