// =============================================================
//  ArtemisAutoQuit — 按钮点击检测版（纯净版）
//  功能：仅检测“退出”按钮点击，点击后自动关闭App
//  不会误判，只在按钮被点击时触发
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

// 仅Hook UIControl 的 sendAction:to:forEvent:
%hook UIControl
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    %orig;
    
    // 只检查按钮
    if ([self isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)self;
        NSString *title = [btn titleForState:UIControlStateNormal];
        if (title) {
            // 检查是否包含退出关键词（支持中文、日文、英文）
            NSArray *keywords = @[@"退出", @"終了", @"Quit", @"Exit", @"終わる", @"閉じる"];
            for (NSString *kw in keywords) {
                if ([title rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    WriteLog(@"👆 检测到退出按钮被点击: %@", title);
                    // 延迟0.5秒，让游戏完成必要的清理
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        WriteLog(@"🔄 执行 exit(0) 关闭 App");
                        exit(0);
                    });
                    break;
                }
            }
        }
    }
}
%end

__attribute__((constructor))
static void initialize() {
    WriteLog(@"===== ArtemisAutoQuit 按钮检测版加载 =====");
    WriteLog(@"Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);
    WriteLog(@"📁 日志路径: %@/AutoQuit.log", [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]);
    WriteLog(@"✅ 已安装按钮点击检测，将监控包含'退出/終了/Quit/Exit'的按钮");
}
