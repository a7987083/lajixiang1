#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import <dispatch/dispatch.h>
#import <stdio.h>

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
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) StoreKitQAObserver *observer;
@end
@implementation StoreKitQAPanel
- (void)simulate:(UIButton *)sender {
    NSArray *states=@[@"SUCCESS (mock)",@"CANCELLED (mock)",@"FAILED (mock)",@"RESTORED (mock)"];
    NSInteger index=sender.tag;
    if (index<0 || index>=states.count) return;
    self.status.text=[NSString stringWithFormat:@"QA: %@",states[index]];
    QALog([NSString stringWithFormat:@"SYNTHETIC %@; no transaction, no rewards, no receipt",states[index]]);
}
- (void)toggle:(UIButton *)sender {
    UIView *panel=[self.window viewWithTag:9001];
    panel.hidden=!panel.hidden;
}
- (void)start {
    if (self.window) return;
    CGRect frame=[UIScreen mainScreen].bounds;
    UIWindow *w=[[UIWindow alloc] initWithFrame:frame];
    w.windowLevel=UIWindowLevelAlert+12;
    w.backgroundColor=[UIColor clearColor];
    w.rootViewController=[UIViewController new];
    w.rootViewController.view.backgroundColor=[UIColor clearColor];
    w.hidden=NO;
    self.window=w;
    UIButton *toggle=[UIButton buttonWithType:UIButtonTypeSystem];
    toggle.frame=CGRectMake(12,110,64,40);
    toggle.backgroundColor=[UIColor colorWithRed:0.07 green:0.13 blue:0.20 alpha:0.95];
    toggle.layer.cornerRadius=10;
    [toggle setTitle:@"IAP QA" forState:UIControlStateNormal];
    [toggle setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [toggle addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventTouchUpInside];
    [w.rootViewController.view addSubview:toggle];
    UIView *panel=[[UIView alloc] initWithFrame:CGRectMake(12,160,245,240)];
    panel.tag=9001; panel.hidden=YES;
    panel.layer.cornerRadius=12;
    panel.backgroundColor=[UIColor colorWithRed:0.07 green:0.10 blue:0.15 alpha:0.97];
    [w.rootViewController.view addSubview:panel];
    UILabel *title=[[UILabel alloc] initWithFrame:CGRectMake(12,8,225,32)];
    title.text=@"StoreKit 1 · QA ONLY";
    title.textColor=UIColor.whiteColor;
    [panel addSubview:title];
    self.status=[[UILabel alloc] initWithFrame:CGRectMake(12,38,225,30)];
    self.status.text=@"No Apple purchase simulated";
    self.status.font=[UIFont systemFontOfSize:12];
    self.status.textColor=UIColor.lightGrayColor;
    [panel addSubview:self.status];
    NSArray *names=@[@"Mock success",@"Mock cancel",@"Mock fail",@"Mock restore"];
    for (NSInteger i=0;i<names.count;i++) {
       UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
       b.tag=i;
       b.frame=CGRectMake(12,73+i*39,220,34);
       b.layer.cornerRadius=6;
       b.backgroundColor=[UIColor colorWithWhite:0.2 alpha:1];
       [b setTitle:names[i] forState:UIControlStateNormal];
       [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
       [b addTarget:self action:@selector(simulate:) forControlEvents:UIControlEventTouchUpInside];
       [panel addSubview:b];
    }
    self.observer=[StoreKitQAObserver new];
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self.observer];
    QALog(@"QA started, passive SKPaymentQueue observer attached");
}
@end
static StoreKitQAPanel *gQA;
__attribute__((constructor)) static void StoreKitQAEntry(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        gQA=[StoreKitQAPanel new];
        [gQA start];
    });
}
