// =============================================================
//  ArtemisAutoQuit — 窗口移除检测版
//  功能：当检测到主窗口 (keyWindow) 被移除时，自动退出 App
//  适用：Artemis 引擎游戏
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

static void monitorThread(void) {
    @autoreleasepool {
        while (1) {
            sleep(1);
            // 获取当前应用的主窗口
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            if (!keyWindow) {
                WriteLog(@"⚠️ 检测到主窗口 (keyWindow) 已被移除，执行退出");
                dispatch_async(dispatch_get_main_queue(), ^{
                    WriteLog(@"🔄 调用 exit(0)");
                    exit(0);
                });
                break;
            }
        }
    }
}

__attribute__((constructor))
static void initialize() {
    WriteLog(@"===== ArtemisAutoQuit 窗口移除检测版加载 =====");
    WriteLog(@"Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);

    // 启动监控线程
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        monitorThread();
    });

    WriteLog(@"📁 日志路径: %@/AutoQuit.log", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]);
}
