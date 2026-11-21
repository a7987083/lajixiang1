#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// External JSON viewer only. No IL2CPP runtime calls or GM command emission.
static UIWindow *sWindow=nil;
static UIColor *Ink(void) { return [UIColor colorWithRed:.91 green:.93 blue:.97 alpha:1]; }
static UIColor *Muted(void) { return [UIColor colorWithRed:.60 green:.66 blue:.76 alpha:1]; }
static UIColor *Accent(void) { return [UIColor colorWithRed:.47 green:.82 blue:.76 alpha:1]; }
static UILabel *Label(NSString *s,CGFloat size) {
    UILabel *v=[UILabel new]; v.text=s; v.textColor=Ink();
    v.font=[UIFont systemFontOfSize:size]; v.numberOfLines=0; return v;
}
static UIButton *Button(NSString *s,id target,SEL action) {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem]; [b setTitle:s forState:UIControlStateNormal];
    [b setTitleColor:Ink() forState:UIControlStateNormal];
    b.backgroundColor=[UIColor colorWithRed:.20 green:.24 blue:.30 alpha:1];
    b.layer.cornerRadius=8; b.titleLabel.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside]; return b;
}
static NSString *CleanName(NSString *s) {
    static NSRegularExpression *regex=nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        regex=[NSRegularExpression regularExpressionWithPattern:@"<[^>]*>" options:0 error:nil];
    });
    return [regex stringByReplacingMatchesInString:s options:0 range:NSMakeRange(0,s.length) withTemplate:@""];
}

@interface XJGMWindow : UIWindow @end
@implementation XJGMWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)event {
    UIView *v=[super hitTest:p withEvent:event];
    return v==self || v==self.rootViewController.view ? nil : v;
}
@end

@interface XJGMController : UIViewController <UITableViewDataSource,UITableViewDelegate,UITextFieldDelegate>
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIButton *bubble;
@property(nonatomic,strong) UIButton *closeButton;
@property(nonatomic,strong) UIButton *reloadButton;
@property(nonatomic,strong) UIButton *groupButton;
@property(nonatomic,strong) UIButton *qualityButton;
@property(nonatomic,strong) UITextField *search;
@property(nonatomic,strong) UITableView *table;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UILabel *selection;
@property(nonatomic,strong) NSArray<NSDictionary *> *allItems;
@property(nonatomic,strong) NSArray<NSDictionary *> *filtered;
@property(nonatomic,strong) NSArray<NSString *> *groups;
@property(nonatomic,strong) NSDictionary *selected;
@property(nonatomic,assign) NSUInteger groupIndex;
@property(nonatomic,assign) NSUInteger qualityIndex;
@end
@implementation XJGMController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=UIColor.clearColor;
    self.bubble=Button(@"GM",self,@selector(toggle:));
    self.bubble.frame=CGRectMake(10,100,48,48);
    self.bubble.layer.cornerRadius=24;
    self.bubble.layer.borderColor=[UIColor colorWithRed:.82 green:.70 blue:.60 alpha:1].CGColor;
    self.bubble.layer.borderWidth=1;
    [self.view addSubview:self.bubble];
    UIPanGestureRecognizer *move=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)];
    [self.bubble addGestureRecognizer:move];

    UIView *p=[UIView new];self.panel=p;p.hidden=YES;
    p.backgroundColor=[UIColor colorWithRed:.085 green:.105 blue:.14 alpha:.97];
    p.layer.cornerRadius=16;p.layer.borderColor=[UIColor colorWithRed:.23 green:.29 blue:.35 alpha:1].CGColor;
    p.layer.borderWidth=1;p.layer.shadowColor=UIColor.blackColor.CGColor;
    p.layer.shadowOpacity=.35;p.layer.shadowRadius=18;p.layer.shadowOffset=CGSizeMake(0,8);
    [self.view addSubview:p];
    UILabel *header=Label(@"物品列表 · 外部 JSON",16);
    header.font=[UIFont systemFontOfSize:16 weight:UIFontWeightBold];header.tag=901;[p addSubview:header];
    self.closeButton=Button(@"收起",self,@selector(toggle:));[p addSubview:self.closeButton];
    self.reloadButton=Button(@"重新加载",self,@selector(loadItems:));[p addSubview:self.reloadButton];
    self.search=[UITextField new];self.search.placeholder=@"搜索名称或 ID";
    self.search.attributedPlaceholder=[[NSAttributedString alloc] initWithString:@"搜索名称或 ID" attributes:@{NSForegroundColorAttributeName:Muted()}];
    self.search.backgroundColor=[UIColor colorWithRed:.15 green:.18 blue:.23 alpha:1];
    self.search.textColor=Ink();self.search.font=[UIFont systemFontOfSize:14];
    self.search.layer.cornerRadius=8;self.search.leftView=[[UIView alloc] initWithFrame:CGRectMake(0,0,9,1)];
    self.search.leftViewMode=UITextFieldViewModeAlways;self.search.delegate=self;
    [self.search addTarget:self action:@selector(filterItems) forControlEvents:UIControlEventEditingChanged];[p addSubview:self.search];
    self.groupButton=Button(@"ID 分组：全部",self,@selector(nextGroup:));[p addSubview:self.groupButton];
    self.qualityButton=Button(@"品质：全部",self,@selector(nextQuality:));[p addSubview:self.qualityButton];
    self.table=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.table.dataSource=self;self.table.delegate=self;self.table.rowHeight=43;
    self.table.backgroundColor=UIColor.clearColor;
    [self.table registerClass:UITableViewCell.class forCellReuseIdentifier:@"entry"];[p addSubview:self.table];
    self.selection=Label(@"点击物品可复制 ID",12);[p addSubview:self.selection];
    self.status=Label(@"只读取 Documents/XiuxianjiazuGM/items.json",11);
    self.status.textColor=Muted();[p addSubview:self.status];
    self.allItems=@[];self.filtered=@[];self.groups=@[@"全部"];
    [self adjustPanel];
}
- (void)viewDidLayoutSubviews {[super viewDidLayoutSubviews];if (!self.panel.hidden) [self adjustPanel];}
- (void)adjustPanel {
    CGRect b=self.view.bounds;CGFloat w=MIN(405,MAX(285,b.size.width-20));
    CGFloat h=MIN(560,MAX(310,b.size.height-35));
    self.panel.frame=CGRectMake((b.size.width-w)/2,(b.size.height-h)/2,w,h);
    CGFloat m=12,inner=w-2*m;
    [self.panel viewWithTag:901].frame=CGRectMake(m,10,inner-62,30);
    self.closeButton.frame=CGRectMake(w-67,11,55,28);
    self.reloadButton.frame=CGRectMake(m,48,86,30);
    self.search.frame=CGRectMake(m+94,48,inner-94,30);
    self.groupButton.frame=CGRectMake(m,88,(inner-8)*.57,30);
    self.qualityButton.frame=CGRectMake(m+(inner-8)*.57+8,88,(inner-8)*.43,30);
    self.table.frame=CGRectMake(m,126,inner,h-211);
    self.selection.frame=CGRectMake(m,h-77,inner,28);
    self.status.frame=CGRectMake(m,h-49,inner,39);
}
- (void)toggle:(id)sender {
    self.panel.hidden=!self.panel.hidden;
    self.bubble.hidden=!self.panel.hidden;
    if (!self.panel.hidden) {[self adjustPanel];if (!self.allItems.count) [self loadItems:nil];}
    else [self.view endEditing:YES];
}
- (void)drag:(UIPanGestureRecognizer *)g {
    CGPoint delta=[g translationInView:self.view];CGPoint c=self.bubble.center;
    CGFloat hw=self.bubble.bounds.size.width/2,hh=self.bubble.bounds.size.height/2;
    self.bubble.center=CGPointMake(MAX(hw,MIN(self.view.bounds.size.width-hw,c.x+delta.x)),
        MAX(hh,MIN(self.view.bounds.size.height-hh,c.y+delta.y)));
    [g setTranslation:CGPointZero inView:self.view];
}
- (void)loadItems:(id)sender {
    NSArray *dirs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *path=dirs.count?[[dirs[0] stringByAppendingPathComponent:@"XiuxianjiazuGM"] stringByAppendingPathComponent:@"items.json"]:nil;
    NSData *bytes=path?[NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil]:nil;
    if (!bytes || bytes.length>8*1024*1024) {
        self.status.text=@"找不到 items.json 或文件过大（上限 8MB）";
        self.allItems=@[];self.filtered=@[];[self.table reloadData];return;
    }
    NSError *error=nil;id json=[NSJSONSerialization JSONObjectWithData:bytes options:0 error:&error];
    if (![json isKindOfClass:NSArray.class]) {
        self.status.text=@"JSON 格式错误：顶层必须是数组";return;
    }
    NSMutableArray *rows=[NSMutableArray array];NSMutableSet *ids=[NSMutableSet set];NSMutableSet *groups=[NSMutableSet set];
    for (id v in (NSArray *)json) {
        if (![v isKindOfClass:NSDictionary.class]) continue;
        id ident=v[@"id"];id name=v[@"name"];
        if (![ident isKindOfClass:NSNumber.class]||![name isKindOfClass:NSString.class]) continue;
        NSInteger i=[ident integerValue];if (i<=0 || [ids containsObject:ident]) continue;
        [ids addObject:ident];
        NSString *idString=[ident stringValue];
        NSString *group=idString.length>=2?[idString substringToIndex:2]:idString;
        [groups addObject:group];
        [rows addObject:@{@"id":ident,@"rawName":name,@"name":CleanName(name),@"group":group}];
    }
    if (!rows.count) {self.status.text=@"没有有效的 ID/名称记录";return;}
    self.allItems=[rows copy];self.selected=nil;self.groupIndex=0;self.qualityIndex=0;
    NSArray *sorted=[[groups allObjects] sortedArrayUsingSelector:@selector(compare:)];
    self.groups=[@[@"全部"] arrayByAddingObjectsFromArray:sorted];
    [self filterItems];
}
- (void)nextGroup:(id)sender {if (!self.groups.count)return;self.groupIndex=(self.groupIndex+1)%self.groups.count;[self filterItems];}
- (void)nextQuality:(id)sender {self.qualityIndex=(self.qualityIndex+1)%6;[self filterItems];}
- (void)filterItems {
    NSArray *qualities=@[@"全部",@"下品",@"中品",@"上品",@"极品",@"绝品"];
    NSString *group=self.groups.count?self.groups[MIN(self.groupIndex,self.groups.count-1)]:@"全部";
    NSString *quality=qualities[self.qualityIndex];
    NSString *query=[self.search.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray *out=[NSMutableArray array];
    for (NSDictionary *entry in self.allItems) {
        if (![group isEqualToString:@"全部"] && ![entry[@"group"] isEqualToString:group])continue;
        if (![quality isEqualToString:@"全部"] &&
            [entry[@"name"] rangeOfString:[NSString stringWithFormat:@"(%@)",quality]].location==NSNotFound)continue;
        NSString *name=entry[@"name"];NSString *ident=[entry[@"id"] stringValue];
        if (query.length && [name rangeOfString:query options:NSCaseInsensitiveSearch].location==NSNotFound &&
            [ident rangeOfString:query].location==NSNotFound)continue;
        [out addObject:entry];
    }
    self.filtered=[out copy];[self.table reloadData];
    [self.groupButton setTitle:[NSString stringWithFormat:@"ID 分组：%@",group] forState:UIControlStateNormal];
    [self.qualityButton setTitle:[NSString stringWithFormat:@"品质：%@",quality] forState:UIControlStateNormal];
    self.status.text=[NSString stringWithFormat:@"已加载 %lu 条 · 当前匹配 %lu 条（ID 分组非原生类型）",
        (unsigned long)self.allItems.count,(unsigned long)self.filtered.count];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {return self.filtered.count;}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"entry" forIndexPath:indexPath];
    NSDictionary *item=self.filtered[(NSUInteger)indexPath.row];
    cell.backgroundColor=UIColor.clearColor;cell.textLabel.textColor=Ink();
    cell.textLabel.font=[UIFont systemFontOfSize:12];
    cell.textLabel.text=[NSString stringWithFormat:@"%@  ·  %@",item[@"name"],item[@"id"]];
    cell.accessoryType=UITableViewCellAccessoryNone;return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item=self.filtered[(NSUInteger)indexPath.row];
    NSString *ident=[item[@"id"] stringValue];UIPasteboard.generalPasteboard.string=ident;
    self.selection.text=[NSString stringWithFormat:@"已复制：%@  ID %@",item[@"name"],ident];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {[textField resignFirstResponder];return YES;}
@end

static XJGMController *sController=nil;
static void XJGMInstall(void) {
    if (sWindow || !UIApplication.sharedApplication) return;
    UIWindowScene *scene=nil;
    if (@available(iOS 13.0,*)) {
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if ([s isKindOfClass:UIWindowScene.class] && s.activationState==UISceneActivationStateForegroundActive)
                {scene=(UIWindowScene *)s;break;}
    }
    if (@available(iOS 13.0,*)) {
        if (!scene)return;
        sWindow=[[XJGMWindow alloc] initWithWindowScene:scene];
    } else sWindow=[[XJGMWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    sWindow.frame=UIScreen.mainScreen.bounds;
    sWindow.windowLevel=UIWindowLevelAlert+1;sWindow.backgroundColor=UIColor.clearColor;
    sController=[XJGMController new];sWindow.rootViewController=sController;sWindow.hidden=NO;
}
__attribute__((constructor)) static void XJGMStart(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        XJGMInstall();
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil
            queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){XJGMInstall();}];
    });
}
