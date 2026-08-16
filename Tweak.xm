// =============================================================
//  ArtemisAutoQuit — 子视图数量监控版
//  原理：检测 keyWindow 的子视图数量，如果突然减少到 < 2，说明游戏已退出
//  适用：Artemis 引擎游戏（如 NinNinDays）
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

static NSUInteger lastSubviewCount = 0;
static BOOL isFirstCheck = YES;

static void checkWindowSubviews(void) {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) {
        WriteLog(@"⚠️ keyWindow 为 nil，执行退出");
        dispatch_async(dispatch_get_main_queue(), ^{
            exit(0);
        });
        return;
    }

    NSUInteger count = keyWindow.subviews.count;
    if (isFirstCheck) {
        lastSubviewCount = count;
        isFirstCheck = NO;
        WriteLog(@"📊 初始子视图数量: %lu", (unsigned long)count);
        return;
    }

    // 如果子视图数量突然减少到 < 2（引擎主视图被移除），判定为退出
    if (count < 2 && lastSubviewCount > 2) {
        WriteLog(@"⚠️ 子视图数量从 %lu 骤减到 %lu，游戏已退出", (unsigned long)lastSubviewCount, (unsigned long)count);
        dispatch_async(dispatch_get_main_queue(), ^{
            WriteLog(@"🔄 执行 exit(0)");
            exit(0);
        });
    }

    // 如果子视图数量变为 0（异常）
    if (count == 0) {
        WriteLog(@"⚠️ 子视图数量为 0，执行退出");
        dispatch_async(dispatch_get_main_queue(), ^{
            exit(0);
        });
    }

    lastSubviewCount = count;
}

static void monitorThread(void) {
    @autoreleasepool {
        while (1) {
            sleep(1); // 每秒检查一次
            dispatch_async(dispatch_get_main_queue(), ^{
                checkWindowSubviews();
            });
        }
    }
}

__attribute__((constructor))
static void initialize() {
    WriteLog(@"===== ArtemisAutoQuit 子视图监控版加载 =====");
    WriteLog(@"Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);

    // 延迟 1 秒后开始监控，确保窗口已初始化
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (keyWindow) {
            lastSubviewCount = keyWindow.subviews.count;
            isFirstCheck = NO;
            WriteLog(@"📊 初始子视图数量: %lu", (unsigned long)lastSubviewCount);
        }
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        monitorThread();
    });

    WriteLog(@"📁 日志路径: %@/AutoQuit.log", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]);
}
