#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static BOOL IsUnityAd(UIViewController *vc) {
    NSString *n = NSStringFromClass([vc class]);
    return [n isEqualToString:@"UnityAds.WebViewContainerViewController"];
}
static UIViewController *FindAd(UIViewController *vc, NSUInteger depth) {
    if (!vc || depth > 16) return nil;
    if (IsUnityAd(vc) && vc.isViewLoaded && vc.view.window) return vc;
    UIViewController *found = FindAd(vc.presentedViewController, depth+1);
    if (found) return found;
    for (UIViewController *child in vc.childViewControllers) {
        found = FindAd(child, depth+1);
        if (found) return found;
    }
    if ([vc isKindOfClass:[UINavigationController class]]) {
        return FindAd(((UINavigationController *)vc).visibleViewController, depth+1);
    }
    return nil;
}
static UIViewController *CurrentAd(UIWindow *exclude) {
    for (UIWindow *w in [UIApplication.sharedApplication.windows reverseObjectEnumerator]) {
        if (w == exclude) continue;
        UIViewController *found = FindAd(w.rootViewController,0);
        if (found) return found;
    }
    return nil;
}


#pragma mark - Observe real UnityAdsShowDelegate callbacks (never synthesize)
static NSString *gLastAdCallback = @"NOT_OBSERVED";
static NSUInteger gCallbackSerial = 0;
static NSMutableSet<NSString *> *gObservedMethods;
static id gShowDelegate;
static NSString *gShowPlacement;
static BOOL gHookedShow = NO;
static __weak UIViewController *gDetectedAd;
static BOOL gSimulated = NO;

static void RecordAdCallback(NSString *name, NSString *placement, NSString *detail) {
    NSString *entry = [NSString stringWithFormat:@"%@ placement=%@ %@",
                       name, placement ?: @"(nil)", detail ?: @""];
    NSLog(@"[AdCloseCallback] %@", entry);
    dispatch_async(dispatch_get_main_queue(), ^{
        gLastAdCallback = entry;
        gCallbackSerial++;
    });
}
static void InstallCallbackObserver(void) {
    if (!gObservedMethods) gObservedMethods = [NSMutableSet new];
    SEL complete = NSSelectorFromString(@"unityAdsShowComplete:withFinishState:");
    SEL failed = NSSelectorFromString(@"unityAdsShowFailed:withError:withMessage:");
    SEL start = NSSelectorFromString(@"unityAdsShowStart:");
    SEL click = NSSelectorFromString(@"unityAdsShowClick:");
    SEL targets[] = {complete, failed, start, click};
    int total = objc_getClassList(NULL, 0);
    if (total <= 0 || total > 50000) return;
    Class __unsafe_unretained *classes = (Class __unsafe_unretained *)calloc((size_t)total, sizeof(Class));
    if (!classes) return;
    int count = objc_getClassList(classes, total);
    NSUInteger installed = 0;
    for (int i = 0; i < count; i++) {
        Class cls = classes[i];
        if (class_isMetaClass(cls)) continue;
        unsigned int n = 0;
        Method *methods = class_copyMethodList(cls, &n);
        for (unsigned int j = 0; j < n; j++) {
            Method m = methods[j];
            SEL selector = method_getName(m);
            int kind = -1;
            for (int k = 0; k < 4; k++) if (selector == targets[k]) { kind = k; break; }
            if (kind < 0) continue;
            NSString *key = [NSString stringWithFormat:@"%s/%s", class_getName(cls), sel_getName(selector)];
            if ([gObservedMethods containsObject:key]) continue;
            IMP original = method_getImplementation(m);
            if (!original) continue;
            IMP replacement = NULL;
            if (kind == 0) {
                replacement = imp_implementationWithBlock(^(id self, NSString *placement, NSInteger state) {
                    RecordAdCallback(@"unityAdsShowComplete", placement, [NSString stringWithFormat:@"finishState=%ld", (long)state]);
                    ((void (*)(id,SEL,NSString *,NSInteger))original)(self, selector, placement, state);
                });
            } else if (kind == 1) {
                replacement = imp_implementationWithBlock(^(id self, NSString *placement, NSInteger error, NSString *msg) {
                    RecordAdCallback(@"unityAdsShowFailed", placement, [NSString stringWithFormat:@"error=%ld message=%@", (long)error, msg]);
                    ((void (*)(id,SEL,NSString *,NSInteger,NSString *))original)(self, selector, placement, error, msg);
                });
            } else {
                NSString *label = kind == 2 ? @"unityAdsShowStart" : @"unityAdsShowClick";
                replacement = imp_implementationWithBlock(^(id self, NSString *placement) {
                    RecordAdCallback(label, placement, @"");
                    ((void (*)(id,SEL,NSString *))original)(self, selector, placement);
                });
            }
            if (replacement) {
                method_setImplementation(m, replacement);
                [gObservedMethods addObject:key];
                installed++;
            }
        }
        free(methods);
    }
    free(classes);
    NSLog(@"[AdCloseCallback] observer active; new methods=%lu total=%lu",
          (unsigned long)installed, (unsigned long)gObservedMethods.count);
}

static void CaptureUnityShowDelegate(void) {
    if (gHookedShow) return;
    Class cls = NSClassFromString(@"UnityAds");
    if (!cls) return;
    SEL sels[] = {NSSelectorFromString(@"show:placementId:showDelegate:"),
                  NSSelectorFromString(@"show:adUnitId:showDelegate:")};
    for (int i=0;i<2;i++) {
        SEL sel = sels[i];
        Method m = class_getClassMethod(cls, sel);
        if (!m || method_getNumberOfArguments(m)!=5) continue;
        IMP orig=method_getImplementation(m);
        IMP hook=imp_implementationWithBlock(^(id receiver, UIViewController *vc, NSString *placement, id delegate) {
            if ([delegate respondsToSelector:NSSelectorFromString(@"unityAdsShowComplete:withFinishState:")]) {
                gShowDelegate=delegate;
                gShowPlacement=[placement copy];
                gSimulated=NO;
                NSLog(@"[AdClose] captured showDelegate=%@ placement=%@",delegate,placement);
            }
            ((void(*)(id,SEL,UIViewController*,NSString*,id))orig)(receiver,sel,vc,placement,delegate);
        });
        method_setImplementation(m,hook);
        gHookedShow=YES;
    }
}
static NSString *SimulateCompleted(void) {
    SEL sel=NSSelectorFromString(@"unityAdsShowComplete:withFinishState:");
    if (!gShowDelegate || !gShowPlacement.length || ![gShowDelegate respondsToSelector:sel])
        return @"NO_DELEGATE: 没捕获到 SDK showDelegate，未模拟回调";
    if (gSimulated) return @"ALREADY_SENT: 本次广告已经模拟过回调";
    NSMethodSignature *sig=[gShowDelegate methodSignatureForSelector:sel];
    if (!sig || sig.numberOfArguments!=4 || strcmp(sig.methodReturnType,@encode(void))!=0)
        return @"BAD_SIGNATURE: 已取消模拟";
    gSimulated=YES;
    NSLog(@"[AdClose][SIMULATED] completed placement=%@",gShowPlacement);
    ((void(*)(id,SEL,NSString*,NSInteger))objc_msgSend)(gShowDelegate,sel,gShowPlacement,(NSInteger)1);
    return @"SIMULATED_COMPLETED_SENT: 回调已发送，游戏奖励是否到账仍需实机确认";
}
@interface AdCloseRoot : UIViewController <WKScriptMessageHandler, UIGestureRecognizerDelegate>
@property(nonatomic,strong) UIButton *bubble;
@property(nonatomic,strong) WKWebView *web;
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,assign) BOOL expanded;
@end
@interface AdCloseWindow : UIWindow
@property(nonatomic,weak) AdCloseRoot *menu;
@end

@implementation AdCloseWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *v = [super hitTest:point withEvent:event];
    if (v == self || v == self.rootViewController.view) return nil;
    return v;
}
@end

@implementation AdCloseRoot
- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    root.backgroundColor = UIColor.clearColor;
    root.userInteractionEnabled = YES;
    self.view = root;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    UIButton *bubble = [UIButton buttonWithType:UIButtonTypeSystem];
    bubble.frame = CGRectMake(14, 130, 53, 53);
    bubble.layer.cornerRadius = 26.5;
    bubble.layer.borderWidth = 1.5;
    bubble.layer.borderColor = [UIColor colorWithRed:.16 green:.82 blue:.93 alpha:1].CGColor;
    bubble.backgroundColor = [UIColor colorWithRed:.05 green:.11 blue:.18 alpha:.96];
    [bubble setTitle:@"H5" forState:UIControlStateNormal];
    [bubble setTitleColor:UIColor.cyanColor forState:UIControlStateNormal];
    bubble.titleLabel.font = [UIFont boldSystemFontOfSize:19];
    [bubble addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:bubble];
    self.bubble = bubble;
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
    pan.delegate = self;
    [bubble addGestureRecognizer:pan];

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(16, 190, 300, 280)];
    panel.backgroundColor = [UIColor colorWithRed:.05 green:.08 blue:.13 alpha:.97];
    panel.layer.cornerRadius = 14;
    panel.layer.borderWidth = 1;
    panel.layer.borderColor = UIColor.cyanColor.CGColor;
    panel.clipsToBounds = YES;
    panel.hidden = YES;
    [self.view addSubview:panel];
    self.panel = panel;

    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    [config.userContentController addScriptMessageHandler:self name:@"adclose"];
    WKWebView *web = [[WKWebView alloc] initWithFrame:panel.bounds configuration:config];
    web.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    web.opaque = NO;
    web.backgroundColor = UIColor.clearColor;
    web.scrollView.scrollEnabled = YES;
    [panel addSubview:web];
    self.web = web;
    NSString *html =
    @"<!doctype html><meta name='viewport' content='width=device-width,initial-scale=1,user-scalable=no'>"
    "<style>body{background:#0e1523;color:#e8faff;font:15px -apple-system;margin:0;padding:16px}"
    "h3{margin:0 0 12px;color:#6be9ff}button{width:100%;padding:12px;margin:5px 0;"
    "border:1px solid #45bcd1;border-radius:9px;background:#193549;color:white;font-size:15px}"
    "button.red{border-color:#c85b65;background:#70333c}#out{font:12px monospace;color:#adc3cb;margin-top:8px;word-break:break-all}</style>"
    "<h3>Unity Ads · 测试</h3>"
    "<div id='out' style='background:#182d3a;border-radius:7px;padding:8px;margin-bottom:8px'>未检测</div>"
    "<button onclick=\"send('status')\">检测广告</button>"
    "<button class='red' onclick=\"send('close')\">关闭广告并模拟回调</button>"
    "<div style='font-size:11px;color:#93bac4'>关闭页面不代表 SDK 回调成功</div>"
    "<script>function send(x){window.webkit.messageHandlers.adclose.postMessage(x)}"
    "function show(x){document.getElementById('out').textContent=x}</script>";
    [web loadHTMLString:html baseURL:nil];
}
- (void)toggle:(UIButton *)sender {
    self.expanded = !self.expanded;
    self.panel.hidden = !self.expanded;
    if (self.expanded) {
        CGFloat w = CGRectGetWidth(self.view.bounds);
        CGFloat h = CGRectGetHeight(self.view.bounds);
        CGFloat x = MIN(MAX(8, CGRectGetMinX(self.bubble.frame)), MAX(8, w-308));
        CGFloat y = CGRectGetMaxY(self.bubble.frame)+8;
        if (y+280 > h-25) y = MAX(8, CGRectGetMinY(self.bubble.frame)-288);
        self.panel.frame = CGRectMake(x,y,300,280);
    }
}
- (void)drag:(UIPanGestureRecognizer *)pan {
    CGPoint d = [pan translationInView:self.view];
    CGRect f = self.bubble.frame;
    f.origin.x = MIN(MAX(0,f.origin.x+d.x),MAX(0,self.view.bounds.size.width-f.size.width));
    f.origin.y = MIN(MAX(24,f.origin.y+d.y),MAX(24,self.view.bounds.size.height-f.size.height-16));
    self.bubble.frame = f;
    [pan setTranslation:CGPointZero inView:self.view];
    if (self.expanded) self.panel.frame = CGRectMake(MIN(MAX(8,f.origin.x),MAX(8,self.view.bounds.size.width-308)),MIN(MAX(45,CGRectGetMaxY(f)+8),MAX(45,self.view.bounds.size.height-288)),300,280);
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer { return NO; }
- (void)showCallbackResult:(NSString *)result {
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[result ?: @"UNKNOWN"] options:0 error:nil];
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *js = [NSString stringWithFormat:@"show((%@)[0])",json ?: @"[\"ERROR\"]"];
    [self.web evaluateJavaScript:js completionHandler:nil];
}
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.body isKindOfClass:[NSString class]]) return;
    NSString *cmd=message.body;
    CaptureUnityShowDelegate();
    UIWindow *w=self.view.window;
    UIViewController *ad=CurrentAd(w);
    if ([cmd isEqualToString:@"status"]) {
        InstallCallbackObserver();
        if (ad!=gDetectedAd) { gDetectedAd=ad; gSimulated=NO; }
        NSString *result=ad ? [NSString stringWithFormat:@"FOUND: %@; delegate=%@ placement=%@",
            NSStringFromClass(ad.class), gShowDelegate?NSStringFromClass([gShowDelegate class]):@"NOT_CAPTURED",
            gShowPlacement?:@"unknown"] : @"NOT_FOUND: 无广告";
        [self showCallbackResult:result];
        return;
    }
    if (![cmd isEqualToString:@"close"]) return;
    if (!ad || !ad.presentingViewController || gDetectedAd!=ad) {
        [self showCallbackResult:@"NEED_DETECT: 请先检测当前广告"];
        return;
    }
    // UIKit dismiss must never depend on capturing the SDK showDelegate.
    // A missing delegate is reported independently; do not claim SDK completion.
    BOOL canSimulate = (gShowDelegate != nil && gShowPlacement.length > 0);
    __weak AdCloseRoot *weakSelf=self;
    [self showCallbackResult:canSimulate ?
        @"正在关闭广告；随后测试模拟回调..." :
        @"正在关闭广告；NO_DELEGATE：回调不可模拟，仅测试关闭"];
    [ad dismissViewControllerAnimated:YES completion:^{
        AdCloseRoot *strongSelf=weakSelf;
        if (!strongSelf) return;
        NSString *result = canSimulate ? SimulateCompleted() :
            @"NO_DELEGATE: 广告已执行 UIKit 关闭，未模拟 SDK 回调";
        [strongSelf showCallbackResult:result];
        NSLog(@"[AdClose] UIKit dismiss completed; callback=%@", result);
    }];
}
- (void)dealloc {
    [self.web.configuration.userContentController removeScriptMessageHandlerForName:@"adclose"];
}
@end

// The overlay is never made key: the host retains keyboard and touch focus.
static AdCloseWindow *gWindow;
static __weak UIWindowScene *gBoundScene;
static BOOL gInstallScheduled;

static UIWindow *FindHostWindow(void) {
    UIApplication *app = UIApplication.sharedApplication;
    if (!app) return nil;
    UIWindow *fallback = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *candidate in app.connectedScenes) {
            if (![candidate isKindOfClass:UIWindowScene.class]) continue;
            if (candidate.activationState != UISceneActivationStateForegroundActive &&
                candidate.activationState != UISceneActivationStateForegroundInactive) continue;
            UIWindowScene *scene = (UIWindowScene *)candidate;
            for (UIWindow *window in scene.windows) {
                if (window == gWindow || window.hidden || window.alpha <= .01 || !window.rootViewController) continue;
                if (window.isKeyWindow) return window;
                if (!fallback && window.windowLevel == UIWindowLevelNormal) fallback = window;
            }
        }
        if (fallback) return fallback;
    }
    if (app.keyWindow && app.keyWindow != gWindow && !app.keyWindow.hidden) return app.keyWindow;
    for (UIWindow *window in app.windows.reverseObjectEnumerator) {
        if (window != gWindow && !window.hidden && window.rootViewController &&
            window.windowLevel == UIWindowLevelNormal) return window;
    }
    return nil;
}

static void InstallOverlay(void);
static void ScheduleOverlayRetry(NSUInteger attempts) {
    if (gInstallScheduled) return;
    gInstallScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        gInstallScheduled = NO;
        InstallOverlay();
        if (!gWindow && attempts < 20) ScheduleOverlayRetry(attempts + 1);
    });
}

static void InstallOverlay(void) {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ InstallOverlay(); });
        return;
    }
    UIWindow *host = FindHostWindow();
    if (!host) {
        if (!gWindow) ScheduleOverlayRetry(0);
        return;
    }
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = host.windowScene;
        if (!scene) {
            if (!gWindow) ScheduleOverlayRetry(0);
            return;
        }
        if (gWindow && gWindow.windowScene != scene) {
            gWindow.hidden = YES;
            gWindow = nil; // release the old scene window; create a fresh one
        }
        if (!gWindow) {
            gWindow = [[AdCloseWindow alloc] initWithWindowScene:scene];
            gBoundScene = scene;
        }
    } else if (!gWindow) {
        gWindow = [[AdCloseWindow alloc] initWithFrame:host.bounds];
    }
    if (!gWindow.rootViewController) {
        AdCloseRoot *root = [AdCloseRoot new];
        gWindow.rootViewController = root;
        gWindow.menu = root;
    }
    gWindow.frame = host.bounds;
    gWindow.windowLevel = MAX(UIWindowLevelAlert + 5, host.windowLevel + 1);
    gWindow.backgroundColor = UIColor.clearColor;
    gWindow.hidden = NO;
    // Do not use makeKeyAndVisible: it would steal focus from the game.
    NSLog(@"[AdCloseOverlay] attached scene=%@ host=%@ frame=%@",
          gBoundScene, host, NSStringFromCGRect(gWindow.frame));
}

__attribute__((constructor)) static void AdCloseOverlayInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
        [nc addObserverForName:UIApplicationDidBecomeActiveNotification object:nil
                        queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            InstallOverlay();
        }];
        [nc addObserverForName:UIWindowDidBecomeKeyNotification object:nil
                        queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            if (note.object != gWindow) InstallOverlay();
        }];
        if (@available(iOS 13.0, *)) {
            [nc addObserverForName:UISceneDidActivateNotification object:nil
                            queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
                InstallOverlay();
            }];
        }
        CaptureUnityShowDelegate();
        InstallOverlay();
        if (!gWindow) ScheduleOverlayRetry(0);
    });
}
