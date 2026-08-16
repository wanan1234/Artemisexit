#import <UIKit/UIKit.h>
#import <substrate.h>
#import <dlfcn.h>
#import <stdarg.h>

// 日志函数
static void WriteLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *logPath = [[paths firstObject] stringByAppendingPathComponent:@"AutoQuit.log"];
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

static void (*orig_loop)(void);

static void my_loop(void) {
    if (orig_loop) orig_loop();
    static BOOL first = YES;
    if (first) {
        WriteLog(@"进入主循环监控");
        first = NO;
    }
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (keyWindow && !keyWindow.rootViewController) {
        WriteLog(@"⚠️ keyWindow 存在但 rootViewController 为空，可能引擎已退出");
    }
}

__attribute__((constructor)) static void initialize() {
    WriteLog(@"===== Artemis诊断插件加载 =====");
    WriteLog(@"App: %@", [[NSBundle mainBundle] bundleIdentifier]);
    void *handle = dlopen(NULL, RTLD_LAZY);
    void *sym = dlsym(handle, "_ZN2cocos2d9Director5loopEv");
    if (!sym) sym = dlsym(handle, "_UnityPlayerLoop");
    if (sym) {
        WriteLog(@"找到符号，开始Hook");
        MSHookFunction(sym, (void *)my_loop, (void **)&orig_loop);
        WriteLog(@"Hook成功");
    } else {
        WriteLog(@"未找到引擎循环符号");
    }
    dlclose(handle);
    WriteLog(@"初始化完成，日志写入: %@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]);
}
