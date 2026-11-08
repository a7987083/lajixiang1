#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import <dispatch/dispatch.h>
#import <stdio.h>\n#import <math.h>

// Local QA simulator: synthetic states NEVER enter StoreKit or grant entitlements.
static void QALog(NSString *event) {
    NSString *line=[NSString stringWithFormat:@"[%@] %@\n", [NSDate date], event];
    NSLog(@"[StoreKitQA] %@", event);
    NSArray *paths=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    if (!paths.count) return;
    NSString *path=[paths[0] stringByAppendingPathComponent:@"storekit-qa.log"];
    NSFileHandle *handle=[NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) { [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; return; }
    @try { [handle seekToEndOfFile]; [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; }
    @finally { [handle closeFile]; }
}

// H5GG FloatWindow-style hit-testing: only interactive overlay subviews receive touches.
// Do not make this window key; all other points must reach the host game.
@interface StoreKitQAPassThroughWindow : UIWindow
@end
@implementation StoreKitQAPassThroughWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *root=self.rootViewController.view;
    for (UIView *child in [root.subviews reverseObjectEnumerator]) {
        if (child.hidden || child.alpha < 0.01 || !child.userInteractionEnabled) continue;
        CGPoint local=[self convertPoint:point toView:child];
        if ([child pointInside:local withEvent:event]) return YES;
    }
    return NO;
}
@end

@interface StoreKitQAObserver : NSObject <SKPaymentTransactionObserver>
@end
@implementation StoreKitQAObserver
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *t in transactions) {
        NSString *pid=t.payment.productIdentifier ?: @"(missing)";
        QALog([NSString stringWithFormat:@"REAL transaction product=%@ state=%ld error=%@ (observation only)",pid,(long)t.transactionState,t.error]);
    }
}
// Never call finishTransaction:; the host app owns transaction lifecycle.
@end

@interface StoreKitQAPanel : NSObject
@property(nonatomic,strong) StoreKitQAPassThroughWindow *window;
@property(nonatomic,strong) UIButton *bubble;
@property(nonatomic,strong) UIView *menu;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) StoreKitQAObserver *observer;
@property(nonatomic,assign) CGPoint panStart;
@property(nonatomic,assign) CGPoint bubbleStart;
@property(nonatomic,assign) BOOL dragged;
@property(nonatomic,assign) NSInteger retries;
@end
@implementation StoreKitQAPanel
- (void)simulate:(UIButton *)sender {
    NSArray *states=@[@"SUCCESS (mock)",@"CANCELLED (mock)",@"FAILED (mock)",@"RESTORED (mock)"];
    NSInteger index=sender.tag;
    if (index<0 || index>=states.count) return;
    self.status.text=[NSString stringWithFormat:@"QA: %@",states[index]];
    QALog([NSString stringWithFormat:@"SYNTHETIC %@; no transaction, no rewards, no receipt",states[index]]);
}
- (void)positionMenu {
    if (!self.window || !self.bubble || !self.menu) return;
    CGRect bounds=self.window.bounds, safe=self.window.safeAreaInsets;
    CGFloat width=MIN(254, MAX(190, bounds.size.width-24));
    CGFloat height=244;
    CGFloat x=CGRectGetMidX(self.bubble.frame)-width/2;
    x=MAX(12,MIN(x,bounds.size.width-width-12));
    CGFloat y=CGRectGetMaxY(self.bubble.frame)+8;
    if (y+height>bounds.size.height-safe.bottom-8)
        y=CGRectGetMinY(self.bubble.frame)-height-8;
    y=MAX(safe.top+8,MIN(y,MAX(safe.top+8,bounds.size.height-safe.bottom-height-8)));
    self.menu.frame=CGRectMake(x,y,width,height);
}
- (void)toggle:(id)sender {
    self.menu.hidden=!self.menu.hidden;
    if (!self.menu.hidden) [self positionMenu];
}
- (void)dragBubble:(UIPanGestureRecognizer *)pan {
    CGPoint p=[pan translationInView:self.window];
    if (pan.state==UIGestureRecognizerStateBegan) {
        self.bubbleStart=self.bubble.center;
        self.dragged=NO;
    }
    if (pan.state==UIGestureRecognizerStateChanged || pan.state==UIGestureRecognizerStateEnded) {
        if (hypot(p.x,p.y)>4) self.dragged=YES;
        UIEdgeInsets safe=self.window.safeAreaInsets;
        CGFloat half=25, width=self.window.bounds.size.width, height=self.window.bounds.size.height;
        CGFloat x=MAX(half+6,MIN(self.bubbleStart.x+p.x,width-half-6));
        CGFloat y=MAX(safe.top+half+6,MIN(self.bubbleStart.y+p.y,height-safe.bottom-half-6));
        self.bubble.center=CGPointMake(x,y);
        if (!self.menu.hidden) [self positionMenu];
    }
}
- (void)layoutChanged:(NSNotification *)note {
    if (!self.window) return;
    self.window.frame=self.window.windowScene ? self.window.windowScene.coordinateSpace.bounds : UIScreen.mainScreen.bounds;
    [self positionMenu];
}
- (UIWindowScene *)foregroundScene {
    if (@available(iOS 13.0,*)) {
        UIWindowScene *inactive=nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            if (scene.activationState==UISceneActivationStateForegroundActive)
                return (UIWindowScene *)scene;
            if (!inactive && scene.activationState==UISceneActivationStateForegroundInactive)
                inactive=(UIWindowScene *)scene;
        }
        return inactive;
    }
    return nil;
}
- (void)start {
    if (self.window) return;
    UIApplication *app=UIApplication.sharedApplication;
    UIWindowScene *scene=[self foregroundScene];
    // Wait for host window/scene initialization, without ever changing the keyWindow.
    if ((!scene && !app.keyWindow) && self.retries++<12) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ [self start]; });
        return;
    }
    StoreKitQAPassThroughWindow *w;
    if (@available(iOS 13.0,*)) {
        w=scene ? [[StoreKitQAPassThroughWindow alloc] initWithWindowScene:scene]
                : [[StoreKitQAPassThroughWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    } else {
        w=[[StoreKitQAPassThroughWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    }
    w.frame=scene ? scene.coordinateSpace.bounds : UIScreen.mainScreen.bounds;
    w.windowLevel=UIWindowLevelAlert-1; // H5GG: alert remains above overlay.
    w.backgroundColor=UIColor.clearColor;
    UIViewController *root=[UIViewController new];
    root.view.backgroundColor=UIColor.clearColor;
    w.rootViewController=root;
    w.hidden=NO; // Never makeKeyAndVisible: avoid stealing game keyboard/input focus.
    self.window=w;

    UIButton *bubble=[UIButton buttonWithType:UIButtonTypeCustom];
    bubble.frame=CGRectMake(22,110,50,50);
    bubble.backgroundColor=[UIColor colorWithRed:0.08 green:0.16 blue:0.24 alpha:0.95];
    bubble.layer.cornerRadius=25;
    bubble.layer.borderColor=[UIColor colorWithRed:0.18 green:0.83 blue:0.94 alpha:1].CGColor;
    bubble.layer.borderWidth=1.5;
    bubble.clipsToBounds=YES;
    bubble.titleLabel.font=[UIFont boldSystemFontOfSize:11];
    [bubble setTitle:@"QA" forState:UIControlStateNormal];
    [bubble setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [bubble addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragBubble:)];
    pan.maximumNumberOfTouches=1;
    [bubble addGestureRecognizer:pan];
    [root.view addSubview:bubble];
    self.bubble=bubble;

    UIView *menu=[[UIView alloc] initWithFrame:CGRectMake(12,170,254,244)];
    menu.hidden=YES;
    menu.layer.cornerRadius=12;
    menu.layer.borderWidth=1;
    menu.layer.borderColor=[UIColor colorWithWhite:0.42 alpha:0.6].CGColor;
    menu.backgroundColor=[UIColor colorWithRed:0.07 green:0.10 blue:0.15 alpha:0.97];
    [root.view addSubview:menu];
    self.menu=menu;
    UILabel *title=[[UILabel alloc] initWithFrame:CGRectMake(12,8,230,29)];
    title.text=@"StoreKit 1 · QA ONLY";
    title.textColor=UIColor.whiteColor;
    [menu addSubview:title];
    self.status=[[UILabel alloc] initWithFrame:CGRectMake(12,37,230,26)];
    self.status.text=@"Local simulation, no purchase";
    self.status.font=[UIFont systemFontOfSize:12];
    self.status.textColor=UIColor.lightGrayColor;
    [menu addSubview:self.status];
    NSArray *names=@[@"Mock success",@"Mock cancel",@"Mock fail",@"Mock restore"];
    for (NSInteger i=0;i<names.count;i++) {
       UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
       button.tag=i;
       button.frame=CGRectMake(12,72+i*40,230,34);
       button.layer.cornerRadius=6;
       button.backgroundColor=[UIColor colorWithWhite:0.2 alpha:1];
       [button setTitle:names[i] forState:UIControlStateNormal];
       [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
       [button addTarget:self action:@selector(simulate:) forControlEvents:UIControlEventTouchUpInside];
       [menu addSubview:button];
    }
    [self positionMenu];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(layoutChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];

    self.observer=[StoreKitQAObserver new];
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self.observer];
    QALog(@"H5GG-style movable floating QA button initialized; passive StoreKit observer attached");
}
@end
static StoreKitQAPanel *gQA;
__attribute__((constructor)) static void StoreKitQAEntry(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        gQA=[StoreKitQAPanel new];
        [gQA start];
    });
}
