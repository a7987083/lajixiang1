// Compact H5GG-style floating UX; original UIKit implementation, no H5GG source copied.
// Uses a pass-through window so touches outside the bubble/panel reach the game.
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

extern int LuaHookV3_IsInstalled(void);
extern int LuaHookV3_RequestGold(void);
extern int LuaHookV3_RequestGem(void);
extern int LuaHookV3_RequestEnergy(int enabled);

@interface LuaV3OverlayWindow : UIWindow
@property(nonatomic, weak) UIView *bubble;
@property(nonatomic, weak) UIView *panel;
@end
@implementation LuaV3OverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit=[super hitTest:point withEvent:event];
    if (!hit || hit==self || hit==self.rootViewController.view) return nil;
    return hit;
}
@end

@interface LuaV3OverlayController : UIViewController
@property(nonatomic, strong) UIButton *bubble;
@property(nonatomic, strong) UIView *panel;
@property(nonatomic, strong) UILabel *status;
@property(nonatomic, assign) CGPoint panOrigin;
@end

@implementation LuaV3OverlayController
- (void)loadView {
    UIView *v=[[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    v.backgroundColor=UIColor.clearColor;
    v.userInteractionEnabled=YES;
    self.view=v;
}
- (UIButton *)makeButton:(NSString *)name tag:(NSInteger)tag y:(CGFloat)y {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
    b.tag=tag;
    b.frame=CGRectMake(16,y,220,42);
    b.layer.cornerRadius=10;
    b.backgroundColor=[UIColor colorWithRed:0.16 green:0.20 blue:0.30 alpha:1];
    [b setTitle:name forState:UIControlStateNormal];
    [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    b.titleLabel.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [b addTarget:self action:@selector(actionTapped:) forControlEvents:UIControlEventTouchUpInside];
    return b;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    UIButton *bubble=[UIButton buttonWithType:UIButtonTypeCustom];
    bubble.frame=CGRectMake(18,140,52,52);
    bubble.layer.cornerRadius=26;
    bubble.layer.borderWidth=1;
    bubble.layer.borderColor=[UIColor colorWithRed:0.34 green:0.70 blue:1 alpha:1].CGColor;
    bubble.layer.shadowColor=UIColor.blackColor.CGColor;
    bubble.layer.shadowOpacity=0.35;
    bubble.layer.shadowRadius=8;
    bubble.backgroundColor=[UIColor colorWithRed:0.08 green:0.13 blue:0.23 alpha:0.95];
    [bubble setTitle:@"H" forState:UIControlStateNormal];
    bubble.titleLabel.font=[UIFont boldSystemFontOfSize:26];
    [bubble setTitleColor:[UIColor colorWithRed:0.42 green:0.81 blue:1 alpha:1] forState:UIControlStateNormal];
    [bubble addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveBubble:)];
    pan.maximumNumberOfTouches=1;
    [bubble addGestureRecognizer:pan];
    [self.view addSubview:bubble];
    self.bubble=bubble;

    UIView *panel=[[UIView alloc] initWithFrame:CGRectMake(78,108,252,298)];
    panel.backgroundColor=[UIColor colorWithRed:0.055 green:0.075 blue:0.12 alpha:0.96];
    panel.layer.cornerRadius=15;
    panel.layer.borderWidth=1;
    panel.layer.borderColor=[UIColor colorWithWhite:0.35 alpha:0.7].CGColor;
    panel.layer.shadowOpacity=0.35;
    panel.layer.shadowRadius=12;
    panel.layer.shadowColor=UIColor.blackColor.CGColor;

    UILabel *title=[[UILabel alloc] initWithFrame:CGRectMake(16,12,210,23)];
    title.text=@"Hollywood · Lua V3";
    title.textColor=UIColor.whiteColor;
    title.font=[UIFont boldSystemFontOfSize:16];
    [panel addSubview:title];
    UILabel *hint=[[UILabel alloc] initWithFrame:CGRectMake(16,38,220,18)];
    hint.text=@"手动测试 · 不自动修改资源";
    hint.font=[UIFont systemFontOfSize:11];
    hint.textColor=[UIColor lightGrayColor];
    [panel addSubview:hint];

    [panel addSubview:[self makeButton:@"金币 +10" tag:1 y:65]];
    [panel addSubview:[self makeButton:@"钻石 +10" tag:2 y:112]];
    [panel addSubview:[self makeButton:@"无限能量：开启" tag:3 y:159]];
    [panel addSubview:[self makeButton:@"无限能量：关闭" tag:4 y:206]];

    UILabel *status=[[UILabel alloc] initWithFrame:CGRectMake(16,252,220,34)];
    status.textColor=[UIColor colorWithRed:0.67 green:0.84 blue:1 alpha:1];
    status.font=[UIFont systemFontOfSize:12];
    status.numberOfLines=2;
    status.text=@"等待 Lua Hook…";
    [panel addSubview:status];
    self.status=status;
    panel.hidden=YES;
    [self.view addSubview:panel];
    self.panel=panel;
    [self.view bringSubviewToFront:bubble];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Keep bubble inside the current screen when rotating.
    CGRect bounds=self.view.bounds;
    CGPoint center=self.bubble.center;
    CGFloat half=26;
    center.x=MAX(half,MIN(CGRectGetWidth(bounds)-half,center.x));
    center.y=MAX(half,MIN(CGRectGetHeight(bounds)-half,center.y));
    self.bubble.center=center;
    CGFloat w=252;
    CGFloat left=center.x+34;
    if(left+w>CGRectGetWidth(bounds)) left=center.x-w-34;
    left=MAX(4,MIN(left,MAX(4,CGRectGetWidth(bounds)-w-4)));
    CGFloat top=MAX(8,MIN(center.y-40,MAX(8,CGRectGetHeight(bounds)-298-8)));
    self.panel.frame=CGRectMake(left,top,w,298);
}
- (void)togglePanel {
    self.panel.hidden=!self.panel.hidden;
    self.status.text=LuaHookV3_IsInstalled()?@"Hook 已安装 · 请选择操作":@"Hook 尚未安装 · 请稍后";
}
- (void)moveBubble:(UIPanGestureRecognizer *)recognizer {
    CGPoint change=[recognizer translationInView:self.view];
    if(recognizer.state==UIGestureRecognizerStateBegan) self.panOrigin=self.bubble.center;
    if(recognizer.state==UIGestureRecognizerStateChanged || recognizer.state==UIGestureRecognizerStateEnded) {
        self.bubble.center=CGPointMake(self.panOrigin.x+change.x,self.panOrigin.y+change.y);
        [self viewDidLayoutSubviews];
    }
}
- (void)actionTapped:(UIButton *)sender {
    int rc=0;
    switch(sender.tag) {
        case 1:rc=LuaHookV3_RequestGold();break;
        case 2:rc=LuaHookV3_RequestGem();break;
        case 3:rc=LuaHookV3_RequestEnergy(1);break;
        case 4:rc=LuaHookV3_RequestEnergy(0);break;
    }
    self.status.text=rc?@"请求已入队 · 等待 Lua 线程执行":@"请求未入队 · 请先完成上次操作";
}
@end

static LuaV3OverlayWindow *gOverlay;
static void LuaV3StartOverlay(unsigned attempts) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(gOverlay) return;
        UIApplication *app=UIApplication.sharedApplication;
        if (!app || app.applicationState==UIApplicationStateBackground || app.windows.count==0) {
            if(attempts>=40) return;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                LuaV3StartOverlay(attempts+1);
            });
            return;
        }
        CGRect bounds=UIScreen.mainScreen.bounds;
        LuaV3OverlayWindow *window=[[LuaV3OverlayWindow alloc] initWithFrame:bounds];
        window.windowLevel=UIWindowLevelAlert-2;
        window.backgroundColor=UIColor.clearColor;
        LuaV3OverlayController *controller=[LuaV3OverlayController new];
        window.rootViewController=controller;
        (void)controller.view; // Force viewDidLoad before connecting pass-through targets.
        window.hidden=NO; // Do not make key, so the game retains input and keyboard ownership.
        window.bubble=controller.bubble;
        window.panel=controller.panel;
        gOverlay=window;
    });
}
__attribute__((constructor)) static void LuaV3OverlayInit(void) {
    LuaV3StartOverlay(0);
}
