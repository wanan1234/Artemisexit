// =============================================================
//  ArtemisAutoQuit — 帧率检测最终版
//  功能：前台检测 CADisplayLink 回调，5秒无帧则退出
//  缓冲：启动后5秒内不检测
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

static CADisplayLink *displayLink = nil;
static NSTimeInterval lastTimestamp = 0;
static BOOL isMonitoring = NO;
static BOOL isInBackground = NO;
static BOOL shouldExit = NO;
static NSTimeInterval launchTime = 0;

// CADisplayLink 回调对象
@interface DisplayLinkTarget : NSObject
@end

@implementation DisplayLinkTarget
- (void)onFrame:(CADisplayLink *)sender {
    if (!isMonitoring) {
        isMonitoring = YES;
        WriteLog(@"✅ 帧监控已激活 (首次帧: %.3f)", sender.timestamp);
    }
    lastTimestamp = sender.timestamp;
}
@end

static DisplayLinkTarget *target = nil;

// 监控线程
static void monitorThread(void) {
    @autoreleasepool {
        while (1) {
            sleep(1);
            if (shouldExit) break;

            // 启动缓冲：前5秒不检测
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            if (now - launchTime < 5.0) {
                WriteLog(@"⏳ 启动缓冲中... (%.1f秒)", now - launchTime);
                continue;
            }

            // 后台不检测
            if (isInBackground) {
                WriteLog(@"⏸️ 后台模式，跳过检测");
                continue;
            }

            // 如果还未收到帧回调，继续等待
            if (!isMonitoring) {
                WriteLog(@"⏳ 等待首次帧回调...");
                continue;
            }

            // 检测帧间隔
            NSTimeInterval diff = now - lastTimestamp;
            WriteLog(@"⏱️ 距上次帧: %.2f秒", diff);
            if (diff > 5.0) {
                WriteLog(@"⚠️ 帧停止超过5秒，执行退出");
                shouldExit = YES;
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
    launchTime = [[NSDate date] timeIntervalSince1970];
    WriteLog(@"===== ArtemisAutoQuit 帧率检测最终版加载 =====");
    WriteLog(@"Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);

    // 主线程创建 CADisplayLink
    dispatch_async(dispatch_get_main_queue(), ^{
        target = [[DisplayLinkTarget alloc] init];
        displayLink = [CADisplayLink displayLinkWithTarget:target selector:@selector(onFrame:)];
        [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        WriteLog(@"✅ CADisplayLink 已创建");
    });

    // 监听前后台
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        isInBackground = YES;
        WriteLog(@"📱 进入后台，暂停检测");
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        isInBackground = NO;
        // 回到前台时重置计时器，避免因后台暂停导致误判
        lastTimestamp = [[NSDate date] timeIntervalSince1970];
        WriteLog(@"📱 回到前台，重置计时器");
    }];

    // 启动监控线程
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        monitorThread();
    });

    WriteLog(@"📁 日志路径: %@/AutoQuit.log", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]);
}
