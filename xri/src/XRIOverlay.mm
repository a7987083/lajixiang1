#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "XRI.h"
#import "XRITrace.h"

namespace {
static UIColor *XColor(unsigned rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 255) / 255.0
                          green:((rgb >> 8) & 255) / 255.0
                           blue:(rgb & 255) / 255.0 alpha:1];
}
static UIButton *XButton(NSString *title, UIColor *bg, id target, SEL action) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.backgroundColor = bg;
    b.layer.cornerRadius = 9;
    b.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}
}

@interface XRIWindow : UIWindow
@end
@implementation XRIWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    // H5GG-style pass-through: only the floating button and panel are touchable.
    return (!hit || hit == self || hit == self.rootViewController.view) ? nil : hit;
}
@end

@interface XRIController : UIViewController <UITextFieldDelegate>
@property(nonatomic, strong) UIButton *bubble;
@property(nonatomic, strong) UIView *panel;
@property(nonatomic, strong) UILabel *status;
@property(nonatomic, strong) UILabel *stats;
@property(nonatomic, strong) UITextView *results;
@property(nonatomic, strong) UITextField *filter;
@property(nonatomic, strong) UISegmentedControl *category;
@property(nonatomic, strong) NSDictionary *snapshot;
@property(nonatomic, strong) NSData *rawSnapshot;
@property(nonatomic, strong) NSDictionary *traceSnapshot;
@property(nonatomic, strong) NSData *rawTrace;
@property(nonatomic, weak) UIWindow *priorKeyWindow;
@end

@implementation XRIController

- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = UIColor.clearColor;
    root.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.view = root;
}

- (UILabel *)label:(NSString *)title font:(CGFloat)size color:(UIColor *)color
            frame:(CGRect)frame parent:(UIView *)parent {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.text = title;
    label.font = [UIFont systemFontOfSize:size];
    label.textColor = color;
    [parent addSubview:label];
    return label;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.bubble = XButton(@"XRI", XColor(0x176A66), self, @selector(togglePanel));
    self.bubble.frame = CGRectMake(20, 90, 52, 52);
    self.bubble.layer.cornerRadius = 26;
    self.bubble.layer.borderColor = XColor(0x70DEC9).CGColor;
    self.bubble.layer.borderWidth = 1.5;
    [self.bubble addGestureRecognizer:[[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(moveBubble:)]];
    [self.view addSubview:self.bubble];

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(18, 158, 340, 454)];
    self.panel = panel;
    panel.backgroundColor = XColor(0x131A25);
    panel.layer.cornerRadius = 16;
    panel.layer.borderWidth = 1;
    panel.layer.borderColor = XColor(0x35465A).CGColor;
    panel.clipsToBounds = YES;
    panel.hidden = YES;
    [self.view addSubview:panel];

    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 340, 56)];
    header.backgroundColor = XColor(0x202C3A);
    [panel addSubview:header];
    [self label:@"◉  XLua Inspector" font:17 color:XColor(0xE6F8F5)
          frame:CGRectMake(16, 9, 245, 24) parent:header];
    [self label:@"P1 · READ-ONLY" font:10 color:XColor(0x70DEC9)
          frame:CGRectMake(17, 34, 180, 14) parent:header];
    UIButton *close = XButton(@"×", XColor(0x334353), self, @selector(togglePanel));
    close.frame = CGRectMake(300, 12, 27, 27);
    [header addSubview:close];
    UIButton *traceButton = XButton(@"跟踪", XColor(0x237E72), self, @selector(toggleTrace));
    traceButton.frame = CGRectMake(239, 12, 56, 27);
    [header addSubview:traceButton];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(movePanel:)];
    [header addGestureRecognizer:pan];

    [self label:@"ARM64       LUA          IL2CPP" font:11 color:XColor(0x8CA5B8)
          frame:CGRectMake(16, 67, 305, 18) parent:panel];
    self.stats = [self label:@"镜像 —   Lua API —   IL2CPP API —" font:12
                        color:XColor(0x70DEC9) frame:CGRectMake(16, 93, 310, 22) parent:panel];
    self.status = [self label:@"状态：等待扫描" font:12
                         color:XColor(0xB6C5D2) frame:CGRectMake(16, 118, 313, 22) parent:panel];

    self.filter = [[UITextField alloc] initWithFrame:CGRectMake(16, 152, 308, 36)];
    self.filter.backgroundColor = XColor(0x243143);
    self.filter.textColor = UIColor.whiteColor;
    self.filter.font = [UIFont systemFontOfSize:13];
    self.filter.placeholder = @"搜索导出符号 / 镜像名称";
    self.filter.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:self.filter.placeholder attributes:@{
        NSForegroundColorAttributeName:XColor(0xA9B8C6)}];
    self.filter.layer.cornerRadius = 9;
    self.filter.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)];
    self.filter.leftViewMode = UITextFieldViewModeAlways;
    self.filter.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.filter.returnKeyType = UIReturnKeyDone;
    self.filter.delegate = self;
    [self.filter addTarget:self action:@selector(renderResults)
          forControlEvents:UIControlEventEditingChanged];
    [panel addSubview:self.filter];

    self.category = [[UISegmentedControl alloc] initWithItems:@[@"全部", @"Lua", @"IL2CPP", @"镜像", @"跟踪"]];
    self.category.frame = CGRectMake(16, 197, 308, 31);
    self.category.selectedSegmentIndex = 0;
    [self.category addTarget:self action:@selector(renderResults)
           forControlEvents:UIControlEventValueChanged];
    [panel addSubview:self.category];

    self.results = [[UITextView alloc] initWithFrame:CGRectMake(16, 239, 308, 151)];
    self.results.backgroundColor = XColor(0x1D2836);
    self.results.textColor = XColor(0xDBE8F1);
    self.results.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.results.layer.cornerRadius = 9;
    self.results.editable = NO;
    self.results.selectable = YES;
    self.results.text = @"点击「扫描」读取 P1 镜像与导出信息。";
    [panel addSubview:self.results];

    UIButton *scan = XButton(@"扫描", XColor(0x237E72), self, @selector(scan));
    scan.frame = CGRectMake(16, 401, 96, 37);
    [panel addSubview:scan];
    UIButton *copy = XButton(@"复制结果", XColor(0x33485E), self, @selector(copyJSON));
    copy.frame = CGRectMake(122, 401, 96, 37);
    [panel addSubview:copy];
    UIButton *save = XButton(@"导出 JSON", XColor(0x33485E), self, @selector(exportJSON));
    save.frame = CGRectMake(228, 401, 96, 37);
    [panel addSubview:save];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect bounds = self.view.bounds;
    if (CGRectIsEmpty(bounds)) return;
    CGFloat bX = MIN(MAX(CGRectGetMinX(self.bubble.frame), 0), MAX(0, bounds.size.width - 52));
    CGFloat bY = MIN(MAX(CGRectGetMinY(self.bubble.frame), 0), MAX(0, bounds.size.height - 52));
    self.bubble.frame = CGRectMake(bX, bY, 52, 52);
    CGRect frame = self.panel.frame;
    frame.size.width = MIN(340, MAX(0, bounds.size.width - 16));
    frame.size.height = MIN(454, MAX(0, bounds.size.height - 20));
    frame.origin.x = MIN(MAX(frame.origin.x, 0), MAX(0, bounds.size.width - frame.size.width));
    frame.origin.y = MIN(MAX(frame.origin.y, 0), MAX(0, bounds.size.height - frame.size.height));
    self.panel.frame = frame;
    // Preserve 340-pt design on phones; narrow screens scroll horizontally only if required.
    self.panel.transform = CGAffineTransformIdentity;
    CGFloat scale = MIN(1.0, MIN(frame.size.width / 340.0, frame.size.height / 454.0));
    // Scale contents as a unit, keeping a fully touchable panel.
    if (scale < 1) {
        self.panel.bounds = CGRectMake(0, 0, 340, 454);
        self.panel.transform = CGAffineTransformMakeScale(scale, scale);
        CGRect f = self.panel.frame;
        f.origin.x = MIN(MAX(f.origin.x, 0), MAX(0, bounds.size.width - f.size.width));
        f.origin.y = MIN(MAX(f.origin.y, 0), MAX(0, bounds.size.height - f.size.height));
        self.panel.frame = f;
    }
}

- (void)togglePanel {
    self.panel.hidden = !self.panel.hidden;
    if (!self.panel.hidden && !self.snapshot) [self scan];
    [self.view bringSubviewToFront:self.bubble];
}

- (void)moveBubble:(UIPanGestureRecognizer *)gesture {
    CGPoint t = [gesture translationInView:self.view];
    self.bubble.center = CGPointMake(self.bubble.center.x + t.x, self.bubble.center.y + t.y);
    [gesture setTranslation:CGPointZero inView:self.view];
    [self.view setNeedsLayout];
}
- (void)movePanel:(UIPanGestureRecognizer *)gesture {
    CGPoint t = [gesture translationInView:self.view];
    self.panel.center = CGPointMake(self.panel.center.x + t.x, self.panel.center.y + t.y);
    [gesture setTranslation:CGPointZero inView:self.view];
    [self.view setNeedsLayout];
}

- (void)toggleTrace {
    NSDictionary *old = [self traceInfo];
    if ([old[@"recording"] boolValue]) {
        xri_trace_stop();
    } else {
        xri_trace_start();
    }
    self.category.selectedSegmentIndex = 4;
    [self renderResults];
}

- (NSDictionary *)traceInfo {
    size_t n = xri_trace_snapshot_json(NULL, 0);
    if (n == 0 || n > (4u << 20)) return @{};
    NSMutableData *bytes = [NSMutableData dataWithLength:n];
    if (!bytes || xri_trace_snapshot_json((char *)bytes.mutableBytes, n) != n) return @{};
    NSData *json = [bytes subdataWithRange:NSMakeRange(0, n - 1)];
    NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:json options:0 error:NULL];
    if (![parsed isKindOfClass:NSDictionary.class]) return @{};
    self.traceSnapshot = parsed;
    self.rawTrace = json;
    return parsed;
}

- (void)scan {
    size_t needed = xri_snapshot_json(NULL, 0);
    if (!needed || needed > (4u << 20)) {
        self.status.text = @"状态：快照长度异常";
        return;
    }
    NSMutableData *data = [NSMutableData dataWithLength:needed];
    if (!data || xri_snapshot_json((char *)data.mutableBytes, needed) != needed) {
        self.status.text = @"状态：扫描失败";
        return;
    }
    NSData *jsonData = [data subdataWithRange:NSMakeRange(0, needed - 1)];
    NSError *error = nil;
    NSDictionary *snapshot = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (![snapshot isKindOfClass:NSDictionary.class]) {
        self.status.text = @"状态：JSON 解码失败";
        return;
    }
    self.rawSnapshot = jsonData;
    self.snapshot = snapshot;
    NSArray *images = snapshot[@"images"];
    NSArray *symbols = snapshot[@"exports"];
    NSUInteger found = 0;
    for (NSDictionary *s in symbols) if ([s[@"found"] boolValue]) ++found;
    NSDictionary *detected = snapshot[@"detected"];
    self.stats.text = [NSString stringWithFormat:@"镜像 %lu   Lua %@   IL2CPP %@",
        (unsigned long)images.count,
        [detected[@"lua"] boolValue] ? @"✓" : @"—",
        [detected[@"il2cpp"] boolValue] ? @"✓" : @"—"];
    self.status.text = [NSString stringWithFormat:@"状态：扫描完成 · %lu 个可见导出", (unsigned long)found];
    [self renderResults];
}

- (void)renderResults {
    if (self.category.selectedSegmentIndex == 4) {
        NSDictionary *trace = [self traceInfo];
        NSArray *chunks = trace[@"chunks"] ?: @[];
        NSArray *states = trace[@"states"] ?: @[];
        NSMutableArray<NSString *> *lines = [NSMutableArray array];
        [lines addObject:[NSString stringWithFormat:@"P2: %@\n%@\nVM 事件 %lu · Chunk %lu",
            [trace[@"recording"] boolValue] ? @"记录中" : @"未记录",
            trace[@"reason"] ?: @"状态不可用", (unsigned long)states.count, (unsigned long)chunks.count]];
        for (NSDictionary *e in states) [lines addObject:[NSString stringWithFormat:@"[VM] %@ %@",e[@"action"],e[@"state"]]];
        for (NSDictionary *e in chunks) [lines addObject:[NSString stringWithFormat:@"[CHUNK] %@ (%@ bytes)\n%@ result=%@",e[@"name"],e[@"size"],e[@"source"],e[@"result"]]];
        self.results.text = [lines componentsJoinedByString:@"\n\n"];
        self.status.text = [trace[@"recording"] boolValue] ? @"状态：Lua 采集中" : @"状态：Lua 未采集";
        return;
    }
    if (!self.snapshot) return;
    NSString *query = self.filter.text.lowercaseString ?: @"";
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    NSInteger category = self.category.selectedSegmentIndex;
    if (category == 0 || category == 3) {
        for (NSDictionary *image in self.snapshot[@"images"]) {
            NSString *path = image[@"path"] ?: @"";
            if (query.length && [path.lowercaseString rangeOfString:query].location == NSNotFound) continue;
            [lines addObject:[NSString stringWithFormat:@"[IMAGE] %@\nUUID %@\nslide %@",
                path.lastPathComponent, image[@"uuid"] ?: @"—", image[@"slide"] ?: @"—"]];
        }
    }
    if (category != 3) {
        for (NSDictionary *s in self.snapshot[@"exports"]) {
            NSString *name = s[@"name"] ?: @"";
            if (category == 1 && ![name hasPrefix:@"lua"] && ![name hasPrefix:@"xlua"]) continue;
            if (category == 2 && ![name hasPrefix:@"il2cpp_"]) continue;
            if (query.length && [name.lowercaseString rangeOfString:query].location == NSNotFound) continue;
            [lines addObject:[NSString stringWithFormat:@"%@ %@ %@",
                [s[@"found"] boolValue] ? @"✓" : @"·", name,
                s[@"loadRelativeOffset"] ?: @"not exported"]];
        }
    }
    self.results.text = lines.count ? [lines componentsJoinedByString:@"\n\n"] : @"没有匹配结果（未导出不代表不存在）。";
}

- (void)copyJSON {
    NSData *source = self.category.selectedSegmentIndex == 4 ? ([self traceInfo], self.rawTrace) : self.rawSnapshot;
    if (!source) { self.status.text = @"状态：请先扫描"; return; }
    NSString *json = [[NSString alloc] initWithData:source encoding:NSUTF8StringEncoding];
    if (!json) { self.status.text = @"状态：文本转换失败"; return; }
    UIPasteboard.generalPasteboard.string = json;
    self.status.text = @"状态：JSON 已复制";
}

- (void)exportJSON {
    NSData *source = self.category.selectedSegmentIndex == 4 ? ([self traceInfo], self.rawTrace) : self.rawSnapshot;
    if (!source) { self.status.text = @"状态：请先扫描"; return; }
    NSString *directory = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    if (!directory) { self.status.text = @"状态：缓存目录不可用"; return; }
    NSString *name = [NSString stringWithFormat:@"xri-snapshot-%lld.json",
                      (long long)[NSDate.date timeIntervalSince1970]];
    NSString *path = [directory stringByAppendingPathComponent:name];
    NSError *error = nil;
    if ([source writeToFile:path options:NSDataWritingAtomic error:&error]) {
        self.status.text = @"状态：已保存到 App/Caches";
    } else {
        self.status.text = @"状态：JSON 写入失败";
    }
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    UIWindow *window = self.view.window;
    UIWindow *current = nil;
    for (UIWindow *candidate in UIApplication.sharedApplication.windows) {
        if (candidate.isKeyWindow && candidate != window) { current = candidate; break; }
    }
    self.priorKeyWindow = current;
    [window makeKeyWindow];
    return YES;
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}
- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self.priorKeyWindow makeKeyWindow];
    self.priorKeyWindow = nil;
}
@end

@interface XRIOverlayHost : NSObject
@property(nonatomic, strong) XRIWindow *window;
@property(nonatomic, strong) XRIController *controller;
+ (instancetype)shared;
- (void)installIfPossible;
@end
@implementation XRIOverlayHost
+ (instancetype)shared {
    static XRIOverlayHost *host = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ host = [XRIOverlayHost new]; });
    return host;
}
- (void)installIfPossible {
    NSAssert(NSThread.isMainThread, @"XRI UIKit setup must run on main thread");
    if (self.window || !UIApplication.sharedApplication) return;
    UIWindow *window = nil;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *best = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                best = (UIWindowScene *)scene;
                break;
            }
        }
        if (!best) return;
        window = [[XRIWindow alloc] initWithWindowScene:best];
    } else {
        window = [[XRIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    }
    self.controller = [XRIController new];
    window.rootViewController = self.controller;
    window.backgroundColor = UIColor.clearColor;
    window.windowLevel = UIWindowLevelAlert - 2;
    window.hidden = NO; // Never makeKeyAndVisible: preserve game's key window.
    self.window = (XRIWindow *)window;
}
@end

__attribute__((constructor))
static void xri_overlay_init(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
            object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *notification) {
                [[XRIOverlayHost shared] installIfPossible];
            }];
        [[XRIOverlayHost shared] installIfPossible];
    });
}
