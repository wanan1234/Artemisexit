// =============================================================
//  ArtemisAutoQuit — 前台帧率检测版
//  功能：仅在前台检测渲染停止，后台暂停检测
//  适用：Artemis 引擎游戏
// =============================================================

#import <UIKit/UIKit.h>
#import <substrate.h>
#import <QuartzCore/QuartzCore.h>

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

static NSTimeInterval lastFrameTime = 0;
static BOOL isInBackground = NO;
static BOOL shouldExit = NO;
static CFRunLoopTimerRef timer = NULL;

static void onFrame(CFRunLoopTimerRef timer, void *info) {
    lastFrameTime = [[NSDate date] timeIntervalSince1970];
}

static void checkAndQuit(void) {
    if (isInBackground) {
        WriteLog(@"⏸️ 应用在后台，跳过检测");
        return;
    }
    if (shouldExit) return;

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval diff = now - lastFrameTime;
    WriteLog(@"⏱️ 帧间隔: %.2f 秒", diff);

    if (diff > 3.0) {
        WriteLog(@"⚠️ 渲染停止超过3秒，执行退出");
        shouldExit = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            WriteLog(@"🔄 调用 exit(0)");
            exit(0);
        });
    }
}

static void monitorThread(void) {
    @autoreleasepool {
        while (1) {
            sleep(1);
            checkAndQuit();
        }
    }
}

__attribute__((constructor))
static void initialize() {
    WriteLog(@"===== ArtemisAutoQuit 前台帧率检测版加载 =====");
    WriteLog(@"Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);

    // 创建帧定时器（主线程）
    dispatch_async(dispatch_get_main_queue(), ^{
        timer = CFRunLoopTimerCreate(NULL, CFAbsoluteTimeGetCurrent(), 1.0/60.0, 0, 0, onFrame, NULL);
        CFRunLoopAddTimer(CFRunLoopGetMain(), timer, kCFRunLoopCommonModes);
        WriteLog(@"✅ 帧监控启动");
    });

    // 监听前后台切换
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        isInBackground = YES;
        lastFrameTime = [[NSDate date] timeIntervalSince1970]; // 重置时间，防止刚返回前台时误判
        WriteLog(@"📱 应用进入后台，暂停检测");
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        isInBackground = NO;
        lastFrameTime = [[NSDate date] timeIntervalSince1970]; // 重置时间，给渲染一点缓冲
        WriteLog(@"📱 应用回到前台，恢复检测");
    }];

    // 启动监控线程
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        monitorThread();
    });

    WriteLog(@"📁 日志路径: %@/AutoQuit.log", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]);
}
