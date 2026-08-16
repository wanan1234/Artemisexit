// =============================================================
//  ArtemisAutoQuit — 悬浮球手动退出版
//  功能：在游戏界面添加一个可拖动的悬浮按钮，点击后弹出确认退出
//  适用：所有 Artemis 引擎游戏
// =============================================================

#import <UIKit/UIKit.h>
#import <substrate.h>

static UIButton *floatButton = nil;
static BOOL isDragging = NO;

// 创建悬浮按钮
static void createFloatButton(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) return;
        
        // 如果已经存在则移除
        if (floatButton) {
            [floatButton removeFromSuperview];
            floatButton = nil;
        }
        
        // 创建按钮
        floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
        floatButton.frame = CGRectMake(20, 100, 50, 50);
        floatButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.7];
        floatButton.layer.cornerRadius = 25;
        floatButton.layer.masksToBounds = YES;
        floatButton.layer.borderWidth = 1;
        floatButton.layer.borderColor = [UIColor whiteColor].CGColor;
        
        // 设置标题
        [floatButton setTitle:@"退出" forState:UIControlStateNormal];
        [floatButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        floatButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
        
        // 添加拖动手势
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:nil action:nil];
        [pan addTarget:self action:@selector(handlePan:)];
        [floatButton addGestureRecognizer:pan];
        
        // 添加点击事件
        [floatButton addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
        
        // 添加到窗口
        [keyWindow addSubview:floatButton];
        [keyWindow bringSubviewToFront:floatButton];
        
        // 记录日志
        NSLog(@"[ArtemisAutoQuit] 悬浮按钮已创建");
    });
}

// 拖动手势处理
static void handlePan(UIPanGestureRecognizer *gesture) {
    if (!floatButton) return;
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        isDragging = YES;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [gesture translationInView:floatButton.superview];
        CGRect newFrame = floatButton.frame;
        newFrame.origin.x += translation.x;
        newFrame.origin.y += translation.y;
        
        // 限制边界（防止移出屏幕）
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        if (newFrame.origin.x < 0) newFrame.origin.x = 0;
        if (newFrame.origin.y < 0) newFrame.origin.y = 0;
        if (newFrame.origin.x + newFrame.size.width > screenSize.width) {
            newFrame.origin.x = screenSize.width - newFrame.size.width;
        }
        if (newFrame.origin.y + newFrame.size.height > screenSize.height) {
            newFrame.origin.y = screenSize.height - newFrame.size.height;
        }
        
        floatButton.frame = newFrame;
        [gesture setTranslation:CGPointZero inView:floatButton.superview];
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        isDragging = NO;
    }
}

// 按钮点击事件
static void buttonTapped(void) {
    if (isDragging) return;
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) return;
    
    UIViewController *rootVC = keyWindow.rootViewController;
    if (!rootVC) return;
    
    // 弹出确认对话框
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"退出游戏"
                                                                   message:@"确定要退出游戏吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定"
                                                            style:UIAlertActionStyleDestructive
                                                          handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"[ArtemisAutoQuit] 用户确认退出，执行 exit(0)");
        exit(0);
    }];
    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    
    [rootVC presentViewController:alert animated:YES completion:nil];
}

// 使用 Category 添加方法（因为 C 函数不能直接作为 action）
@interface NSObject (FloatButton)
+ (void)createButton;
+ (void)handlePan:(UIPanGestureRecognizer *)gesture;
+ (void)buttonTapped;
@end

@implementation NSObject (FloatButton)
+ (void)createButton { createFloatButton(); }
+ (void)handlePan:(UIPanGestureRecognizer *)gesture { handlePan(gesture); }
+ (void)buttonTapped { buttonTapped(); }
@end

// 初始化
__attribute__((constructor))
static void initialize() {
    NSLog(@"[ArtemisAutoQuit] 悬浮球手动退出版加载，Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);
    
    // 延迟创建悬浮按钮，确保 window 已加载
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        createFloatButton();
    });
}
