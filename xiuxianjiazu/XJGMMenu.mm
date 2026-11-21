#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// External items.json supplies the searchable catalog; GM request lives in a separate module.
#include <stdint.h>
#include <limits.h>
extern "C" int XJGMSendItem(int32_t itemId,int32_t count);
extern "C" int XJGMExportActors(void);
extern "C" int XJGMSendSkill(int32_t actorId,int32_t skillId);
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
    self.allItems=@[];self.allSkills=@[];self.filtered=@[];self.selectedCategory=0;self.page=0;self.skillsMode=NO;
    self.bubble=Btn(@"GM",self,@selector(toggle:));
    self.bubble.frame=CGRectMake(10,100,48,48);self.bubble.layer.cornerRadius=24;
    [self.view addSubview:self.bubble];
    [self.bubble addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)]];

    self.panel=[UIView new];self.panel.hidden=YES;self.panel.backgroundColor=Paper();
    self.panel.layer.borderColor=Border().CGColor;self.panel.layer.borderWidth=1;
    self.panel.layer.cornerRadius=10;self.panel.layer.shadowColor=UIColor.blackColor.CGColor;
    self.panel.layer.shadowOpacity=.36;self.panel.layer.shadowRadius=16;
    [self.view addSubview:self.panel];

    UILabel *title=Txt(@"修仙家族 · GM 物品管理",16);
    title.font=[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];title.textAlignment=NSTextAlignmentCenter;
    title.tag=901;[self.panel addSubview:title];
    self.closeButton=Btn(@"收起",self,@selector(toggle:));[self.panel addSubview:self.closeButton];
    self.itemsTab=Btn(@"物品功能",self,@selector(showItems:));[self.panel addSubview:self.itemsTab];
    self.skillsTab=Btn(@"功法列表",self,@selector(showSkills:));[self.panel addSubview:self.skillsTab];
    self.reloadButton=Btn(@"重新加载",self,@selector(loadItems:));[self.panel addSubview:self.reloadButton];

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
    self.itemsTab.frame=CGRectMake(m,41,94,28);
    self.skillsTab.frame=CGRectMake(m+100,41,94,28);
    self.reloadButton.frame=CGRectMake(w-104,41,95,28);
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
    self.statusLabel.frame=CGRectMake(m,bottom+68,inner,40);
}
- (void)toggle:(id)sender {
    self.panel.hidden=!self.panel.hidden;self.bubble.hidden=!self.panel.hidden;
    if (!self.panel.hidden) {
        [self adjustPanel];if(!(self.skillsMode?self.allSkills.count:self.allItems.count))[self loadItems:nil];
    } else {
        [self.view endEditing:YES];self.actorPicker.hidden=YES;
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
- (void)showItems:(id)sender {
    [self.view endEditing:YES];
    self.skillsMode=NO;self.selectedActor=nil;self.selected=nil;self.selectedCategory=0;self.page=0;self.query.text=@"";
    [self.categoryTable reloadData];[self showSelected];
    if(!self.allItems.count)[self loadItems:nil];else[self rebuildFilter];
}
- (void)showSkills:(id)sender {
    [self.view endEditing:YES];
    self.skillsMode=YES;self.selectedActor=nil;self.selected=nil;self.selectedCategory=0;self.page=0;self.query.text=@"";
    [self.categoryTable reloadData];[self showSelected];
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
    self.actorButton.hidden=!self.skillsMode;
    if(self.skillsMode)[self.actorButton setTitle:self.selectedActor?
        [NSString stringWithFormat:@"弟子：%@",self.selectedActor[@"name"]]:@"选择弟子" forState:UIControlStateNormal];
    self.quantity.hidden=self.skillsMode;self.minusButton.hidden=self.skillsMode;self.plusButton.hidden=self.skillsMode;
    [self.sendButton setTitle:self.skillsMode?@"添加功法":@"发放物品" forState:UIControlStateNormal];
    if(!o){
        self.pickedLabel.text=self.skillsMode?
            [NSString stringWithFormat:@"弟子：%@ · 未选功法",self.selectedActor[@"name"]?:@"未选择"]:@"未选择物品";
        self.detailLabel.text=self.skillsMode?@"功法说明\n\n选择阶位和功法查看详细配置。":@"物品说明\n\n选择分类和物品后，在这里查看 ID 与类型字段。";
        return;
    }
    self.pickedLabel.text=self.skillsMode?
        [NSString stringWithFormat:@"弟子：%@ · 功法：%@ ID %@",self.selectedActor[@"name"]?:@"未选择",o[@"name"],o[@"id"]]:
        [NSString stringWithFormat:@"已选：%@  ID %@",o[@"name"],o[@"id"]];
    if(self.skillsMode) {
        self.detailLabel.text=[NSString stringWithFormat:@"功法说明\n%@\nID：%@\n阶位：%@\n类别：%@ 类型：%@\n自创：%@\n层数：%@\n\n%@",
            o[@"name"],o[@"id"],o[@"skillQuality"],o[@"skillCategory"],o[@"skillType"],
            o[@"isSelfCreation"],o[@"lvtext"],o[@"skillDescribe"]];
    } else {
        self.detailLabel.text=[NSString stringWithFormat:@"物品说明\n\n%@\n\nID：%@\ntype：%@\nchildType：%@\nsearchType：%@",
            o[@"name"],o[@"id"],o[@"type"],o[@"childType"],o[@"searchType"]];
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
            [NSString stringWithFormat:@"功法请求已发送：弟子 %d，技能 %d；学习结果待实机确认",actorId,skillId]:
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
    if(rc==1)self.statusLabel.text=[NSString stringWithFormat:@"请求已发送：ID %d × %d；请以背包实际到账为准",ident,count];
    else self.statusLabel.text=[NSString stringWithFormat:@"E%03d：GM 请求未发送，检查 gm-send-stage.txt",-rc];
    NSLog(@"[XJGM] send ID=%d count=%d result=%d",ident,count,rc);
}
- (void)openActors:(id)sender {
    if(!self.skillsMode)return;
    [self.view endEditing:YES];self.actorPicker.hidden=NO;
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
    if(tableView==self.actorTable){
        NSDictionary *a=self.visibleActors[(NSUInteger)indexPath.row];
        cell.textLabel.text=[NSString stringWithFormat:@"%@ · ID %@ · 势力 %@",a[@"name"],a[@"id"],a[@"forceId"]];
        cell.backgroundColor=(self.selectedActor && [self.selectedActor[@"id"] isEqual:a[@"id"]])?Tan():Panel();
    } else if(tableView==self.categoryTable){
        NSArray *names=self.skillsMode?@[@"全部",@"一阶",@"二阶",@"三阶",@"四阶",@"五阶",@"六阶",@"七阶",@"八阶",@"九阶",@"自创"]:CategoryNames();
        cell.textLabel.text=names[(NSUInteger)indexPath.row];
        cell.backgroundColor=self.selectedCategory==indexPath.row?Tan():Panel();
    } else {
        NSUInteger index=(NSUInteger)self.page*[self pageSize]+(NSUInteger)indexPath.row;
        NSDictionary *o=self.filtered[index];
        cell.textLabel.text=[NSString stringWithFormat:@"%@\nID %@",o[@"name"],o[@"id"]];
        if(self.selected && [self.selected[@"id"] isEqual:o[@"id"]])cell.backgroundColor=Tan();
    }
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(tableView==self.actorTable){
        if((NSUInteger)indexPath.row>=self.visibleActors.count)return;
        self.selectedActor=self.visibleActors[(NSUInteger)indexPath.row];
        self.actorPicker.hidden=YES;[self.view endEditing:YES];
        [self showSelected];
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
