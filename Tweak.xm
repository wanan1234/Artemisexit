// =============================================================
//  ArtemisAutoQuit — 诊断版
//  功能：记录黑屏时的窗口层次，不自动退出
//  日志：打印所有 windows 和 rootViewController
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
    NSLog(@"[ArtemisDiag] %@", msg);
}

static void dumpWindowState(void) {
    NSArray *windows = [UIApplication sharedApplication].windows;
    WriteLog(@"📱 当前 windows 数量: %lu", (unsigned long)windows.count);
    for (NSInteger i = 0; i < windows.count; i++) {
        UIWindow *win = windows[i];
        WriteLog(@"  Window[%ld]: frame=%@, hidden=%d, rootVC=%@, subviews=%lu",
                 (long)i,
                 NSStringFromCGRect(win.frame),
                 win.hidden,
                 win.rootViewController,
                 (unsigned long)win.subviews.count);
        if (win.rootViewController) {
            WriteLog(@"    rootVC class: %@", NSStringFromClass([win.rootViewController class]));
        }
        for (UIView *sub in win.subviews) {
            WriteLog(@"    ├─ %@ frame=%@ hidden=%d alpha=%.2f",
                     NSStringFromClass([sub class]),
                     NSStringFromCGRect(sub.frame),
                     sub.hidden,
                     sub.alpha);
        }
    }
}

// 定时检测（每10秒打印一次状态）
static void startMonitoring(void) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (1) {
            sleep(10);
            WriteLog(@"⏱️ 定时窗口状态 (10秒)");
            dumpWindowState();
        }
    });
}

// 监听后台事件
static void observeNotifications(void) {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        WriteLog(@"📱 App 进入后台，2秒后打印窗口状态...");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            dumpWindowState();
        });
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        WriteLog(@"📱 App 即将失去焦点 (WillResignActive)");
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        WriteLog(@"📱 App 回到前台 (DidBecomeActive)");
    }];
}

__attribute__((constructor))
static void initialize() {
    WriteLog(@"===== ArtemisAutoQuit 诊断版加载 =====");
    WriteLog(@"Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);
    WriteLog(@"App 名称: %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]);
    WriteLog(@"📁 日志路径: %@/AutoQuit.log", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]);

    // 初始状态
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        WriteLog(@"=== 初始窗口状态 ===");
        dumpWindowState();
    });

    observeNotifications();
    startMonitoring();

    WriteLog(@"✅ 诊断版启动，每10秒记录一次窗口状态，请点击退出游戏后等待10秒，然后提供日志。");
}
