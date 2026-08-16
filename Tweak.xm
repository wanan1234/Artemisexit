// =============================================================
//  ArtemisAutoQuit — 自动退出插件（黑屏检测版）
//  功能：检测游戏退出或黑屏，自动关闭 App
//  日志：写入 Documents/AutoQuit.log
// =============================================================

#import <UIKit/UIKit.h>
#import <substrate.h>

static void WriteLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docPath = [paths firstObject];
    NSString *logPath = [docPath stringByAppendingPathComponent:@"AutoQuit.log"];

    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:docPath]) {
        [fm createDirectoryAtPath:docPath withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    NSString *timestamp = [df stringFromDate:[NSDate date]];
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", timestamp, msg];

    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:logPath];
    if (!fh) {
        [line writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        [fh seekToEndOfFile];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
    NSLog(@"[ArtemisAutoQuit] %@", msg);
}

// 检测窗口是否处于黑屏状态
static BOOL isWindowBlackScreen(UIWindow *window) {
    if (!window) return YES; // 窗口不存在，视为黑屏
    
    // 条件1：窗口尺寸为 0
    if (window.frame.size.width == 0 || window.frame.size.height == 0) {
        WriteLog(@"📐 窗口尺寸为 0 (width=%.0f, height=%.0f)", window.frame.size.width, window.frame.size.height);
        return YES;
    }
    
    // 条件2：窗口被隐藏
    if (window.hidden) {
        WriteLog(@"👻 窗口被隐藏");
        return YES;
    }
    
    // 条件3：rootViewController 为 nil
    if (!window.rootViewController) {
        WriteLog(@"📭 rootViewController 为 nil");
        return YES;
    }
    
    // 条件4：检测窗口的 subviews 是否为空（黑屏标志）
    if (window.subviews.count == 0) {
        WriteLog(@"🖼️ 窗口没有任何子视图");
        return YES;
    }
    
    // 条件5：检查第一个子视图是否隐藏或尺寸异常
    UIView *firstView = window.subviews.firstObject;
    if (firstView && firstView.hidden) {
        WriteLog(@"👁️ 主视图被隐藏");
        return YES;
    }
    
    return NO;
}

// 检测并退出
static void checkAndQuit(void) {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    
    if (isWindowBlackScreen(keyWindow)) {
        WriteLog(@"⚠️ 检测到黑屏状态，执行自动退出");
        dispatch_async(dispatch_get_main_queue(), ^{
            WriteLog(@"🔄 调用 exit(0) 终止 App");
            exit(0);
        });
    } else {
        WriteLog(@"✅ 窗口状态正常 (frame=%@, hidden=%d, rootVC=%@, subviews=%lu)",
                 NSStringFromCGRect(keyWindow.frame),
                 keyWindow.hidden,
                 keyWindow.rootViewController,
                 (unsigned long)keyWindow.subviews.count);
    }
}

// 定时监控线程
static void startMonitoring(void) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int counter = 0;
        while (1) {
            sleep(1); // 改为每秒检测一次，更快响应
            counter++;
            if (counter % 5 == 0) {
                WriteLog(@"⏱️ 定时检测 (第%d次)", counter);
            }
            checkAndQuit();
        }
    });
}

__attribute__((constructor))
static void initialize() {
    WriteLog(@"===== ArtemisAutoQuit 诊断插件加载 =====");
    WriteLog(@"Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);
    WriteLog(@"App 名称: %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]);

    // 监听进入后台（游戏退出时通常触发）
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        WriteLog(@"📱 App 进入后台，启动黑屏检测...");
        // 进入后台后连续检测5次，每次间隔0.5秒
        for (int i = 0; i < 5; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                WriteLog(@"🔍 后台检测 #%d", i+1);
                checkAndQuit();
            });
        }
    }];

    // 监听前台激活（用于诊断）
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        WriteLog(@"📱 App 回到前台");
    }];

    // 启动定时检测（后备方案）
    startMonitoring();

    WriteLog(@"✅ 自动退出监控已启动（黑屏检测 + 后台通知 + 定时轮询）");
    WriteLog(@"📁 日志路径: %@/AutoQuit.log", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]);
}
