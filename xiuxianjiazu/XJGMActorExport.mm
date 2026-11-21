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
static thread_local bool sSkipActorCheckpoint=false;
static void checkpoint(const char *stage){
 if(sSkipActorCheckpoint)return;
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


// P2.2.2: read-only, runtime actor attribute array snapshot.
// The indices below are raw List<long> positions; do NOT assume semantic mapping
// to UnitAttrTmpl.id without checking actual game UI in a later validation step.
namespace {
static int exportActorAttributes(int32_t actorId,const char* expectedName,int32_t expectedForceId,
                                 int32_t attributeIndex=-1,int64_t* readValue=nullptr) {
 checkpoint("attr_start");
 if(actorId<=0 || !expectedName || !expectedName[0])return -440;
 APIs r={};
 int status=setup(r);if(status!=1)return status;
 void* domain=r.domain();if(!domain)return -404;
 if(!r.threadCurrent()&&!r.threadAttach(domain))return -405;
 void* assembly=r.assembly(domain,"gameCore.dll");
 void* image=assembly?r.image(assembly):nullptr;
 if(!image)return -406;
 void* cacheClass=r.fromName(image,"","DataCache");
 if(!cacheClass)return -407;
 void* getInstance=r.method(cacheClass,"get_Instance",0);
 void* getActor=r.method(cacheClass,"TryGetActor",1);
 if(!getInstance||!getActor)return -441;
 void* cache=nullptr;
 if(!call(r,getInstance,nullptr,nullptr,&cache)||!cache)return -409;
 void* args[]={&actorId};
 void* actor=nullptr;
 if(!call(r,getActor,cache,args,&actor)||!actor)return -442;
 checkpoint("attr_actor_found");
 void* actorCls=r.objectClass(actor);if(!actorCls)return -443;
 void* getName=r.method(actorCls,"get_name",0);
 void* getForce=r.method(actorCls,"get_forceId",0);
 void* getAttr=r.method(actorCls,"GetAttr",1);
 if(!getName||!getForce||!getAttr)return -444;
 int32_t force=0;
 if(intGetter(r,actor,getForce,&force)!=1)return -445;
 void* managedName=nullptr;
 if(!call(r,getName,actor,nullptr,&managedName))return -445;
 NSString *name=readString(r,managedName);
 NSString *expected=[NSString stringWithUTF8String:expectedName];
 if(!name||!expected||![name isEqualToString:expected]||force!=expectedForceId)return -446;
 checkpoint("attr_get_list");
 bool falseArg=false;void* getArgs[]={&falseArg};
 void* list=nullptr;
 if(!call(r,getAttr,actor,getArgs,&list)||!list)return -447;
 void* listCls=r.objectClass(list);if(!listCls)return -448;
 void* getCount=r.method(listCls,"get_Count",0);
 void* getItem=r.method(listCls,"get_Item",1);
 if(!getCount||!getItem)return -449;
 int32_t count=0;
 if(intGetter(r,list,getCount,&count)!=1||count<0||count>4096)return -450;
 if(readValue && (attributeIndex<0||attributeIndex>=count))return -455;
 // Live lock readback needs only one List<long> element. Avoid O(N) scans.
 if(readValue) {
  int32_t index=attributeIndex;
  void* boxed=nullptr;void* indexArgs[]={&index};
  if(!call(r,getItem,list,indexArgs,&boxed)||!boxed)return -451;
  void* raw=r.unbox(boxed);if(!raw)return -451;
  *readValue=*(int64_t*)raw;
  return 1;
 }
 NSMutableArray *values=[NSMutableArray arrayWithCapacity:(NSUInteger)count];
 for(int32_t index=0;index<count;index++){
  void* boxed=nullptr;void* indexArgs[]={&index};
  if(!call(r,getItem,list,indexArgs,&boxed)||!boxed)return -451;
  void* raw=r.unbox(boxed);if(!raw)return -451;
  [values addObject:@{@"index":@(index),@"value":@(*(int64_t*)raw)}];
 }
 checkpoint("attr_encode");
 NSDictionary* obj=@{@"actorId":@(actorId),@"actorName":name,@"forceId":@(force),
                     @"count":@(count),@"values":values,
                     @"indexMappingVerified":@NO};
 NSData* data=[NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
 if(!data||data.length>1024*1024)return -452;
 NSArray* dirs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
 if(!dirs.count)return -453;
 NSString *dir=[dirs[0] stringByAppendingPathComponent:@"XiuxianjiazuGM"];
 if(![[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil])return -453;
 if(![data writeToFile:[dir stringByAppendingPathComponent:@"actor-attributes.json"] options:NSDataWritingAtomic error:nil])return -454;
 checkpoint("attr_success");
 return count;
}
}
extern "C" __attribute__((visibility("default"))) int XJGMExportActorAttributes(int32_t actorId,
    const char* expectedName,int32_t expectedForceId) {
 @autoreleasepool{return exportActorAttributes(actorId,expectedName,expectedForceId);}
}




// Shared read-only runtime path, with the same live ActorData identity validation
// as the already verified attribute exporter. No storage write on lock sampling.
extern "C" __attribute__((visibility("default"))) int XJGMReadActorAttributeLive(
    int32_t actorId,int32_t attrIndex,const char* expectedName,
    int32_t expectedForceId,int64_t* outValue) {
  @autoreleasepool {
    if(!outValue)return -456;
    // Periodic readback must not create diagnostic log files every few seconds.
    bool previous=sSkipActorCheckpoint;
    sSkipActorCheckpoint=true;
    int result=exportActorAttributes(actorId,expectedName,expectedForceId,attrIndex,outValue);
    sSkipActorCheckpoint=previous;
    return result;
  }
}

// Save slot/world generation guard. Distinguishes a reopened world with reused
// actor IDs from the old one; nil/empty means no reliable world context.
extern "C" __attribute__((visibility("default"))) NSString* XJGMCurrentWorldToken(void) {
  @autoreleasepool {
    APIs r={};
    if(setup(r)!=1)return nil;
    void* domain=r.domain();if(!domain)return nil;
    if(!r.threadCurrent()&&!r.threadAttach(domain))return nil;
    void* asmCore=r.assembly(domain,"gameCore.dll");
    void* img=asmCore?r.image(asmCore):nullptr;
    void* cls=img?r.fromName(img,"","GameApp"):nullptr;
    if(!cls)return nil;
    void* instance=nullptr;
    if(!call(r,r.method(cls,"get_Instance",0),nullptr,nullptr,&instance)||!instance)return nil;
    void* method=r.method(cls,"GetCurrentCustomGSWorldUUID",0);
    if(!method)return nil;
    void* tokenObj=nullptr;
    if(!call(r,method,instance,nullptr,&tokenObj)||!tokenObj)return nil;
    NSString* token=readString(r,tokenObj);
    if(!token.length)return nil;
    // A save's UUID may stay the same across reloads. Bind locks additionally
    // to the live GSWorld instance, not just to the save slot.
    auto field=(void*(*)(void*,const char*))dlsym(r.handle,"il2cpp_class_get_field_from_name");
    auto fieldValue=(void(*)(void*,void*,void*))dlsym(r.handle,"il2cpp_field_get_value");
    if(!field || !fieldValue)return nil;
    void* worldField=field(cls,"CustomGSWorld");
    if(!worldField)return nil;
    void* world=nullptr;fieldValue(instance,worldField,&world);
    if(!world)return nil;
    return [NSString stringWithFormat:@"%@|%p",token,world];
  }
}


extern "C" __attribute__((visibility("default"))) int XJGMExportActorBloods(
    int32_t actorId,const char* expectedName,int32_t expectedForceId) {
 @autoreleasepool {
  if(actorId<=0||!expectedName||!expectedName[0])return -701;
  APIs r={};if(setup(r)!=1)return -702;
  void* domain=r.domain();if(!domain)return -703;
  if(!r.threadCurrent()&&!r.threadAttach(domain))return -704;
  void* assembly=r.assembly(domain,"gameCore.dll");
  void* image=assembly?r.image(assembly):nullptr;
  void* cacheCls=image?r.fromName(image,"","DataCache"):nullptr;
  if(!cacheCls)return -705;
  void* cache=nullptr;
  if(!call(r,r.method(cacheCls,"get_Instance",0),nullptr,nullptr,&cache)||!cache)return -706;
  void* lookup=r.method(cacheCls,"TryGetActor",1);
  void* actor=nullptr;void* actorArgs[]={&actorId};
  if(!call(r,lookup,cache,actorArgs,&actor)||!actor)return -707;
  void* actorCls=r.objectClass(actor);if(!actorCls)return -708;
  int32_t force=0;
  if(intGetter(r,actor,r.method(actorCls,"get_forceId",0),&force)!=1)return -708;
  void* nameObject=nullptr;
  if(!call(r,r.method(actorCls,"get_name",0),actor,nullptr,&nameObject))return -708;
  NSString* name=readString(r,nameObject);
  NSString* expected=[NSString stringWithUTF8String:expectedName];
  if(!name||!expected||![name isEqualToString:expected]||force!=expectedForceId)return -709;
  // ActorData.GetBloods(false) is read-only in the managed object graph.
  bool falseArg=false;void* getArgs[]={&falseArg};
  void* bloodList=nullptr;
  if(!call(r,r.method(actorCls,"GetBloods",1),actor,getArgs,&bloodList)||!bloodList)return -710;
  void* listClass=r.objectClass(bloodList);if(!listClass)return -711;
  void* countMethod=r.method(listClass,"get_Count",0);
  void* getItemMethod=r.method(listClass,"get_Item",1);
  if(!countMethod||!getItemMethod)return -711;
  int32_t count=0;
  if(intGetter(r,bloodList,countMethod,&count)!=1||count<0||count>1024)return -712;
  NSMutableArray* result=[NSMutableArray arrayWithCapacity:(NSUInteger)count];
  for(int32_t i=0;i<count;i++){
   void* entry=nullptr;void* args[]={&i};
   if(!call(r,getItemMethod,bloodList,args,&entry)||!entry)return -713;
   void* type=r.objectClass(entry);if(!type)return -714;
   void* idBox=nullptr;void* valueBox=nullptr;void* activeBox=nullptr;
   if(!call(r,r.method(type,"get_tmplId",0),entry,nullptr,&idBox)||!idBox ||
      !call(r,r.method(type,"get_value",0),entry,nullptr,&valueBox)||!valueBox ||
      !call(r,r.method(type,"get_fullActive",0),entry,nullptr,&activeBox)||!activeBox)return -715;
   void* idRaw=r.unbox(idBox),*valRaw=r.unbox(valueBox),*activeRaw=r.unbox(activeBox);
   if(!idRaw||!valRaw||!activeRaw)return -715;
   int16_t bid=*(int16_t*)idRaw, purity=*(int16_t*)valRaw;
   BOOL active=*(uint8_t*)activeRaw!=0;
   [result addObject:@{@"id":@(bid),@"purity":@(purity),@"active":@(active)}];
  }
  NSArray* dirs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
  if(!dirs.count)return -716;
  NSString* dir=[dirs[0] stringByAppendingPathComponent:@"XiuxianjiazuGM"];
  if(![[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil])return -716;
  NSDictionary* obj=@{@"actorId":@(actorId),@"actorName":name,
       @"forceId":@(force),@"bloods":result};
  NSData* json=[NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
  if(!json||json.length>1024*1024)return -717;
  if(![json writeToFile:[dir stringByAppendingPathComponent:@"actor-bloods.json"]
             options:NSDataWritingAtomic error:nil])return -718;
  return count;
 }
}
