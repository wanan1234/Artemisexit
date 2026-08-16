// =============================================================
//  ArtemisDiagnose — 诊断插件
//  功能：监测引擎退出事件，记录日志到沙盒
//  适用：Artemis 引擎游戏（基于 Cocos2d-x / Unity）
//  注入方式：TrollFools
// =============================================================

#import <UIKit/UIKit.h>
#import <substrate.h>
#import <dlfcn.h>
#import <stdarg.h>

// ---------- 日志写入沙盒 ----------
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

// ---------- 保存原始函数指针 ----------
static void (*orig_cocos_loop)(void);
static void (*orig_unity_loop)(void);

// ---------- 自定义 Cocos2d-x 循环 ----------
static void my_cocos_loop(void) {
    // 调用原始循环
    if (orig_cocos_loop) orig_cocos_loop();
    
    // 检测游戏状态（示例：检查窗口是否还在）
    static BOOL firstCheck = YES;
    if (firstCheck) {
        WriteLog(@"进入 Cocos 循环监控");
        firstCheck = NO;
    }
    
    // 检查 keyWindow 和 rootViewController
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (keyWindow && !keyWindow.rootViewController) {
        WriteLog(@"⚠️ 检测到 keyWindow 存在但 rootViewController 为空 —— 可能引擎已退出");
    }
    // 可增加更多检查，如游戏主场景是否已被释放等
}

// ---------- 自定义 Unity 循环 ----------
static void my_unity_loop(void) {
    if (orig_unity_loop) orig_unity_loop();
    // Unity 的检测方式类似，可查看 UnityAppController 等
    static BOOL firstUnity = YES;
    if (firstUnity) {
        WriteLog(@"进入 Unity 循环监控");
        firstUnity = NO;
    }
    // 检测 Unity 是否正在退出（通过 UnityAppController 的 applicationWillTerminate 等）
}

// ---------- 初始化 ----------
__attribute__((constructor))
static void initialize() {
    WriteLog(@"===== Artemis 诊断插件加载 =====");
    WriteLog(@"设备: %@", [[UIDevice currentDevice] model]);
    WriteLog(@"系统: %@ %@", [[UIDevice currentDevice] systemName], [[UIDevice currentDevice] systemVersion]);
    WriteLog(@"App: %@", [[NSBundle mainBundle] bundleIdentifier]);
    
    // 尝试 Hook Cocos2d-x 主循环符号
    void *handle = dlopen(NULL, RTLD_LAZY);
    if (!handle) {
        WriteLog(@"❌ dlopen 失败: %s", dlerror());
        return;
    }
    
    void *cocos_sym = dlsym(handle, "_ZN2cocos2d9Director5loopEv");
    void *unity_sym = dlsym(handle, "_UnityPlayerLoop");
    
    if (cocos_sym) {
        WriteLog(@"✅ 找到 Cocos2d-x 主循环符号，开始 Hook");
        MSHookFunction(cocos_sym, (void *)my_cocos_loop, (void **)&orig_cocos_loop);
        WriteLog(@"Hook Cocos 循环成功");
    } else if (unity_sym) {
        WriteLog(@"✅ 找到 Unity 主循环符号，开始 Hook");
        MSHookFunction(unity_sym, (void *)my_unity_loop, (void **)&orig_unity_loop);
        WriteLog(@"Hook Unity 循环成功");
    } else {
        WriteLog(@"❌ 未找到 Cocos2d-x 或 Unity 主循环符号，尝试其他 Artemis 特定符号...");
        // 可在此添加 Artemis 引擎特有符号
    }
    
    dlclose(handle);
    
    // 额外监听 App 生命周期
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        WriteLog(@"📱 App 进入后台");
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        WriteLog(@"📱 App 即将终止（系统正常退出）");
    }];
    
    WriteLog(@"初始化完成，日志将写入: %@", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]);
}
