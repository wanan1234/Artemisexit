// =============================================================
//  ArtemisDiagnose — 诊断插件
//  纯 MSHookFunction，无需 fishhook
// =============================================================

#import <UIKit/UIKit.h>
#import <substrate.h>
#import <dlfcn.h>   // 添加缺少的头文件

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

// 原始函数指针
static void (*orig_loop)(void);

// 自定义循环监控
static void my_loop(void) {
    if (orig_loop) orig_loop();

    static int count = 0;
    count++;
    if (count % 30 == 0) {  // 每30帧检查一次
        UIWindow *mainWindow = [UIApplication sharedApplication].windows.firstObject;
        if (mainWindow && !mainWindow.rootViewController) {
            WriteLog(@"⚠️ 检测到 rootViewController 为空，可能已退出");
        }
        WriteLog(@"心跳: 循环仍在运行 (帧数: %d)", count);
    }
}

// 构造函数
__attribute__((constructor))
static void initialize() {
    WriteLog(@"===== Artemis 诊断插件加载 =====");
    WriteLog(@"Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);

    // 尝试 Hook Cocos2d-x 主循环
    void *handle = dlopen(NULL, RTLD_LAZY);
    if (handle) {
        void *sym = dlsym(handle, "_ZN2cocos2d9Director5loopEv");
        if (sym) {
            WriteLog(@"找到 Cocos2d-x 主循环，开始 Hook");
            MSHookFunction(sym, (void *)my_loop, (void **)&orig_loop);
            WriteLog(@"Hook 成功");
        } else {
            WriteLog(@"未找到 Cocos2d-x 主循环，尝试 Unity...");
            sym = dlsym(handle, "_UnityPlayerLoop");
            if (sym) {
                WriteLog(@"找到 Unity 主循环，开始 Hook");
                MSHookFunction(sym, (void *)my_loop, (void **)&orig_loop);
                WriteLog(@"Hook 成功");
            } else {
                WriteLog(@"未找到任何引擎主循环，仅监控窗口状态");
                // 即使没有 Hook，也启动定时监控
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    while (1) {
                        sleep(2);
                        UIWindow *mainWindow = [UIApplication sharedApplication].windows.firstObject;
                        if (mainWindow && !mainWindow.rootViewController) {
                            WriteLog(@"⚠️ 窗口存在但 rootViewController 为空 (定时检测)");
                        }
                    }
                });
            }
        }
        dlclose(handle);
    } else {
        WriteLog(@"dlopen 失败，启动定时监控");
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            while (1) {
                sleep(2);
                UIWindow *mainWindow = [UIApplication sharedApplication].windows.firstObject;
                if (mainWindow && !mainWindow.rootViewController) {
                    WriteLog(@"⚠️ 窗口存在但 rootViewController 为空 (定时检测)");
                }
            }
        });
    }

    WriteLog(@"诊断插件初始化完成");
    WriteLog(@"日志路径: %@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]);
}
