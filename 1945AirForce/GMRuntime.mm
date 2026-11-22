#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <dispatch/dispatch.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <float.h>
#include <math.h>
#include <limits.h>

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
 const char *(*class_get_namespace)(Il2CppClass *);
 const Il2CppType *(*class_get_type)(Il2CppClass *);
 Il2CppClass *(*class_from_type)(const Il2CppType *);
 void *(*class_get_field_from_name)(Il2CppClass *, const char *);
 int (*field_get_flags)(const void *);
 const Il2CppType *(*field_get_type)(const void *);
 void (*field_static_get_value)(const void *, void *);

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
 RESOLVE(class_get_namespace,"class_get_namespace");
 RESOLVE(class_get_type,"class_get_type");
 RESOLVE(class_from_type,"class_from_type");
 RESOLVE(class_get_field_from_name,"class_get_field_from_name");
 RESOLVE(field_get_flags,"field_get_flags");
 RESOLVE(field_get_type,"field_get_type");
 RESOLVE(field_static_get_value,"field_static_get_value");

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

static NSString *GMTrim(NSString *s) {
 return [s?:@"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}
static NSString *GMTypeName(const Il2CppType *type) {
 if(!type||!gAPI.type_get_name)return @"?";
 char *raw=gAPI.type_get_name(type);
 NSString *name=raw?[NSString stringWithUTF8String:raw]:@"?";
 if(raw&&gAPI.free_fn)gAPI.free_fn(raw);
 return name?:@"?";
}
static Il2CppClass *GMResolveClass(NSString *assembly,NSString *ns,NSString *name) {
 Il2CppDomain *domain=gAPI.domain_get();
 size_t count=0;
 const Il2CppAssembly **assemblies=domain?gAPI.domain_get_assemblies(domain,&count):nullptr;
 if(!assemblies||!count||count>8192)return nullptr;
 NSString *wanted=GMTrim(assembly);
 if(!wanted.length)wanted=@"Assembly-CSharp";
 NSString *normalized=[wanted hasSuffix:@".dll"]?[wanted substringToIndex:wanted.length-4]:wanted;
 for(size_t i=0;i<count;i++){
  const Il2CppImage *img=gAPI.assembly_get_image(assemblies[i]);
  const char *raw=img?gAPI.image_get_name(img):nullptr;
  if(!raw)continue;
  NSString *image=[NSString stringWithUTF8String:raw];
  NSString *imageBase=[image hasSuffix:@".dll"]?[image substringToIndex:image.length-4]:image;
  if([imageBase caseInsensitiveCompare:normalized]!=NSOrderedSame)continue;
  Il2CppClass *klass=gAPI.class_from_name(img,(ns?:@"").UTF8String,name.UTF8String);
  if(klass)return klass;
 }
 return nullptr;
}
static NSString *GMHierarchy(Il2CppClass *klass) {
 NSMutableArray<NSString *> *lines=[NSMutableArray array];
 Il2CppClass *cur=klass;
 for(unsigned i=0;i<12&&cur;i++){
  const char *name=gAPI.class_get_name(cur);
  const char *ns=gAPI.class_get_namespace?gAPI.class_get_namespace(cur):nullptr;
  NSString *n=name?[NSString stringWithUTF8String:name]:@"?";
  NSString *prefix=ns&&*ns?[NSString stringWithFormat:@"%s.",ns]:@"";
  [lines addObject:[prefix stringByAppendingString:n]];
  Il2CppClass *next=gAPI.class_get_parent(cur);
  if(next==cur)break;
  cur=next;
 }
 return [lines componentsJoinedByString:@" → "];
}
static NSArray<NSString *> *GMArgs(NSString *raw) {
 NSString *s=GMTrim(raw);
 if(!s.length)return @[];
 NSArray *parts=[s componentsSeparatedByString:@"|"];
 NSMutableArray *out=[NSMutableArray array];
 for(NSString *part in parts)[out addObject:GMTrim(part)];
 return out;
}
static const MethodInfo *GMFindMethod(Il2CppClass *klass,NSString *method,NSUInteger argc,
                                      NSArray<NSString *> *exactTypes,NSString **error) {
 void *iter=nullptr;
 const MethodInfo *match=nullptr;
 NSUInteger count=0;
 while(const MethodInfo *m=gAPI.class_get_methods(klass,&iter)) {
  const char *name=gAPI.method_get_name(m);
  if(!name||strcmp(name,method.UTF8String)||gAPI.method_get_param_count(m)!=argc)continue;
  if(exactTypes){
   BOOL same=exactTypes.count==argc;
   for(uint32_t i=0;same&&i<argc;i++)
    same=[GMTypeName(gAPI.method_get_param(m,i)) isEqualToString:exactTypes[i]];
   if(!same)continue;
  }
  match=m;count++;
 }
 if(count==1)return match;
 if(error)*error=GMDiagnostic(count?@"E106":@"E105",count?@"重载签名存在歧义，拒绝猜测":@"方法或参数类型不匹配");
 return nullptr;
}
static BOOL GMSupportedType(NSString *type) {
 return [@[@"System.Boolean",@"System.Int32",@"System.UInt32",@"System.Int64",
           @"System.UInt64",@"System.Single",@"System.Double",@"System.String"] containsObject:type];
}
static NSArray<NSDictionary<NSString *,id> *> *GMEnumerateDataCheat(NSString **error) {
 if(!LoadAPI()){if(error)*error=@"E101：IL2CPP 导出未就绪";return @[];}
 Il2CppDomain *domain=gAPI.domain_get();
 if(!domain){if(error)*error=@"E102：IL2CPP Domain 未就绪";return @[];}
 if(!gAPI.thread_current())gAPI.thread_attach(domain);
 if(!gAPI.thread_current()){if(error)*error=@"E108：线程附加失败";return @[];}
 Il2CppClass *klass=GMResolveClass(@"Assembly-CSharp",@"",@"DataCheat");
 if(!klass){if(error)*error=@"E104：Assembly-CSharp.DataCheat 不存在";return @[];}
 NSMutableArray<NSDictionary<NSString *,id> *> *out=[NSMutableArray array];
 void *iter=nullptr;
 NSUInteger count=0;
 while(const MethodInfo *method=gAPI.class_get_methods(klass,&iter)){
  if(++count>4096)break;
  const char *raw=gAPI.method_get_name(method);
  if(!raw)continue;
  NSString *name=[NSString stringWithUTF8String:raw];
  NSUInteger argc=gAPI.method_get_param_count(method);
  BOOL supported=argc<=8 && ![name hasPrefix:@"."];
  NSMutableArray<NSString *> *types=[NSMutableArray array];
  for(NSUInteger i=0;i<MIN(argc,(NSUInteger)16);i++){
   NSString *type=GMTypeName(gAPI.method_get_param(method,(uint32_t)i));
   [types addObject:type];
   if(!GMSupportedType(type))supported=NO;
  }
  if(argc>16)supported=NO;
  uint32_t aux=0;
  BOOL isStatic=(gAPI.method_get_flags(method,&aux)&0x10u)!=0;
  NSString *label=[NSString stringWithFormat:@"%@(%@) → %@",
                    name,[types componentsJoinedByString:@", "],
                    GMTypeName(gAPI.method_get_return_type(method))];
  [out addObject:@{@"method":name,@"argc":@(argc),@"types":types,
                   @"signature":label,@"isStatic":@(isStatic),@"supported":@(supported)}];
 }
 [out sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){
  return [a[@"method"] localizedStandardCompare:b[@"method"]];
 }];
 if(error)*error=[NSString stringWithFormat:@"DataCheat 已枚举 %lu 个方法（直接声明）",(unsigned long)out.count];
 return out;
}
static NSString *GMDescribeMethod(const MethodInfo *m,Il2CppClass *cls) {
 uint32_t impl=0;
 BOOL isStatic=(gAPI.method_get_flags(m,&impl)&0x10u)!=0;
 NSMutableArray *parts=[NSMutableArray array];
 for(uint32_t i=0;i<gAPI.method_get_param_count(m);i++)
  [parts addObject:GMTypeName(gAPI.method_get_param(m,i))];
 return [NSString stringWithFormat:@"%@ · %@(%@) → %@\n继承：%@",
         isStatic?@"Static":@"Instance",
         [NSString stringWithUTF8String:gAPI.method_get_name(m)]?:@"?",
         [parts componentsJoinedByString:@", "],
         GMTypeName(gAPI.method_get_return_type(m)),GMHierarchy(cls)];
}
// Conservative fallback for already-instantiated singleton static fields.
// Never treat a primitive field as an object pointer.
static Il2CppObject *GMStaticSingleton(Il2CppClass *klass,NSString **status) {
 if(!gAPI.class_get_field_from_name||!gAPI.field_get_flags||
    !gAPI.field_get_type||!gAPI.field_static_get_value||!gAPI.class_from_type)return nullptr;
 const char *names[]={"Instance","instance","_instance","s_Instance","s_instance"};
 for(Il2CppClass *cur=klass;cur;){
  for(const char *key:names){
   void *field=gAPI.class_get_field_from_name(cur,key);
   if(!field || !(gAPI.field_get_flags(field)&0x10))continue;
   const Il2CppType *type=gAPI.field_get_type(field);
   Il2CppClass *fieldClass=type?gAPI.class_from_type(type):nullptr;
   if(!fieldClass||!gAPI.class_is_assignable_from(fieldClass,klass))continue;
   Il2CppObject *obj=nullptr;
   gAPI.field_static_get_value(field,&obj);
   if(obj&&gAPI.class_is_assignable_from(klass,gAPI.object_get_class(obj))){
    if(status)*status=[NSString stringWithFormat:@"静态字段 %s 已解析",key];
    return obj;
   }
  }
  Il2CppClass *next=gAPI.class_get_parent(cur);
  if(next==cur)break;
  cur=next;
 }
 return nullptr;
}
static Il2CppObject *GMExistingInstance(Il2CppClass *klass,NSString **status) {
 NSString *singletonStatus=@"";
 Il2CppObject *obj=ResolveSingleton(klass,&singletonStatus); // keep validated standalone baseline
 if(obj){
  if(status)*status=@"PersistentSingleton<T>.get_Instance 已获取";
  return obj;
 }
 obj=GMStaticSingleton(klass,status);
 if(obj)return obj;
 if(status)*status=[NSString stringWithFormat:@"%@；也未找到有效静态实例字段",singletonStatus];
 return nullptr;
}
static BOOL GMParseSigned(NSString *value,int64_t *out) {
 const char *raw=GMTrim(value).UTF8String;
 if(!raw||!*raw)return NO;
 char *end=nullptr;errno=0;
 long long v=strtoll(raw,&end,0);
 if(errno||end==raw||*end)return NO;
 *out=v;return YES;
}
static BOOL GMParseUnsigned(NSString *value,uint64_t *out) {
 NSString *str=GMTrim(value);
 if(!str.length||[str hasPrefix:@"-"])return NO;
 char *end=nullptr;errno=0;
 unsigned long long v=strtoull(str.UTF8String,&end,0);
 if(errno||end==str.UTF8String||*end)return NO;
 *out=v;return YES;
}
static BOOL GMEncodeArgument(NSString *type,NSString *value,uint64_t *slot,void **pointer,
                             NSString **error) {
 NSString *v=GMTrim(value);
 if([type isEqualToString:@"System.String"]){
  if(!gAPI.string_new){if(error)*error=@"il2cpp_string_new 不可用";return NO;}
  *pointer=gAPI.string_new(v.UTF8String);
  return *pointer!=nullptr;
 }
 if([type isEqualToString:@"System.Boolean"]){
  BOOL b=[@[@"1",@"true",@"yes",@"on"] containsObject:v.lowercaseString];
  BOOL f=[@[@"0",@"false",@"no",@"off"] containsObject:v.lowercaseString];
  if(!b&&!f){if(error)*error=@"Boolean 只接受 true/false 或 1/0";return NO;}
  uint8_t x=b?1:0;memcpy(slot,&x,sizeof(x));*pointer=slot;return YES;
 }
 if([type isEqualToString:@"System.Single"]||[type isEqualToString:@"System.Double"]){
  const char *raw=v.UTF8String;char *end=nullptr;errno=0;
  double x=strtod(raw,&end);
  if(!raw||end==raw||*end||errno||!isfinite(x)){if(error)*error=@"浮点值无效";return NO;}
  if([type isEqualToString:@"System.Single"]){
   if(x>FLT_MAX||x< -FLT_MAX){if(error)*error=@"Single 超出范围";return NO;}
   float f=(float)x;memcpy(slot,&f,sizeof(f));
  } else memcpy(slot,&x,sizeof(x));
  *pointer=slot;return YES;
 }
 BOOL isUnsigned=[type isEqualToString:@"System.UInt32"]||[type isEqualToString:@"System.UInt64"];
 BOOL isSigned=[type isEqualToString:@"System.Int32"]||[type isEqualToString:@"System.Int64"];
 if(isSigned){
  int64_t val=0;
  if(!GMParseSigned(v,&val)||([type isEqualToString:@"System.Int32"]&&(val<INT32_MIN||val>INT32_MAX))){
   if(error)*error=@"有符号整数不合法";return NO;
  }
  if([type isEqualToString:@"System.Int32"]){int32_t x=(int32_t)val;memcpy(slot,&x,sizeof(x));}
  else memcpy(slot,&val,sizeof(val));
  *pointer=slot;return YES;
 }
 if(isUnsigned){
  uint64_t val=0;
  if(!GMParseUnsigned(v,&val)||([type isEqualToString:@"System.UInt32"]&&val>UINT32_MAX)){
   if(error)*error=@"无符号整数不合法";return NO;
  }
  if([type isEqualToString:@"System.UInt32"]){uint32_t x=(uint32_t)val;memcpy(slot,&x,sizeof(x));}
  else memcpy(slot,&val,sizeof(val));
  *pointer=slot;return YES;
 }
 if(error)*error=[NSString stringWithFormat:@"暂不支持参数类型 %@（ref/out、结构体与对象参数拒绝执行）",type];
 return NO;
}
static NSString *GMReturnValue(const Il2CppType *type,Il2CppObject *result) {
 NSString *name=GMTypeName(type);
 if([name isEqualToString:@"System.Void"])return @"Void";
 if(!result)return [NSString stringWithFormat:@"%@ = null",name];
 void *unboxed=gAPI.object_unbox?gAPI.object_unbox(result):nullptr;
 if(unboxed){
  if([name isEqualToString:@"System.Int32"]){int32_t x=0;memcpy(&x,unboxed,4);return [NSString stringWithFormat:@"Int32 = %d",x];}
  if([name isEqualToString:@"System.UInt32"]){uint32_t x=0;memcpy(&x,unboxed,4);return [NSString stringWithFormat:@"UInt32 = %u",x];}
  if([name isEqualToString:@"System.Int64"]){int64_t x=0;memcpy(&x,unboxed,8);return [NSString stringWithFormat:@"Int64 = %lld",(long long)x];}
  if([name isEqualToString:@"System.UInt64"]){uint64_t x=0;memcpy(&x,unboxed,8);return [NSString stringWithFormat:@"UInt64 = %llu",(unsigned long long)x];}
  if([name isEqualToString:@"System.Single"]){float x=0;memcpy(&x,unboxed,4);return [NSString stringWithFormat:@"Float = %g",(double)x];}
  if([name isEqualToString:@"System.Double"]){double x=0;memcpy(&x,unboxed,8);return [NSString stringWithFormat:@"Double = %.9g",x];}
  if([name isEqualToString:@"System.Boolean"]){uint8_t x=0;memcpy(&x,unboxed,1);return x?@"Boolean = true":@"Boolean = false";}
 }
 return [NSString stringWithFormat:@"%@ · object=%p",name,result];
}
static NSString *Invoke(NSString *assembly,NSString *namespaceText,NSString *className,
                        NSString *method,NSString *parameter,NSInteger mode,
                        NSArray<NSString *> *exactTypes) {
 if(!LoadAPI())return GMDiagnostic(@"E101",@"IL2CPP Runtime 导出不可用");
 Il2CppDomain *domain=gAPI.domain_get();
 if(!domain)return GMDiagnostic(@"E102",@"IL2CPP Domain 尚未就绪");
 if(!gAPI.thread_current())gAPI.thread_attach(domain);
 if(!gAPI.thread_current())return GMDiagnostic(@"E108",@"Runtime 线程附加失败");
 Il2CppClass *cls=GMResolveClass(assembly,namespaceText,className);
 if(!cls)return GMDiagnostic(@"E104",@"未找到程序集中的类");
 if(mode==3)return [NSString stringWithFormat:@"OK：Class %@\n%@",className,GMHierarchy(cls)];
 NSArray<NSString *> *values=GMArgs(parameter);
 if(values.count>8)return GMDiagnostic(@"E109",@"最多支持八个参数");
 NSString *findError=nil;
 const MethodInfo *found=GMFindMethod(cls,method,values.count,exactTypes,&findError);
 if(!found)return findError?:@"E105";
 if(mode==0)return [@"OK：方法详情\n" stringByAppendingString:GMDescribeMethod(found,cls)];
 uint32_t iflags=0;
 BOOL isStatic=(gAPI.method_get_flags(found,&iflags)&0x10u)!=0;
 NSString *status=@"";
 Il2CppObject *instance=nullptr;
 if(!isStatic){
  instance=GMExistingInstance(cls,&status);
  if(!instance)return [NSString stringWithFormat:@"FAILED_INSTANCE：%@",status];
 }
 if(mode==1)return [NSString stringWithFormat:@"OK：%@\n%@",isStatic?@"静态方法无需实例":status,GMDescribeMethod(found,cls)];
 uint64_t slots[8]={};
 void *args[8]={};
 for(NSUInteger i=0;i<values.count;i++){
  NSString *type=GMTypeName(gAPI.method_get_param(found,(uint32_t)i));
  NSString *argError=nil;
  if(!GMEncodeArgument(type,values[i],&slots[i],&args[i],&argError))
   return [NSString stringWithFormat:@"FAILED_ARGUMENT_%lu：%@",(unsigned long)(i+1),argError?:@"类型编码失败"];
 }
 Il2CppException *ex=nullptr;
 Il2CppObject *result=gAPI.runtime_invoke(found,instance,values.count?args:nullptr,&ex);
 if(ex)return GMDiagnostic(@"E111",@"IL2CPP 托管异常，执行失败");
 return [NSString stringWithFormat:@"OK：方法已返回（副作用需实机验证）\n%@",
         GMReturnValue(gAPI.method_get_return_type(found),result)];
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
@interface GMController:UIViewController <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property(nonatomic,strong) UIScrollView *panel;
@property(nonatomic,strong) UIButton *bubble;
@property(nonatomic,strong) NSArray<UITextField *> *fields;
@property(nonatomic,strong) UILabel *result;
@property(nonatomic,assign) BOOL expanded;
@property(nonatomic,strong) UIView *methodBrowser;
@property(nonatomic,strong) UISearchBar *methodSearch;
@property(nonatomic,strong) UITableView *methodTable;
@property(nonatomic,copy) NSArray<NSDictionary<NSString *,id> *> *allCheatMethods;
@property(nonatomic,copy) NSArray<NSDictionary<NSString *,id> *> *filteredCheatMethods;
@property(nonatomic,copy) NSArray<NSString *> *selectedParamTypes;
@property(nonatomic,copy) NSString *selectedMethodName;
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
 _panel=[UIScrollView new];_panel.alwaysBounceVertical=YES;_panel.keyboardDismissMode=UIScrollViewKeyboardDismissModeOnDrag;_panel.backgroundColor=[UIColor colorWithRed:.055 green:.075 blue:.11 alpha:.97];
 _panel.layer.cornerRadius=13;_panel.layer.borderColor=Accent().CGColor;_panel.layer.borderWidth=1;
 _panel.hidden=YES;[self.view addSubview:_panel];
 UILabel *title=MakeLabel(@"1945 Air Force · IL2CPP GM",16);
 title.font=[UIFont boldSystemFontOfSize:16];title.frame=CGRectMake(14,12,270,28);[_panel addSubview:title];
 UIButton *close=[self button:@"收起" action:@selector(toggle)];
 close.tag=700;[_panel addSubview:close];
 NSArray *placeholders=@[@"Assembly",@"Namespace（可为空）",@"Class",@"Method",@"参数：按顺序用 | 分隔，空=0 参数"];
 NSArray *values=@[@"Assembly-CSharp",@"",@"DataCheat",@"AddGem",@"1000"];
 NSMutableArray *fields=[NSMutableArray array];
 for(NSUInteger i=0;i<placeholders.count;i++){
  UITextField *f=MakeField(placeholders[i],values[i]);f.delegate=self;
  f.tag=800+i;[_panel addSubview:f];[fields addObject:f];
 }
 _fields=fields;
 NSArray *titles=@[@"DataCheat 功能",@"方法详情",@"获取实例",@"执行方法",@"继承关系",@"保存配置",@"恢复配置"];
 NSArray *selectors=@[@"browseDataCheat",@"inspect",@"resolve",@"execute",@"classInfo",@"saveConfig",@"loadConfig"];
 for(NSUInteger i=0;i<titles.count;i++){
  UIButton *button=[self button:titles[i] action:NSSelectorFromString(selectors[i])];
  button.tag=710+(NSInteger)i;
  [_panel addSubview:button];
 }
 _result=MakeLabel(@"点击「DataCheat 功能」直接显示游戏中的全部 DataCheat 方法；选择后按需填写参数再执行。",12);
 [_panel addSubview:_result];
 _methodBrowser=[UIView new];
 _methodBrowser.backgroundColor=[UIColor colorWithRed:.055 green:.075 blue:.11 alpha:.99];
 _methodBrowser.layer.cornerRadius=13;
 _methodBrowser.layer.borderWidth=1;
 _methodBrowser.layer.borderColor=Accent().CGColor;
 _methodBrowser.hidden=YES;
 [self.view addSubview:_methodBrowser];
 UILabel *browserTitle=MakeLabel(@"DataCheat · 全部方法",16);
 browserTitle.font=[UIFont boldSystemFontOfSize:16];
 browserTitle.tag=910;
 [_methodBrowser addSubview:browserTitle];
 UIButton *back=[self button:@"返回" action:@selector(closeMethodBrowser)];
 back.tag=911;
 [_methodBrowser addSubview:back];
 _methodSearch=[[UISearchBar alloc]initWithFrame:CGRectZero];
 _methodSearch.placeholder=@"搜索方法名 / 参数类型";
 _methodSearch.searchBarStyle=UISearchBarStyleMinimal;
 _methodSearch.delegate=self;
 _methodSearch.tag=912;
 [_methodBrowser addSubview:_methodSearch];
 _methodTable=[[UITableView alloc]initWithFrame:CGRectZero style:UITableViewStylePlain];
 _methodTable.backgroundColor=UIColor.clearColor;
 _methodTable.separatorColor=[UIColor colorWithWhite:.25 alpha:1];
 _methodTable.dataSource=self;
 _methodTable.delegate=self;
 _methodTable.rowHeight=68;
 [_methodBrowser addSubview:_methodTable];
 _allCheatMethods=@[];
 _filteredCheatMethods=@[];
}
- (void)viewDidLayoutSubviews {
 [super viewDidLayoutSubviews];
 CGFloat width=MIN(350,MAX(290,self.view.bounds.size.width-20));
 CGFloat height=MIN(510,MAX(270,self.view.bounds.size.height-32));
 _panel.frame=CGRectMake((self.view.bounds.size.width-width)*.5,
                         MAX(8,(self.view.bounds.size.height-height)*.5),width,height);
 _panel.contentSize=CGSizeMake(width,565);
 [[_panel viewWithTag:700]setFrame:CGRectMake(width-69,12,55,27)];
 for(NSUInteger i=0;i<_fields.count;i++)_fields[i].frame=CGRectMake(14,49+i*43,width-28,35);
 for(NSUInteger i=0;i<7;i++){
  CGFloat buttonW=(width-38)*.5;
  [[_panel viewWithTag:710+(NSInteger)i]setFrame:CGRectMake(i%2?24+buttonW:14,272+(i/2)*39,buttonW,34)];
 }
 _result.frame=CGRectMake(14,432,width-28,115);
 _methodBrowser.frame=_panel.frame;
 [[_methodBrowser viewWithTag:910]setFrame:CGRectMake(14,11,width-90,31)];
 [[_methodBrowser viewWithTag:911]setFrame:CGRectMake(width-67,13,54,29)];
 _methodSearch.frame=CGRectMake(5,45,width-10,48);
 _methodTable.frame=CGRectMake(8,96,width-16,height-104);
}
- (void)toggle {
 self.expanded=!self.expanded;self.panel.hidden=!self.expanded;self.methodBrowser.hidden=YES;self.bubble.hidden=self.expanded;
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
- (void)browseDataCheat {
 [self.view endEditing:YES];
 NSString *status=nil;
 NSArray *methods=GMEnumerateDataCheat(&status);
 self.allCheatMethods=methods;
 self.filteredCheatMethods=methods;
 self.methodSearch.text=@"";
 [self.methodTable reloadData];
 self.result.text=status?:@"DataCheat 方法枚举失败";
 if(!methods.count){self.panel.hidden=NO;return;}
 self.panel.hidden=YES;
 self.methodBrowser.hidden=NO;
 self.bubble.hidden=YES;
 self.expanded=YES;
 [self.view setNeedsLayout];
}
- (void)closeMethodBrowser {
 [self.view endEditing:YES];
 self.methodBrowser.hidden=YES;
 self.panel.hidden=NO;
 [self.view setNeedsLayout];
}
- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
 NSString *query=[searchText lowercaseString];
 if(!query.length)self.filteredCheatMethods=self.allCheatMethods?:@[];
 else {
  NSPredicate *p=[NSPredicate predicateWithBlock:^BOOL(NSDictionary *item,NSDictionary *bindings){
   (void)bindings;
   return [[item[@"signature"] lowercaseString] containsString:query];
  }];
  self.filteredCheatMethods=[self.allCheatMethods filteredArrayUsingPredicate:p];
 }
 [self.methodTable reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
 (void)tableView;(void)section;
 return (NSInteger)self.filteredCheatMethods.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
 UITableViewCell *cell=[tableView dequeueReusableCellWithIdentifier:@"cheatMethod"];
 if(!cell)cell=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cheatMethod"];
 NSDictionary *entry=self.filteredCheatMethods[(NSUInteger)indexPath.row];
 cell.backgroundColor=UIColor.clearColor;
 cell.textLabel.text=entry[@"method"];
 cell.textLabel.textColor=UIColor.whiteColor;
 cell.textLabel.font=[UIFont boldSystemFontOfSize:14];
 cell.detailTextLabel.text=[NSString stringWithFormat:@"%@ · %@",
  [entry[@"isStatic"] boolValue]?@"Static":@"Instance",entry[@"signature"]];
 cell.detailTextLabel.numberOfLines=2;
 cell.detailTextLabel.font=[UIFont systemFontOfSize:11];
 cell.detailTextLabel.textColor=[entry[@"supported"] boolValue]?
  [UIColor colorWithRed:.5 green:.8 blue:.75 alpha:1]:UIColor.lightGrayColor;
 cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
 return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
 [tableView deselectRowAtIndexPath:indexPath animated:YES];
 NSDictionary *entry=self.filteredCheatMethods[(NSUInteger)indexPath.row];
 NSArray<NSString *> *types=entry[@"types"]?:@[];
 self.fields[0].text=@"Assembly-CSharp";
 self.fields[1].text=@"";
 self.fields[2].text=@"DataCheat";
 self.fields[3].text=entry[@"method"];
 self.selectedMethodName=entry[@"method"];
 self.selectedParamTypes=types;
 NSMutableArray<NSString *> *defaults=[NSMutableArray array];
 for(NSString *type in types){
  if([type isEqualToString:@"System.Boolean"])[defaults addObject:@"false"];
  else if([type isEqualToString:@"System.String"])[defaults addObject:@""];
  else [defaults addObject:@"0"];
 }
 self.fields[4].text=[defaults componentsJoinedByString:@"|"];
 self.result.text=[NSString stringWithFormat:@"%@\n%@\n%@",
  entry[@"signature"],
  [entry[@"supported"] boolValue]?@"参数类型可由当前调用器处理":@"包含尚不支持的参数类型，禁止盲目执行",
  @"请检查参数后手动点击「执行方法」"];
 [self closeMethodBrowser];
}
- (void)inspect{[self run:0];}
- (void)classInfo{[self run:3];}
- (void)resolve{[self run:1];}
- (void)execute{[self run:2];}
- (void)saveConfig{
 NSMutableArray *values=[NSMutableArray array];
 for(UITextField *field in self.fields)[values addObject:field.text?:@""];
 [NSUserDefaults.standardUserDefaults setObject:values forKey:@"zonoe.1945gm.runtime-config.v2"];
 self.result.text=@"OK：已保存方法配置，不保存实例指针或 GCHandle";
}
- (void)loadConfig{
 NSArray *values=[NSUserDefaults.standardUserDefaults objectForKey:@"zonoe.1945gm.runtime-config.v2"];
 if(![values isKindOfClass:NSArray.class]||values.count!=self.fields.count){self.result.text=@"没有已保存配置";return;}
 for(NSUInteger i=0;i<values.count;i++)if([values[i] isKindOfClass:NSString.class])self.fields[i].text=values[i];
 self.result.text=@"OK：方法配置已恢复";
}
- (void)run:(NSInteger)mode {
 [self.view endEditing:YES];
 NSString *(^clean)(NSUInteger)=^NSString *(NSUInteger i){
  return [self.fields[i].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]?:@"";
 };
 if(!clean(2).length||!clean(3).length){self.result.text=@"E100：类名和方法名不能为空";return;}
 NSArray<NSString *> *exactTypes=([self.selectedMethodName isEqualToString:clean(3)] &&
                                  [clean(2) isEqualToString:@"DataCheat"])?self.selectedParamTypes:nil;
 self.result.text=Invoke(clean(0),clean(1),clean(2),clean(3),clean(4),mode,exactTypes);
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
