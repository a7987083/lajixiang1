#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <dispatch/dispatch.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// IL2CPP ABI declarations: resolved at runtime; no Unity headers needed.
struct Il2CppDomain; struct Il2CppAssembly; struct Il2CppImage;
struct Il2CppClass; struct Il2CppObject; struct MethodInfo; struct Il2CppException;
struct Il2CppType; struct Il2CppString;
typedef void *(*FnSymbol)(void);
struct API {
 void *handle;
 Il2CppDomain *(*domain_get)(void);
 const Il2CppAssembly **(*domain_get_assemblies)(const Il2CppDomain *, size_t *);
 const Il2CppImage *(*assembly_get_image)(const Il2CppAssembly *);
 const char *(*image_get_name)(const Il2CppImage *);
 Il2CppClass *(*class_from_name)(const Il2CppImage *, const char *, const char *);
 const MethodInfo *(*class_get_methods)(Il2CppClass *, void **);
 const char *(*method_get_name)(const MethodInfo *);
 uint32_t (*method_get_param_count)(const MethodInfo *);
 const Il2CppType *(*method_get_param)(const MethodInfo *, uint32_t);
 const Il2CppType *(*method_get_return_type)(const MethodInfo *);
 uint32_t (*method_get_flags)(const MethodInfo *, uint32_t *);
 char *(*type_get_name)(const Il2CppType *);
 Il2CppObject *(*runtime_invoke)(const MethodInfo *, void *, void **, Il2CppException **);
 Il2CppObject *(*object_unbox)(Il2CppObject *);
 void *(*thread_current)(void);
 void *(*thread_attach)(Il2CppDomain *);
 void (*free_fn)(void *);
 Il2CppString *(*string_new)(const char *);
 const char *(*class_get_name)(Il2CppClass *);
 Il2CppClass *(*class_get_parent)(Il2CppClass *);
 const MethodInfo *(*class_get_method_from_name)(Il2CppClass *, const char *, int);
 Il2CppClass *(*object_get_class)(Il2CppObject *);
 bool (*class_is_assignable_from)(Il2CppClass *, Il2CppClass *);
};
static API gAPI={};
static NSString *GMDiagnostic(NSString *code, NSString *detail) {
 return [NSString stringWithFormat:@"%@：%@", code, detail ?: @""];
}
static bool LoadAPI(void) {
 if(gAPI.domain_get)return true;
 void *h=dlopen("UnityFramework",RTLD_NOLOAD|RTLD_NOW);
 if(!h) {
  for(uint32_t i=0;i<_dyld_image_count();++i){
   const char *p=_dyld_get_image_name(i);
   if(p && strstr(p,"UnityFramework")){h=dlopen(p,RTLD_NOLOAD|RTLD_NOW);break;}
  }
 }
 if(!h)h=dlopen(NULL,RTLD_NOW);
 if(!h)return false;
 #define RESOLVE(field,symbol) gAPI.field=(decltype(gAPI.field))dlsym(h,"il2cpp_" symbol)
 RESOLVE(domain_get,"domain_get");
 RESOLVE(domain_get_assemblies,"domain_get_assemblies");
 RESOLVE(assembly_get_image,"assembly_get_image");
 RESOLVE(image_get_name,"image_get_name");
 RESOLVE(class_from_name,"class_from_name");
 RESOLVE(class_get_methods,"class_get_methods");
 RESOLVE(method_get_name,"method_get_name");
 RESOLVE(method_get_param_count,"method_get_param_count");
 RESOLVE(method_get_param,"method_get_param");
 RESOLVE(method_get_return_type,"method_get_return_type");
 RESOLVE(method_get_flags,"method_get_flags");
 RESOLVE(type_get_name,"type_get_name");
 RESOLVE(runtime_invoke,"runtime_invoke");
 RESOLVE(object_unbox,"object_unbox");
 RESOLVE(thread_current,"thread_current");
 RESOLVE(thread_attach,"thread_attach");
 RESOLVE(free_fn,"free");
 RESOLVE(string_new,"string_new");
 RESOLVE(class_get_name,"class_get_name");
 RESOLVE(class_get_parent,"class_get_parent");
 RESOLVE(class_get_method_from_name,"class_get_method_from_name");
 RESOLVE(object_get_class,"object_get_class");
 RESOLVE(class_is_assignable_from,"class_is_assignable_from");
 #undef RESOLVE
 if(!(gAPI.domain_get && gAPI.domain_get_assemblies && gAPI.assembly_get_image &&
      gAPI.image_get_name && gAPI.class_from_name && gAPI.class_get_methods &&
      gAPI.method_get_name && gAPI.method_get_param_count && gAPI.method_get_param &&
      gAPI.method_get_flags && gAPI.type_get_name && gAPI.runtime_invoke &&
      gAPI.thread_current && gAPI.thread_attach && gAPI.class_get_parent &&
      gAPI.class_get_method_from_name && gAPI.object_get_class &&
      gAPI.class_is_assignable_from && gAPI.class_get_name)) {
  memset(&gAPI,0,sizeof(gAPI));return false;
 }
 gAPI.handle=h;
 return true;
}
// Only the game's existing PersistentSingleton<T> accessor is considered.
// Never fabricate a MonoBehaviour with il2cpp_object_new.
static Il2CppObject *ResolveSingleton(Il2CppClass *cls, NSString **diagnostic) {
 Il2CppClass *parent=gAPI.class_get_parent(cls);
 const char *parentName=parent?gAPI.class_get_name(parent):nullptr;
 if(!parentName || strncmp(parentName,"PersistentSingleton",19)!=0) {
  *diagnostic=GMDiagnostic(@"E112",@"非已知 PersistentSingleton 类型，无可信实例来源");
  return nullptr;
 }
 // Query inherited method on the closed derived type first (generic inflation).
 const MethodInfo *getter=gAPI.class_get_method_from_name(cls,"get_Instance",0);
 if(!getter) {
  *diagnostic=GMDiagnostic(@"E113",@"未解析到已闭合的 get_Instance 方法");
  return nullptr;
 }
 uint32_t aux=0;
 if(!(gAPI.method_get_flags(getter,&aux)&0x0010u)) {
  *diagnostic=GMDiagnostic(@"E114",@"单例访问器不是静态方法");
  return nullptr;
 }
 Il2CppException *error=nullptr;
 Il2CppObject *obj=gAPI.runtime_invoke(getter,nullptr,nullptr,&error);
 if(error) {
  *diagnostic=GMDiagnostic(@"E115",@"get_Instance 抛出托管异常");
  return nullptr;
 }
 if(!obj) {
  *diagnostic=GMDiagnostic(@"E116",@"get_Instance 返回 null，未执行");
  return nullptr;
 }
 Il2CppClass *actual=gAPI.object_get_class(obj);
 if(!actual || !gAPI.class_is_assignable_from(cls,actual)) {
  *diagnostic=GMDiagnostic(@"E117",@"单例实例类型不符，拒绝调用");
  return nullptr;
 }
 // UnityEngine.Object native destroyed semantics are not established here.
 *diagnostic=GMDiagnostic(@"OK",@"PersistentSingleton 实例已解析；Unity 原生生命周期仍需实机确认");
 return obj;
}
static NSString *Invoke(NSString *assembly,NSString *namespaceText,NSString *className,
                        NSString *method,NSString *parameter,BOOL perform) {
 if(!LoadAPI())return GMDiagnostic(@"E101",@"IL2CPP Runtime 导出不可用");
 Il2CppDomain *domain=gAPI.domain_get();
 if(!domain)return GMDiagnostic(@"E102",@"IL2CPP Domain 尚未就绪");
 if(!gAPI.thread_current())gAPI.thread_attach(domain);
 size_t count=0;
 const Il2CppAssembly **assemblies=gAPI.domain_get_assemblies(domain,&count);
 if(!assemblies||count==0||count>8192)return GMDiagnostic(@"E103",@"程序集列表不可用");
 Il2CppClass *cls=nullptr;
 for(size_t i=0;i<count;i++){
  const Il2CppImage *img=gAPI.assembly_get_image(assemblies[i]);
  const char *name=img?gAPI.image_get_name(img):nullptr;
  if(!name)continue;
  NSString *n=[NSString stringWithUTF8String:name];
  NSString *expected=assembly.length?assembly:@"Assembly-CSharp";
  if(![n isEqualToString:expected] && ![n isEqualToString:[expected stringByAppendingString:@".dll"]])continue;
  cls=gAPI.class_from_name(img,namespaceText.UTF8String,className.UTF8String);
  if(cls)break;
 }
 if(!cls)return GMDiagnostic(@"E104",@"未找到程序集中的类（检查命名空间）");
 void *iter=nullptr;const MethodInfo *found=nullptr;NSUInteger matches=0;
 BOOL hasArg=parameter.length>0;
 while(const MethodInfo *m=gAPI.class_get_methods(cls,&iter)){
  if(strcmp(gAPI.method_get_name(m),method.UTF8String)!=0)continue;
  uint32_t pc=gAPI.method_get_param_count(m);
  if(pc!=(hasArg?1u:0u))continue;
  found=m;matches++;
 }
 if(!matches)return GMDiagnostic(@"E105",@"方法或参数数量不匹配");
 if(matches>1)return GMDiagnostic(@"E106",@"同名重载不明确，拒绝猜测参数签名");
 uint32_t iflags=0;
 uint32_t flags=gAPI.method_get_flags(found,&iflags);
 const bool isStatic=(flags & 0x0010u)!=0;
 Il2CppObject *instance=nullptr;
 NSString *instanceStatus=@"";
 if(!isStatic){
  instance=ResolveSingleton(cls,&instanceStatus);
  if(!instance)return instanceStatus;
 }
 if(!perform)return GMDiagnostic(@"OK",isStatic?@"静态方法解析成功（未执行）":@"已通过 PersistentSingleton 取得实例（未执行）");
 if(!gAPI.thread_current())return GMDiagnostic(@"E108",@"Runtime 线程附加失败");
 void *args[1]={nullptr};
 int32_t val=0;
 if(hasArg){
  const Il2CppType *type=gAPI.method_get_param(found,0);
  char *typeName=type?gAPI.type_get_name(type):nullptr;
  NSString *tn=typeName?[NSString stringWithUTF8String:typeName]:@"";
  if(typeName&&gAPI.free_fn)gAPI.free_fn(typeName);
  if(![tn isEqualToString:@"System.Int32"])return GMDiagnostic(@"E109",@"当前仅支持一个 System.Int32 参数");
  NSScanner *scanner=[NSScanner scannerWithString:parameter];
  NSInteger n=0;
  if(![scanner scanInteger:&n]||!scanner.isAtEnd||n<INT32_MIN||n>INT32_MAX)
   return GMDiagnostic(@"E110",@"Int32 参数不合法");
  val=(int32_t)n;args[0]=&val;
 }
 Il2CppException *ex=nullptr;
 Il2CppObject *ret=gAPI.runtime_invoke(found,instance,hasArg?args:nullptr,&ex);
 if(ex)return GMDiagnostic(@"E111",@"托管异常（不代表执行成功）");
 (void)ret;
 return GMDiagnostic(@"OK",isStatic?@"静态调用已返回，实际副作用未验证":@"单例方法调用已返回；资源同步/持久化未验证");
}

static UIColor *Accent(void){return [UIColor colorWithRed:.12 green:.80 blue:.95 alpha:1];}
static UILabel *MakeLabel(NSString *text,CGFloat size){
 UILabel *l=[UILabel new];l.text=text;l.font=[UIFont systemFontOfSize:size];
 l.textColor=UIColor.whiteColor;l.numberOfLines=0;return l;
}
static UITextField *MakeField(NSString *placeholder, NSString *value){
 UITextField *f=[UITextField new];f.placeholder=placeholder;f.text=value;
 f.textColor=UIColor.whiteColor;f.backgroundColor=[UIColor colorWithWhite:.16 alpha:1];
 f.layer.cornerRadius=7;f.font=[UIFont systemFontOfSize:14];
 f.attributedPlaceholder=[[NSAttributedString alloc] initWithString:placeholder
 attributes:@{NSForegroundColorAttributeName:[UIColor colorWithWhite:.60 alpha:1]}];
 f.leftView=[[UIView alloc]initWithFrame:CGRectMake(0,0,9,1)];
 f.leftViewMode=UITextFieldViewModeAlways;
 return f;
}
@interface GMWindow:UIWindow @end
@implementation GMWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
 UIView *v=[super hitTest:point withEvent:event];
 if(v==self || v==self.rootViewController.view)return nil;
 return v;
}
@end
@interface GMController:UIViewController <UITextFieldDelegate>
@property(nonatomic,strong) UIView *panel;
@property(nonatomic,strong) UIButton *bubble;
@property(nonatomic,strong) NSArray<UITextField *> *fields;
@property(nonatomic,strong) UILabel *result;
@property(nonatomic,assign) BOOL expanded;
@end
@implementation GMController
- (UIButton *)button:(NSString *)title action:(SEL)action {
 UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
 [b setTitle:title forState:UIControlStateNormal];
 [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
 b.backgroundColor=[UIColor colorWithRed:.09 green:.37 blue:.49 alpha:1];
 b.layer.cornerRadius=8;b.titleLabel.font=[UIFont boldSystemFontOfSize:14];
 [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];return b;
}
- (void)viewDidLoad {
 [super viewDidLoad];self.view.backgroundColor=UIColor.clearColor;
 _bubble=[self button:@"GM" action:@selector(toggle)];
 _bubble.frame=CGRectMake(12,100,48,48);_bubble.layer.cornerRadius=24;
 [self.view addSubview:_bubble];
 UIPanGestureRecognizer *pan=[[UIPanGestureRecognizer alloc]initWithTarget:self action:@selector(drag:)];
 [_bubble addGestureRecognizer:pan];
 _panel=[UIView new];_panel.backgroundColor=[UIColor colorWithRed:.055 green:.075 blue:.11 alpha:.97];
 _panel.layer.cornerRadius=13;_panel.layer.borderColor=Accent().CGColor;_panel.layer.borderWidth=1;
 _panel.hidden=YES;[self.view addSubview:_panel];
 UILabel *title=MakeLabel(@"1945 Air Force · IL2CPP GM",16);
 title.font=[UIFont boldSystemFontOfSize:16];title.frame=CGRectMake(14,12,270,28);[_panel addSubview:title];
 UIButton *close=[self button:@"收起" action:@selector(toggle)];
 close.tag=700;[_panel addSubview:close];
 NSArray *placeholders=@[@"Assembly",@"Namespace（可为空）",@"Class",@"Method",@"Int32 参数（可为空）"];
 NSArray *values=@[@"Assembly-CSharp",@"",@"DataCheat",@"AddGem",@"1000"];
 NSMutableArray *fields=[NSMutableArray array];
 for(NSUInteger i=0;i<placeholders.count;i++){
  UITextField *f=MakeField(placeholders[i],values[i]);f.delegate=self;
  f.tag=800+i;[_panel addSubview:f];[fields addObject:f];
 }
 _fields=fields;
 UIButton *resolve=[self button:@"解析 / 检测实例" action:@selector(resolve)];
 resolve.tag=710;[_panel addSubview:resolve];
 UIButton *execute=[self button:@"执行方法" action:@selector(execute)];
 execute.tag=711;[_panel addSubview:execute];
 _result=MakeLabel(@"就绪：支持静态方法与已验证类型的 PersistentSingleton；其他实例方法安全拒绝。",12);
 [_panel addSubview:_result];
}
- (void)viewDidLayoutSubviews {
 [super viewDidLayoutSubviews];
 CGFloat width=MIN(350,MAX(290,self.view.bounds.size.width-20));
 CGFloat height=346;
 _panel.frame=CGRectMake((self.view.bounds.size.width-width)*.5,
                         MAX(25,(self.view.bounds.size.height-height)*.5),width,height);
 [[_panel viewWithTag:700]setFrame:CGRectMake(width-69,12,55,27)];
 for(NSUInteger i=0;i<_fields.count;i++)_fields[i].frame=CGRectMake(14,49+i*43,width-28,35);
 [[_panel viewWithTag:710]setFrame:CGRectMake(14,272,(width-38)*.5,32)];
 [[_panel viewWithTag:711]setFrame:CGRectMake(24+(width-38)*.5,272,(width-38)*.5,32)];
 _result.frame=CGRectMake(14,307,width-28,32);
}
- (void)toggle {
 self.expanded=!self.expanded;self.panel.hidden=!self.expanded;self.bubble.hidden=self.expanded;
 if(!self.expanded)[self.view endEditing:YES];
 [self.view setNeedsLayout];
}
- (void)drag:(UIPanGestureRecognizer *)pan {
 CGPoint t=[pan translationInView:self.view];
 CGPoint p=self.bubble.center;p.x+=t.x;p.y+=t.y;
 p.x=MAX(24,MIN(self.view.bounds.size.width-24,p.x));
 p.y=MAX(24,MIN(self.view.bounds.size.height-24,p.y));
 self.bubble.center=p;[pan setTranslation:CGPointZero inView:self.view];
}
- (void)resolve{[self run:NO];}
- (void)execute{[self run:YES];}
- (void)run:(BOOL)perform {
 [self.view endEditing:YES];
 NSString *(^clean)(NSUInteger)=^NSString *(NSUInteger i){
  return [self.fields[i].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]?:@"";
 };
 if(!clean(2).length||!clean(3).length){self.result.text=@"E100：类名和方法名不能为空";return;}
 self.result.text=Invoke(clean(0),clean(1),clean(2),clean(3),clean(4),perform);
 NSLog(@"[1945GM] %@",self.result.text);
}
- (BOOL)textFieldShouldReturn:(UITextField *)f{[f resignFirstResponder];return YES;}
@end

static GMWindow *gWindow=nil;
static UIWindow *HostWindow(void){
 if(@available(iOS 13.0,*)){
  for(UIScene *scene in UIApplication.sharedApplication.connectedScenes){
   if(![scene isKindOfClass:UIWindowScene.class]||scene.activationState!=UISceneActivationStateForegroundActive)continue;
   for(UIWindow *w in ((UIWindowScene *)scene).windows)if(w.isKeyWindow)return w;
  }
 }else{return UIApplication.sharedApplication.keyWindow;}
 return nil;
}
static void Install(void){
 if(gWindow)return;
 UIWindow *host=HostWindow();if(!host)return;
 if(@available(iOS 13.0,*))gWindow=[[GMWindow alloc]initWithWindowScene:host.windowScene];
 else gWindow=[[GMWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];
 gWindow.windowLevel=UIWindowLevelAlert+3;
 gWindow.backgroundColor=UIColor.clearColor;
 gWindow.rootViewController=[GMController new];
 gWindow.frame=host.bounds;
 gWindow.hidden=NO;
 NSLog(@"[1945GM] overlay installed");
}
__attribute__((constructor)) static void Init1945GM(void){
 dispatch_async(dispatch_get_main_queue(), ^{
  [[NSNotificationCenter defaultCenter]addObserverForName:UIApplicationDidBecomeActiveNotification
   object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){(void)n;Install();}];
  Install();
 });
}
