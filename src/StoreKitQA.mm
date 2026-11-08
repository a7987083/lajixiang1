#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import <dispatch/dispatch.h>
#import <stdio.h>
#import <math.h>
#include "QAProducts.h"

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
@property(nonatomic,strong) NSArray<NSDictionary *> *products;
@property(nonatomic,assign) NSInteger selectedIndex;
@property(nonatomic,strong) UILabel *detail;
@property(nonatomic,strong) UIScrollView *productList;
@property(nonatomic,strong) UILabel *inventoryLabel;
@property(nonatomic,assign) CGPoint panStart;
@property(nonatomic,assign) CGPoint bubbleStart;
@property(nonatomic,assign) BOOL dragged;
@property(nonatomic,assign) NSInteger retries;
@end
@implementation StoreKitQAPanel
- (void)loadQAProducts {
    NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"PaySettings.qa.json"];
    NSData *data=[NSData dataWithContentsOfFile:path];
    BOOL overridden=data!=nil;
    if (!data) data=[[NSString stringWithUTF8String:kQAProductsJSON] dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error=nil;
    id parsed=[NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (![parsed isKindOfClass:NSArray.class]) {
        QALog([NSString stringWithFormat:@"QA catalog invalid %@, falling back to bundled snapshot",error]);
        parsed=[NSJSONSerialization JSONObjectWithData:[[NSString stringWithUTF8String:kQAProductsJSON] dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        overridden=NO;
    }
    NSMutableArray *valid=[NSMutableArray new];
    NSMutableSet *ids=[NSMutableSet new];
    for (id item in (NSArray *)parsed) {
        if (![item isKindOfClass:NSDictionary.class] || ![item[@"Id"] isKindOfClass:NSNumber.class]) continue;
        NSNumber *sku=item[@"Id"];
        if ([ids containsObject:sku]) continue;
        [ids addObject:sku];
        [valid addObject:item];
    }
    self.products=[valid copy];
    self.selectedIndex=0;
    QALog([NSString stringWithFormat:@"QA catalog loaded count=%lu source=%@",(unsigned long)valid.count,overridden?@"Documents/PaySettings.qa.json":@"bundled PaySettings 2.json"]);
}
- (void)updateSelection {
    if (!self.products.count) { self.detail.text=@"No QA products"; return; }
    NSDictionary *p=self.products[self.selectedIndex];
    self.detail.text=[NSString stringWithFormat:@"ID %@ · Type %@ · Medal %@ · General %@",
      p[@"Id"],p[@"Type"]?:@0,p[@"Medal"]?:@0,p[@"GeneralId"]?:@0];
    for (UIView *v in self.productList.subviews) {
        if (![v isKindOfClass:UIButton.class]) continue;
        UIButton *b=(UIButton *)v;
        b.backgroundColor=(b.tag==self.selectedIndex)
          ? [UIColor colorWithRed:0.08 green:0.42 blue:0.53 alpha:1]
          : [UIColor colorWithWhite:0.20 alpha:1];
    }
}
- (void)selectProduct:(UIButton *)sender {
    if (sender.tag<0 || sender.tag>=self.products.count) return;
    self.selectedIndex=sender.tag;
    [self updateSelection];
    QALog([NSString stringWithFormat:@"QA selected internal product Id=%@",self.products[self.selectedIndex][@"Id"]]);
}
// This ledger is isolated from host-game saves, StoreKit, receipts and entitlements.
- (NSString *)inventoryPath {
    NSString *dir=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    return [dir stringByAppendingPathComponent:@"storekit-qa-inventory.json"];
}
- (NSMutableDictionary *)inventorySnapshot {
    NSData *data=[NSData dataWithContentsOfFile:[self inventoryPath]];
    id value=data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil] : nil;
    if (![value isKindOfClass:NSDictionary.class] || ![value[@"qaOnly"] isEqual:@YES])
        return [@{@"qaOnly":@YES,@"medals":@0,@"generals":[NSMutableArray new],
                  @"extraArmy":[NSMutableArray new],@"items":[NSMutableDictionary new],
                  @"deliveries":@0} mutableCopy];
    return [value mutableCopy];
}
- (void)updateInventoryLabel {
    NSDictionary *inv=[self inventorySnapshot];
    self.inventoryLabel.text=[NSString stringWithFormat:@"QA Inventory: medals=%@  generals=%lu  orders=%@",
        inv[@"medals"]?:@0,(unsigned long)[inv[@"generals"] count],inv[@"deliveries"]?:@0];
}
- (void)showInventory:(id)sender {
    NSDictionary *inv=[self inventorySnapshot];
    NSString *message=[NSString stringWithFormat:@"QA medals: %@\nGenerals: %@\nExtra army: %@\nItems: %@\nSimulated orders: %@\n\nNot added to the real game.",
       inv[@"medals"],inv[@"generals"],inv[@"extraArmy"],inv[@"items"],inv[@"deliveries"]];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"QA Inventory (isolated)"
      message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
}
- (void)resetInventory:(id)sender {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"Clear QA inventory?"
      message:@"This clears only the isolated QA test ledger. Game data is not modified."
      preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Clear" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        BOOL ok=[[NSFileManager defaultManager] removeItemAtPath:[self inventoryPath] error:nil];
        self.status.text=@"QA inventory reset";
        QALog([NSString stringWithFormat:@"QA inventory reset existed=%d",ok]);
        [self updateInventoryLabel];
    }]];
    [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
}
- (BOOL)deliverMockProduct:(NSDictionary *)product {
    NSMutableDictionary *inv=[self inventorySnapshot];
    long long medal=[product[@"Medal"] respondsToSelector:@selector(longLongValue)] ? [product[@"Medal"] longLongValue] : 0;
    if (medal>0 && medal<=100000000)
        inv[@"medals"]=@([inv[@"medals"] longLongValue]+medal);
    NSMutableSet *generals=[NSMutableSet setWithArray:[inv[@"generals"] isKindOfClass:NSArray.class]?inv[@"generals"]:@[]];
    for (NSString *field in @[@"GeneralId",@"GeneralId2"]) {
        id g=product[field];
        if ([g respondsToSelector:@selector(integerValue)] && [g integerValue]>0) [generals addObject:g];
    }
    inv[@"generals"]=[[generals allObjects] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableSet *extra=[NSMutableSet setWithArray:[inv[@"extraArmy"] isKindOfClass:NSArray.class]?inv[@"extraArmy"]:@[]];
    if ([product[@"ExArmyId"] isKindOfClass:NSArray.class])
        for (id v in product[@"ExArmyId"]) if ([v respondsToSelector:@selector(integerValue)] && [v integerValue]>0) [extra addObject:v];
    inv[@"extraArmy"]=[[extra allObjects] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableDictionary *items=[([inv[@"items"] isKindOfClass:NSDictionary.class]?inv[@"items"]:@{}) mutableCopy];
    NSArray *pairs=[product[@"ItemIds"] isKindOfClass:NSArray.class] ? product[@"ItemIds"] : @[];
    for (NSUInteger i=0;i+1<pairs.count;i+=2) {
        NSInteger code=[pairs[i] integerValue], count=[pairs[i+1] integerValue];
        if (code<=0 || count<=0 || count>10000000) continue;
        NSString *key=[NSString stringWithFormat:@"%ld",(long)code];
        items[key]=@([items[key] longLongValue]+count);
    }
    inv[@"items"]=items;
    inv[@"deliveries"]=@([inv[@"deliveries"] integerValue]+1);
    NSData *json=[NSJSONSerialization dataWithJSONObject:inv options:NSJSONWritingPrettyPrinted error:nil];
    NSError *error=nil;
    BOOL ok=json && [json writeToFile:[self inventoryPath] options:NSDataWritingAtomic error:&error];
    QALog([NSString stringWithFormat:@"QA mock delivery id=%@ recorded=%d error=%@ (isolated only)",product[@"Id"],ok,error]);
    [self updateInventoryLabel];
    return ok;
}
- (void)simulate:(UIButton *)sender {
    NSArray *states=@[@"success",@"cancelled",@"failed",@"restored"];
    NSInteger index=sender.tag;
    if (index<0 || index>=states.count || !self.products.count) return;
    NSDictionary *product=self.products[self.selectedIndex];
    NSString *state=states[index];
    BOOL delivered=[state isEqualToString:@"success"] ? [self deliverMockProduct:product] : NO;
    self.status.text=[NSString stringWithFormat:@"QA %@ · ID %@ %@",state,product[@"Id"], delivered?@"recorded":@""];
    NSDictionary *event=@{@"time":@([[NSDate date] timeIntervalSince1970]),
      @"kind":@"local_qa", @"outcome":state, @"mockDeliveryRecorded":@(delivered), @"internalProductId":product[@"Id"],
      @"type":product[@"Type"]?:@0,@"medal":product[@"Medal"]?:@0,
      @"generalId":product[@"GeneralId"]?:@0,@"items":product[@"ItemIds"]?:@[]};
    NSData *json=[NSJSONSerialization dataWithJSONObject:event options:NSJSONWritingFragmentsAllowed error:nil];
    NSString *line=[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    NSString *dir=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    NSString *path=[dir stringByAppendingPathComponent:@"storekit-qa-events.jsonl"];
    NSFileHandle *handle=[NSFileHandle fileHandleForWritingAtPath:path];
    NSString *record=[line stringByAppendingString:@"\n"];
    if (handle) {
        @try { [handle seekToEndOfFile]; [handle writeData:[record dataUsingEncoding:NSUTF8StringEncoding]]; }
        @finally { [handle closeFile]; }
    } else {
        [record writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    QALog([NSString stringWithFormat:@"SYNTHETIC state=%@ internalSKU=%@ no StoreKit, receipt, payment or game reward",state,product[@"Id"]]);
}
- (void)positionMenu {
    if (!self.window || !self.bubble || !self.menu) return;
    CGRect bounds=self.window.bounds;
    UIEdgeInsets safe=self.window.safeAreaInsets;
    CGFloat width=MIN(254, MAX(190, bounds.size.width-24));
    CGFloat height=MIN(490, MAX(350, bounds.size.height-safe.top-safe.bottom-16));
    CGFloat x=CGRectGetMidX(self.bubble.frame)-width/2;
    x=MAX(12,MIN(x,bounds.size.width-width-12));
    CGFloat y=CGRectGetMaxY(self.bubble.frame)+8;
    if (y+height>bounds.size.height-safe.bottom-8)
        y=CGRectGetMinY(self.bubble.frame)-height-8;
    y=MAX(safe.top+8,MIN(y,MAX(safe.top+8,bounds.size.height-safe.bottom-height-8)));
    self.menu.frame=CGRectMake(x,y,width,height);
    self.productList.frame=CGRectMake(12,92,width-24,MAX(48,height-315));
    self.detail.frame=CGRectMake(12,66,width-24,23);
    self.inventoryLabel.frame=CGRectMake(12,height-49,width-24,18);
    for (UIView *v in self.menu.subviews) if ([v isKindOfClass:UIButton.class]) { UIButton *b=(UIButton *)v; if (b.tag>=100) b.frame=CGRectMake(b.tag==100?12:width/2+2,height-27,width/2-14,24); }
    for (UIView *v in self.menu.subviews) {
        if ([v isKindOfClass:UIButton.class] && v.tag<100) { UIButton *b=(UIButton *)v; b.frame=CGRectMake(12,height-189+b.tag*35,width-24,30); }
    }
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

    [self loadQAProducts];
    UIView *menu=[[UIView alloc] initWithFrame:CGRectMake(12,170,254,490)];
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
    UILabel *detail=[[UILabel alloc] initWithFrame:CGRectMake(12,66,230,23)];
    detail.textColor=UIColor.whiteColor; detail.font=[UIFont systemFontOfSize:11];
    [menu addSubview:detail]; self.detail=detail;
    UIScrollView *list=[[UIScrollView alloc] initWithFrame:CGRectMake(12,92,230,145)];
    list.backgroundColor=[UIColor colorWithWhite:0.10 alpha:1];
    list.layer.cornerRadius=6;
    [menu addSubview:list]; self.productList=list;
    for (NSInteger i=0;i<self.products.count;i++) {
        NSDictionary *p=self.products[i];
        UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
        button.tag=i; button.frame=CGRectMake(2,i*32+2,226,29);
        button.titleLabel.font=[UIFont systemFontOfSize:12];
        [button setTitle:[NSString stringWithFormat:@"ID %@ | Type %@ | Medal %@ | General %@",p[@"Id"],p[@"Type"]?:@0,p[@"Medal"]?:@0,p[@"GeneralId"]?:@0] forState:UIControlStateNormal];
        [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        [button addTarget:self action:@selector(selectProduct:) forControlEvents:UIControlEventTouchUpInside];
        [list addSubview:button];
    }
    list.contentSize=CGSizeMake(230,self.products.count*32+4);
    NSArray *names=@[@"Mock success",@"Mock cancel",@"Mock fail",@"Mock restore"];
    for (NSInteger i=0;i<names.count;i++) {
       UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
       button.tag=i; button.frame=CGRectMake(12,245+i*38,230,32);
       button.layer.cornerRadius=6;
       button.backgroundColor=[UIColor colorWithWhite:0.2 alpha:1];
       [button setTitle:names[i] forState:UIControlStateNormal];
       [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
       [button addTarget:self action:@selector(simulate:) forControlEvents:UIControlEventTouchUpInside];
       [menu addSubview:button];
    }
    UILabel *inventoryLabel=[[UILabel alloc] initWithFrame:CGRectMake(12,445,230,18)];
    inventoryLabel.font=[UIFont systemFontOfSize:10];
    inventoryLabel.textColor=UIColor.lightGrayColor;
    [menu addSubview:inventoryLabel]; self.inventoryLabel=inventoryLabel;
    for (NSInteger i=0;i<2;i++) {
       UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
       button.frame=CGRectMake(i==0?12:131,462,111,25);
       button.tag=100+i;
       button.layer.cornerRadius=5;
       button.backgroundColor=[UIColor colorWithWhite:0.22 alpha:1];
       [button setTitle:i==0?@"QA Inventory":@"Clear QA" forState:UIControlStateNormal];
       [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
       [button addTarget:self action:i==0?@selector(showInventory:):@selector(resetInventory:) forControlEvents:UIControlEventTouchUpInside];
       [menu addSubview:button];
    }
    [self updateSelection];
    [self updateInventoryLabel];
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
