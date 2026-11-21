#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#import <Foundation/Foundation.h>

// Read-only IL2CPP catalog adapter for the exact game represented by dump.cs.
// Never synthesizes items, never creates GM messages and never edits game data.
namespace {
typedef void* (*DomainGet)();
typedef void* (*DomainAssemblyOpen)(void*,const char*);
typedef void* (*AssemblyGetImage)(void*);
typedef void* (*ClassFromName)(void*,const char*,const char*);
typedef void* (*ClassGetMethod)(void*,const char*,int);
typedef void* (*RuntimeInvoke)(void*,void*,void**,void**);
typedef void* (*ClassGetField)(void*,const char*);
typedef void  (*FieldGetValue)(void*,void*,void*);
typedef int32_t (*StringLength)(void*);
typedef const uint16_t* (*StringChars)(void*);
typedef void* (*ThreadCurrent)();
typedef void* (*ThreadAttach)(void*);

struct Runtime {
  void* handle;
  DomainGet domain;
  DomainAssemblyOpen assembly;
  AssemblyGetImage image;
  ClassFromName fromName;
  ClassGetMethod method;
  RuntimeInvoke invoke;
  ClassGetField field;
  FieldGetValue fieldValue;
  StringLength stringLength;
  StringChars stringChars;
  ThreadCurrent current;
  ThreadAttach attach;
};
static void* sym(void *h,const char* name) { return dlsym(h,name); }
static void* managedImage(Runtime &r,void* domain,const char* assemblyName) {
  void* assembly=r.assembly(domain,assemblyName);
  return assembly ? r.image(assembly) : nullptr;
}
static int resolve(Runtime& r) {
  memset(&r,0,sizeof(r));
  bool seen=false, invalid=false;
  const char* fullPath=nullptr;
  for (uint32_t i=0;i<_dyld_image_count();++i) {
    const char* raw=_dyld_get_image_name(i);
    const struct mach_header* header=_dyld_get_image_header(i);
    if (!raw || !header) continue;
    NSString* path=[NSString stringWithUTF8String:raw];
    if (!path || ![path.lastPathComponent isEqualToString:@"UnityFramework"]) continue;
    seen=true;
    if (header->magic!=MH_MAGIC_64 || header->cputype!=CPU_TYPE_ARM64) {
      invalid=true; continue;
    }
    fullPath=raw; break;
  }
  if (!fullPath) return (seen && invalid) ? -202 : -201;
  r.handle=dlopen(fullPath,RTLD_NOW|RTLD_NOLOAD);
  if (!r.handle) r.handle=dlopen(fullPath,RTLD_NOW|RTLD_LOCAL);
  if (!r.handle) {
    NSLog(@"[XJGM] E203 dlopen failed: %s",dlerror() ?: "unknown");
    return -203;
  }
#define LOAD_API(fieldName,symbolName) do { \
    r.fieldName=(decltype(r.fieldName))sym(r.handle,symbolName); \
    if (!r.fieldName) { NSLog(@"[XJGM] E204 missing symbol: %s",symbolName); return -204; } \
  } while(0)
  LOAD_API(domain,"il2cpp_domain_get");
  LOAD_API(assembly,"il2cpp_domain_assembly_open");
  LOAD_API(image,"il2cpp_assembly_get_image");
  LOAD_API(fromName,"il2cpp_class_from_name");
  LOAD_API(method,"il2cpp_class_get_method_from_name");
  LOAD_API(invoke,"il2cpp_runtime_invoke");
  LOAD_API(field,"il2cpp_class_get_field_from_name");
  LOAD_API(fieldValue,"il2cpp_field_get_value");
  LOAD_API(stringLength,"il2cpp_string_length");
  LOAD_API(stringChars,"il2cpp_string_chars");
  LOAD_API(current,"il2cpp_thread_current");
  LOAD_API(attach,"il2cpp_thread_attach");
#undef LOAD_API
  return 1;
}
}
// Exact-game, exact-build GM request bridge.
// Derived from OnClickBtnAdd(0x1B1D610) instruction data flow:
// 0x448B310 = managed typeStr literal slot;
// 0x4479768 = managed route literal slot;
// 0x194ABC8 = IL2CPP metadata initialization helper.
// These are VAs for a Mach-O with __TEXT vmaddr=0; UUID guard is mandatory.

namespace {
static const uint8_t kTargetUUID[16] = {
  0x31,0x69,0x50,0xd2,0x5c,0xd5,0x32,0xb9,0xa2,0xdf,0xff,0xbf,0x3d,0x3b,0x8d,0x11
};
static uintptr_t exactImageBase() {
  for (uint32_t i=0;i<_dyld_image_count();++i) {
    const char *name=_dyld_get_image_name(i);
    if (!name || !strstr(name,"UnityFramework")) continue;
    const mach_header_64 *mh=(const mach_header_64*)_dyld_get_image_header(i);
    if (!mh || mh->magic!=MH_MAGIC_64) continue;
    const uint8_t *cmd=(const uint8_t*)(mh+1);
    for (uint32_t j=0;j<mh->ncmds;++j) {
      const load_command *lc=(const load_command*)cmd;
      if (lc->cmdsize<sizeof(load_command)) break;
      if (lc->cmd==LC_UUID && lc->cmdsize>=sizeof(uuid_command)) {
        const uuid_command *uuid=(const uuid_command*)lc;
        if (!memcmp(uuid->uuid,kTargetUUID,16)) return (uintptr_t)mh;
      }
      cmd+=lc->cmdsize;
    }
  }
  return 0;
}
static void *managedLiteral(uintptr_t base,uintptr_t slotVA) {
  using MetadataInit=void(*)(void*);
  auto init=(MetadataInit)(base+0x194ABC8);
  void **slot=(void**)(base+slotVA);
  init(slot);
  return *slot;
}
static bool invoke(Runtime& r,void* method,void* object,void** args,void** output=nullptr) {
  if (!method) return false;
  void* exception=nullptr;
  void* value=r.invoke(method,object,args,&exception);
  if (exception) return false;
  if (output) *output=value;
  return true;
}
static void stage(const char* step) {
  NSArray* dirs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
  if (!dirs.count) return;
  NSString* folder=[dirs[0] stringByAppendingPathComponent:@"XiuxianjiazuGM"];
  [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
  NSString* path=[folder stringByAppendingPathComponent:@"gm-send-stage.txt"];
  [[NSString stringWithFormat:@"V1 stage=%s",step] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
static int sendOriginalItem(int32_t id,int32_t count) {
  stage("start");
  if (id<=0 || count<=0 || count>9999) return -301;
  uintptr_t base=exactImageBase();
  if (!base) return -302;
  stage("uuid_verified");
  Runtime r={};
  if (resolve(r)!=1) return -303;
  void* domain=r.domain(); if (!domain) return -304;
  if (!r.current() && !r.attach(domain)) return -305;
  void* configImage=managedImage(r,domain,"gameConfigs.dll");
  void* protocolImage=managedImage(r,domain,"gameProtocal.dll");
  void* coreImage=managedImage(r,domain,"gameCore.dll");
  if (!configImage || !protocolImage || !coreImage) return -306;
  void* itemCls=r.fromName(configImage,"config.export.excel","ItemTmpl");
  void* cmdCls=r.fromName(protocolImage,"xxjz.game","C2S_GMComand");
  void* appCls=r.fromName(coreImage,"","GameApp");
  if (!itemCls || !cmdCls || !appCls) return -307;
  // Require the ID to exist in game's original catalog, not just the UI.
  void* find=r.method(itemCls,"Find",1);
  void* a[]={&id};
  stage("classes_resolved");
  void* item=nullptr;
  if (!invoke(r,find,nullptr,a,&item) || !item) return -308;
  // Instantiate the original data object and invoke its original mutators.
  using NewObject=void*(*)(void*);
  auto newObject=(NewObject)sym(r.handle,"il2cpp_object_new");
  if (!newObject) return -309;
  void* cmd=newObject(cmdCls);
  if (!cmd || !invoke(r,r.method(cmdCls,".ctor",0),cmd,nullptr)) return -310;
  stage("command_created");
  void* typeLiteral=managedLiteral(base,0x448B310);
  void* routeLiteral=managedLiteral(base,0x4479768);
  if (!typeLiteral || !routeLiteral) return -311;
  stage("literals_resolved");
  void* setArgs[]={typeLiteral};
  if (!invoke(r,r.method(cmdCls,"set_typeStr",1),cmd,setArgs)) return -312;
  void* idArgs[]={&id}; void* countArgs[]={&count};
  auto add=r.method(cmdCls,"AddToParams1",1);
  if (!invoke(r,add,cmd,idArgs) || !invoke(r,add,cmd,countArgs)) return -313;
  void* app=nullptr;
  if (!invoke(r,r.method(appCls,"get_Instance",0),nullptr,nullptr,&app) || !app) return -314;
  stage("parameters_added");
  void* sendArgs[]={routeLiteral,cmd};
  bool ok=invoke(r,r.method(appCls,"Send",2),app,sendArgs);
  if(ok)stage("submitted");
  return ok ? 1 : -315;
}
}
extern "C" __attribute__((visibility("default"))) int XJGMSendItem(int32_t id,int32_t count) {
  @autoreleasepool { return sendOriginalItem(id,count); }
}


// P2.1.5: independent skill GM command path.
// Verified target-version reverse engineering reference: GMSkillBlock.OnClickBtnAdd.
// Arguments: ActorData.id -> SkillInfo.id. No dependency on GMView instance.
namespace {
static void skillStage(const char* step) {
  NSArray *dirs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
  if(!dirs.count)return;
  NSString *dir=[dirs[0] stringByAppendingPathComponent:@"XiuxianjiazuGM"];
  [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  [[NSString stringWithFormat:@"P2.1.5 stage=%s",step]
    writeToFile:[dir stringByAppendingPathComponent:@"gm-skill-stage.txt"]
    atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
static int sendOriginalSkill(int32_t actorId,int32_t skillId) {
  skillStage("start");
  if(actorId<=0||skillId<=0)return -501;
  uintptr_t base=exactImageBase();
  if(!base)return -502;
  skillStage("uuid_verified");
  Runtime r={};
  if(resolve(r)!=1)return -503;
  void* domain=r.domain();
  if(!domain)return -504;
  if(!r.current()&&!r.attach(domain))return -505;
  void* configImage=managedImage(r,domain,"gameConfigs.dll");
  void* protocolImage=managedImage(r,domain,"gameProtocal.dll");
  void* coreImage=managedImage(r,domain,"gameCore.dll");
  if(!configImage||!protocolImage||!coreImage)return -506;
  void* skillCls=r.fromName(configImage,"config.export.excel","SkillInfo");
  void* cacheCls=r.fromName(coreImage,"","DataCache");
  void* cmdCls=r.fromName(protocolImage,"xxjz.game","C2S_GMComand");
  void* appCls=r.fromName(coreImage,"","GameApp");
  if(!skillCls||!cacheCls||!cmdCls||!appCls)return -507;
  skillStage("classes_resolved");

  // Validate that the requested skill is in the game's current SkillInfo catalog.
  void* skill=nullptr;void* skillArgs[]={&skillId};
  if(!invoke(r,r.method(skillCls,"Find",1),nullptr,skillArgs,&skill)||!skill)return -508;

  // Validate that the target actor is still in the game cache immediately before sending.
  void* cache=nullptr;
  if(!invoke(r,r.method(cacheCls,"get_Instance",0),nullptr,nullptr,&cache)||!cache)return -509;
  void* actor=nullptr;void* actorArgs[]={&actorId};
  if(!invoke(r,r.method(cacheCls,"TryGetActor",1),cache,actorArgs,&actor)||!actor)return -510;
  skillStage("actor_and_skill_verified");

  using NewObject=void*(*)(void*);
  auto newObject=(NewObject)sym(r.handle,"il2cpp_object_new");
  if(!newObject)return -511;
  void* cmd=newObject(cmdCls);
  if(!cmd||!invoke(r,r.method(cmdCls,".ctor",0),cmd,nullptr))return -512;
  skillStage("command_created");

  // Exact-game managed literal slots from the original GMSkillBlock call chain.
  // Do not carry forward across different UnityFramework UUIDs.
  void* typeLiteral=managedLiteral(base,0x448DC00);
  void* routeLiteral=managedLiteral(base,0x4479768);
  if(!typeLiteral||!routeLiteral)return -513;
  void* typeArgs[]={typeLiteral};
  if(!invoke(r,r.method(cmdCls,"set_typeStr",1),cmd,typeArgs))return -514;
  void* first[]={&actorId};void* second[]={&skillId};
  void* add=r.method(cmdCls,"AddToParams1",1);
  if(!invoke(r,add,cmd,first)||!invoke(r,add,cmd,second))return -515;
  skillStage("parameters_added");
  void* app=nullptr;
  if(!invoke(r,r.method(appCls,"get_Instance",0),nullptr,nullptr,&app)||!app)return -516;
  void* args[]={routeLiteral,cmd};
  skillStage("invoke_send");
  bool submitted=invoke(r,r.method(appCls,"Send",2),app,args);
  if(submitted)skillStage("submitted");
  return submitted?1:-517;
}
}
extern "C" __attribute__((visibility("default"))) int XJGMSendSkill(int32_t actorId,int32_t skillId) {
  @autoreleasepool{return sendOriginalSkill(actorId,skillId);}
}


// P2.2.3: GMAttrBlock.OnClickBtnSet native equivalent.
// Confirmed by instruction trace in UUID-guarded UnityFramework:
// C2S_GMComand(typeStr@0x4487DF0) -> actorId, attributeId, intValue,
// route@0x4479768 -> GameApp.Send. Returns request submission only.
namespace {
static void attributeStage(const char* step) {
  NSArray *dirs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
  if(!dirs.count)return;
  NSString *dir=[dirs[0] stringByAppendingPathComponent:@"XiuxianjiazuGM"];
  [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  [[NSString stringWithFormat:@"P2.2.3 stage=%s",step]
    writeToFile:[dir stringByAppendingPathComponent:@"gm-attribute-stage.txt"]
    atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
static int sendOriginalActorAttribute(int32_t actorId,int32_t attributeId,int32_t value) {
  attributeStage("start");
  if(actorId<=0||attributeId<0||attributeId>=100||value<0||value>9999)return -601;
  uintptr_t base=exactImageBase();if(!base)return -602;
  attributeStage("uuid_verified");
  Runtime r={};if(resolve(r)!=1)return -603;
  void* domain=r.domain();if(!domain)return -604;
  if(!r.current()&&!r.attach(domain))return -605;
  void* cfg=managedImage(r,domain,"gameConfigs.dll");
  void* protocol=managedImage(r,domain,"gameProtocal.dll");
  void* core=managedImage(r,domain,"gameCore.dll");
  if(!cfg||!protocol||!core)return -606;
  void* attrCls=r.fromName(cfg,"config.export.excel","UnitAttrTmpl");
  void* cacheCls=r.fromName(core,"","DataCache");
  void* cmdCls=r.fromName(protocol,"xxjz.game","C2S_GMComand");
  void* appCls=r.fromName(core,"","GameApp");
  if(!attrCls||!cacheCls||!cmdCls||!appCls)return -607;
  void* attr=nullptr;void* attrArgs[]={&attributeId};
  if(!invoke(r,r.method(attrCls,"Find",1),nullptr,attrArgs,&attr)||!attr)return -608;
  // Fetch and check current attribute type directly from current runtime config;
  // percentage encoded fields must remain disabled pending normalization audit.
  void* typeField=r.field(attrCls,"valueType");
  if(!typeField)return -609;
  int32_t valueType=-1;
  r.fieldValue(attr,typeField,&valueType);
  if(valueType!=0)return -610;
  void* cache=nullptr;
  if(!invoke(r,r.method(cacheCls,"get_Instance",0),nullptr,nullptr,&cache)||!cache)return -611;
  void* actor=nullptr;void* actorArgs[]={&actorId};
  if(!invoke(r,r.method(cacheCls,"TryGetActor",1),cache,actorArgs,&actor)||!actor)return -612;
  attributeStage("validated_actor_and_attribute");
  using NewObject=void*(*)(void*);
  auto newObject=(NewObject)sym(r.handle,"il2cpp_object_new");
  if(!newObject)return -613;
  void* cmd=newObject(cmdCls);
  if(!cmd||!invoke(r,r.method(cmdCls,".ctor",0),cmd,nullptr))return -614;
  void* typeLiteral=managedLiteral(base,0x4487DF0);
  void* routeLiteral=managedLiteral(base,0x4479768);
  if(!typeLiteral||!routeLiteral)return -615;
  void* typeArgs[]={typeLiteral};
  if(!invoke(r,r.method(cmdCls,"set_typeStr",1),cmd,typeArgs))return -616;
  void* first[]={&actorId},*second[]={&attributeId},*third[]={&value};
  auto add=r.method(cmdCls,"AddToParams1",1);
  if(!invoke(r,add,cmd,first)||!invoke(r,add,cmd,second)||
     !invoke(r,add,cmd,third))return -617;
  attributeStage("parameters_added");
  void* app=nullptr;
  if(!invoke(r,r.method(appCls,"get_Instance",0),nullptr,nullptr,&app)||!app)return -618;
  void* sendArgs[]={routeLiteral,cmd};
  attributeStage("invoke_send");
  bool ok=invoke(r,r.method(appCls,"Send",2),app,sendArgs);
  if(ok)attributeStage("submitted");
  return ok?1:-619;
}
}
extern "C" __attribute__((visibility("default"))) int XJGMSendActorAttribute(
    int32_t actorId,int32_t attrId,int32_t value) {
  @autoreleasepool{return sendOriginalActorAttribute(actorId,attrId,value);}
}
