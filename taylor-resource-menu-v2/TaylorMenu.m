#import <UIKit/UIKit.h>
#import "TaylorResourceMenu.h"

@interface TaylorWindow : UIWindow
@end
@implementation TaylorWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
  UIView *v = [super hitTest:p withEvent:e];
  return (!v || v == self || v == self.rootViewController.view) ? nil : v;
}
@end
@interface TaylorMenu : UIViewController <UITextFieldDelegate>
@property(nonatomic,strong) UIButton *bubble;
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UITextField *amount;
@property(nonatomic,strong) UILabel *feedback;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,weak) UIWindow *previousKey;
@property(nonatomic) CGPoint dragOrigin;
@end
@implementation TaylorMenu
- (void)loadView {
  self.view = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.view.backgroundColor = UIColor.clearColor;
}
- (UIButton *)button:(NSString *)title tag:(NSInteger)tag frame:(CGRect)frame {
  UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
  b.frame = frame; b.tag = tag; b.layer.cornerRadius = 9;
  b.backgroundColor = [UIColor colorWithRed:0.12 green:0.22 blue:0.28 alpha:1];
  [b setTitleColor:[UIColor colorWithRed:0.4 green:1 blue:0.86 alpha:1] forState:UIControlStateNormal];
  [b setTitle:title forState:UIControlStateNormal];
  b.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
  [b addTarget:self action:@selector(tap:) forControlEvents:UIControlEventTouchUpInside];
  return b;
}
- (void)viewDidLoad {
  [super viewDidLoad];
  self.bubble = [self button:@"T" tag:9 frame:CGRectMake(14,140,46,46)];
  self.bubble.layer.cornerRadius = 23;
  [self.bubble addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)]];
  [self.view addSubview:self.bubble];
  self.panel = [[UIView alloc] initWithFrame:CGRectMake(68,120,270,300)];
  self.panel.backgroundColor = [UIColor colorWithRed:0.035 green:0.065 blue:0.09 alpha:0.97];
  self.panel.layer.cornerRadius = 14;
  self.panel.layer.borderWidth = 1;
  self.panel.layer.borderColor = [UIColor colorWithRed:0.18 green:0.55 blue:0.48 alpha:1].CGColor;
  UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(14,10,240,24)];
  title.text = @"Taylor · 资源测试 V2"; title.textColor = UIColor.whiteColor;
  title.font = [UIFont boldSystemFontOfSize:16]; [self.panel addSubview:title];
  UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(14,43,90,32)];
  label.text = @"增加数量"; label.textColor = UIColor.lightGrayColor;
  label.font = [UIFont systemFontOfSize:14]; [self.panel addSubview:label];
  self.amount = [[UITextField alloc] initWithFrame:CGRectMake(110,43,144,32)];
  self.amount.text = @"10"; self.amount.placeholder = @"1–100";
  self.amount.textColor = UIColor.whiteColor; self.amount.textAlignment = NSTextAlignmentCenter;
  self.amount.backgroundColor = [UIColor colorWithWhite:0.14 alpha:1]; self.amount.layer.cornerRadius = 6;
  self.amount.keyboardType = UIKeyboardTypeNumberPad; self.amount.delegate = self;
  UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0,0,270,44)];
  toolbar.items = @[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],
                    [[UIBarButtonItem alloc] initWithTitle:@"完成" style:UIBarButtonItemStyleDone target:self action:@selector(endInput)]];
  self.amount.inputAccessoryView = toolbar; [self.panel addSubview:self.amount];
  NSArray<NSString *> *names = @[@"增加钻石", @"增加体力", @"增加星星"];
  for (NSInteger i=0; i<3; i++) [self.panel addSubview:[self button:names[i] tag:i+1 frame:CGRectMake(14,85+i*40,240,34)]];
  [self.panel addSubview:[self button:@"刷新余额" tag:0 frame:CGRectMake(14,209,240,30)]];
  self.feedback = [[UILabel alloc] initWithFrame:CGRectMake(14,245,240,48)];
  self.feedback.textColor = UIColor.lightGrayColor; self.feedback.numberOfLines = 3;
  self.feedback.font = [UIFont systemFontOfSize:11]; [self.panel addSubview:self.feedback];
  self.panel.hidden = YES; [self.view addSubview:self.panel];
  [self.view bringSubviewToFront:self.bubble];
  __weak TaylorMenu *weakSelf = self;
  self.timer = [NSTimer scheduledTimerWithTimeInterval:0.4 repeats:YES block:^(NSTimer *timer) {
    (void)timer; [weakSelf poll];
  }];
  [self poll];
}
- (void)poll {
  char s[768]; TaylorResourceStatus(s,sizeof(s));
  self.feedback.text = [NSString stringWithUTF8String:s] ?: @"状态文本不可读";
}
- (void)tap:(UIButton *)sender {
  if (sender.tag == 9) { [self endInput]; self.panel.hidden = !self.panel.hidden; return; }
  [self endInput];
  int n = 0;
  if (sender.tag != 0) {
    NSString *text = self.amount.text ?: @"";
    NSCharacterSet *bad = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet];
    if (text.length == 0 || text.length > 3 || [text rangeOfCharacterFromSet:bad].location != NSNotFound
        || text.integerValue < 1 || text.integerValue > 100) {
      self.feedback.text = @"请输入 1–100 的整数"; return;
    }
    n = (int)text.integerValue;
  }
  if (!TaylorResourceRequest((int)sender.tag,n)) self.feedback.text = @"尚未接入、已停用或仍有请求待处理";
  else [self poll];
}
- (BOOL)textFieldShouldBeginEditing:(UITextField *)field {
  (void)field;
  UIWindow *ours = self.view.window;
  for (UIWindow *w in UIApplication.sharedApplication.windows) {
    if (w.isKeyWindow && w != ours) { self.previousKey = w; break; }
  }
  [ours makeKeyWindow];
  return YES;
}
- (void)textFieldDidEndEditing:(UITextField *)field {
  (void)field; [self.previousKey makeKeyWindow]; self.previousKey = nil;
}
- (void)endInput { [self.amount resignFirstResponder]; }
- (void)drag:(UIPanGestureRecognizer *)g {
  if (g.state == UIGestureRecognizerStateBegan) { [self endInput]; self.dragOrigin = self.bubble.center; }
  CGPoint t = [g translationInView:self.view];
  self.bubble.center = CGPointMake(self.dragOrigin.x+t.x,self.dragOrigin.y+t.y);
  [self.view setNeedsLayout];
}
- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  CGRect r = UIEdgeInsetsInsetRect(self.view.bounds,self.view.safeAreaInsets);
  CGPoint c = self.bubble.center;
  c.x = MAX(CGRectGetMinX(r)+23,MIN(CGRectGetMaxX(r)-23,c.x));
  c.y = MAX(CGRectGetMinY(r)+23,MIN(CGRectGetMaxY(r)-23,c.y)); self.bubble.center = c;
  CGFloat x = c.x+28;
  if (x+270 > CGRectGetMaxX(r)) x = c.x-298;
  x = MAX(CGRectGetMinX(r)+4,MIN(CGRectGetMaxX(r)-274,x));
  CGFloat y = MAX(CGRectGetMinY(r)+4,MIN(CGRectGetMaxY(r)-304,c.y-26));
  self.panel.frame = CGRectMake(x,y,270,300);
}
- (void)dealloc { [self.timer invalidate]; }
@end
static TaylorWindow *overlay;
static void attach_overlay(unsigned retry) {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (overlay) return;
    UIApplication *app = UIApplication.sharedApplication;
    UIWindow *game = nil;
    for (UIWindow *w in app.windows) if (w.isKeyWindow && !w.hidden) { game = w; break; }
    if (!game || app.applicationState != UIApplicationStateActive) {
      if (retry < 120) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),dispatch_get_main_queue(),^{attach_overlay(retry+1);});
      return;
    }
    if (@available(iOS 13.0,*)) {
      if (game.windowScene) overlay = [[TaylorWindow alloc] initWithWindowScene:game.windowScene];
    }
    if (!overlay) overlay = [[TaylorWindow alloc] initWithFrame:game.bounds];
    overlay.frame = game.bounds; overlay.backgroundColor = UIColor.clearColor;
    overlay.windowLevel = UIWindowLevelAlert-2;
    overlay.rootViewController = [TaylorMenu new]; overlay.hidden = NO;
  });
}
// Called exactly once by the runtime after the compatibility signature and
// Hook trampoline are both verified. A mismatched image creates no UI.
void TaylorResourceMenuActivate(void) { attach_overlay(0); }
