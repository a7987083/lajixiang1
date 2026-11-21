#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

extern "C" int XJGMExportItems(int *savedOut);
extern "C" int XJGMCheckItems(void);

// Keep the floating window/bubble lifecycle and drag behavior unchanged.
// This build deliberately has NO catalog enumeration, GM request sender, or timers.
static UIWindow *sWindow=nil;
static UIColor *Ink(void) { return [UIColor colorWithRed:.91 green:.93 blue:.97 alpha:1]; }
static UIColor *Muted(void) { return [UIColor colorWithRed:.60 green:.66 blue:.76 alpha:1]; }
static UIColor *Accent(void) { return [UIColor colorWithRed:.47 green:.82 blue:.76 alpha:1]; }
static UILabel *Label(NSString *s,CGFloat size) {
    UILabel *label=[UILabel new]; label.text=s;
    label.font=[UIFont systemFontOfSize:size]; label.textColor=Ink();
    label.numberOfLines=0; return label;
}
static UIButton *Button(NSString *title,id target,SEL action) {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:Ink() forState:UIControlStateNormal];
    b.backgroundColor=[UIColor colorWithRed:.20 green:.24 blue:.30 alpha:1];
    b.layer.cornerRadius=8; b.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside]; return b;
}

@interface XJGMWindow : UIWindow @end
@implementation XJGMWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)event {
    UIView *v=[super hitTest:p withEvent:event];
    return v==self || v==self.rootViewController.view ? nil : v;
}
@end

@interface XJGMController : UIViewController <UITextFieldDelegate>
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIButton *bubble;
@property(nonatomic,strong) UILabel *subtitle;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UITextField *search;
@property(nonatomic,strong) UIButton *searchButton;
@property(nonatomic,strong) UIButton *closeButton;
@property(nonatomic,strong) UILabel *heading;
@property(nonatomic,assign) BOOL preflightPassed;
@end

@implementation XJGMController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=UIColor.clearColor;
    // Preserved from the stable branch: size, position, gesture, hitTest.
    self.bubble=Button(@"GM",self,@selector(toggle:));
    self.bubble.frame=CGRectMake(10,100,48,48);
    self.bubble.layer.cornerRadius=24;
    self.bubble.layer.borderColor=[UIColor colorWithRed:.82 green:.70 blue:.60 alpha:1].CGColor;
    self.bubble.layer.borderWidth=1;
    [self.view addSubview:self.bubble];
    UIPanGestureRecognizer *move=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
    [self.bubble addGestureRecognizer:move];

    self.panel=[UIView new];
    self.panel.backgroundColor=[UIColor colorWithRed:.085 green:.105 blue:.14 alpha:.97];
    self.panel.layer.cornerRadius=16;
    self.panel.layer.borderColor=[UIColor colorWithRed:.23 green:.29 blue:.35 alpha:1].CGColor;
    self.panel.layer.borderWidth=1;
    self.panel.layer.shadowColor=UIColor.blackColor.CGColor;
    self.panel.layer.shadowOpacity=.35;
    self.panel.layer.shadowRadius=18;
    self.panel.layer.shadowOffset=CGSizeMake(0,8);
    self.panel.hidden=YES;
    [self.view addSubview:self.panel];

    self.heading=Label(@"物品 · 配置导出 V1",17);
    self.heading.font=[UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    [self.panel addSubview:self.heading];
    self.closeButton=Button(@"收起",self,@selector(toggle:));
    [self.panel addSubview:self.closeButton];
    self.subtitle=Label(@"只读读取 ItemTmpl.configs，导出完整物品 ID 与名称。不调用 GMItemBlock，也不发送 GM 命令。",11);
    self.subtitle.textColor=Muted();
    [self.panel addSubview:self.subtitle];

    self.search=[[UITextField alloc] init];
    self.search.placeholder=@"保存到 Documents/XiuxianjiazuGM/";
    self.search.attributedPlaceholder=[[NSAttributedString alloc] initWithString:@"保存到 Documents/XiuxianjiazuGM/"
        attributes:@{NSForegroundColorAttributeName:Muted()}];
    self.search.textColor=Ink();self.search.font=[UIFont systemFontOfSize:14];
    self.search.backgroundColor=[UIColor colorWithRed:.15 green:.18 blue:.23 alpha:1];
    self.search.layer.cornerRadius=9;self.search.layer.borderWidth=1;
    self.search.layer.borderColor=[UIColor colorWithRed:.27 green:.33 blue:.39 alpha:1].CGColor;
    self.search.leftView=[[UIView alloc] initWithFrame:CGRectMake(0,0,11,1)];
    self.search.leftViewMode=UITextFieldViewModeAlways;
    self.search.enabled=NO;self.search.delegate=self;
    [self.panel addSubview:self.search];
    self.searchButton=Button(@"检查物品配置",self,@selector(runSearch:));
    self.searchButton.backgroundColor=Accent();
    [self.searchButton setTitleColor:[UIColor colorWithRed:.08 green:.15 blue:.17 alpha:1] forState:UIControlStateNormal];
    [self.panel addSubview:self.searchButton];

    self.status=Label(@"未导出 · 等游戏加载配置后点击按钮",12);
    self.status.textColor=Muted();
    [self.panel addSubview:self.status];
    [self adjustPanel];
}
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; if (!self.panel.hidden) [self adjustPanel]; }
- (void)adjustPanel {
    CGRect b=self.view.bounds;
    CGFloat w=MIN(365,MAX(280,b.size.width-24));
    CGFloat h=MIN(265,MAX(215,b.size.height-24));
    self.panel.frame=CGRectMake((b.size.width-w)/2,(b.size.height-h)/2,w,h);
    CGFloat m=17,inner=w-2*m;
    self.heading.frame=CGRectMake(m,17,inner-65,25);
    self.closeButton.frame=CGRectMake(w-71,15,54,29);
    self.subtitle.frame=CGRectMake(m,51,inner,39);
    self.search.frame=CGRectMake(m,99,inner,39);
    self.searchButton.frame=CGRectMake(m,148,inner,40);
    self.status.frame=CGRectMake(m,200,inner,MAX(40,h-207));
}
- (void)toggle:(id)sender {
    self.panel.hidden=!self.panel.hidden;
    self.bubble.hidden=!self.panel.hidden;
    if (!self.panel.hidden) [self adjustPanel];
    else [self.view endEditing:YES];
}
- (void)drag:(UIPanGestureRecognizer *)g {
    CGPoint delta=[g translationInView:self.view];
    CGPoint c=self.bubble.center;
    CGFloat hw=self.bubble.bounds.size.width/2,hh=self.bubble.bounds.size.height/2;
    self.bubble.center=CGPointMake(MAX(hw,MIN(self.view.bounds.size.width-hw,c.x+delta.x)),
        MAX(hh,MIN(self.view.bounds.size.height-hh,c.y+delta.y)));
    [g setTranslation:CGPointZero inView:self.view];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { return NO; }
- (void)runSearch:(id)sender {
    [self.view endEditing:YES];
    self.searchButton.enabled=NO;
    if (!self.preflightPassed) {
        int preflight=XJGMCheckItems();
        self.searchButton.enabled=YES;
        if (preflight==1) {
            self.preflightPassed=YES;
            [self.searchButton setTitle:@"确认导出物品列表" forState:UIControlStateNormal];
            self.status.text=@"预检通过。再次点击读取配置；异常时查看 export-stage.txt";
        } else {
            self.status.text=[NSString stringWithFormat:@"预检 E%03d：配置未就绪或无法访问",-preflight];
        }
        return;
    }
    int saved=0;
    // Export only after a successful explicit preflight.
    int result=XJGMExportItems(&saved);
    self.searchButton.enabled=YES;
    self.preflightPassed=NO;
    [self.searchButton setTitle:@"检查物品配置" forState:UIControlStateNormal];
    if (result>=0 && saved) {
        self.status.text=[NSString stringWithFormat:@"已导出 %d 条：Documents/XiuxianjiazuGM/items.json",result];
    } else if (result==-102) {
        self.status.text=@"E102：游戏配置尚未加载，进入游戏后重试";
    } else {
        self.status.text=[NSString stringWithFormat:@"E%03d：导出失败（未写入有效文件）",-result];
    }
    NSLog(@"[XJGMExportV1] user export result=%d saved=%d",result,saved);
}

@end

static XJGMController *sController=nil;
static void XJGMInstall(void) {
    if (sWindow || !UIApplication.sharedApplication) return;
    UIWindowScene *scene=nil;
    if (@available(iOS 13.0,*)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if ([s isKindOfClass:UIWindowScene.class] &&
                s.activationState==UISceneActivationStateForegroundActive) {scene=(UIWindowScene *)s;break;}
    }
    if (@available(iOS 13.0,*)) {
        if (!scene) return;
        sWindow=[[XJGMWindow alloc] initWithWindowScene:scene];
    } else sWindow=[[XJGMWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    sWindow.frame=UIScreen.mainScreen.bounds;
    sWindow.windowLevel=UIWindowLevelAlert+1;
    sWindow.backgroundColor=UIColor.clearColor;
    sController=[XJGMController new];sWindow.rootViewController=sController;
    sWindow.hidden=NO;
    // Preserve non-key window behavior.
}
__attribute__((constructor)) static void XJGMStart(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        XJGMInstall();
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
            object:nil queue:NSOperationQueue.mainQueue
            usingBlock:^(NSNotification *note) {XJGMInstall();}];
    });
}
