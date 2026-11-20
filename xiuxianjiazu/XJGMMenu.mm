#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// UI module only. Game-specific IL2CPP adapter must provide real entries and executor.
// Executor returns 0 on rejection, 1 on accepted request (not server-side success).
extern "C" int XJGMQueryItemById(int32_t id);
extern "C" int XJGMSearchItems(const char *query);
extern "C" int XJGMExportCatalog(const char *category);
extern "C" int XJGMSwitchNativeGMWindow(int enabled);
typedef int (*XJGMExecutor)(const char *kind, int32_t itemId, int32_t count, const char *argument);
static XJGMExecutor sExecutor = NULL;
static NSArray<NSDictionary *> *sItems = nil;
static NSArray<NSDictionary *> *sSkills = nil;
static NSArray<NSDictionary *> *sAttrs = nil;
static UIWindow *sWindow = nil;
static BOOL sItemsReady=NO, sSkillsReady=NO;
static NSUInteger sExportAttempts=0;
static int sItemExportCode=-299,sSkillExportCode=-299;
static int sItemExportCount=0,sSkillExportCount=0;
static BOOL sItemSaved=NO,sSkillSaved=NO;

static NSString *ExportMessage(NSString *name,BOOL ready,int code,int count,BOOL saved) {
    if (code==-299) return [NSString stringWithFormat:@"%@：等待自动导出",name];
    if (code<0) return [NSString stringWithFormat:@"%@：E%03d 导出失败，点击重新导出",name,-code];
    if (!ready) return [NSString stringWithFormat:@"%@：读取 %d 项，列表尚未就绪",name,count];
    return [NSString stringWithFormat:@"%@：%d 项，%@",name,count,saved?@"JSON 已保存":@"E109 JSON 保存失败，列表可用"];
}
static UIColor *BG(void) { return [UIColor colorWithRed:.97 green:.95 blue:.91 alpha:1]; }
static UIColor *Tan(void) { return [UIColor colorWithRed:.82 green:.70 blue:.60 alpha:1]; }
static UIColor *Ink(void) { return [UIColor colorWithRed:.30 green:.24 blue:.21 alpha:1]; }
static UIButton *Button(NSString *title, id target, SEL action) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:Ink() forState:UIControlStateNormal];
    b.backgroundColor = [Tan() colorWithAlphaComponent:.68];
    b.layer.cornerRadius = 6;
    b.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}
static UILabel *Label(NSString *text, CGFloat size) {
    UILabel *v = [UILabel new]; v.text = text; v.textColor = Ink();
    v.font = [UIFont systemFontOfSize:size]; v.numberOfLines = 2; return v;
}
static UITextField *Input(NSString *placeholder) {
    UITextField *v = [UITextField new]; v.placeholder = placeholder;
    v.font = [UIFont systemFontOfSize:13]; v.textColor = Ink();
    v.backgroundColor = [UIColor whiteColor]; v.layer.cornerRadius = 5;
    v.layer.borderWidth = .5; v.layer.borderColor = Tan().CGColor;
    v.leftView = [[UIView alloc] initWithFrame:CGRectMake(0,0,7,1)];
    v.leftViewMode = UITextFieldViewModeAlways; return v;
}

@interface XJGMWindow : UIWindow @end
@implementation XJGMWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)event {
    UIView *v = [super hitTest:p withEvent:event];
    return v == self || v == self.rootViewController.view ? nil : v;
}
@end

@interface XJGMController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate>
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIButton *bubble;
@property(nonatomic,strong) UITableView *table;
@property(nonatomic,strong) UIButton *dropdown;
@property(nonatomic,strong) UIButton *retryExportButton;
@property(nonatomic,strong) UISwitch *nativeGMSwitch;
@property(nonatomic,assign) BOOL dropdownExpanded;
@property(nonatomic,strong) UITextField *search;
@property(nonatomic,strong) UITextField *quantity;
@property(nonatomic,strong) UITextField *command;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UILabel *selection;
@property(nonatomic,strong) UISegmentedControl *tabs;
@property(nonatomic,strong) NSArray<NSDictionary *> *filtered;
@property(nonatomic,strong) NSDictionary *selected;
@property(nonatomic,assign) NSInteger page;
@property(nonatomic,assign) NSInteger tab;
@end

@implementation XJGMController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.clearColor;
    self.bubble = Button(@"GM", self, @selector(toggle:));
    self.bubble.frame = CGRectMake(10,100,48,48);
    self.bubble.layer.cornerRadius = 24;
    self.bubble.layer.borderColor = Tan().CGColor;
    self.bubble.layer.borderWidth = 1;
    [self.view addSubview:self.bubble];
    UIPanGestureRecognizer *move = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
    [self.bubble addGestureRecognizer:move];
    [self makePanel];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (!self.panel.hidden) [self adjustPanel];
}
- (void)adjustPanel {
    CGRect b = self.view.bounds;
    CGFloat w = MIN(540, MAX(290, b.size.width-20));
    CGFloat h = MIN(470, MAX(300, b.size.height-40));
    self.panel.frame = CGRectMake((b.size.width-w)/2,(b.size.height-h)/2,w,h);
    CGFloat margin=12, inner=w-2*margin;
    UILabel *title=(UILabel *)[self.panel viewWithTag:810];
    UILabel *nativeLabel=(UILabel *)[self.panel viewWithTag:814];
    UIButton *close=(UIButton *)[self.panel viewWithTag:811];
    CGFloat closeX=w-66, switchX=closeX-51;
    title.frame=CGRectMake(margin,9,MAX(80,switchX-margin-80),28);
    nativeLabel.frame=CGRectMake(switchX-72,8,68,29);
    self.nativeGMSwitch.frame=CGRectMake(switchX,7,51,31);
    close.frame=CGRectMake(closeX,8,54,29);
    self.tabs.frame=CGRectMake(margin,48,inner,30);
    self.search.frame=CGRectMake(margin,88,inner-78,30);
    UIView *lookup=[self.panel viewWithTag:813]; lookup.frame=CGRectMake(w-margin-72,88,72,30);
    self.dropdown.frame=CGRectMake(margin,125,inner-86,30);
    self.retryExportButton.frame=CGRectMake(w-margin-78,125,78,30);
    self.table.frame=CGRectMake(margin,161,inner,h-266);
    self.selection.frame=CGRectMake(margin,h-97,inner,20);
    self.quantity.frame=CGRectMake(margin,h-71,70,32);
    self.command.frame=CGRectMake(margin+76,h-71,inner-186,32);
    UIView *footer=[self.panel viewWithTag:812];
    footer.frame=CGRectMake(w-100,h-71,88,32);
    self.status.frame=CGRectMake(margin,h-39,inner,34);
}
- (void)makePanel {
    UIView *p = [UIView new]; p.backgroundColor=BG();
    p.layer.cornerRadius=9; p.layer.borderWidth=1.2; p.layer.borderColor=Tan().CGColor;
    p.layer.shadowOpacity=.20; p.layer.shadowRadius=10; p.layer.shadowOffset=CGSizeMake(0,3);
    p.hidden=YES; self.panel=p; [self.view addSubview:p];
    UILabel *title=Label(@"GM 管理",15);
    title.tag=810; title.font=[UIFont boldSystemFontOfSize:15]; title.frame=CGRectMake(12,9,80,28); [p addSubview:title];
    UILabel *nativeLabel=Label(@"原生 GM",11);
    nativeLabel.tag=814; nativeLabel.textAlignment=NSTextAlignmentRight; [p addSubview:nativeLabel];
    self.nativeGMSwitch=[UISwitch new]; self.nativeGMSwitch.onTintColor=Tan();
    [self.nativeGMSwitch addTarget:self action:@selector(nativeGMChanged:) forControlEvents:UIControlEventValueChanged];
    [p addSubview:self.nativeGMSwitch];
    UIButton *close=Button(@"收起",self,@selector(toggle:));
    close.autoresizingMask=UIViewAutoresizingFlexibleLeftMargin; close.frame=CGRectMake(0,8,54,29);
    close.tag=811; [p addSubview:close];
    self.retryExportButton=Button(@"重新导出",self,@selector(retryCurrentExport:));
    [p addSubview:self.retryExportButton];
    self.tabs=[[UISegmentedControl alloc] initWithItems:@[@"物品",@"功法",@"属性",@"GM 命令"]];
    self.tabs.selectedSegmentIndex=0; self.tabs.selectedSegmentTintColor=Tan();
    [self.tabs addTarget:self action:@selector(changeTab:) forControlEvents:UIControlEventValueChanged]; [p addSubview:self.tabs];
    self.search=Input(@"搜索名称或 ID，留空显示全部"); self.search.delegate=self;
    [self.search addTarget:self action:@selector(refresh) forControlEvents:UIControlEventEditingChanged]; [p addSubview:self.search];
    UIButton *lookup=Button(@"搜索物品",self,@selector(lookupItem:)); lookup.tag=813; [p addSubview:lookup];
    self.dropdown=Button(@"选择列表 ▼（自动导出后可选）",self,@selector(toggleDropdown:));
    self.dropdown.contentHorizontalAlignment=UIControlContentHorizontalAlignmentLeft;
    [p addSubview:self.dropdown]; self.dropdownExpanded=YES;
    self.table=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.dataSource=self; self.table.delegate=self; self.table.rowHeight=35;
    self.table.backgroundColor=UIColor.clearColor;
    [self.table registerClass:UITableViewCell.class forCellReuseIdentifier:@"row"]; [p addSubview:self.table];
    self.selection=Label(@"未选择条目",12); [p addSubview:self.selection];
    self.quantity=Input(@"数量"); self.quantity.keyboardType=UIKeyboardTypeNumberPad;
    self.quantity.text=@"1"; [p addSubview:self.quantity];
    self.command=Input(@"参数（GM 命令时输入完整命令）"); [p addSubview:self.command];
    UIButton *apply=Button(@"执行",self,@selector(execute:)); apply.tag=812; [p addSubview:apply];
    self.status=Label(@"配置自动导出后，下拉选择物品或功法",11); [p addSubview:self.status];
    [self adjustPanel];
}
- (void)toggle:(id)sender {
    self.panel.hidden = !self.panel.hidden;
    self.bubble.hidden = !self.panel.hidden;
    if (!self.panel.hidden) {
        [self adjustPanel];
        [self refresh];
    } else { [self.view endEditing:YES]; }
}
- (void)drag:(UIPanGestureRecognizer *)g {
    CGPoint delta=[g translationInView:self.view];
    CGPoint c=self.bubble.center;
    CGFloat hw=self.bubble.bounds.size.width/2, hh=self.bubble.bounds.size.height/2;
    self.bubble.center=CGPointMake(MAX(hw,MIN(self.view.bounds.size.width-hw,c.x+delta.x)),
        MAX(hh,MIN(self.view.bounds.size.height-hh,c.y+delta.y)));
    [g setTranslation:CGPointZero inView:self.view];
}
- (NSArray *)source {
    switch (self.tab) { case 0: return sItems ?: @[]; case 1: return sSkills ?: @[];
        case 2: return sAttrs ?: @[]; default: return @[]; }
}
- (void)changeTab:(UISegmentedControl *)tab {
    self.tab=tab.selectedSegmentIndex; self.selected=nil; self.page=0;
    self.search.hidden=self.tab==3; [self.panel viewWithTag:813].hidden=self.tab>1;
    self.dropdown.hidden=self.tab==3; self.retryExportButton.hidden=self.tab>1;
    self.table.hidden=self.tab==3 || !self.dropdownExpanded;
    self.quantity.hidden=self.tab==3; self.command.placeholder=self.tab==3?@"输入 GM 命令":@"可选参数";
    [self refresh];
}
- (void)toggleDropdown:(id)sender {
    self.dropdownExpanded=!self.dropdownExpanded;
    [self refresh];
}
- (void)refresh {
    NSString *query=[self.search.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].lowercaseString;
    NSArray *list=[self source];
    if (query.length) {
        NSPredicate *filter=[NSPredicate predicateWithBlock:^BOOL(NSDictionary *entry, NSDictionary *bindings) {
            NSString *name=[entry[@"name"] description] ?: @"";
            NSString *ident=[entry[@"id"] description] ?: @"";
            return [name.lowercaseString containsString:query] || [ident containsString:query];
        }];
        list=[list filteredArrayUsingPredicate:filter];
    }
    self.filtered=list; [self.table reloadData];
    self.table.hidden=self.tab==3 || !self.dropdownExpanded;
    NSString *caption=self.tab==1?@"功法":@"物品";
    [self.dropdown setTitle:[NSString stringWithFormat:@"%@列表 %@ · %lu 项（显示前200）",
        caption,self.dropdownExpanded?@"▲":@"▼",(unsigned long)list.count] forState:UIControlStateNormal];
    self.selection.text=self.selected? [NSString stringWithFormat:@"已选择：%@（ID：%@）",self.selected[@"name"],self.selected[@"id"]] : @"未选择条目";
    if (self.tab==0) self.status.text=ExportMessage(@"物品",sItemsReady,sItemExportCode,sItemExportCount,sItemSaved);
    else if (self.tab==1) self.status.text=ExportMessage(@"功法",sSkillsReady,sSkillExportCode,sSkillExportCount,sSkillSaved);
    else self.status.text=@"当前页面无可导出配置";
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return MIN((NSUInteger)200,self.filtered.count); }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"row" forIndexPath:path];
    NSDictionary *data=self.filtered[path.row];
    cell.textLabel.text=[NSString stringWithFormat:@"%@     ID：%@",data[@"name"] ?: @"",data[@"id"] ?: @""];
    cell.textLabel.font=[UIFont systemFontOfSize:13];
    cell.backgroundColor=UIColor.clearColor;
    cell.accessoryType=[data[@"id"] isEqual:self.selected[@"id"]]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    self.selected=self.filtered[path.row]; self.dropdownExpanded=NO; [self refresh];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [textField resignFirstResponder]; return YES; }
- (void)lookupItem:(id)sender {
    if (self.tab>1) return;
    [self.view endEditing:YES];
    // All searches use previously exported live config, not a runtime invocation per tap.
    [self refresh];
    self.dropdownExpanded=YES;
    self.table.hidden=NO;
    if ((self.tab==0 && sItemsReady) || (self.tab==1 && sSkillsReady))
        self.status.text=self.filtered.count?[NSString stringWithFormat:@"搜索到 %lu 项，展开列表选择",(unsigned long)self.filtered.count]:
          @"无匹配结果，请修改关键词";
}
- (void)retryCurrentExport:(id)sender {
    if (self.tab!=0 && self.tab!=1) { self.status.text=@"请切换物品或功法页面"; return; }
    [self.view endEditing:YES];
    const char* category=self.tab==0?"item":"skill";
    self.retryExportButton.enabled=NO;
    int result=XJGMExportCatalog(category);
    self.retryExportButton.enabled=YES;
    NSLog(@"[XJGM] manual export %s: %d",category,result);
}
- (void)nativeGMChanged:(UISwitch *)sender {
    int result=XJGMSwitchNativeGMWindow(sender.isOn?1:0);
    if (result!=1) {
        [sender setOn:NO animated:YES];
        self.status.text=[NSString stringWithFormat:@"调用原生 GM 失败：E%03d",-result];
        return;
    }
    if (sender.isOn) {
        self.status.text=@"已请求打开原生 GM 窗口";
        [self.view endEditing:YES];
        // Hide the overlay panel so the native game window is not covered.
        self.panel.hidden=YES;
        self.bubble.hidden=NO;
    } else {
        self.status.text=@"已请求关闭原生 GM 窗口";
    }
}
- (void)execute:(id)sender {
    if (!sExecutor) { self.status.text=@"执行失败：游戏执行桥未连接"; return; }
    int32_t itemId=0;
    if (self.tab!=3) {
        if (!self.selected) { self.status.text=@"请先选择条目"; return; }
        itemId=[self.selected[@"id"] intValue];
    }
    int32_t n=1;
    if (self.tab==0) {
        NSInteger parsed=self.quantity.text.integerValue;
        if (parsed<=0 || parsed>INT32_MAX) { self.status.text=@"数量必须在 1~2147483647 之间"; return; }
        n=(int32_t)parsed;
    }
    NSString *arg=self.command.text ?: @"";
    if (self.tab==3 && !arg.length) { self.status.text=@"请输入命令"; return; }
    [self.view endEditing:YES];
    const char *kind=self.tab==0?"item":self.tab==1?"skill":self.tab==2?"attr":"command";
    int result=sExecutor(kind,itemId,n,arg.UTF8String);
    self.status.text=result?@"请求已交给游戏执行器；未确认服务端成功":@"执行器拒绝请求（未修改游戏数据）";
}
@end

static XJGMController *sController=nil;
static void XJGMInstall(void) {
    if (sWindow || !UIApplication.sharedApplication) return;
    UIWindowScene *scene=nil;
    if (@available(iOS 13.0,*)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:UIWindowScene.class] && s.activationState==UISceneActivationStateForegroundActive) {
                scene=(UIWindowScene *)s; break;
            }
        }
    }
    if (@available(iOS 13.0,*)) {
        if (!scene) return;
        sWindow=[[XJGMWindow alloc] initWithWindowScene:scene];
    } else sWindow=[[XJGMWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    sWindow.frame=UIScreen.mainScreen.bounds;
    sWindow.windowLevel=UIWindowLevelAlert+1;
    sWindow.backgroundColor=UIColor.clearColor;
    sController=[XJGMController new]; sWindow.rootViewController=sController;
    sWindow.hidden=NO;
    // Do not make the overlay key: preserve game input and first responder.
}
extern "C" __attribute__((visibility("default"))) void XJGMSetExecutor(XJGMExecutor executor) {
    dispatch_async(dispatch_get_main_queue(), ^{ sExecutor=executor; [sController refresh]; });
}
extern "C" __attribute__((visibility("default"))) int XJGMSetEntries(const char *category, const char *json) {
    if (!category || !json) return 0;
    NSString *key=[NSString stringWithUTF8String:category];
    NSData *data=[[NSString stringWithUTF8String:json] dataUsingEncoding:NSUTF8StringEncoding];
    if (!data || data.length>8*1024*1024) return 0;
    NSArray *entries=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![entries isKindOfClass:NSArray.class]) return 0;
    NSMutableArray *valid=[NSMutableArray array];
    for (id entry in entries) {
        if (![entry isKindOfClass:NSDictionary.class] || ![entry[@"id"] isKindOfClass:NSNumber.class] ||
            ![entry[@"name"] isKindOfClass:NSString.class]) return 0;
        [valid addObject:@{@"id":entry[@"id"],@"name":entry[@"name"]}];
    }
    if (![@[@"item",@"skill",@"attr"] containsObject:key]) return 0;
    NSArray *snapshot=[valid copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([key isEqualToString:@"item"]) { sItems=snapshot; sItemsReady=(snapshot.count>0); }
        else if ([key isEqualToString:@"skill"]) { sSkills=snapshot; sSkillsReady=(snapshot.count>0); }
        else sAttrs=snapshot;
        [sController refresh];
    });
    return 1;
}
// Retry only while the game's managed config is still unavailable.
// Timer runs on main queue to preserve the game's lifecycle assumptions.
extern "C" __attribute__((visibility("default"))) void XJGMReportExport(const char *category,int result,int saved) {
    if (!category) return;
    NSString *key=[NSString stringWithUTF8String:category];
    if (![@[@"item",@"skill"] containsObject:key]) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([key isEqualToString:@"item"]) {
            sItemExportCode=result; sItemSaved=saved!=0;
            if (result>=0) sItemExportCount=result;
        } else {
            sSkillExportCode=result; sSkillSaved=saved!=0;
            if (result>=0) sSkillExportCount=result;
        }
        [sController refresh];
    });
}
static void XJGMStartExport(void) {
    static dispatch_source_t source=nil;
    if (source) return;
    source=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
    dispatch_source_set_timer(source,dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),
                              3*NSEC_PER_SEC,250*NSEC_PER_MSEC);
    dispatch_source_set_event_handler(source,^{
        if (sItemsReady && sSkillsReady) {
            dispatch_source_cancel(source); return;
        }
        if (++sExportAttempts>60) {
            NSLog(@"[XJGM] automatic retries exhausted; manual retry remains available");
            dispatch_source_cancel(source); return;
        }
        if (!sItemsReady) {
            int status=XJGMExportCatalog("item");
            if (status<0 && (sExportAttempts%5)==1) NSLog(@"[XJGM] item export error %d",status);
        }
        if (!sSkillsReady) {
            int status=XJGMExportCatalog("skill");
            if (status<0 && (sExportAttempts%5)==1) NSLog(@"[XJGM] skill export error %d",status);
        }
    });
    dispatch_resume(source);
}
__attribute__((constructor)) static void XJGMStart(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        XJGMInstall();
        XJGMStartExport();
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil
            queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { XJGMInstall(); }];
    });
}
