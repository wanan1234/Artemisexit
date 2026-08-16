// =============================================================
//  ArtemisAutoQuit — 悬浮退出按钮版
//  功能：在游戏界面上添加一个可拖动的“退出”按钮，点击后弹出确认框，确定后退出 App
//  适用：所有 iOS 应用（无侵入性）
// =============================================================

#import <UIKit/UIKit.h>
#import <substrate.h>

static UIWindow *floatWindow = nil;
static UIButton *floatButton = nil;
static BOOL isDragging = NO;

// 按钮事件处理类
@interface FloatButtonTarget : NSObject
- (void)buttonTapped;
- (void)handlePan:(UIPanGestureRecognizer *)pan;
@end

@implementation FloatButtonTarget

- (void)buttonTapped {
    // 显示退出确认对话框
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"退出游戏"
                                                                   message:@"确定要退出游戏吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        // 退出 App
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
        // 保存位置
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setFloat:floatWindow.frame.origin.x forKey:@"floatButtonX"];
        [defaults setFloat:floatWindow.frame.origin.y forKey:@"floatButtonY"];
        [defaults synchronize];
    }
}

@end

static FloatButtonTarget *target = nil;

// 保存位置函数
static void saveFloatButtonPosition(void) {
    if (floatWindow) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setFloat:floatWindow.frame.origin.x forKey:@"floatButtonX"];
        [defaults setFloat:floatWindow.frame.origin.y forKey:@"floatButtonY"];
        [defaults synchronize];
    }
}

// 初始化
__attribute__((constructor))
static void initialize() {
    // 延迟执行，确保 App 已完全启动
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        target = [[FloatButtonTarget alloc] init];
        
        // 创建浮动窗口
        floatWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
        floatWindow.windowLevel = UIWindowLevelAlert + 1;
        floatWindow.backgroundColor = [UIColor clearColor];
        floatWindow.userInteractionEnabled = YES;
        floatWindow.hidden = NO;
        
        // 创建按钮
        floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
        floatButton.frame = CGRectMake(0, 0, 60, 60);
        [floatButton setTitle:@"退出" forState:UIControlStateNormal];
        [floatButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [floatButton setBackgroundColor:[UIColor colorWithRed:1.0 green:0.2 blue:0.2 alpha:0.85]];
        floatButton.layer.cornerRadius = 30;
        floatButton.clipsToBounds = YES;
        floatButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        [floatButton addTarget:target action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
        
        // 添加拖动手势
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:target action:@selector(handlePan:)];
        [floatButton addGestureRecognizer:pan];
        
        [floatWindow addSubview:floatButton];
        floatWindow.rootViewController = [[UIViewController alloc] init];
        floatWindow.rootViewController.view.backgroundColor = [UIColor clearColor];
        floatWindow.userInteractionEnabled = YES;
        
        // 恢复保存的位置
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        CGFloat x = [defaults floatForKey:@"floatButtonX"];
        CGFloat y = [defaults floatForKey:@"floatButtonY"];
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat screenHeight = [UIScreen mainScreen].bounds.size.height;
        if (x != 0 || y != 0) {
            // 确保在屏幕内
            x = MAX(0, MIN(x, screenWidth - 60));
            y = MAX(0, MIN(y, screenHeight - 60));
            floatWindow.frame = CGRectMake(x, y, 60, 60);
        } else {
            // 默认在右上角
            floatWindow.frame = CGRectMake(screenWidth - 80, 100, 60, 60);
        }
        
        // 显示
        floatWindow.hidden = NO;
        [floatWindow makeKeyAndVisible];
        
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
        
        NSLog(@"[ArtemisAutoQuit] 悬浮按钮已加载，位置已恢复");
    });
}
