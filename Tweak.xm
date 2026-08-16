// =============================================================
//  ArtemisAutoQuit — CADisplayLink 帧率监控版 v2
//  修复：初始化 lastFrameTime 为当前时间，允许 5 秒启动缓冲
//  兼容：处理应用前后台切换
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
static NSTimeInterval launchTime = 0;

// 使用 CADisplayLink 的回调方法
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
        // 给予 5 秒的启动缓冲
        dispatch_async(dispatch_get_main_queue(), ^{
            launchTime = [[NSDate date] timeIntervalSince1970];
            WriteLog(@"📌 启动缓冲开始，等待 CADisplayLink 回调...");
        });

        while (1) {
            sleep(1);
            if (shouldExit) break;

            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            
            // 如果应用进入后台，跳过检测
            if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
                WriteLog(@"⏸️ 应用在后台，跳过检测");
                continue;
            }

            // 如果还没有收到回调，检查是否超过 5 秒启动缓冲
            if (!isDisplayLinkActive) {
                if (now - launchTime > 5.0) {
                    WriteLog(@"⚠️ CADisplayLink 启动超时（5秒），可能引擎未正常启动，执行退出");
                    shouldExit = YES;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        WriteLog(@"🔄 调用 exit(0)");
                        exit(0);
                    });
                    break;
                }
                continue;
            }

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
    WriteLog(@"===== ArtemisAutoQuit CADisplayLink 监控版 v2 加载 =====");
    WriteLog(@"Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);

    // 初始化 lastFrameTime 为当前时间（用于首次检查）
    lastFrameTime = [[NSDate date] timeIntervalSince1970];
    launchTime = lastFrameTime;

    // 创建 CADisplayLink（在主线程）
    dispatch_async(dispatch_get_main_queue(), ^{
        target = [[DisplayLinkTarget alloc] init];
        displayLink = [CADisplayLink displayLinkWithTarget:target selector:@selector(onFrame:)];
        [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        WriteLog(@"✅ CADisplayLink 已创建并添加到主 RunLoop");
    });

    // 监听前后台切换
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        WriteLog(@"📱 应用进入后台，暂停检测");
    }];

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        // 回到前台时重置计时器
        lastFrameTime = [[NSDate date] timeIntervalSince1970];
        launchTime = lastFrameTime;
        isDisplayLinkActive = NO; // 强制等待新回调
        WriteLog(@"📱 应用回到前台，重置计时器");
    }];

    // 启动监控线程
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        monitorThread();
    });

    WriteLog(@"📁 日志路径: %@/AutoQuit.log", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]);
}
