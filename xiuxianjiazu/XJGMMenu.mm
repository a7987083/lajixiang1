#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// External items.json supplies the searchable catalog; GM request lives in a separate module.
#include <stdint.h>
#include <limits.h>
extern "C" int XJGMSendItem(int32_t itemId,int32_t count);
extern "C" int XJGMExportActors(void);
extern "C" int XJGMSendSkill(int32_t actorId,int32_t skillId);
extern "C" int XJGMExportAttributes(void);
extern "C" int XJGMExportActorAttributes(int32_t actorId,const char* expectedName,int32_t expectedForceId);
extern "C" int XJGMSendActorAttribute(int32_t actorId,int32_t attrId,int32_t value,bool expectedPercent);
extern "C" int XJGMReadActorAttributeLive(int32_t actorId,int32_t attrIndex,const char* expectedName,int32_t expectedForceId,int64_t* outValue);
extern "C" NSString* XJGMCurrentWorldToken(void);
static UIWindow *sWindow=nil;
static UIColor *Paper(void) { return [UIColor colorWithRed:.92 green:.88 blue:.80 alpha:1]; }
static UIColor *Panel(void) { return [UIColor colorWithRed:.97 green:.95 blue:.89 alpha:1]; }
static UIColor *Tan(void) { return [UIColor colorWithRed:.79 green:.67 blue:.58 alpha:1]; }
static UIColor *Border(void) { return [UIColor colorWithRed:.59 green:.49 blue:.42 alpha:1]; }
static UIColor *Ink(void) { return [UIColor colorWithRed:.25 green:.19 blue:.17 alpha:1]; }
static UIColor *Dim(void) { return [UIColor colorWithRed:.45 green:.37 blue:.32 alpha:1]; }
static UILabel *Txt(NSString *v,CGFloat size) {
    UILabel *x=[UILabel new];x.text=v;x.textColor=Ink();x.font=[UIFont systemFontOfSize:size];
    x.numberOfLines=0;return x;
}
static UIButton *Btn(NSString *label,id target,SEL selector) {
    UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:label forState:UIControlStateNormal];[b setTitleColor:Ink() forState:UIControlStateNormal];
    b.titleLabel.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    b.titleLabel.adjustsFontSizeToFitWidth=YES;
    b.titleLabel.minimumScaleFactor=.65;
    b.backgroundColor=Tan();b.layer.borderColor=Border().CGColor;b.layer.borderWidth=.75;
    b.layer.cornerRadius=4;[b addTarget:target action:selector forControlEvents:UIControlEventTouchUpInside];
    return b;
}
static NSString *CleanName(NSString *name) {
    static NSRegularExpression *regex=nil;static dispatch_once_t once;
    dispatch_once(&once,^{regex=[NSRegularExpression regularExpressionWithPattern:@"<[^>]*>" options:0 error:nil];});
    return [regex stringByReplacingMatchesInString:name?:@"" options:0
              range:NSMakeRange(0,(name?:@"").length) withTemplate:@""];
}
static NSArray<NSString *> *CategoryNames(void) {
    return @[@"全部",@"丹药",@"灵植材料",@"装备法宝",@"符箓",@"阵法",@"功法",@"灵兽",@"种子",@"其他"];
}
@interface XJGMWindow : UIWindow @end
@implementation XJGMWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *v=[super hitTest:point withEvent:event];
    return (v==self||v==self.rootViewController.view)?nil:v;
}
@end

@interface XJGMController : UIViewController <UITableViewDelegate,UITableViewDataSource,UITextFieldDelegate>
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIButton *bubble;
@property(nonatomic,strong) UIButton *closeButton;
@property(nonatomic,strong) UIButton *itemsTab;
@property(nonatomic,strong) UIButton *skillsTab;
@property(nonatomic,strong) UIButton *attributesTab;
@property(nonatomic,strong) UIScrollView *attributePanel;
@property(nonatomic,assign) BOOL attributesMode;
@property(nonatomic,strong) UITextView *attributeText;
@property(nonatomic,strong) UIButton *attributeRefresh;
@property(nonatomic,strong) UIButton *attributeLockButton;
@property(nonatomic,strong) NSMutableDictionary<NSString*,NSMutableDictionary*> *attributeLocks;
@property(nonatomic,strong) NSString *lockWorldToken;
@property(nonatomic,strong) NSTimer *attributeLockTimer;
@property(nonatomic,strong) UITextField *attributeSearch;
@property(nonatomic,strong) UITextField *attributeValue;
@property(nonatomic,strong) UITableView *attributeTable;
@property(nonatomic,strong) UIButton *attributeSend;
@property(nonatomic,strong) NSArray<NSDictionary *> *attributeDefs;
@property(nonatomic,strong) NSArray<NSDictionary *> *attributeFiltered;
@property(nonatomic,strong) NSDictionary *selectedAttribute;
@property(nonatomic,strong) NSDictionary *attributeRawValues;
@property(nonatomic,assign) BOOL attributeFreshReady;
@property(nonatomic,assign) BOOL attributePickPending;
@property(nonatomic,strong) UIButton *actorButton;
@property(nonatomic,strong) UIView *actorPicker;
@property(nonatomic,strong) UITextField *actorQuery;
@property(nonatomic,strong) UITableView *actorTable;
@property(nonatomic,strong) NSArray<NSDictionary *> *liveActors;
@property(nonatomic,strong) NSArray<NSDictionary *> *visibleActors;
@property(nonatomic,strong) NSDictionary *selectedActor;
@property(nonatomic,strong) UILabel *actorStatus;
@property(nonatomic,strong) UIButton *reloadButton;
@property(nonatomic,strong) UIButton *prevButton;
@property(nonatomic,strong) UIButton *nextButton;
@property(nonatomic,strong) UIButton *minusButton;
@property(nonatomic,strong) UIButton *plusButton;
@property(nonatomic,strong) UIButton *sendButton;
@property(nonatomic,strong) UITextField *query;
@property(nonatomic,strong) UITextField *quantity;
@property(nonatomic,strong) UILabel *countLabel;
@property(nonatomic,strong) UITextView *detailLabel;
@property(nonatomic,strong) UILabel *pickedLabel;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UITableView *categoryTable;
@property(nonatomic,strong) UITableView *itemTable;
@property(nonatomic,strong) NSArray<NSDictionary *> *allItems;
@property(nonatomic,strong) NSArray<NSDictionary *> *allSkills;
@property(nonatomic,assign) BOOL skillsMode;
@property(nonatomic,strong) NSArray<NSDictionary *> *filtered;
@property(nonatomic,strong) NSDictionary *selected;
@property(nonatomic,assign) NSInteger selectedCategory;
@property(nonatomic,assign) NSInteger page;
@end

@implementation XJGMController
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=UIColor.clearColor;
    self.liveActors=@[];self.visibleActors=@[];
    self.allItems=@[];self.allSkills=@[];self.filtered=@[];self.selectedCategory=0;self.page=0;self.skillsMode=NO;self.attributesMode=NO;
    self.bubble=Btn(@"GM",self,@selector(toggle:));
    self.bubble.frame=CGRectMake(10,100,48,48);self.bubble.layer.cornerRadius=24;
    [self.view addSubview:self.bubble];
    [self.bubble addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)]];

    self.panel=[UIView new];self.panel.hidden=YES;self.panel.backgroundColor=Paper();
    self.panel.layer.borderColor=Border().CGColor;self.panel.layer.borderWidth=1;
    self.panel.layer.cornerRadius=10;self.panel.layer.shadowColor=UIColor.blackColor.CGColor;
    self.panel.layer.shadowOpacity=.36;self.panel.layer.shadowRadius=16;
    [self.view addSubview:self.panel];

    UILabel *title=Txt(@"修仙家族 · GM 管理",16);
    title.font=[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];title.textAlignment=NSTextAlignmentCenter;
    title.tag=901;[self.panel addSubview:title];
    self.closeButton=Btn(@"收起",self,@selector(toggle:));[self.panel addSubview:self.closeButton];
    self.itemsTab=Btn(@"物品功能",self,@selector(showItems:));[self.panel addSubview:self.itemsTab];
    self.skillsTab=Btn(@"功法列表",self,@selector(showSkills:));[self.panel addSubview:self.skillsTab];
    self.attributesTab=Btn(@"属性查看",self,@selector(showAttributes:));
    [self.panel addSubview:self.attributesTab];
    self.reloadButton=Btn(@"重新加载",self,@selector(reloadCurrent:));[self.panel addSubview:self.reloadButton];

    self.query=[UITextField new];self.query.delegate=self;
    self.query.placeholder=@"名称或 ID";self.query.textColor=Ink();self.query.font=[UIFont systemFontOfSize:12];
    self.query.backgroundColor=Panel();self.query.layer.cornerRadius=4;
    self.query.layer.borderWidth=.8;self.query.layer.borderColor=Border().CGColor;
    self.query.leftView=[[UIView alloc] initWithFrame:CGRectMake(0,0,8,1)];
    self.query.leftViewMode=UITextFieldViewModeAlways;
    [self.query addTarget:self action:@selector(rebuildFilter) forControlEvents:UIControlEventEditingChanged];
    [self.panel addSubview:self.query];

    self.categoryTable=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.itemTable=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    for (UITableView *table in @[self.categoryTable,self.itemTable]) {
        table.dataSource=self;table.delegate=self;table.backgroundColor=Panel();
        table.layer.borderWidth=.8;table.layer.borderColor=Border().CGColor;
        table.rowHeight=36;table.separatorStyle=UITableViewCellSeparatorStyleSingleLine;
        [table registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"];
        [self.panel addSubview:table];
    }
    self.countLabel=Txt(@"0 项 · 1/1",11);self.countLabel.textAlignment=NSTextAlignmentCenter;
    [self.panel addSubview:self.countLabel];
    self.prevButton=Btn(@"<",self,@selector(previous:));
    self.nextButton=Btn(@">",self,@selector(next:));
    [self.panel addSubview:self.prevButton];[self.panel addSubview:self.nextButton];

    self.detailLabel=[UITextView new];
    self.detailLabel.text=@"物品说明\n\n选择左侧分类，再点击物品查看名称、ID 和类型信息。";
    self.detailLabel.font=[UIFont systemFontOfSize:11];
    self.detailLabel.textColor=Ink();self.detailLabel.editable=NO;
    self.detailLabel.selectable=YES;self.detailLabel.scrollEnabled=YES;
    self.detailLabel.backgroundColor=Panel();
    self.detailLabel.layer.borderWidth=.8;self.detailLabel.layer.borderColor=Border().CGColor;
    self.detailLabel.textAlignment=NSTextAlignmentLeft;
    [self.panel addSubview:self.detailLabel];
    self.pickedLabel=Txt(@"未选择物品",12);[self.panel addSubview:self.pickedLabel];

    self.minusButton=Btn(@"－",self,@selector(decrease:));
    self.plusButton=Btn(@"＋",self,@selector(increase:));
    self.quantity=[UITextField new];self.quantity.text=@"1";self.quantity.keyboardType=UIKeyboardTypeNumberPad;
    self.quantity.textAlignment=NSTextAlignmentCenter;self.quantity.delegate=self;
    // Number pad has no built-in Done key on iPhone; provide a dedicated accessory bar.
    UIToolbar *quantityBar=[[UIToolbar alloc] initWithFrame:CGRectMake(0,0,320,44)];
    quantityBar.barStyle=UIBarStyleDefault;
    UIBarButtonItem *flex=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
    UIBarButtonItem *done=[[UIBarButtonItem alloc] initWithTitle:@"完成" style:UIBarButtonItemStyleDone target:self action:@selector(finishQuantity:)];
    quantityBar.items=@[flex,done];
    self.quantity.inputAccessoryView=quantityBar;
    self.quantity.font=[UIFont systemFontOfSize:13];self.quantity.textColor=Ink();
    self.quantity.backgroundColor=Panel();self.quantity.layer.borderWidth=.8;
    self.quantity.layer.borderColor=Border().CGColor;
    [self.panel addSubview:self.minusButton];[self.panel addSubview:self.plusButton];
    [self.panel addSubview:self.quantity];
    self.actorButton=Btn(@"选择弟子",self,@selector(openActors:));
    self.actorButton.hidden=YES;[self.panel addSubview:self.actorButton];
    self.sendButton=Btn(@"发放物品",self,@selector(sendItem:));
    self.sendButton.enabled=NO;self.sendButton.alpha=.5;[self.panel addSubview:self.sendButton];
    self.statusLabel=Txt(@"加载外部 JSON 后选择物品并设置发放数量",10);
    self.statusLabel.textColor=Dim();[self.panel addSubview:self.statusLabel];
    // Independent actor chooser, backed by a freshly fetched DataCache list.
    self.actorPicker=[UIView new];self.actorPicker.hidden=YES;
    self.actorPicker.backgroundColor=Paper();self.actorPicker.layer.cornerRadius=7;
    self.actorPicker.layer.borderColor=Border().CGColor;self.actorPicker.layer.borderWidth=1;
    [self.panel addSubview:self.actorPicker];
    UILabel *actorTitle=Txt(@"选择实时弟子",16);actorTitle.tag=902;
    [self.actorPicker addSubview:actorTitle];
    UIButton *actorClose=Btn(@"返回",self,@selector(closeActors:));actorClose.tag=903;
    [self.actorPicker addSubview:actorClose];
    UIButton *actorReload=Btn(@"刷新弟子",self,@selector(refreshActors:));actorReload.tag=904;
    [self.actorPicker addSubview:actorReload];
    self.actorQuery=[UITextField new];self.actorQuery.placeholder=@"搜索姓名或 ID";
    self.actorQuery.font=[UIFont systemFontOfSize:13];self.actorQuery.textColor=Ink();
    self.actorQuery.backgroundColor=Panel();self.actorQuery.layer.borderWidth=1;
    self.actorQuery.layer.borderColor=Border().CGColor;
    self.actorQuery.returnKeyType=UIReturnKeyDone;self.actorQuery.delegate=self;
    [self.actorQuery addTarget:self action:@selector(filterActors) forControlEvents:UIControlEventEditingChanged];
    [self.actorPicker addSubview:self.actorQuery];
    self.actorTable=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.actorTable.dataSource=self;self.actorTable.delegate=self;
    self.actorTable.rowHeight=44;self.actorTable.backgroundColor=Panel();
    [self.actorTable registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"];
    [self.actorPicker addSubview:self.actorTable];
    self.actorStatus=Txt(@"进入游戏后刷新弟子列表",11);
    [self.actorPicker addSubview:self.actorStatus];
    self.attributePanel=[UIScrollView new];self.attributePanel.backgroundColor=Paper();
    self.attributePanel.alwaysBounceVertical=YES;
    self.attributePanel.showsVerticalScrollIndicator=YES;
    self.attributePanel.layer.cornerRadius=4;self.attributePanel.hidden=YES;
    [self.panel addSubview:self.attributePanel];
    UIButton *attrSelect=Btn(@"选择弟子",self,@selector(chooseAttributeActor:));
    attrSelect.tag=907;[self.attributePanel addSubview:attrSelect];
    self.attributeRefresh=Btn(@"刷新属性",self,@selector(refreshAttributes:));
    [self.attributePanel addSubview:self.attributeRefresh];
    self.attributeText=[UITextView new];self.attributeText.editable=NO;
    self.attributeText.backgroundColor=Panel();self.attributeText.textColor=Ink();
    self.attributeText.font=[UIFont systemFontOfSize:12];self.attributeText.text=@"选择弟子后实时读取属性数组。";
    [self.attributePanel addSubview:self.attributeText];
    self.attributeSearch=[UITextField new];
    self.attributeSearch.placeholder=@"搜索动态属性名称";
    self.attributeSearch.font=[UIFont systemFontOfSize:12];self.attributeSearch.textColor=Ink();
    self.attributeSearch.backgroundColor=Panel();self.attributeSearch.layer.borderColor=Border().CGColor;
    self.attributeSearch.layer.borderWidth=1;self.attributeSearch.returnKeyType=UIReturnKeyDone;
    self.attributeSearch.delegate=self;
    [self.attributeSearch addTarget:self action:@selector(filterAttributeList) forControlEvents:UIControlEventEditingChanged];
    [self.attributePanel addSubview:self.attributeSearch];
    self.attributeTable=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.attributeTable.delegate=self;self.attributeTable.dataSource=self;
    self.attributeTable.rowHeight=37;self.attributeTable.backgroundColor=Panel();
    [self.attributeTable registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"];
    [self.attributePanel addSubview:self.attributeTable];
    self.attributeValue=[UITextField new];self.attributeValue.placeholder=@"输入属性数值";
    self.attributeValue.keyboardType=UIKeyboardTypeDecimalPad;
    self.attributeValue.font=[UIFont systemFontOfSize:12];self.attributeValue.textColor=Ink();
    self.attributeValue.textAlignment=NSTextAlignmentCenter;
    self.attributeValue.layer.borderColor=Border().CGColor;self.attributeValue.layer.borderWidth=1;
    self.attributeValue.backgroundColor=Panel();self.attributeValue.delegate=self;
    UIToolbar *attributeBar=[[UIToolbar alloc] initWithFrame:CGRectMake(0,0,320,44)];
    UIBarButtonItem *finish=[[UIBarButtonItem alloc] initWithTitle:@"完成" style:UIBarButtonItemStyleDone target:self action:@selector(finishAttributeInput:)];
    attributeBar.items=@[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil],finish];
    self.attributeValue.inputAccessoryView=attributeBar;
    [self.attributePanel addSubview:self.attributeValue];
    self.attributeSend=Btn(@"设置一次",self,@selector(sendAttribute:));
    self.attributeSend.enabled=NO;self.attributeSend.alpha=.5;
    [self.attributePanel addSubview:self.attributeSend];
    self.attributeLockButton=Btn(@"锁定",self,@selector(toggleAttributeLock:));
    self.attributeLockButton.enabled=NO;self.attributeLockButton.alpha=.5;
    [self.attributePanel addSubview:self.attributeLockButton];
    self.attributeLocks=[NSMutableDictionary dictionary];
    // Reconcile only in an active game and only while locks exist.
    self.attributeLockTimer=[NSTimer timerWithTimeInterval:1.0 target:self
        selector:@selector(reconcileAttributeLocks:) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.attributeLockTimer forMode:NSRunLoopCommonModes];
    self.attributeDefs=@[];self.attributeFiltered=@[];self.attributeRawValues=@{};
    [self adjustPanel];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];if (!self.panel.hidden)[self adjustPanel];
}
- (void)adjustPanel {
    CGRect b=self.view.bounds;
    CGFloat w=MIN(620,MAX(294,b.size.width-12));
    CGFloat h=MIN(560,MAX(340,b.size.height-26));
    self.panel.frame=CGRectMake((b.size.width-w)/2,(b.size.height-h)/2,w,h);
    CGFloat m=9,inner=w-2*m;
    [self.panel viewWithTag:901].frame=CGRectMake(m,7,w-75,28);
    self.closeButton.frame=CGRectMake(w-61,9,51,27);
    CGFloat tabWidth=floor((inner-18)/4);
    self.itemsTab.frame=CGRectMake(m,41,tabWidth,28);
    self.skillsTab.frame=CGRectMake(m+tabWidth+6,41,tabWidth,28);
    self.attributesTab.frame=CGRectMake(m+(tabWidth+6)*2,41,tabWidth,28);
    self.reloadButton.frame=CGRectMake(m+(tabWidth+6)*3,41,tabWidth,28);
    self.query.frame=CGRectMake(m,77,inner,31);

    // Compact iPhone portrait: categories 24%, list 35%, details remaining 41%.
    CGFloat space=6,areaW=inner-2*space;
    CGFloat leftW=floor(areaW*.23),middleW=floor(areaW*.35);
    CGFloat rightW=areaW-leftW-middleW;
    CGFloat listTop=115,listBottom=h-132,listH=MAX(105,listBottom-listTop);
    self.categoryTable.frame=CGRectMake(m,listTop,leftW,listH);
    self.itemTable.frame=CGRectMake(m+leftW+space,listTop,middleW,listH-33);
    self.prevButton.frame=CGRectMake(m+leftW+space,listBottom-29,30,27);
    self.nextButton.frame=CGRectMake(m+leftW+space+middleW-30,listBottom-29,30,27);
    self.countLabel.frame=CGRectMake(m+leftW+space+30,listBottom-29,MAX(4,middleW-60),27);
    self.detailLabel.frame=CGRectMake(m+leftW+space+middleW+space,listTop,rightW,listH);
    CGFloat bottom=h-124;
    self.pickedLabel.frame=CGRectMake(m,bottom,inner,30);
    self.minusButton.frame=CGRectMake(m,bottom+35,30,29);
    self.quantity.frame=CGRectMake(m+35,bottom+35,56,29);
    self.plusButton.frame=CGRectMake(m+96,bottom+35,30,29);
    self.actorButton.frame=CGRectMake(m,bottom+35,126,29);
    self.sendButton.frame=CGRectMake(m+134,bottom+35,MAX(50,inner-134),29);
    self.actorPicker.frame=CGRectMake(4,4,w-8,h-8);
    CGFloat aw=self.actorPicker.bounds.size.width,ah=self.actorPicker.bounds.size.height;
    [self.actorPicker viewWithTag:902].frame=CGRectMake(14,12,aw-95,32);
    [self.actorPicker viewWithTag:903].frame=CGRectMake(aw-72,14,60,29);
    [self.actorPicker viewWithTag:904].frame=CGRectMake(14,52,98,32);
    self.actorQuery.frame=CGRectMake(119,52,aw-133,32);
    self.actorTable.frame=CGRectMake(14,94,aw-28,MAX(110,ah-151));
    self.actorStatus.frame=CGRectMake(14,ah-49,aw-28,41);
    // Same main panel and toolbar as the item/skill tabs. No full-panel overlay.
    self.attributePanel.frame=CGRectMake(m,77,inner,h-86);
    CGFloat vw=self.attributePanel.bounds.size.width,vh=self.attributePanel.bounds.size.height;
    CGFloat contentH=MAX(460,vh);
    self.attributePanel.contentSize=CGSizeMake(vw,contentH);
    [self.attributePanel viewWithTag:907].frame=CGRectMake(5,contentH-205,MAX(100,vw*.49-8),32);
    self.attributeRefresh.frame=CGRectMake(MAX(112,vw*.49+2),contentH-205,MAX(90,vw*.51-7),32);
    self.attributeSearch.frame=CGRectMake(5,2,vw-10,32);
    self.attributeTable.frame=CGRectMake(5,42,vw-10,MAX(80,contentH-223));
    [self.attributePanel viewWithTag:907].frame=CGRectMake(5,contentH-173,MAX(100,vw*.49-8),32);
    self.attributeRefresh.frame=CGRectMake(MAX(112,vw*.49+2),contentH-173,MAX(90,vw*.51-7),32);
    CGFloat controlW=floor((vw-20)/3);
    self.attributeValue.frame=CGRectMake(5,contentH-133,controlW,32);
    self.attributeSend.frame=CGRectMake(10+controlW,contentH-133,controlW,32);
    self.attributeLockButton.frame=CGRectMake(15+2*controlW,contentH-133,
        vw-20-2*controlW,32);
    self.attributeText.frame=CGRectMake(5,contentH-94,vw-10,89);
    self.statusLabel.frame=CGRectMake(m,bottom+68,inner,40);
}
- (void)toggle:(id)sender {
    self.panel.hidden=!self.panel.hidden;self.bubble.hidden=!self.panel.hidden;
    if (!self.panel.hidden) {
        [self adjustPanel];
        if(self.attributesMode)[self showAttributes:nil];
        else if(!(self.skillsMode?self.allSkills.count:self.allItems.count))[self loadItems:nil];
    } else {
        [self.view endEditing:YES];self.actorPicker.hidden=YES;
        self.attributePanel.hidden=YES;self.attributePickPending=NO;
        self.selectedActor=nil;self.liveActors=@[];self.visibleActors=@[];
        [self showSelected];
    }
}
- (void)drag:(UIPanGestureRecognizer *)g {
    CGPoint d=[g translationInView:self.view],c=self.bubble.center;
    CGFloat rx=self.bubble.bounds.size.width*.5,ry=self.bubble.bounds.size.height*.5;
    self.bubble.center=CGPointMake(MAX(rx,MIN(self.view.bounds.size.width-rx,c.x+d.x)),
        MAX(ry,MIN(self.view.bounds.size.height-ry,c.y+d.y)));
    [g setTranslation:CGPointZero inView:self.view];
}
- (void)exportAttributes:(id)sender {
    [self.view endEditing:YES];
    self.attributesTab.enabled=NO;
    self.statusLabel.text=@"正在只读导出属性配置…";
    int count=XJGMExportAttributes();
    self.attributesTab.enabled=YES;
    if(count>=0)self.statusLabel.text=[NSString stringWithFormat:@"导出属性配置 %d 条：Documents/XiuxianjiazuGM/attributes.json",count];
    else self.statusLabel.text=[NSString stringWithFormat:@"属性表导出 E%03d；检查 export-stage.txt",-count];
    NSLog(@"[XJGM] attribute export count=%d",count);
}

- (void)updateModeViews {
    BOOL attr=self.attributesMode;
    // One shared root UI. Hide the item/skill content, not the common toolbar.
    for(UIView *view in @[self.query,self.categoryTable,self.itemTable,self.prevButton,
         self.nextButton,self.countLabel,self.detailLabel,self.pickedLabel,
         self.minusButton,self.quantity,self.plusButton,self.actorButton,
         self.sendButton,self.statusLabel]) view.hidden=attr;
    self.attributePanel.hidden=!attr;
    [self.reloadButton setTitle:attr?@"刷新属性":@"重新加载" forState:UIControlStateNormal];
}
- (void)reloadCurrent:(id)sender {
    if(self.attributesMode)[self refreshAttributes:sender];
    else [self loadItems:sender];
}
- (void)showAttributes:(id)sender {
    [self.view endEditing:YES];
    BOOL newlySelected=!self.attributesMode;
    self.attributesMode=YES;
    if(newlySelected){self.selectedAttribute=nil;self.attributeValue.text=@"";
        self.attributeSearch.text=@"";}
    [self updateModeViews];
    [self adjustPanel];
    if(!self.selectedActor) {
        self.attributeFreshReady=NO;self.attributeDefs=@[];self.attributeFiltered=@[];
        self.attributeRawValues=@{};self.attributeSend.enabled=NO;self.attributeSend.alpha=.5;
        [self.attributeTable reloadData];
        self.attributeText.text=@"点击下方「选择弟子」后，实时读取该弟子的属性。";
        UIButton *choose=(UIButton *)[self.attributePanel viewWithTag:907];
        [choose setTitle:@"选择弟子" forState:UIControlStateNormal];
    } else {
        [self refreshAttributes:nil];
    }
}
- (void)chooseAttributeActor:(id)sender {
    self.attributePickPending=YES;
    [self openActors:nil];
}
- (void)refreshAttributes:(id)sender {
    if(!self.selectedActor) {
        self.attributeText.text=@"请先选择弟子。";return;
    }
    self.attributeFreshReady=NO;
    self.attributeSend.enabled=NO;
    self.attributeRefresh.enabled=NO;
    int code=XJGMExportAttributes(); // Live UnitAttrTmpl.configs, not the previous JSON.
    if(code<0) {
        self.attributeText.text=[NSString stringWithFormat:@"属性定义读取失败 E%03d。检查 export-stage.txt",-code];
        self.attributeRefresh.enabled=YES;return;
    }
    NSDictionary *actor=self.selectedActor;
    int count=[self reloadLiveActors:NO];
    if(count<0) {
        self.attributeText.text=@"实时弟子列表刷新失败；已取消属性读取。";
        self.attributeRefresh.enabled=YES;return;
    }
    BOOL stillPresent=NO;
    for(NSDictionary *a in self.liveActors) {
        if([a[@"id"] isEqual:actor[@"id"]] &&
           [a[@"name"] isEqual:actor[@"name"]] &&
           [a[@"forceId"] isEqual:actor[@"forceId"]]){stillPresent=YES;break;}
    }
    if(!stillPresent) {
        self.selectedActor=nil;self.attributeText.text=@"弟子已经变化，请重新选择。";
        self.attributeRefresh.enabled=YES;return;
    }
    code=XJGMExportActorAttributes([actor[@"id"] intValue],
         [actor[@"name"] UTF8String],[actor[@"forceId"] intValue]);
    if(code<0) {
        self.attributeText.text=[NSString stringWithFormat:@"属性数值读取失败 E%03d。检查 actor-export-stage.txt",-code];
        self.attributeRefresh.enabled=YES;return;
    }
    NSArray *dirs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *dir=dirs.count?[dirs[0] stringByAppendingPathComponent:@"XiuxianjiazuGM"]:@"";
    NSData *defsData=[NSData dataWithContentsOfFile:[dir stringByAppendingPathComponent:@"attributes.json"]];
    NSData *valsData=[NSData dataWithContentsOfFile:[dir stringByAppendingPathComponent:@"actor-attributes.json"]];
    id defs=defsData?[NSJSONSerialization JSONObjectWithData:defsData options:0 error:nil]:nil;
    id snapshot=valsData?[NSJSONSerialization JSONObjectWithData:valsData options:0 error:nil]:nil;
    if(![defs isKindOfClass:NSArray.class] || ![snapshot isKindOfClass:NSDictionary.class] ||
        ![snapshot[@"values"] isKindOfClass:NSArray.class] ||
        ![snapshot[@"actorId"] isEqual:actor[@"id"]] ||
        ![snapshot[@"actorName"] isEqual:actor[@"name"]] ||
        ![snapshot[@"forceId"] isEqual:actor[@"forceId"]]) {
        self.attributeText.text=@"属性快照校验失败，未显示旧数据。";self.attributeRefresh.enabled=YES;return;
    }
    NSMutableDictionary *names=[NSMutableDictionary dictionary];
    NSMutableDictionary *raw=[NSMutableDictionary dictionary];
    for(id entry in snapshot[@"values"]) {
        if([entry isKindOfClass:NSDictionary.class] &&
           [entry[@"index"] isKindOfClass:NSNumber.class] &&
           [entry[@"value"] isKindOfClass:NSNumber.class])
           raw[entry[@"index"]]=entry[@"value"];
    }
    self.attributeRawValues=[raw copy];
    NSMutableArray *validDefs=[NSMutableArray array];
    for(id obj in (NSArray*)defs) {
        if([obj isKindOfClass:NSDictionary.class] &&
           [obj[@"id"] isKindOfClass:NSNumber.class] && [obj[@"name"] isKindOfClass:NSString.class])
        {
            names[obj[@"id"]]=obj[@"name"];
            if([obj[@"valueType"] isKindOfClass:NSNumber.class] &&
               [obj[@"isPercentage"] isKindOfClass:NSNumber.class] &&
               [obj[@"id"] integerValue]>=0 && [obj[@"id"] integerValue]<100)
                [validDefs addObject:obj];
        }
    }
    NSMutableString *view=[NSMutableString stringWithFormat:@"弟子：%@\n定义：%lu 项 · 原始属性：%d 项\n\n⚠ 数组索引与属性 ID 的映射尚未实机确认；以下名称只是候选对照，数值为原始 List<long> 数据。\n\n",
        actor[@"name"],(unsigned long)names.count,code];
    for(id entry in snapshot[@"values"]) {
        if(![entry isKindOfClass:NSDictionary.class] ||
           ![entry[@"index"] isKindOfClass:NSNumber.class] ||
           ![entry[@"value"] isKindOfClass:NSNumber.class])continue;
        NSString *candidate=names[entry[@"index"]]?:@"未匹配";
        [view appendFormat:@"[%@] %@（候选）  %@\n",
            entry[@"index"],candidate,entry[@"value"]];
    }
    self.attributeDefs=[validDefs sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b) {
        return [a[@"id"] compare:b[@"id"]];
    }];
    NSDictionary *retained=nil;
    for(NSDictionary *a in self.attributeDefs)
        if(self.selectedAttribute && [a[@"id"] isEqual:self.selectedAttribute[@"id"]] &&
           [a[@"name"] isEqual:self.selectedAttribute[@"name"]] &&
           [a[@"valueType"] isEqual:self.selectedAttribute[@"valueType"]] &&
           [a[@"isPercentage"] isEqual:self.selectedAttribute[@"isPercentage"]]) {retained=a;break;}
    self.selectedAttribute=retained;
    [self filterAttributeList];
    self.attributeFreshReady=YES;
    UIButton *choose=(UIButton *)[self.attributePanel viewWithTag:907];
    [choose setTitle:[NSString stringWithFormat:@"弟子：%@",actor[@"name"]] forState:UIControlStateNormal];
    self.attributeText.text=[NSString stringWithFormat:@"弟子：%@ · %lu 条属性\n已选：%@\n%@",
        actor[@"name"],(unsigned long)self.attributeDefs.count,
        self.selectedAttribute[@"name"]?:@"未选择",
        @"当前值来自原始数组索引，属性名对应关系待写入后验证。"];
    [self updateAttributeSendState];
    self.attributeRefresh.enabled=YES;
}

- (void)finishAttributeInput:(id)sender {
    [self.attributeValue resignFirstResponder];
}
- (void)filterAttributeList {
    NSString *q=[self.attributeSearch.text stringByTrimmingCharactersInSet:
         NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray *result=[NSMutableArray array];
    for(NSDictionary *d in self.attributeDefs) {
        if(q.length && [d[@"name"] rangeOfString:q options:NSCaseInsensitiveSearch].location==NSNotFound &&
           [[d[@"id"] stringValue] rangeOfString:q].location==NSNotFound)continue;
        [result addObject:d];
    }
    self.attributeFiltered=result;[self.attributeTable reloadData];
}
- (void)updateAttributeSendState {
    BOOL canSend=self.attributeFreshReady && self.selectedActor && self.selectedAttribute &&
        [self.selectedAttribute[@"isPercentage"] isKindOfClass:NSNumber.class] &&
        self.attributeRawValues[self.selectedAttribute[@"id"]]!=nil;
    self.attributeSend.enabled=canSend;self.attributeSend.alpha=canSend?1:.5;
    NSString *key=[self lockKeyForActor:self.selectedActor attribute:self.selectedAttribute];
    BOOL locked=key && self.attributeLocks[key]!=nil;
    [self.attributeLockButton setTitle:locked?@"恢复":@"锁定" forState:UIControlStateNormal];
    self.attributeLockButton.enabled=locked || canSend;
    self.attributeLockButton.alpha=(locked || canSend)?1:.5;
}

- (NSString *)lockKeyForActor:(NSDictionary *)actor attribute:(NSDictionary *)attr {
    if(!actor || !attr || !self.lockWorldToken.length)return nil;
    return [NSString stringWithFormat:@"%@|%@|%@",self.lockWorldToken,actor[@"id"],attr[@"id"]];
}
- (void)clearAttributeLocks:(NSString *)reason {
    if(!self.attributeLocks.count)return;
    [self.attributeLocks removeAllObjects];self.lockWorldToken=nil;
    if(self.attributesMode) {
        self.attributeText.text=reason?:@"锁定已全部停止。";
        [self.attributeTable reloadData];[self updateAttributeSendState];
    }
}
- (void)reconcileAttributeLocks:(NSTimer *)timer {
    if(!self.attributeLocks.count)return;
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    NSString *world=XJGMCurrentWorldToken();
    // An unavailable world token can be transient during scene transitions.
    // Pause checks without deleting locks; a *different valid* UUID resets them.
    if(!world.length)return;
    if(![world isEqualToString:self.lockWorldToken]) {
        [self clearAttributeLocks:@"存档或游戏世界已切换；全部锁定已停止。"];
        return;
    }
    // Each lock is independent: a failure on one attribute must not remove
    // any other lock. Read failures are retained for a later one-second tick.
    for(NSString *key in [self.attributeLocks allKeys]) {
        NSMutableDictionary *entry=self.attributeLocks[key];
        if(!entry)continue;
        int64_t current=0;
        int status=XJGMReadActorAttributeLive([entry[@"actorId"] intValue],
            [entry[@"attrId"] intValue],[entry[@"actorName"] UTF8String],
            [entry[@"forceId"] intValue],&current);
        if(status!=1) {
            entry[@"lastReadError"]=@(status);
            continue;
        }
        [entry removeObjectForKey:@"lastReadError"];
        if(current==[entry[@"target"] longLongValue])continue;
        // Exactly one GM submission per changed attribute per timer tick.
        // Never use a global retry count to deactivate unrelated locks.
        int rc=XJGMSendActorAttribute([entry[@"actorId"] intValue],
            [entry[@"attrId"] intValue],[entry[@"target"] intValue],
            [entry[@"isPercentage"] boolValue]);
        if(rc!=1)entry[@"lastWriteError"]=@(rc);
        else [entry removeObjectForKey:@"lastWriteError"];
    }
}
- (void)toggleAttributeLock:(id)sender {
    NSDictionary *actor=self.selectedActor,*attr=self.selectedAttribute;
    NSString *key=[self lockKeyForActor:actor attribute:attr];
    if(key && self.attributeLocks[key]){
        // '恢复' means STOP locking only. Never restore or write the old value.
        [self.attributeLocks removeObjectForKey:key];
        if(!self.attributeLocks.count)self.lockWorldToken=nil;
        self.attributeText.text=[NSString stringWithFormat:
            @"已停止锁定：%@ · %@；当前值不回滚。",actor[@"name"],attr[@"name"]];
        [self.attributeTable reloadData];[self updateAttributeSendState];
        return;
    }
    if(self.attributeLocks.count>=8){
        self.attributeText.text=@"最多同时锁定 8 项属性，避免持续检查造成游戏卡顿。";
        return;
    }
    NSString *world=XJGMCurrentWorldToken();
    if(!world.length){
        self.attributeText.text=@"未取得当前游戏世界标识；本次不启用锁定。";
        return;
    }
    if(self.attributeLocks.count && ![world isEqualToString:self.lockWorldToken]){
        [self clearAttributeLocks:@"游戏世界变化，已清理旧锁定。"];
        return;
    }
    self.lockWorldToken=world;
    [self performAttributeAction:YES];
}
- (void)sendAttribute:(id)sender {
    [self performAttributeAction:NO];
}
- (void)performAttributeAction:(BOOL)shouldLock {
    [self.view endEditing:YES];
    NSDictionary *actor=self.selectedActor,*attr=self.selectedAttribute;
    if(!self.attributeFreshReady || !actor || !attr) {
        self.attributeText.text=@"动态弟子或属性尚未完成校验，请刷新。";return;
    }
    if(![attr[@"isPercentage"] isKindOfClass:NSNumber.class]) {
        self.attributeText.text=@"原生属性类型未读取，禁止发送。";return;
    }
    int type=[attr[@"isPercentage"] boolValue]?1:0;
    NSString *entered=[self.attributeValue.text stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    // The native GM protocol accepts Int32. Input does not enforce an invented
    // 9999/100% cap. True gameplay caps vary and are not supplied by UnitAttrTmpl.
    // Percent fields: original AttrHelper.GetAttValueString divides raw by 100.0.
    NSString *pattern=type==1?@"^[0-9]+(?:\\.[0-9]{1,2})?$":@"^[0-9]+$";
    NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    if(!entered.length || entered.length>16 ||
       [regex numberOfMatchesInString:entered options:0 range:NSMakeRange(0,entered.length)]!=1) {
        self.attributeText.text=type==1?@"请输入百分比，最多两位小数。":@"请输入非负整数。";
        return;
    }
    NSDecimalNumber *display=[NSDecimalNumber decimalNumberWithString:entered locale:
        @{NSLocaleDecimalSeparator:@"."}];
    NSDecimalNumber *scale=[NSDecimalNumber decimalNumberWithString:type==1?@"100":@"1"];
    NSDecimalNumber *encoded=[display decimalNumberByMultiplyingBy:scale];
    NSDecimalNumber *limit=[NSDecimalNumber decimalNumberWithString:@"2147483647"];
    if([encoded isEqualToNumber:NSDecimalNumber.notANumber] ||
       [encoded compare:limit]==NSOrderedDescending ||
       [encoded compare:NSDecimalNumber.zero]==NSOrderedAscending) {
        self.attributeText.text=@"超出游戏 GM 指令的 Int32 参数范围；未发送。";
        return;
    }
    int32_t value=encoded.intValue;
    // No modal. A lock is only activated after the initial request is submitted.
    // Still fail closed if any actor identity or attribute definition has changed.
    self.attributeSend.enabled=NO;
    [self refreshAttributes:nil];
    NSDictionary *fresh=self.selectedAttribute,*newActor=self.selectedActor;
    if(!self.attributeFreshReady || !fresh || !newActor ||
       ![newActor[@"id"] isEqual:actor[@"id"]] ||
       ![newActor[@"name"] isEqual:actor[@"name"]] ||
       ![newActor[@"forceId"] isEqual:actor[@"forceId"]] ||
       ![fresh[@"id"] isEqual:attr[@"id"]] ||
       ![fresh[@"name"] isEqual:attr[@"name"]] ||
       ![fresh[@"valueType"] isEqual:attr[@"valueType"]] ||
       ![fresh[@"isPercentage"] isEqual:attr[@"isPercentage"]]) {
        self.attributeText.text=@"弟子或属性已变更，本次未发送。请重新选择。";
        [self updateAttributeSendState];return;
    }
    int rc=XJGMSendActorAttribute([actor[@"id"] intValue],[attr[@"id"] intValue],value,[attr[@"isPercentage"] boolValue]);
    if(rc==1 && shouldLock) {
        NSString *key=[self lockKeyForActor:actor attribute:attr];
        self.attributeLocks[key]=[@{@"actorId":actor[@"id"],@"actorName":actor[@"name"],
            @"forceId":actor[@"forceId"],@"attrId":attr[@"id"],
            @"attrName":attr[@"name"],@"isPercentage":attr[@"isPercentage"],
            @"target":@(value)} mutableCopy];
        [self.attributeTable reloadData];
    }
    self.attributeText.text=rc==1?
        [NSString stringWithFormat:@"%@：%@ · %@ → %@",
            shouldLock?@"锁定监控已开启":@"设置一次已提交",
            actor[@"name"],attr[@"name"],entered]:
        [NSString stringWithFormat:@"属性发送失败 E%03d；未启用锁定", -rc];
    [self updateAttributeSendState];
}
- (void)showItems:(id)sender {
    [self.view endEditing:YES];
    self.attributesMode=NO;self.attributePickPending=NO;
    self.skillsMode=NO;self.selectedActor=nil;self.selected=nil;self.selectedCategory=0;self.page=0;self.query.text=@"";
    [self.categoryTable reloadData];[self showSelected];[self updateModeViews];
    if(!self.allItems.count)[self loadItems:nil];else[self rebuildFilter];
}
- (void)showSkills:(id)sender {
    [self.view endEditing:YES];
    self.attributesMode=NO;self.attributePickPending=NO;
    self.skillsMode=YES;self.selectedActor=nil;self.selected=nil;self.selectedCategory=0;self.page=0;self.query.text=@"";
    [self.categoryTable reloadData];[self showSelected];[self updateModeViews];
    if(!self.allSkills.count)[self loadItems:nil];else[self rebuildFilter];
}
- (void)loadItems:(id)sender {
    NSArray *dirs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *filename=self.skillsMode?@"skills.json":@"items.json";
    NSString *path=dirs.count?[[dirs[0] stringByAppendingPathComponent:@"XiuxianjiazuGM"]
                         stringByAppendingPathComponent:filename]:nil;
    NSData *bytes=path?[NSData dataWithContentsOfFile:path options:0 error:nil]:nil;
    if(!bytes || bytes.length>8*1024*1024){
        if(self.skillsMode)self.allSkills=@[];else self.allItems=@[];
        self.filtered=@[];self.selected=nil;
        self.statusLabel.text=[NSString stringWithFormat:@"缺少 Documents/XiuxianjiazuGM/%@（或超过 8MB）",filename];
        [self.itemTable reloadData];[self showSelected];return;
    }
    NSError *error=nil;id root=[NSJSONSerialization JSONObjectWithData:bytes options:0 error:&error];
    if (![root isKindOfClass:NSArray.class]) {
        self.statusLabel.text=[NSString stringWithFormat:@"%@ 格式错误：顶层应为数组",filename];return;
    }
    NSMutableArray *valid=[NSMutableArray array];NSMutableSet *seen=[NSMutableSet set];
    for(id obj in (NSArray *)root) {
        if(![obj isKindOfClass:NSDictionary.class])continue;
        NSDictionary *o=obj;id ident=o[@"id"],raw=o[@"name"];
        if(![ident isKindOfClass:NSNumber.class]||![raw isKindOfClass:NSString.class])continue;
        if([ident integerValue]<=0||[seen containsObject:ident])continue;
        [seen addObject:ident];NSString *clean=CleanName(raw);
        if(self.skillsMode) {
            [valid addObject:@{@"id":ident,@"name":clean,@"raw":raw,
                @"skillQuality":[o[@"skillQuality"] isKindOfClass:NSNumber.class]?o[@"skillQuality"]:@(-1),
                @"skillCategory":[o[@"skillCategory"] isKindOfClass:NSNumber.class]?o[@"skillCategory"]:@(-1),
                @"skillType":[o[@"skillType"] isKindOfClass:NSNumber.class]?o[@"skillType"]:@(-1),
                @"isSelfCreation":[o[@"isSelfCreation"] isKindOfClass:NSNumber.class]?o[@"isSelfCreation"]:@(-1),
                @"skillDescribe":[o[@"skillDescribe"] isKindOfClass:NSString.class]?CleanName(o[@"skillDescribe"]):@"",
                @"lvtext":[o[@"lvtext"] isKindOfClass:NSString.class]?o[@"lvtext"]:@""}];
        } else {
            [valid addObject:@{@"id":ident,@"name":clean,@"raw":raw,
                @"type":[o[@"type"] isKindOfClass:NSNumber.class]?o[@"type"]:@(-1),
                @"childType":[o[@"childType"] isKindOfClass:NSNumber.class]?o[@"childType"]:@(-1),
                @"searchType":[o[@"searchType"] isKindOfClass:NSNumber.class]?o[@"searchType"]:@(-1)}];
        }
    }
    if(self.skillsMode)self.allSkills=[valid copy];else self.allItems=[valid copy];
    self.selected=nil;self.selectedCategory=0;self.page=0;
    [self.categoryTable reloadData];[self showSelected];[self rebuildFilter];
}
- (void)rebuildFilter {
    NSString *text=[self.query.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray *a=[NSMutableArray array];
    NSArray *source=self.skillsMode?self.allSkills:self.allItems;
    for(NSDictionary *item in source){
        if(self.skillsMode) {
            if(self.selectedCategory>=1 && self.selectedCategory<=9 &&
               [item[@"skillQuality"] integerValue]!=self.selectedCategory)continue;
            if(self.selectedCategory==10 && [item[@"isSelfCreation"] integerValue]!=1)continue;
        } else if(self.selectedCategory &&
                  [item[@"type"] integerValue]!=self.selectedCategory)continue;
        NSString *name=item[@"name"],*ident=[item[@"id"] stringValue];
        if(text.length && [name rangeOfString:text options:NSCaseInsensitiveSearch].location==NSNotFound
                && [ident rangeOfString:text].location==NSNotFound)continue;
        [a addObject:item];
    }
    self.filtered=[a copy];self.page=0;[self updatePage];
    self.statusLabel.text=[NSString stringWithFormat:@"%@：%lu 条 · 当前匹配 %lu 条",
        self.skillsMode?@"功法配置":@"物品配置",(unsigned long)source.count,(unsigned long)self.filtered.count];
}
- (NSUInteger)pageSize {return 9;}
- (NSUInteger)pageCount {return MAX((NSUInteger)1,(self.filtered.count+[self pageSize]-1)/[self pageSize]);}
- (void)updatePage {
    NSUInteger pages=[self pageCount];if(self.page<0)self.page=0;
    if((NSUInteger)self.page>=pages)self.page=(NSInteger)pages-1;
    self.countLabel.text=[NSString stringWithFormat:@"%lu 项  %ld/%lu",
        (unsigned long)self.filtered.count,(long)self.page+1,(unsigned long)pages];
    [self.itemTable reloadData];
}
- (void)previous:(id)sender {if(self.page>0){self.page--;[self updatePage];}}
- (void)next:(id)sender {if((NSUInteger)(self.page+1)<[self pageCount]){self.page++;[self updatePage];}}
- (void)showSelected {
    NSDictionary *o=self.selected;
    BOOL canSend=self.skillsMode?(o!=nil && self.selectedActor!=nil):(o!=nil);
    self.sendButton.enabled=canSend;self.sendButton.alpha=canSend?1:.5;
    self.actorButton.hidden=!self.skillsMode || self.attributesMode;
    if(self.skillsMode)[self.actorButton setTitle:self.selectedActor?
        [NSString stringWithFormat:@"弟子：%@",self.selectedActor[@"name"]]:@"选择弟子" forState:UIControlStateNormal];
    self.quantity.hidden=self.skillsMode;self.minusButton.hidden=self.skillsMode;self.plusButton.hidden=self.skillsMode;
    [self.sendButton setTitle:self.skillsMode?@"添加功法":@"发放物品" forState:UIControlStateNormal];
    if(!o){
        self.pickedLabel.text=self.skillsMode?
            [NSString stringWithFormat:@"弟子：%@ · 未选择功法",self.selectedActor[@"name"]?:@"未选择"]:@"未选择物品";
        self.detailLabel.text=self.skillsMode?@"功法说明\n\n请选择功法查看效果。":@"物品说明\n\n请选择物品。";
        return;
    }
    self.pickedLabel.text=self.skillsMode?
        [NSString stringWithFormat:@"弟子：%@ · 功法：%@",self.selectedActor[@"name"]?:@"未选择",o[@"name"]]:
        [NSString stringWithFormat:@"已选：%@",o[@"name"]];
    if(self.skillsMode) {
        NSString *level=[o[@"lvtext"] isKindOfClass:NSString.class]?o[@"lvtext"]:@"";
        NSString *description=[o[@"skillDescribe"] isKindOfClass:NSString.class]?o[@"skillDescribe"]:@"";
        self.detailLabel.text=[NSString stringWithFormat:@"功法说明\n%@\n\n%@%@",
            o[@"name"],level.length?[NSString stringWithFormat:@"层数：%@\n\n",level]:@"",
            description.length?description:@"暂无说明"];
    } else {
        self.detailLabel.text=[NSString stringWithFormat:@"物品说明\n\n%@",o[@"name"]];
    }
}
- (void)decrease:(id)sender {
    NSInteger n=MAX(1,MIN(9999,self.quantity.text.integerValue-1));
    self.quantity.text=[NSString stringWithFormat:@"%ld",(long)n];
}
- (void)increase:(id)sender {
    NSInteger n=MAX(1,MIN(9999,self.quantity.text.integerValue+1));
    self.quantity.text=[NSString stringWithFormat:@"%ld",(long)n];
}
- (void)finishQuantity:(id)sender {
    [self.quantity resignFirstResponder];
}
- (void)sendItem:(id)sender {
    // Do not send twice during keyboard dismissal or multiple taps.
    [self.view endEditing:YES];
    if(self.skillsMode) {
        if(!self.selected || !self.selectedActor) {
            self.statusLabel.text=@"请先选择功法与目标弟子";return;
        }
        int32_t actorId=[self.selectedActor[@"id"] intValue];
        int32_t skillId=[self.selected[@"id"] intValue];
        NSString *oldName=self.selectedActor[@"name"]?:@"";
        int oldForce=[self.selectedActor[@"forceId"] intValue];
        self.sendButton.enabled=NO;
        // Re-fetch live actors immediately before issuing a GM mutation.
        int count=[self reloadLiveActors:NO];
        if(count<0) {
            self.statusLabel.text=[NSString stringWithFormat:@"刷新弟子失败 E%03d；已取消发放",-count];
            [self showSelected];return;
        }
        NSDictionary *fresh=nil;
        for(NSDictionary *actor in self.liveActors)
            if([actor[@"id"] intValue]==actorId){fresh=actor;break;}
        if(!fresh || ![fresh[@"name"] isEqualToString:oldName] ||
           [fresh[@"forceId"] intValue]!=oldForce) {
            self.selectedActor=nil;
            self.statusLabel.text=@"弟子名单已变更，请重新选择后再发送";
            [self showSelected];return;
        }
        int rc=XJGMSendSkill(actorId,skillId);
        [self showSelected];
        self.statusLabel.text=rc==1?
            [NSString stringWithFormat:@"已发送：%@ → %@",oldName,self.selected[@"name"]]:
            [NSString stringWithFormat:@"功法发送失败 E%03d，检查 gm-skill-stage.txt",-rc];
        NSLog(@"[XJGM] skill actor=%d id=%d result=%d",actorId,skillId,rc);
        return;
    }
    NSDictionary *selected=self.selected;
    if(!selected || ![self.allItems containsObject:selected]) {
        self.statusLabel.text=@"未选择有效物品，未发送";return;
    }
    NSInteger itemId=[selected[@"id"] integerValue];
    NSString *qty=[self.quantity.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSCharacterSet *nonDigits=[[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if(itemId<=0 || itemId>INT32_MAX || !qty.length || [qty rangeOfCharacterFromSet:nonDigits].location!=NSNotFound ||
       qty.length>4 || qty.integerValue<1 || qty.integerValue>9999) {
        self.statusLabel.text=@"ID 或数量无效，数量范围为 1～9999";return;
    }
    int32_t ident=(int32_t)itemId, count=(int32_t)qty.integerValue;
    self.sendButton.enabled=NO;
    int rc=XJGMSendItem(ident,count);
    self.sendButton.enabled=(self.selected!=nil);
    if(rc==1)self.statusLabel.text=[NSString stringWithFormat:@"已发送：%@ × %d",selected[@"name"],count];
    else self.statusLabel.text=[NSString stringWithFormat:@"E%03d：GM 请求未发送，检查 gm-send-stage.txt",-rc];
    NSLog(@"[XJGM] send ID=%d count=%d result=%d",ident,count,rc);
}
- (void)openActors:(id)sender {
    if(!self.skillsMode && !self.attributePickPending)return;
    [self.view endEditing:YES];self.actorPicker.hidden=NO;
    [self.panel bringSubviewToFront:self.actorPicker];
    self.actorQuery.text=@"";
    [self reloadLiveActors:YES];
}
- (void)closeActors:(id)sender {
    [self.view endEditing:YES];self.actorPicker.hidden=YES;
}
- (void)refreshActors:(id)sender {
    [self.view endEditing:YES];[self reloadLiveActors:YES];
}
- (int)reloadLiveActors:(BOOL)updateUI {
    // Use the verified read-only runtime exporter as a fresh snapshot transport.
    // Never trust an older actors.json: read only after successful export.
    int code=XJGMExportActors();
    if(code<0) {
        self.liveActors=@[];self.visibleActors=@[];
        if(updateUI) {
            self.actorStatus.text=[NSString stringWithFormat:@"读取失败 E%03d（actor-export-stage.txt）",-code];
            [self.actorTable reloadData];
        }
        return code;
    }
    NSArray *dirs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    NSString *path=dirs.count?[[dirs[0] stringByAppendingPathComponent:@"XiuxianjiazuGM"]
                      stringByAppendingPathComponent:@"actors.json"]:nil;
    NSData *data=path?[NSData dataWithContentsOfFile:path options:0 error:nil]:nil;
    id root=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
    if(![root isKindOfClass:NSArray.class]) {
        self.liveActors=@[];return -430;
    }
    NSMutableArray *valid=[NSMutableArray array];NSMutableSet *ids=[NSMutableSet set];
    for(id obj in (NSArray *)root) {
        if(![obj isKindOfClass:NSDictionary.class])continue;
        NSDictionary *a=obj;
        if(![a[@"id"] isKindOfClass:NSNumber.class] ||
           ![a[@"name"] isKindOfClass:NSString.class] ||
           ![a[@"forceId"] isKindOfClass:NSNumber.class])continue;
        if([a[@"id"] intValue]<=0 || [ids containsObject:a[@"id"]])continue;
        [ids addObject:a[@"id"]];[valid addObject:a];
    }
    if(valid.count!=(NSUInteger)code) {
        self.liveActors=@[];return -431;
    }
    self.liveActors=[valid copy];
    if(updateUI) {
        // Retain selection only if all identity fields still match the fresh live snapshot.
        NSDictionary *matched=nil;
        for(NSDictionary *a in self.liveActors)
            if(self.selectedActor && [a[@"id"] isEqual:self.selectedActor[@"id"]] &&
                [a[@"name"] isEqual:self.selectedActor[@"name"]] &&
                [a[@"forceId"] isEqual:self.selectedActor[@"forceId"]]){matched=a;break;}
        self.selectedActor=matched;
        self.actorStatus.text=[NSString stringWithFormat:@"实时读取 %lu 名弟子", (unsigned long)valid.count];
        [self filterActors];[self showSelected];
    }
    return (int)valid.count;
}
- (void)filterActors {
    NSString *query=[self.actorQuery.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray *matching=[NSMutableArray array];
    for(NSDictionary *a in self.liveActors) {
        if(query.length && [a[@"name"] rangeOfString:query options:NSCaseInsensitiveSearch].location==NSNotFound &&
           [[a[@"id"] stringValue] rangeOfString:query].location==NSNotFound)continue;
        [matching addObject:a];
    }
    self.visibleActors=[matching copy];[self.actorTable reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{return 1;}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if(tableView==self.attributeTable)return self.attributeFiltered.count;
    if(tableView==self.actorTable)return self.visibleActors.count;
    if(tableView==self.categoryTable)return self.skillsMode?11:CategoryNames().count;
    NSInteger start=self.page*(NSInteger)[self pageSize];
    return MAX(0,MIN((NSInteger)[self pageSize],(NSInteger)self.filtered.count-start));
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.backgroundColor=Panel();cell.textLabel.textColor=Ink();
    cell.textLabel.font=[UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    cell.textLabel.numberOfLines=2;
    if(tableView==self.attributeTable){
        NSDictionary *a=self.attributeFiltered[(NSUInteger)indexPath.row];
        NSNumber *raw=self.attributeRawValues[a[@"id"]];
        BOOL percentage=[a[@"isPercentage"] boolValue];
        NSString *shown=raw?(percentage?
            [NSString stringWithFormat:@"%.2f%%",raw.doubleValue/100.0]:
            raw.stringValue):@"—";
        NSString *key=[self lockKeyForActor:self.selectedActor attribute:a];
        BOOL locked=key && self.attributeLocks[key]!=nil;
        cell.textLabel.text=[NSString stringWithFormat:@"%@   当前：%@%@",
            a[@"name"],shown,locked?@"   已锁定":@""];
        cell.backgroundColor=(self.selectedAttribute && [self.selectedAttribute[@"id"] isEqual:a[@"id"]])?Tan():Panel();
    } else if(tableView==self.actorTable){
        NSDictionary *a=self.visibleActors[(NSUInteger)indexPath.row];
        cell.textLabel.text=a[@"name"];
        cell.backgroundColor=(self.selectedActor && [self.selectedActor[@"id"] isEqual:a[@"id"]])?Tan():Panel();
    } else if(tableView==self.categoryTable){
        NSArray *names=self.skillsMode?@[@"全部",@"一阶",@"二阶",@"三阶",@"四阶",@"五阶",@"六阶",@"七阶",@"八阶",@"九阶",@"自创"]:CategoryNames();
        cell.textLabel.text=names[(NSUInteger)indexPath.row];
        cell.backgroundColor=self.selectedCategory==indexPath.row?Tan():Panel();
    } else {
        NSUInteger index=(NSUInteger)self.page*[self pageSize]+(NSUInteger)indexPath.row;
        NSDictionary *o=self.filtered[index];
        cell.textLabel.text=o[@"name"];
        if(self.selected && [self.selected[@"id"] isEqual:o[@"id"]])cell.backgroundColor=Tan();
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(tableView==self.attributeTable){
        if((NSUInteger)indexPath.row>=self.attributeFiltered.count)return;
        self.selectedAttribute=self.attributeFiltered[(NSUInteger)indexPath.row];
        NSNumber *raw=self.attributeRawValues[self.selectedAttribute[@"id"]];
        BOOL percentage=[self.selectedAttribute[@"isPercentage"] boolValue];
        NSString *shown=raw?(percentage?
            [NSString stringWithFormat:@"%.2f%%",raw.doubleValue/100.0]:raw.stringValue):@"—";
        self.attributeValue.placeholder=percentage?@"百分比，例如 12.50":@"输入整数";
        self.attributeValue.text=@"";
        self.attributeText.text=[NSString stringWithFormat:
            @"弟子：%@\n属性：%@\n当前值：%@\n百分比按游戏原始格式换算；未知游戏上限不作假设。",
            self.selectedActor[@"name"]?:@"未选择",self.selectedAttribute[@"name"],shown];
        [self updateAttributeSendState];
        [self.attributeTable reloadData];
    } else if(tableView==self.actorTable){
        if((NSUInteger)indexPath.row>=self.visibleActors.count)return;
        self.selectedActor=self.visibleActors[(NSUInteger)indexPath.row];
        self.actorPicker.hidden=YES;[self.view endEditing:YES];
        [self showSelected];
        if(self.attributePickPending) {
            self.attributePickPending=NO;
            [self.panel bringSubviewToFront:self.attributePanel];
            [self refreshAttributes:nil];
        }
    } else if(tableView==self.categoryTable){
        self.selectedCategory=indexPath.row;self.selected=nil;[self showSelected];[self.categoryTable reloadData];[self rebuildFilter];
    } else {
        NSUInteger index=(NSUInteger)self.page*[self pageSize]+(NSUInteger)indexPath.row;
        if(index>=self.filtered.count)return;
        self.selected=self.filtered[index];[self showSelected];[self.itemTable reloadData];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {[textField resignFirstResponder];return YES;}
@end

static XJGMController *sController=nil;
static void XJGMInstall(void) {
    if(sWindow||!UIApplication.sharedApplication)return;
    UIWindowScene *scene=nil;
    if(@available(iOS 13.0,*)){
        for(UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if([s isKindOfClass:UIWindowScene.class]&&s.activationState==UISceneActivationStateForegroundActive)
                {scene=(UIWindowScene *)s;break;}
    }
    if(@available(iOS 13.0,*)){
        if(!scene)return;sWindow=[[XJGMWindow alloc] initWithWindowScene:scene];
    }else sWindow=[[XJGMWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    sWindow.frame=UIScreen.mainScreen.bounds;sWindow.windowLevel=UIWindowLevelAlert+1;
    sWindow.backgroundColor=UIColor.clearColor;
    sController=[XJGMController new];sWindow.rootViewController=sController;sWindow.hidden=NO;
}
__attribute__((constructor)) static void XJGMStart(void){
    dispatch_async(dispatch_get_main_queue(),^{
        XJGMInstall();
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
            object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){XJGMInstall();}];
    });
}
