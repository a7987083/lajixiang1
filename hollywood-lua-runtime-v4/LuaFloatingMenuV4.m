// Compact H5GG-style floating UX; original UIKit implementation, no H5GG source copied.
// Uses a pass-through window so touches outside the bubble/panel reach the game.
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

extern int LuaHookV4_RequestGold(void);
extern int LuaHookV4_RequestGem(void);
extern int LuaHookV4_RequestEnergy(int enabled);
extern int LuaHookV4_IsInstalled(void);
extern int LuaHookV4_ModStatus(void);
extern void LuaHookV4_CopyStatus(char *,size_t);

@interface LuaV4OverlayWindow : UIWindow
@property(nonatomic, weak) UIView *bubble;
@property(nonatomic, weak) UIView *panel;
@end
@implementation LuaV4OverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit=[super hitTest:point withEvent:event];
    if (!hit || hit==self || hit==self.rootViewController.view) return nil;
    return hit;
}
@end

@interface LuaV4OverlayController : UIViewController
@property(nonatomic, strong) UIButton *bubble;
@property(nonatomic, strong) UIView *panel;
@property(nonatomic, assign) CGPoint panOrigin;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) NSTimer *statusTimer;
@end

@implementation LuaV4OverlayController
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

    UIView *panel=[[UIView alloc] initWithFrame:CGRectMake(78,108,252,308)];
    panel.backgroundColor=[UIColor colorWithRed:0.055 green:0.075 blue:0.12 alpha:0.96];
    panel.layer.cornerRadius=15;
    panel.layer.borderWidth=1;
    panel.layer.borderColor=[UIColor colorWithWhite:0.35 alpha:0.7].CGColor;
    panel.layer.shadowOpacity=0.35;
    panel.layer.shadowRadius=12;
    panel.layer.shadowColor=UIColor.blackColor.CGColor;

    UILabel *title=[[UILabel alloc] initWithFrame:CGRectMake(16,12,210,23)];
    title.text=@"Hollywood · Lua V4";
    title.textColor=UIColor.whiteColor;
    title.font=[UIFont boldSystemFontOfSize:16];
    [panel addSubview:title];

    [panel addSubview:[self makeButton:@"金币 +10" tag:1 y:43]];
    [panel addSubview:[self makeButton:@"钻石 +10" tag:2 y:90]];
    [panel addSubview:[self makeButton:@"无限能量：开启" tag:3 y:137]];
    [panel addSubview:[self makeButton:@"无限能量：关闭" tag:4 y:184]];

    UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(16,230,220,70)];
    label.text=@"等待 Hook 结果";
    label.textColor=[UIColor colorWithRed:0.51 green:0.9 blue:0.83 alpha:1];
    label.font=[UIFont systemFontOfSize:11];
    label.numberOfLines=4;
    [panel addSubview:label];
    self.statusLabel=label;
    __weak typeof(self) weakSelf=self;
    self.statusTimer=[NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) {
        (void)timer; [weakSelf refreshStatus];
    }];
    [self refreshStatus];
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
    CGFloat top=MAX(8,MIN(center.y-40,MAX(8,CGRectGetHeight(bounds)-308-8)));
    self.panel.frame=CGRectMake(left,top,w,308);
}
- (void)togglePanel {
    self.panel.hidden=!self.panel.hidden;
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
        case 1:rc=LuaHookV4_RequestGold();break;
        case 2:rc=LuaHookV4_RequestGem();break;
        case 3:rc=LuaHookV4_RequestEnergy(1);break;
        case 4:rc=LuaHookV4_RequestEnergy(0);break;
    }
    [self refreshStatus];
    if(!rc) self.statusLabel.text=[@"请求被拒绝： " stringByAppendingString:self.statusLabel.text ?: @"查看日志"];
}
- (void)refreshStatus {
    char b[384]={0};
    LuaHookV4_CopyStatus(b,sizeof(b));
    NSString *msg=[NSString stringWithUTF8String:b] ?: @"不可读";
    self.statusLabel.text=[NSString stringWithFormat:@"Hook:%@ · _MOD:%@\n%@",
        LuaHookV4_IsInstalled()?@"OK":@"未安装",
        LuaHookV4_ModStatus()==2?@"就绪":(LuaHookV4_ModStatus()==1?@"缺失":@"等待"),
        msg];
}
- (void)dealloc { [self.statusTimer invalidate]; }
@end

static LuaV4OverlayWindow *gOverlay;
static void LuaV4StartOverlay(unsigned attempts) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(gOverlay) return;
        UIApplication *app=UIApplication.sharedApplication;
        if (!app || app.applicationState==UIApplicationStateBackground || app.windows.count==0) {
            if(attempts>=40) return;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
                LuaV4StartOverlay(attempts+1);
            });
            return;
        }
        CGRect bounds=UIScreen.mainScreen.bounds;
        LuaV4OverlayWindow *window=[[LuaV4OverlayWindow alloc] initWithFrame:bounds];
        window.windowLevel=UIWindowLevelAlert-2;
        window.backgroundColor=UIColor.clearColor;
        LuaV4OverlayController *controller=[LuaV4OverlayController new];
        window.rootViewController=controller;
        (void)controller.view; // Force viewDidLoad before connecting pass-through targets.
        window.hidden=NO; // Do not make key, so the game retains input and keyboard ownership.
        window.bubble=controller.bubble;
        window.panel=controller.panel;
        gOverlay=window;
    });
}
__attribute__((constructor)) static void LuaV4OverlayInit(void) {
    LuaV4StartOverlay(0);
}
