#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#import <Foundation/Foundation.h>

// Read-only live actor inventory. No network requests or GM messages.
// DataCache.Instance.GetActorList() -> List<ActorData>.
// The actor IDs are live/runtime IDs, never derived from skill/item configuration.
namespace {
typedef void* (*Fn0)();
typedef void* (*FnAssembly)(void*,const char*);
typedef void* (*FnImage)(void*);
typedef void* (*FnClass)(void*,const char*,const char*);
typedef void* (*FnMethod)(void*,const char*,int);
typedef void* (*FnInvoke)(void*,void*,void**,void**);
typedef void* (*FnObjectClass)(void*);
typedef void* (*FnUnbox)(void*);
typedef int32_t (*FnStringLength)(void*);
typedef const uint16_t* (*FnStringChars)(void*);
struct APIs {
 void *handle;
 Fn0 domain,threadCurrent;
 void* (*threadAttach)(void*);
 FnAssembly assembly;
 FnImage image;
 FnClass fromName;
 FnMethod method;
 FnInvoke invoke;
 FnObjectClass objectClass;
 FnUnbox unbox;
 FnStringLength strLength;
 FnStringChars strChars;
};
static void* resolveSymbol(void *handle,const char *name){return dlsym(handle,name);}
static int setup(APIs &r){
 memset(&r,0,sizeof(r));
 const char *path=nullptr;
 for(uint32_t i=0;i<_dyld_image_count();i++){
  const char *name=_dyld_get_image_name(i);
  const struct mach_header *header=_dyld_get_image_header(i);
  if(!name||!header||header->magic!=MH_MAGIC_64||header->cputype!=CPU_TYPE_ARM64)continue;
  NSString *p=[NSString stringWithUTF8String:name];
  if([p.lastPathComponent isEqualToString:@"UnityFramework"]){path=name;break;}
 }
 if(!path)return -401;
 r.handle=dlopen(path,RTLD_NOW|RTLD_NOLOAD);
 if(!r.handle)r.handle=dlopen(path,RTLD_NOW|RTLD_LOCAL);
 if(!r.handle)return -402;
#define LOAD(field,symbol) do{r.field=(decltype(r.field))resolveSymbol(r.handle,symbol);if(!r.field)return -403;}while(0)
 LOAD(domain,"il2cpp_domain_get");
 LOAD(threadCurrent,"il2cpp_thread_current");
 LOAD(threadAttach,"il2cpp_thread_attach");
 LOAD(assembly,"il2cpp_domain_assembly_open");
 LOAD(image,"il2cpp_assembly_get_image");
 LOAD(fromName,"il2cpp_class_from_name");
 LOAD(method,"il2cpp_class_get_method_from_name");
 LOAD(invoke,"il2cpp_runtime_invoke");
 LOAD(objectClass,"il2cpp_object_get_class");
 LOAD(unbox,"il2cpp_object_unbox");
 LOAD(strLength,"il2cpp_string_length");
 LOAD(strChars,"il2cpp_string_chars");
#undef LOAD
 return 1;
}
static bool call(APIs &r,void* method,void* instance,void** args,void** result){
 if(!method)return false;
 void *error=nullptr;
 void *value=r.invoke(method,instance,args,&error);
 if(error)return false;
 if(result)*result=value;
 return true;
}
static void checkpoint(const char *stage){
 NSArray *dirs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
 if(!dirs.count)return;
 NSString *dir=[dirs[0] stringByAppendingPathComponent:@"XiuxianjiazuGM"];
 [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
 NSString *path=[dir stringByAppendingPathComponent:@"actor-export-stage.txt"];
 [[NSString stringWithFormat:@"P2.1.4 stage=%s",stage] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
static NSString* readString(APIs &r,void *v){
 if(!v)return @"";
 int32_t len=r.strLength(v);
 if(len<0||len>1024)return nil;
 const uint16_t *chars=r.strChars(v);
 if(len&&!chars)return nil;
 return [[NSString alloc] initWithCharacters:(const unichar*)chars length:(NSUInteger)len];
}
static int intGetter(APIs &r,void *o,void *method,int32_t *out){
 void *boxed=nullptr;
 if(!call(r,method,o,nullptr,&boxed)||!boxed)return -418;
 *out=*(int32_t*)r.unbox(boxed);return 1;
}
static int exportActors(){
 checkpoint("start");
 APIs r={};
 int result=setup(r);
 if(result!=1)return result;
 checkpoint("runtime_resolved");
 void *domain=r.domain();
 if(!domain)return -404;
 if(!r.threadCurrent()&&!r.threadAttach(domain))return -405;
 void *assembly=r.assembly(domain,"gameCore.dll");
 if(!assembly)return -406;
 void *image=r.image(assembly);
 if(!image)return -406;
 void *cacheClass=r.fromName(image,"","DataCache");
 if(!cacheClass)return -407;
 void *getInstance=r.method(cacheClass,"get_Instance",0);
 void *getList=r.method(cacheClass,"GetActorList",0);
 if(!getInstance||!getList)return -408;
 checkpoint("get_cache");
 void *cache=nullptr;
 if(!call(r,getInstance,nullptr,nullptr,&cache)||!cache)return -409;
 checkpoint("get_actor_list");
 void *list=nullptr;
 if(!call(r,getList,cache,nullptr,&list)||!list)return -410;
 void *listClass=r.objectClass(list);
 if(!listClass)return -411;
 void *getCount=r.method(listClass,"get_Count",0);
 void *getItem=r.method(listClass,"get_Item",1);
 if(!getCount||!getItem)return -412;
 int32_t count=0;
 if(intGetter(r,list,getCount,&count)!=1||count<0||count>30000)return -413;
 checkpoint("resolve_actor_methods");
 // ActorData methods are virtual objects returned from the concrete List<ActorData>.
 void *actorClass=nullptr,*getId=nullptr,*getName=nullptr,*getForce=nullptr;
 NSMutableArray *entries=[NSMutableArray arrayWithCapacity:(NSUInteger)count];
 NSMutableSet *seen=[NSMutableSet set];
 for(int32_t i=0;i<count;i++){
  if(i==0||i%256==0){char stage[64];snprintf(stage,sizeof(stage),"read_actor_%d",i);checkpoint(stage);}
  void* actor=nullptr;void* args[]={&i};
  if(!call(r,getItem,list,args,&actor))return -414;
  if(!actor)continue;
  void *actual=r.objectClass(actor);
  if(!actual)return -415;
  if(actual!=actorClass){
   actorClass=actual;
   getId=r.method(actual,"get_id",0);
   getName=r.method(actual,"get_name",0);
   getForce=r.method(actual,"get_forceId",0);
   if(!getId||!getName||!getForce)return -416;
  }
  int32_t id=0,force=0;
  if(intGetter(r,actor,getId,&id)!=1||intGetter(r,actor,getForce,&force)!=1)return -417;
  if(id<=0||[seen containsObject:@(id)])continue;
  void *managedName=nullptr;
  if(!call(r,getName,actor,nullptr,&managedName))return -419;
  NSString *name=readString(r,managedName);
  if(!name)return -420;
  [seen addObject:@(id)];
  [entries addObject:@{@"id":@(id),@"name":name,@"forceId":@(force)}];
 }
 [entries sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){
  return [a[@"id"] compare:b[@"id"]];
 }];
 checkpoint("json");
 NSData *json=[NSJSONSerialization dataWithJSONObject:entries options:0 error:nil];
 if(!json||json.length>8*1024*1024)return -421;
 NSArray *dirs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
 if(!dirs.count)return -422;
 NSString *dir=[dirs[0] stringByAppendingPathComponent:@"XiuxianjiazuGM"];
 if(![[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil])return -422;
 NSString *path=[dir stringByAppendingPathComponent:@"actors.json"];
 if(![json writeToFile:path options:NSDataWritingAtomic error:nil])return -423;
 checkpoint("success");
 return (int)entries.count;
}
}
extern "C" __attribute__((visibility("default"))) int XJGMExportActors(void){
 @autoreleasepool{return exportActors();}
}
