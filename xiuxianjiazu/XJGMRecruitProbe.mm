#include <stdint.h>
#include <string.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#import <Foundation/Foundation.h>

namespace {
#include "XJGMRuntimeShared.h"

static const uint8_t kTargetUUID[16] = {
  0x31,0x69,0x50,0xd2,0x5c,0xd5,0x32,0xb9,0xa2,0xdf,0xff,0xbf,0x3d,0x3b,0x8d,0x11
};

static bool exactGame() {
  for(uint32_t i=0;i<_dyld_image_count();i++) {
    const char *path=_dyld_get_image_name(i);
    const struct mach_header *header=_dyld_get_image_header(i);
    if(!path||!header)continue;
    NSString *name=[[NSString stringWithUTF8String:path] lastPathComponent];
    if(![name isEqualToString:@"UnityFramework"])continue;
    if(header->magic!=MH_MAGIC_64||header->cputype!=CPU_TYPE_ARM64)return false;
    auto mh=(const mach_header_64*)header;
    auto cmd=(const uint8_t*)(mh+1);
    for(uint32_t j=0;j<mh->ncmds;j++) {
      auto lc=(const load_command*)cmd;
      if(lc->cmdsize<sizeof(load_command))return false;
      if(lc->cmd==LC_UUID&&lc->cmdsize>=sizeof(uuid_command))
        return memcmp(((const uuid_command*)lc)->uuid,kTargetUUID,16)==0;
      cmd+=lc->cmdsize;
    }
    return false;
  }
  return false;
}

static int save(NSDictionary *data,int code) {
  NSArray *dirs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
  if(!dirs.count)return code;
  NSString *dir=[dirs[0] stringByAppendingPathComponent:@"XiuxianjiazuGM"];
  [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  NSMutableDictionary *out=[data mutableCopy];
  out[@"status"]=@(code);
  out[@"timestamp"]=[NSDate date].description;
  out[@"readOnly"]=@YES;
  NSData *json=[NSJSONSerialization dataWithJSONObject:out options:NSJSONWritingPrettyPrinted error:nil];
  if(json)[json writeToFile:[dir stringByAppendingPathComponent:@"recruit-probe.json"] options:NSDataWritingAtomic error:nil];
  return code;
}

static bool call(Runtime &r,void *method,void *instance,void **args,void **result) {
  if(!method)return false;
  void *exception=nullptr;
  void *value=r.invoke(method,instance,args,&exception);
  if(exception)return false;
  if(result)*result=value;
  return true;
}

static int probe() {
  NSMutableDictionary *facts=[@{@"targetUUID":@"316950D2-5CD5-32B9-A2DF-FFBF3D3B8D11",
                                @"note":@"Does not create candidates, invoke RecruitActor, send network messages, or modify game data"} mutableCopy];
  if(!exactGame())return save(facts,-901);
  Runtime r={};
  if(resolve(r)!=1)return save(facts,-902);
  void *domain=r.domain();
  if(!domain)return save(facts,-903);
  if(!r.current()&&!r.attach(domain))return save(facts,-904);
  void *core=managedImage(r,domain,"gameCore.dll");
  void *server=managedImage(r,domain,"gameServer.dll");
  if(!core||!server)return save(facts,-905);
  void *appClass=r.fromName(core,"","GameApp");
  void *worldClass=r.fromName(server,"GS","GSWorld");
  void *forceClass=r.fromName(server,"GS","GSForce");
  if(!appClass||!worldClass||!forceClass)return save(facts,-906);
  facts[@"serverClassesResolved"]=@YES;
  void *handler=r.method(forceClass,"RecruitActor",3);
  void *add=r.method(forceClass,"AddRecruitActor",1);
  facts[@"recruitHandlerResolved"]=@(handler!=nullptr);
  facts[@"addCandidateResolved"]=@(add!=nullptr);
  facts[@"candidateFieldResolved"]=@(r.field(forceClass,"waitRecruitActors")!=nullptr);
  facts[@"membersFieldResolved"]=@(r.field(forceClass,"actors")!=nullptr);
  facts[@"candidateValidatorResolved"]=@(r.method(forceClass,"IsValidRecruitCandidate",1)!=nullptr);
  void *instance=nullptr;
  if(!call(r,r.method(appClass,"get_Instance",0),nullptr,nullptr,&instance)||!instance)
    return save(facts,-907);
  void *worldField=r.field(appClass,"CustomGSWorld");
  if(!worldField)return save(facts,-908);
  void *world=nullptr;
  r.fieldValue(instance,worldField,&world);
  facts[@"worldAvailable"]=@(world!=nullptr);
  if(!world)return save(facts,-909);
  void *forcesField=r.field(worldClass,"forces");
  if(!forcesField)return save(facts,-910);
  void *forces=nullptr;
  r.fieldValue(world,forcesField,&forces);
  if(!forces)return save(facts,-911);
  auto classOf=(void*(*)(void*))sym(r.handle,"il2cpp_object_get_class");
  auto unbox=(void*(*)(void*))sym(r.handle,"il2cpp_object_unbox");
  if(!classOf||!unbox)return save(facts,-912);
  void *dictClass=classOf(forces);
  if(!dictClass)return save(facts,-913);
  void *boxed=nullptr;
  if(!call(r,r.method(dictClass,"get_Count",0),forces,nullptr,&boxed)||!boxed)
    return save(facts,-914);
  void *raw=unbox(boxed);
  if(!raw)return save(facts,-915);
  int32_t count=*(int32_t*)raw;
  if(count<0||count>20000)return save(facts,-916);
  facts[@"forceCount"]=@(count);
  facts[@"worldObjectPresent"]=@YES;
  // Count and metadata availability do NOT prove the game-server handler is callable
  // from UIKit or that a save will persist. No mutations in this probe.
  return save(facts,1);
}
}
extern "C" __attribute__((visibility("default"))) int XJGMProbeRecruitState(void) {
  @autoreleasepool {return probe();}
}
