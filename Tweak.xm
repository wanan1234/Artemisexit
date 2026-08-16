// =============================================================
//  ArtemisAutoQuit — 组合检测版
//  原理：同时监控 rootViewController 变化 + exit() 调用 + 按钮点击
//  不会误退，只在游戏真正退出时触发
// =============================================================

#import <UIKit/UIKit.h>
#import <substrate.h>
#import <dlfcn.h>

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

// ---------- 方法1：Hook exit() 函数 ----------
static void (*orig_exit)(int status);

static void my_exit(int status) {
    WriteLog(@"⚠️ 检测到 exit(%d) 被调用，游戏正在退出", status);
    // 不阻塞原始退出，只记录并确保App关闭
    // 由于 exit() 本身就会终止进程，我们不需要额外操作
    if (orig_exit) {
        orig_exit(status);
    }
}

// ---------- 方法2：监控 rootViewController 变化 ----------
static UIViewController *lastRootVC = nil;
static void monitorRootViewController(void) {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) return;
    
    UIViewController *currentRootVC = keyWindow.rootViewController;
    
    // 如果 rootViewController 从 AppController 变成了其他东西（或nil）
    // 且变化后不再是 AppController，说明游戏已退出
    if (lastRootVC && currentRootVC != lastRootVC) {
        NSString *lastClass = NSStringFromClass([lastRootVC class]);
        NSString *currentClass = currentRootVC ? NSStringFromClass([currentRootVC class]) : @"nil";
        
        // 如果之前的 rootVC 是 AppController，现在不是了 -> 游戏退出
        if ([lastClass isEqualToString:@"AppController"] && 
            ![currentClass isEqualToString:@"AppController"]) {
            WriteLog(@"⚠️ rootViewController 从 %@ 变为 %@，游戏已退出", lastClass, currentClass);
            dispatch_async(dispatch_get_main_queue(), ^{
                WriteLog(@"🔄 执行 exit(0) 关闭 App");
                exit(0);
            });
        }
    }
    lastRootVC = currentRootVC;
}

// ---------- 方法3：Hook UIButton 点击（检测“退出”按钮） ----------
%hook UIControl
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    %orig;
    
    // 检查是否点击了“退出”相关的按钮
    if ([self isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)self;
        NSString *title = [btn titleForState:UIControlStateNormal];
        if (title && ([title rangeOfString:@"退出"].location != NSNotFound ||
                      [title rangeOfString:@"終了"].location != NSNotFound ||
                      [title rangeOfString:@"Quit"].location != NSNotFound ||
                      [title rangeOfString:@"Exit"].location != NSNotFound)) {
            WriteLog(@"👆 检测到退出按钮被点击: %@", title);
            // 延迟一点点，让引擎完成清理，然后退出
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                WriteLog(@"🔄 执行 exit(0) 关闭 App");
                exit(0);
            });
        }
    }
}
%end

// ---------- 定时监控线程 ----------
static void monitorThread(void) {
    @autoreleasepool {
        while (1) {
            sleep(2);
            monitorRootViewController();
        }
    }
}

// ---------- 初始化 ----------
__attribute__((constructor))
static void initialize() {
    WriteLog(@"===== ArtemisAutoQuit 组合检测版加载 =====");
    WriteLog(@"Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);
    
    // 1. Hook exit() 函数
    void *handle = dlopen(NULL, RTLD_LAZY);
    if (handle) {
        void *exit_sym = dlsym(handle, "exit");
        if (exit_sym) {
            MSHookFunction(exit_sym, (void *)my_exit, (void **)&orig_exit);
            WriteLog(@"✅ exit() Hook 成功");
        } else {
            WriteLog(@"❌ exit() Hook 失败");
        }
        dlclose(handle);
    }
    
    // 2. 初始化 rootViewController 监控
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (keyWindow) {
            lastRootVC = keyWindow.rootViewController;
            WriteLog(@"✅ 初始 rootViewController: %@", NSStringFromClass([lastRootVC class]));
        }
    });
    
    // 3. 启动监控线程
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        monitorThread();
    });
    
    WriteLog(@"📁 日志路径: %@/AutoQuit.log", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]);
}
