#import <UIKit/UIKit.h>
static UIColor *C(int hex){return [UIColor colorWithRed:((hex>>16)&255)/255. green:((hex>>8)&255)/255. blue:(hex&255)/255. alpha:1];}
static UILabel *L(NSString *s,CGFloat font,BOOL bold,UIColor *color){UILabel *l=[UILabel new];l.text=s;l.textColor=color;l.font=bold?[UIFont boldSystemFontOfSize:font]:[UIFont systemFontOfSize:font];return l;}
@interface Screen : UIViewController
@property NSInteger tab;
@property(nonatomic,strong) UIView *content;
@property(nonatomic,strong) UIScrollView *scroll;
@property(nonatomic,strong) UIView *dock;
@end
@implementation Screen
- (void)demo {UIAlertController *a=[UIAlertController alertControllerWithTitle:@"界面演示" message:@"当前为 UI 占位，尚未接入实际安装、插件或系统管理功能。" preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"知道了" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:a animated:YES completion:nil];}
- (void)viewDidLoad {[super viewDidLoad];self.view.backgroundColor=C(0xF2F2F7);[self build];}
- (CGFloat)line:(NSString*)text y:(CGFloat)y x:(CGFloat)x color:(UIColor*)color size:(CGFloat)size bold:(BOOL)bold height:(CGFloat)h {
 UILabel *l=L(text,size,bold,color);l.numberOfLines=0;l.frame=CGRectMake(x,y,self.view.bounds.size.width-2*x,h);[self.content addSubview:l];return y+h;
}
- (CGFloat)card:(NSString*)name detail:(NSString*)detail symbol:(NSString*)symbol badge:(NSString*)badge y:(CGFloat)y {
 CGFloat w=self.view.bounds.size.width;
 UIView *v=[[UIView alloc]initWithFrame:CGRectMake(18,y,w-36,48)];v.backgroundColor=UIColor.whiteColor;v.layer.cornerRadius=12;[self.content addSubview:v];
 UIView *ic=[[UIView alloc]initWithFrame:CGRectMake(10,8,32,32)];ic.backgroundColor=C(0xE6F0FF);ic.layer.cornerRadius=8;[v addSubview:ic];
 UIImageView *iv=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:symbol?:@"app.fill"]];iv.tintColor=C(0x337CFA);iv.contentMode=UIViewContentModeScaleAspectFit;iv.frame=CGRectInset(ic.bounds,7,7);[ic addSubview:iv];
 UILabel *t=L(name,11,YES,UIColor.blackColor);t.frame=CGRectMake(50,3,w-92,15);[v addSubview:t];
 UILabel *d=L(detail,9,NO,C(0x8E8E93));d.adjustsFontSizeToFitWidth=YES;d.minimumScaleFactor=.75;d.frame=CGRectMake(50,17,w-89,13);[v addSubview:d];
 if(badge){UILabel *b=L(badge,8,NO,[badge isEqual:@"TrollStore"]?C(0x36B85A):C(0x337CFA));b.backgroundColor=[badge isEqual:@"TrollStore"]?C(0xE7F8EB):C(0xE6F0FF);b.textAlignment=NSTextAlignmentCenter;b.layer.cornerRadius=4;b.clipsToBounds=YES;b.frame=CGRectMake(50,32,[badge isEqual:@"TrollStore"]?53:47,12);[v addSubview:b];}
 UIButton *tap=[UIButton buttonWithType:UIButtonTypeCustom];tap.frame=v.bounds;[tap addTarget:self action:@selector(demo) forControlEvents:UIControlEventTouchUpInside];[v addSubview:tap];
 return y+54;
}
- (CGFloat)setting:(NSString*)name icon:(NSString*)icon color:(UIColor*)color y:(CGFloat)y {
 CGFloat w=self.view.bounds.size.width;UIView *v=[[UIView alloc]initWithFrame:CGRectMake(18,y,w-36,50)];v.backgroundColor=UIColor.whiteColor;v.layer.cornerRadius=19;[self.content addSubview:v];
 UIImageView *iv=[[UIImageView alloc]initWithImage:[UIImage systemImageNamed:icon]];iv.frame=CGRectMake(23,13,24,24);iv.tintColor=color;iv.contentMode=UIViewContentModeScaleAspectFit;[v addSubview:iv];
 UILabel *lab=L(name,16,NO,color);lab.frame=CGRectMake(63,6,w-107,38);lab.adjustsFontSizeToFitWidth=YES;lab.minimumScaleFactor=.7;[v addSubview:lab];
 UIButton *tap=[UIButton buttonWithType:UIButtonTypeCustom];tap.frame=v.bounds;[tap addTarget:self action:@selector(demo) forControlEvents:UIControlEventTouchUpInside];[v addSubview:tap];return y+59;
}
- (void)build {
 CGFloat w=self.view.bounds.size.width;
 self.scroll=[[UIScrollView alloc]initWithFrame:self.view.bounds];self.scroll.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;self.scroll.contentInset=UIEdgeInsetsMake(0,0,104,0);[self.view addSubview:self.scroll];
 self.content=[[UIView alloc]initWithFrame:CGRectMake(0,0,w,1700)];[self.scroll addSubview:self.content];
 CGFloat y=0;
 if(self.tab==3){
 UILabel *title=L(@"设置",21,YES,UIColor.blackColor);title.textAlignment=NSTextAlignmentCenter;title.frame=CGRectMake(0,68,w,40);[self.content addSubview:title];y=123;
 y=[self line:@"如果应用安装后没有立即出现在主屏幕，请在此处注销一次。对于无法启动的应用，可以尝试刷新应用注册状态。" y:y x:30 color:C(0x8E8E93) size:14 bold:NO height:59]+15;
 y=[self line:@"设备管理" y:y x:30 color:C(0x8E8E93) size:14 bold:NO height:27]+5;
 NSArray *names=@[@"自定义清理",@"切换 App Store 账户",@"允许所有 App 粘贴",@"屏蔽 / 恢复 系统更新",@"直降应用"];
 NSArray *icons=@[@"trash.circle.fill",@"person.2.circle.fill",@"doc.on.doc.fill",@"shield.slash.fill",@"arrow.down.to.line"];
 for(NSInteger i=0;i<names.count;i++)y=[self setting:names[i] icon:icons[i] color:C(0x337CFA) y:y];
 y=[self line:@"自定义清理功能允许你添加文件或文件夹路径，以便快速清理缓存垃圾或其它文件。\n直降应用功能允许你直接降级设备未安装应用到指定版本。" y:y x:30 color:C(0x8E8E93) size:14 bold:NO height:95]+5;
 y=[self line:@"签名工具 (LDID)" y:y x:30 color:C(0x8E8E93) size:14 bold:NO height:30]+5;
 y=[self setting:@"ldid: 已安装 (v2.1.5-procursus7-new)" icon:@"checkmark.seal.fill" color:C(0x8E8E93) y:y];
 y=[self line:@"ldid 状态仅为演示占位，未进行系统检测。" y:y x:30 color:C(0x8E8E93) size:13 bold:NO height:35]+8;
 y=[self line:@"持久性助手" y:y x:30 color:C(0x8E8E93) size:14 bold:NO height:32]+8;
 y=[self setting:@"助手状态（演示占位）" icon:@"checkmark.square.fill" color:C(0x8E8E93) y:y];
 y=[self setting:@"卸载持久化助手" icon:@"trash" color:UIColor.systemRedColor y:y];
 }else{
 NSString *heading=@[@"应用",@"安装包",@"插件"][self.tab];
 y=[self line:heading y:100 x:20 color:UIColor.blackColor size:37 bold:YES height:53]+8;
 if(self.tab==0){
 NSArray *items=@[
 @[@"123云盘",@"3.3.2 · com.mfcloudcalculate.123networkdisk",@"cloud.fill",@"App Store"],
 @[@"阿里巴巴",@"12.11.1 · com.alibaba.wireless",@"shippingbox.fill",@"App Store"],
 @[@"阿里云盘",@"6.12.2 · com.alicloud.smartdrive",@"externaldrive.fill",@"App Store"],
 @[@"爱思全能版",@"2.2.0 · com.ownbook.notes",@"app.badge.fill",@"App Store"],
 @[@"保通双录",@"2.2.7 · com.baoinsurance.dr",@"video.fill",@"App Store"],
 @[@"必剪",@"2.91.0 · com.bilibili.studio",@"play.rectangle.fill",@"App Store"],
 @[@"哔哩哔哩",@"8.76.0 · tv.danmaku.bilianime",@"tv.fill",@"App Store"],
 @[@"Truck Simulator : Ultimate",@"1.3.7 · com.zuuks.truck.simulator.ultimate",@"truck.box.fill",@"TrollStore"],
 @[@"X",@"12.33 · com.atebits.Tweetie2",@"xmark",@"App Store"],
 @[@"XP Hero",@"26.2.0 · io.supercent.weaponrpg",@"gamecontroller.fill",@"TrollStore"],
 @[@"YouTube",@"20.02.3 · com.google.ios.youtube",@"play.rectangle.fill",@"TrollStore"],
 @[@"YY",@"8.62.0 · yyvoice",@"waveform",@"App Store"],
 @[@"zonoe",@"0.2.18 · com.GameStore.maicha.rebuild",@"pawprint.fill",@"TrollStore"],
 @[@"zonoe",@"3.0.0 · com.hfa.sign",@"pawprint.fill",@"App Store"]];
 for(NSArray *a in items)y=[self card:a[0] detail:a[1] symbol:a[2] badge:a[3] y:y];
 } else if(self.tab==1){
 y=[self card:@"1" detail:@"文件夹 · 2026-10-11 09:21（演示）" symbol:@"folder.fill" badge:nil y:y];
 y=[self card:@"Random Dice 2.ipa" detail:@"273.6 MB · 2026-10-10 02:35（演示）" symbol:@"doc.fill" badge:nil y:y];
 y=[self card:@"test.ipa" detail:@"960 KB · 2026-10-11 06:42（演示）" symbol:@"doc.fill" badge:nil y:y];
 }else{y=175;}
 }
 self.content.frame=CGRectMake(0,0,w,MAX(y,self.view.bounds.size.height-104));self.scroll.contentSize=CGSizeMake(w,y);
 if(self.tab==1 || self.tab==2){UIButton *edit=[UIButton buttonWithType:UIButtonTypeSystem];edit.frame=CGRectMake(w-108,72,42,34);[edit setTitle:@"编辑" forState:UIControlStateNormal];edit.titleLabel.font=[UIFont systemFontOfSize:16];[edit addTarget:self action:@selector(demo) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:edit];}
 if(self.tab==3){UIButton *brush=[UIButton buttonWithType:UIButtonTypeSystem];brush.frame=CGRectMake(w-58,69,40,40);[brush setImage:[UIImage systemImageNamed:@"paintbrush.pointed.fill"] forState:UIControlStateNormal];brush.tintColor=C(0x337CFA);[brush addTarget:self action:@selector(demo) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:brush];}
 if(self.tab!=3){UIButton *plus=[UIButton buttonWithType:UIButtonTypeSystem];plus.frame=CGRectMake(w-53,68,42,42);[plus setImage:[UIImage systemImageNamed:@"plus.circle.fill" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:29]] forState:UIControlStateNormal];plus.tintColor=C(0x337CFA);[plus addTarget:self action:@selector(demo) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:plus];}
 [self tabs];
}
- (void)change:(UIButton*)sender {Screen *s=[Screen new];s.tab=sender.tag;self.view.window.rootViewController=s;}
- (void)tabs {
 CGFloat w=self.view.bounds.size.width;CGFloat dockWidth=MIN(w-112,320);
 UIView *bar=[[UIView alloc]initWithFrame:CGRectMake((w-dockWidth)/2,self.view.bounds.size.height-94,dockWidth,60)];
 bar.autoresizingMask=UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin;bar.layer.cornerRadius=30;bar.layer.borderWidth=.5;bar.layer.borderColor=C(0xD0D0D4).CGColor;bar.backgroundColor=C(0xF9F9FB);bar.layer.shadowColor=UIColor.blackColor.CGColor;bar.layer.shadowOpacity=.08;bar.layer.shadowRadius=11;[self.view addSubview:bar];
 NSArray *names=@[@"应用",@"安装包",@"插件",@"设置"],*icons=@[@"square.grid.3x3.fill",@"shippingbox.fill",@"puzzlepiece.fill",@"gearshape.fill"];
 for(NSInteger i=0;i<4;i++){CGFloat col=dockWidth/4;UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];b.tag=i;b.frame=CGRectMake(i*col,2,col,38);b.tintColor=i==self.tab?C(0x337CFA):C(0x8E8E93);[b setImage:[UIImage systemImageNamed:icons[i] withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:19]] forState:UIControlStateNormal];[b addTarget:self action:@selector(change:) forControlEvents:UIControlEventTouchUpInside];[bar addSubview:b];UILabel *t=L(names[i],10,i==self.tab,b.tintColor);t.textAlignment=NSTextAlignmentCenter;t.frame=CGRectMake(i*col,38,col,17);[bar addSubview:t];}
}
@end
@interface SkinDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation SkinDelegate
- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)options {self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[Screen new];[self.window makeKeyAndVisible];return YES;}
@end
int main(int argc,char**argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass([SkinDelegate class]));}}
