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
@property(nonatomic, strong) UISegmentedControl *resourceKind;
@property(nonatomic, strong) UIButton *scanButton;
@property(nonatomic, strong) UIButton *secondaryButton;
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
    [self label:@"P3.2 · WRAPPER REGISTRATION · READ-ONLY" font:10 color:XColor(0x70DEC9)
          frame:CGRectMake(17, 34, 180, 14) parent:header];
    UIButton *close = XButton(@"×", XColor(0x334353), self, @selector(togglePanel));
    close.frame = CGRectMake(300, 12, 27, 27);
    [header addSubview:close];
    [self label:@"AUTO" font:12 color:XColor(0x70DEC9)
          frame:CGRectMake(245, 12, 52, 27) parent:header];
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
    [self.category addTarget:self action:@selector(updateCategory)
           forControlEvents:UIControlEventValueChanged];
    [panel addSubview:self.category];

    self.resourceKind = [[UISegmentedControl alloc] initWithItems:
                         @[@"钻石", @"金币", @"体力", @"对照"]];
    self.resourceKind.frame = CGRectMake(16, 234, 308, 30);
    self.resourceKind.selectedSegmentIndex = 0;
    self.resourceKind.hidden = YES;
    [panel addSubview:self.resourceKind];

    self.results = [[UITextView alloc] initWithFrame:CGRectMake(16, 239, 308, 151)];
    self.results.backgroundColor = XColor(0x1D2836);
    self.results.textColor = XColor(0xDBE8F1);
    self.results.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    self.results.layer.cornerRadius = 9;
    self.results.editable = NO;
    self.results.selectable = YES;
    self.results.text = @"自动跟踪已启用。点击「扫描」读取镜像与导出信息。";
    [panel addSubview:self.results];

    UIButton *scan = XButton(@"扫描", XColor(0x237E72), self, @selector(scanOrBegin));
    scan.frame = CGRectMake(16, 401, 96, 37);
    [panel addSubview:scan];
    UIButton *copy = XButton(@"复制结果", XColor(0x33485E), self, @selector(copyOrEnd));
    copy.frame = CGRectMake(122, 401, 96, 37);
    [panel addSubview:copy];
    self.scanButton = scan;
    self.secondaryButton = copy;
    UIButton *save = XButton(@"导出 JSON", XColor(0x33485E), self, @selector(exportJSON));
    save.frame = CGRectMake(228, 401, 96, 37);
    [panel addSubview:save];
    [self updateCategory];
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
    if (!self.panel.hidden && self.category.selectedSegmentIndex == 4) [self renderResults];
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

- (NSDictionary *)traceInfo {
    // Event collection continues concurrently; size can grow between ABI calls.
    // Retry bounded snapshots instead of treating normal growth as a fault.
    for (NSUInteger attempt = 0; attempt < 5; ++attempt) {
        size_t n = xri_trace_snapshot_json(NULL, 0);
        if (n == 0 || n > (4u << 20)) return @{};
        NSMutableData *bytes = [NSMutableData dataWithLength:n];
        if (!bytes) return @{};
        size_t actual = xri_trace_snapshot_json((char *)bytes.mutableBytes, n);
        if (actual > n) continue;
        if (actual == 0 || actual > (4u << 20)) return @{};
        NSData *json = [bytes subdataWithRange:NSMakeRange(0, actual - 1)];
        NSDictionary *parsed = [NSJSONSerialization JSONObjectWithData:json options:0 error:NULL];
        if (![parsed isKindOfClass:NSDictionary.class]) return @{};
        self.traceSnapshot = parsed;
        self.rawTrace = json;
        return parsed;
    }
    return @{};
}

- (void)updateCategory {
    BOOL trace = self.category.selectedSegmentIndex == 4;
    self.resourceKind.hidden = !trace;
    self.results.frame = trace ? CGRectMake(16, 270, 308, 120)
                               : CGRectMake(16, 239, 308, 151);
    [self.scanButton setTitle:trace ? @"操作前" : @"扫描" forState:UIControlStateNormal];
    [self.secondaryButton setTitle:trace ? @"操作后" : @"复制结果" forState:UIControlStateNormal];
    self.filter.placeholder = trace ? @"搜索方法 / 类 / Lua C回调 / callId" :
                                      @"搜索导出符号 / 镜像名称";
    [self renderResults];
}

- (void)scanOrBegin {
    if (self.category.selectedSegmentIndex != 4) {
        [self scan];
        return;
    }
    NSArray<NSString *> *types = @[@"diamond", @"gold", @"energy", @"other"];
    NSInteger index = self.resourceKind.selectedSegmentIndex;
    if (index < 0 || index >= (NSInteger)types.count) return;
    int result = xri_resource_probe_begin(types[(NSUInteger)index].UTF8String);
    self.status.text = result == 1 ? @"状态：操作前已标记，请执行游戏操作" :
                                     @"状态：已有未结束的操作记录";
    [self renderResults];
}

- (void)copyOrEnd {
    if (self.category.selectedSegmentIndex != 4) {
        [self copyJSON];
        return;
    }
    int result = xri_resource_probe_end();
    self.status.text = result == 1 ? @"状态：操作已记录，查看事件后导出 JSON" :
                                     @"状态：请先点击「操作前」";
    [self renderResults];
}

- (void)appendTraceLine:(NSString *)line
                     to:(NSMutableArray<NSString *> *)lines
                  query:(NSString *)query {
    if (!query.length || [line rangeOfString:query
        options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound) {
        [lines addObject:line];
    }
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
        NSArray *executions = trace[@"executions"] ?: @[];
        NSArray *bridges = trace[@"bridges"] ?: @[];
        NSArray *checks = trace[@"resourceProbes"] ?: @[];
        NSArray *comparisons = trace[@"resourceComparisons"] ?: @[];
        NSArray *registrations = trace[@"cFunctionRegistrations"] ?: @[];
        NSDictionary *registrationStats = trace[@"cFunctionRegistrationStats"] ?: @{};
        NSDictionary *active = [trace[@"activeResourceProbe"] isKindOfClass:NSDictionary.class] ?
                               trace[@"activeResourceProbe"] : nil;
        NSDictionary *execStats = trace[@"executionStats"] ?: @{};
        NSDictionary *bridgeStats = trace[@"bridgeStats"] ?: @{};
        NSString *query = self.filter.text ?: @"";
        NSMutableArray<NSString *> *lines = [NSMutableArray array];

        [lines addObject:[NSString stringWithFormat:
            @"P3.2: %@ | %@\nVM %lu · Chunk %lu · 执行 %@ · IL2CPP %@\n操作样本 %lu · C回调注册 %@ · %@",
            [trace[@"recording"] boolValue] ? @"记录中" : @"未记录",
            trace[@"reason"] ?: @"状态不可用",
            (unsigned long)states.count, (unsigned long)chunks.count,
            execStats[@"total"] ?: @0, bridgeStats[@"total"] ?: @0,
            (unsigned long)checks.count,registrationStats[@"total"] ?: @0,
            active ? [NSString stringWithFormat:@"正在采集 %@", active[@"kind"]] : @"待标记"]];

        for (NSDictionary *e in states) {
            NSString *line = [NSString stringWithFormat:
                @"[VM] %@ %@ · #%@",e[@"action"] ?: @"",
                e[@"state"] ?: @"",e[@"sequence"] ?: @0];
            [self appendTraceLine:line to:lines query:query];
        }
        for (NSDictionary *e in chunks) {
            NSString *line = [NSString stringWithFormat:
                @"[CHUNK] %@ (%@ bytes) · %@ · result %@ · state %@",
                e[@"name"] ?: @"", e[@"size"] ?: @0,
                e[@"source"] ?: @"", e[@"result"] ?: @0,e[@"state"] ?: @""];
            [self appendTraceLine:line to:lines query:query];
        }
        for (NSDictionary *e in executions) {
            NSString *line = [NSString stringWithFormat:
                @"[EXEC] lua_pcallk callId %@ · state %@ · thread %@\nargs %@ · status %@ · %@ ns",
                e[@"callId"] ?: @0, e[@"state"] ?: @"",e[@"threadId"] ?: @0,
                e[@"nargs"] ?: @0,e[@"status"] ?: @0,e[@"durationNs"] ?: @0];
            [self appendTraceLine:line to:lines query:query];
        }
        for (NSDictionary *e in bridges) {
            NSString *line = [NSString stringWithFormat:
                @"[IL2CPP] %@.%@.%@ · method %@\ncallId %@ · thread %@ · %@ ns%@",
                e[@"namespace"] ?: @"",e[@"className"] ?: @"",
                e[@"methodName"] ?: @"",e[@"method"] ?: @"",
                e[@"protectedCallId"] ?: @0,e[@"threadId"] ?: @0,
                e[@"durationNs"] ?: @0,
                [e[@"exception"] boolValue] ? @" · exception" : @""];
            [self appendTraceLine:line to:lines query:query];
        }
        NSDictionary *names = @{
            @"diamond":@"钻石", @"gold":@"金币", @"energy":@"体力", @"other":@"对照"
        };
        // Registration is evidence of a native Lua callback being pushed.
        // It is not proof that the callback ran, or identification of a C# method.
        NSArray *sortedRegistrations = [registrations sortedArrayUsingComparator:
            ^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                NSComparisonResult r = [b[@"count"] compare:a[@"count"]];
                return r != NSOrderedSame ? r :
                    [a[@"callback"] compare:b[@"callback"]];
            }];
        NSUInteger displayedRegistrations = 0;
        for (NSDictionary *e in sortedRegistrations) {
            if (!query.length && displayedRegistrations++ >= 30) break;
            NSString *line = [NSString stringWithFormat:
                @"[Lua C回调注册·非执行] %@ · %@ ×%@\n归属 %@ · offset %@ · upvalues %@",
                e[@"callback"] ?: @"", e[@"state"] ?: @"", e[@"count"] ?: @0,
                [e[@"ownerImage"] lastPathComponent] ?: @"",
                e[@"ownerImageOffset"] ?: @"",e[@"upvalues"] ?: @0];
            [self appendTraceLine:line to:lines query:query];
        }
        for (NSDictionary *e in checks) {
            NSString *kind = e[@"kind"] ?: @"other";
            NSArray *counts = [e[@"methodCounts"] isKindOfClass:NSArray.class] ?
                e[@"methodCounts"] : @[];
            NSArray *ordered = [counts sortedArrayUsingComparator:
                ^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                    NSComparisonResult r = [b[@"count"] compare:a[@"count"]];
                    return r != NSOrderedSame ? r :
                        [a[@"method"] compare:b[@"method"]];
                }];
            NSMutableArray<NSString *> *top = [NSMutableArray array];
            for (NSDictionary *entry in ordered) {
                if (top.count >= 8) break;
                [top addObject:[NSString stringWithFormat:@"%@ ×%@",
                    entry[@"method"] ?: @"",entry[@"count"] ?: @0]];
            }
            NSString *line = [NSString stringWithFormat:
                @"[操作观察·%@] Lua增量 %@ · IL2CPP增量 %@ · 实时聚合 %@\n%@\n%@\n资源实际数值：未验证",
                names[kind] ?: kind,e[@"executionDelta"] ?: @0,
                e[@"bridgeDelta"] ?: @0,e[@"matchedMethodCount"] ?: @0,
                [top componentsJoinedByString:@"\n"],
                [e[@"methodAggregationOverflow"] unsignedLongLongValue] ?
                   @"存在超限方法，结果不完整" : @"聚合容量内"];
            [self appendTraceLine:line to:lines query:query];
        }
        for (NSDictionary *cmp in comparisons) {
            if (![cmp[@"comparisonReady"] boolValue]) continue;
            NSArray *deltas = cmp[@"methodDeltas"] ?: @[];
            NSMutableArray *candidates = [NSMutableArray array];
            for (NSDictionary *entry in deltas) {
                double rise = [entry[@"targetRatePer1kLuaCalls"] doubleValue] -
                              [entry[@"controlRatePer1kLuaCalls"] doubleValue];
                if (rise <= 0) continue;
                [candidates addObject:@{@"method":entry[@"method"] ?: @"",
                                        @"rise":@(rise)}];
            }
            [candidates sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                NSComparisonResult r = [b[@"rise"] compare:a[@"rise"]];
                return r != NSOrderedSame ? r :
                    [a[@"method"] compare:b[@"method"]];
            }];
            NSMutableArray<NSString *> *top = [NSMutableArray array];
            for (NSDictionary *entry in candidates) {
                if (top.count >= 8) break;
                [top addObject:[NSString stringWithFormat:@"%@ Δ+%.2f/千次Lua",
                    entry[@"method"],[entry[@"rise"] doubleValue]]];
            }
            NSString *line = [NSString stringWithFormat:
                @"[体力/对照差异 · 观察相关非因果]\n对照 #%@ → 体力 #%@\n%@",
                cmp[@"controlStartSequence"] ?: @0,
                cmp[@"targetStartSequence"] ?: @0,
                top.count ? [top componentsJoinedByString:@"\n"] :
                            @"未发现归一化增量为正的方法"];
            [self appendTraceLine:line to:lines query:query];
        }
        if (lines.count == 1 && query.length)
            [lines addObject:@"没有匹配记录；搜索不影响 JSON 原始数据。"];
        self.results.text = [lines componentsJoinedByString:@"\n\n"];
        self.status.text = [trace[@"recording"] boolValue] ?
            @"状态：跟踪中 · 资源变化需实机验证" :
            [NSString stringWithFormat:@"状态：%@",trace[@"reason"] ?: @"等待 Hook"];
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
    // Always export both current views to a stable directory in the host
    // application's data container, never inside the signed .app bundle.
    [self scan];
    [self traceInfo];
    if (!self.rawSnapshot || !self.rawTrace) {
        self.status.text = @"状态：无法生成完整 JSON";
        return;
    }
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (!documents.length) {
        self.status.text = @"状态：Documents 不可用";
        return;
    }
    NSString *directory = [documents stringByAppendingPathComponent:@"XRI"];
    NSFileManager *fm = NSFileManager.defaultManager;
    NSError *error = nil;
    if (![fm createDirectoryAtPath:directory withIntermediateDirectories:YES
                        attributes:nil error:&error]) {
        self.status.text = [NSString stringWithFormat:@"目录创建失败：%@", error.localizedDescription];
        return;
    }
    NSDictionary<NSString *, NSData *> *files = @{
        @"snapshot.json":self.rawSnapshot,
        @"trace.json":self.rawTrace
    };
    for (NSString *name in files) {
        NSString *path = [directory stringByAppendingPathComponent:name];
        if (![files[name] writeToFile:path options:NSDataWritingAtomic error:&error]) {
            self.status.text = [NSString stringWithFormat:@"%@ 写入失败：%@",
                                name, error.localizedDescription];
            return;
        }
    }
    self.status.text = @"状态：已写入 Documents/XRI";
    self.results.text = [NSString stringWithFormat:
        @"已导出：\n%@\n\nsnapshot.json\ntrace.json\n\n此目录位于当前游戏沙盒中。", directory];
    self.category.selectedSegmentIndex = 4;
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
