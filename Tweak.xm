// =============================================================
//  ArtemisAutoQuit — CADisplayLink 帧率监控版
//  功能：当 CADisplayLink 回调停止超过3秒，自动退出 App
//  适用：Artemis 引擎游戏
//  日志：详细记录启动、帧更新和超时检测
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
static NSTimeInterval lastFrameTime = 0;
static BOOL isDisplayLinkActive = NO;
static BOOL shouldExit = NO;

// CADisplayLink 回调
static void onFrame(CFRunLoopTimerRef timer, void *info) {
    // 这个方法不会被 CADisplayLink 使用，这里仅作为占位
}

// 使用 CADisplayLink 的回调方法（通过 NSObject 的 selector 方式）
@interface DisplayLinkTarget : NSObject
@end

@implementation DisplayLinkTarget
- (void)onFrame:(CADisplayLink *)sender {
    lastFrameTime = sender.timestamp;
    if (!isDisplayLinkActive) {
        isDisplayLinkActive = YES;
        WriteLog(@"✅ CADisplayLink 首次回调，帧率监控已激活");
    }
}
@end

static DisplayLinkTarget *target = nil;

// 监控线程
static void monitorThread(void) {
    @autoreleasepool {
        while (1) {
            sleep(1);
            if (shouldExit) break;

            if (!isDisplayLinkActive) {
                WriteLog(@"⏳ 等待 CADisplayLink 激活...");
                continue;
            }

            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            NSTimeInterval diff = now - lastFrameTime;
            WriteLog(@"⏱️ 距上次帧回调: %.2f 秒", diff);
            if (diff > 3.0) {
                WriteLog(@"⚠️ 帧回调停止超过3秒，执行退出");
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
    WriteLog(@"===== ArtemisAutoQuit CADisplayLink 监控版加载 =====");
    WriteLog(@"Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);

    // 创建 CADisplayLink（在主线程）
    dispatch_async(dispatch_get_main_queue(), ^{
        target = [[DisplayLinkTarget alloc] init];
        displayLink = [CADisplayLink displayLinkWithTarget:target selector:@selector(onFrame:)];
        [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        WriteLog(@"✅ CADisplayLink 已创建并添加到主 RunLoop");
    });

    // 启动监控线程
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        monitorThread();
    });

    WriteLog(@"📁 日志路径: %@/AutoQuit.log", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]);
}
