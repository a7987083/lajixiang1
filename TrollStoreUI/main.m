#import <UIKit/UIKit.h>
static UIColor *BG(void){return [UIColor colorWithRed:.951 green:.951 blue:.965 alpha:1];}
static UIColor *BLUE(void){return [UIColor colorWithRed:.19 green:.46 blue:.98 alpha:1];}
static UILabel *Lab(NSString *s,CGFloat size,BOOL bold,UIColor *color){UILabel*l=[UILabel new];l.text=s;l.font=bold?[UIFont boldSystemFontOfSize:size]:[UIFont systemFontOfSize:size];l.textColor=color?:UIColor.blackColor;return l;}
static UIView *Card(void){UIView*v=[UIView new];v.backgroundColor=UIColor.whiteColor;v.layer.cornerRadius=18;v.clipsToBounds=YES;return v;}
@interface MainVC:UIViewController <UIScrollViewDelegate,UITextFieldDelegate>
@property(nonatomic) NSInteger selected;
@property(nonatomic,strong) UIView *bar,*content;
@property(nonatomic,strong) UIScrollView *scroll;
@property(nonatomic,strong) NSMutableArray<NSDictionary*> *apps;
@property(nonatomic,strong) UITextField *search;
@end
@implementation MainVC
- (void)viewDidLoad{[super viewDidLoad];self.view.backgroundColor=BG();self.apps=[NSMutableArray array];[self build];}
- (void)clear{for(UIView*v in [self.view.subviews copy])[v removeFromSuperview];}
- (void)button:(NSString*)name at:(CGRect)r parent:(UIView*)parent action:(SEL)sel tag:(NSInteger)tag{
 UIButton*b=[UIButton buttonWithType:UIButtonTypeSystem];b.frame=r;[b setTitle:name forState:UIControlStateNormal];b.tintColor=BLUE();b.titleLabel.font=[UIFont systemFontOfSize:17];b.tag=tag;[b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];[parent addSubview:b];
}
- (void)build{
 [self clear];CGFloat w=self.view.bounds.size.width,h=self.view.bounds.size.height;CGFloat top=self.view.safeAreaInsets.top;if(top<20)top=50;
 self.scroll=[[UIScrollView alloc]initWithFrame:CGRectMake(0,top,w,h-top)];self.scroll.contentInset=UIEdgeInsetsMake(0,0,142,0);self.scroll.alwaysBounceVertical=YES;[self.view addSubview:self.scroll];
 NSString*title=@[@"应用",@"安装包",@"插件",@"设置"][self.selected];
 UILabel*heading=Lab(title,37,YES,UIColor.blackColor);heading.frame=CGRectMake(17,78,w-34,56);[self.scroll addSubview:heading];
 if(self.selected==3){[self button:@"🖌" at:CGRectMake(w-67,22,52,45) parent:self.scroll action:@selector(appearance) tag:0];[self settings:w];}
 else{
 [self button:@"+" at:CGRectMake(w-60,17,42,42) parent:self.scroll action:@selector(add) tag:0];
 if(self.selected>0)[self button:@"编辑" at:CGRectMake(w-120,17,60,42) parent:self.scroll action:@selector(edit) tag:0];
 if(self.selected==0)[self appsPage:w];
 }
 [self tabbar:w height:h];
}
- (void)viewDidLayoutSubviews{[super viewDidLayoutSubviews];if(self.bar){CGFloat w=self.view.bounds.size.width,h=self.view.bounds.size.height;self.bar.frame=CGRectMake(43,h-self.view.safeAreaInsets.bottom-82,w-86,69);}}
- (void)tabbar:(CGFloat)w height:(CGFloat)h{
 self.bar=Card();self.bar.layer.borderWidth=.5;self.bar.layer.borderColor=[UIColor colorWithWhite:.79 alpha:1].CGColor;self.bar.layer.cornerRadius=37;self.bar.layer.shadowColor=UIColor.blackColor.CGColor;self.bar.layer.shadowOpacity=.08;self.bar.layer.shadowRadius=17;self.bar.clipsToBounds=NO;
 [self.view addSubview:self.bar];
 NSArray*names=@[@"应用",@"安装包",@"插件",@"设置"],*icons=@[@"▦",@"▣",@"✚",@"⚙"];
 CGFloat width=(w-86)/4;
 for(NSInteger i=0;i<4;i++){
 UIButton*b=[UIButton buttonWithType:UIButtonTypeSystem];b.tag=i;b.frame=CGRectMake(width*i,4,width,61);
 UILabel*icon=Lab(icons[i],29,YES,i==self.selected?BLUE():UIColor.grayColor);icon.textAlignment=NSTextAlignmentCenter;icon.frame=CGRectMake(0,2,width,33);[b addSubview:icon];
 UILabel*name=Lab(names[i],11,i==self.selected,i==self.selected?BLUE():UIColor.grayColor);name.textAlignment=NSTextAlignmentCenter;name.frame=CGRectMake(0,42,width,14);[b addSubview:name];
 [b addTarget:self action:@selector(switchTab:) forControlEvents:UIControlEventTouchUpInside];[self.bar addSubview:b];
 }
}
- (void)switchTab:(UIButton*)sender{self.selected=sender.tag;[self build];}
- (void)appsPage:(CGFloat)w{
 UIView*search=Card();search.frame=CGRectMake(16,145,w-32,39);search.layer.cornerRadius=11;search.backgroundColor=[UIColor colorWithWhite:.88 alpha:1];[self.scroll addSubview:search];
 UITextField*t=[[UITextField alloc]initWithFrame:CGRectMake(14,0,w-60,39)];t.placeholder=@"⌕ 搜索";t.delegate=self;t.clearButtonMode=UITextFieldViewModeWhileEditing;[t addTarget:self action:@selector(filterApps) forControlEvents:UIControlEventEditingChanged];[search addSubview:t];self.search=t;
 NSFileManager*fm=NSFileManager.defaultManager;
 NSString*path=@"/var/containers/Bundle/Application";
 NSArray*dirs=[fm contentsOfDirectoryAtPath:path error:nil];
 for(NSString*dir in dirs){
  NSString*p=[path stringByAppendingPathComponent:dir];
  for(NSString*entry in [fm contentsOfDirectoryAtPath:p error:nil]){
   if(![entry.pathExtension.lowercaseString isEqualToString:@"app"])continue;
   NSString*appPath=[p stringByAppendingPathComponent:entry];
   NSDictionary*info=[NSDictionary dictionaryWithContentsOfFile:[appPath stringByAppendingPathComponent:@"Info.plist"]];
   if(!info)continue;
   [self.apps addObject:@{@"name":info[@"CFBundleDisplayName"]?:info[@"CFBundleName"]?:entry,@"bundle":info[@"CFBundleIdentifier"]?:@"",@"version":info[@"CFBundleShortVersionString"]?:@"",@"icon":@"",}];
  }
 }
 [self.apps sortUsingComparator:^NSComparisonResult(NSDictionary*a,NSDictionary*b){return [a[@"name"] localizedStandardCompare:b[@"name"]];}];
 [self renderApps];
}
- (void)filterApps{[self renderApps];}
- (void)renderApps{
 for(UIView*v in [self.scroll.subviews copy])if(v.tag==900)[v removeFromSuperview];
 CGFloat w=self.view.bounds.size.width,y=207;
 for(NSDictionary*d in self.apps){
  if(self.search.text.length&&[d[@"name"] rangeOfString:self.search.text options:NSCaseInsensitiveSearch].location==NSNotFound)continue;
  UIView*card=Card();card.tag=900;card.frame=CGRectMake(16,y,w-32,77);[self.scroll addSubview:card];
  UIView*ico=Card();ico.frame=CGRectMake(16,11,54,54);ico.layer.cornerRadius=12;ico.backgroundColor=[UIColor colorWithRed:.30 green:.49 blue:.95 alpha:1];[card addSubview:ico];
  UILabel*letter=Lab([d[@"name"] substringToIndex:MIN((NSUInteger)1,[d[@"name"] length])],24,YES,UIColor.whiteColor);letter.frame=ico.bounds;letter.textAlignment=NSTextAlignmentCenter;[ico addSubview:letter];
  UILabel*name=Lab(d[@"name"],17,YES,nil);name.frame=CGRectMake(84,8,w-115,23);[card addSubview:name];
  UILabel*bundle=Lab([NSString stringWithFormat:@"%@ · %@",d[@"version"],d[@"bundle"]],12,NO,UIColor.grayColor);bundle.frame=CGRectMake(84,32,w-118,18);[card addSubview:bundle];
  UILabel*origin=Lab(@"App Store",11,NO,BLUE());origin.frame=CGRectMake(84,53,95,17);[card addSubview:origin];
  y+=88;
 }
 self.scroll.contentSize=CGSizeMake(w,MAX(self.scroll.bounds.size.height+1,y+45));
}
- (void)settings:(CGFloat)w{
 NSArray*sections=@[
 @{@"label":@"实用工具",@"items":@[@"注销",@"刷新应用注册状态",@"重建图标缓存"]},
 @{@"label":@"设备管理",@"items":@[@"自定义清理",@"切换 App Store 账户",@"允许所有 App 粘贴",@"屏蔽/恢复 系统更新",@"直降应用"]},
 @{@"label":@"签名",@"items":@[@"签名工具",@"修改应用信息"]}];
 CGFloat y=171;
 for(NSDictionary*s in sections){
 UILabel*label=Lab(s[@"label"],14,NO,UIColor.grayColor);label.frame=CGRectMake(30,y,w-50,24);[self.scroll addSubview:label];y+=29;
 for(NSString*name in s[@"items"]){
 UIView*cell=Card();cell.frame=CGRectMake(17,y,w-34,46);[self.scroll addSubview:cell];
 UILabel*txt=Lab([@"⦿    " stringByAppendingString:name],17,NO,BLUE());txt.frame=CGRectMake(22,0,w-70,46);[cell addSubview:txt];
 UITapGestureRecognizer*g=[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(settingTapped:)];[cell addGestureRecognizer:g];cell.accessibilityLabel=name;y+=57;
 }
 if([s[@"label"] isEqual:@"实用工具"]){UILabel*note=Lab(@"如果应用安装后没有立即出现在主屏幕，请在此处注销一次。",13,NO,UIColor.grayColor);note.numberOfLines=0;note.frame=CGRectMake(30,y,w-60,46);[self.scroll addSubview:note];y+=56;}
 y+=27;
 }
 self.scroll.contentSize=CGSizeMake(w,y+130);
}
- (void)settingTapped:(UITapGestureRecognizer*)gesture{
 NSString*name=gesture.view.accessibilityLabel;
 if([name isEqual:@"修改应用信息"]){[self showEditSheet];return;}
 [self message:[NSString stringWithFormat:@"%@：此预览版本尚未连接系统操作。",name]];
}
- (void)showEditSheet{
 UIViewController*v=[UIViewController new];v.view.backgroundColor=BG();v.title=@"修改应用信息";
 UINavigationController*n=[[UINavigationController alloc]initWithRootViewController:v];n.modalPresentationStyle=UIModalPresentationPageSheet;
 v.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(dismissSheet)];
 UIScrollView*scroll=[[UIScrollView alloc]initWithFrame:v.view.bounds];scroll.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;[v.view addSubview:scroll];CGFloat w=self.view.bounds.size.width,y=24;
 NSArray*rows=@[@"移除所有应用扩展",@"移除所有手表扩展",@"备份可执行文件",@"修复插件依赖",@"选择依赖库",@"开启文件访问",@"注入选项",@"@executable_path         @rpath",@"根目录 (/)         框架目录 (/Frameworks)",@"高级操作",@"选择注入文件...",@"选择要移除的库...",@"确认修改/打包"];
 for(NSString*str in rows){
 BOOL heading=[str isEqual:@"注入选项"]||[str isEqual:@"高级操作"];
 if(heading){UILabel*l=Lab(str,14,NO,UIColor.grayColor);l.frame=CGRectMake(20,y,w-40,35);[scroll addSubview:l];y+=44;continue;}
 UIView*c=Card();c.frame=CGRectMake(20,y,w-40,48);[scroll addSubview:c];
 UILabel*l=Lab(str,15,NO,UIColor.blackColor);l.frame=CGRectMake(16,0,w-90,48);[c addSubview:l];
 if([str containsString:@"扩展"]||[str containsString:@"文件"]||[str containsString:@"依赖"]){if([str hasPrefix:@"移除"]||[str hasPrefix:@"备份"]||[str hasPrefix:@"修复"]||[str hasPrefix:@"开启"]){UISwitch*s=[UISwitch new];s.frame=CGRectMake(w-93,8,55,32);[c addSubview:s];}}
 y+=62;
 }
 scroll.contentSize=CGSizeMake(w,y+45);[self presentViewController:n animated:YES completion:nil];
}
- (void)dismissSheet{[self dismissViewControllerAnimated:YES completion:nil];}
- (void)appearance{[self message:@"外观选项尚未连接。"];}
- (void)add{[self message:@"导入界面待连接。"];}
- (void)edit{[self message:@"编辑模式待连接。"];}
- (void)message:(NSString*)s{UIAlertController*a=[UIAlertController alertControllerWithTitle:@"UI 预览" message:s preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:a animated:YES completion:nil];}
@end
@interface AppDelegate:UIResponder<UIApplicationDelegate>
@property(nonatomic,strong)UIWindow*window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication*)app didFinishLaunchingWithOptions:(NSDictionary*)opts{self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];MainVC*vc=[MainVC new];self.window.rootViewController=vc;[self.window makeKeyAndVisible];return YES;}
@end
int main(int argc,char**argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(AppDelegate.class));}}
