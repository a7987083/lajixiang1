#import <Foundation/Foundation.h>
#include <stdint.h>
#include <string.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>

namespace {
#include "XJGMRuntimeShared.h"
static const uint8_t kUUID[16]={0x31,0x69,0x50,0xd2,0x5c,0xd5,0x32,0xb9,0xa2,0xdf,0xff,0xbf,0x3d,0x3b,0x8d,0x11};
static bool targetMatches() {
  for(uint32_t i=0;i<_dyld_image_count();++i) {
    const char* path=_dyld_get_image_name(i);
    const mach_header* header=_dyld_get_image_header(i);
    if(!path||!header)continue;
    NSString* name=[[NSString stringWithUTF8String:path] lastPathComponent];
    if(![name isEqualToString:@"UnityFramework"])continue;
    if(header->magic!=MH_MAGIC_64||header->cputype!=CPU_TYPE_ARM64)return false;
    const mach_header_64* h=(const mach_header_64*)header;
    const uint8_t* p=(const uint8_t*)(h+1);
    for(uint32_t j=0;j<h->ncmds;++j) {
      const load_command* lc=(const load_command*)p;
      if(lc->cmdsize<sizeof(load_command))return false;
      if(lc->cmd==LC_UUID&&lc->cmdsize>=sizeof(uuid_command)) {
        return memcmp(((const uuid_command*)lc)->uuid,kUUID,16)==0;
      }
      p+=lc->cmdsize;
    }
    return false;
  }
  return false;
}
static void logStage(NSString* s) {
  NSArray* roots=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
  if(!roots.count)return;
  NSString* folder=[roots[0] stringByAppendingPathComponent:@"XiuxianjiazuGM"];
  [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
  NSString* file=[folder stringByAppendingPathComponent:@"ad-test-stage.txt"];
  NSString* msg=[NSString stringWithFormat:@"%@ %@\n",[NSDate date],s];
  NSFileHandle* handle=[NSFileHandle fileHandleForWritingAtPath:file];
  if(!handle){[msg writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:nil];return;}
  @try{[handle seekToEndOfFile];[handle writeData:[msg dataUsingEncoding:NSUTF8StringEncoding]];}
  @finally{[handle closeFile];}
}
}
extern "C" __attribute__((visibility("default"))) int XJGMTestAdComplete(int32_t adId) {
  @autoreleasepool {
    if(adId!=2)return -801; // Only the previously traced recruitment ad.
    if(!targetMatches()){logStage(@"E802 target UUID mismatch");return -802;}
    Runtime r={};
    if(resolve(r)!=1){logStage(@"E803 IL2CPP unavailable");return -803;}
    void* domain=r.domain();
    if(!domain)return -804;
    if(!r.current()&&!r.attach(domain))return -805;
    void* image=managedImage(r,domain,"gameCore.dll");
    if(!image)return -806;
    void* cls=r.fromName(image,"","GameApp");
    if(!cls)return -807;
    void* singleton=r.method(cls,"get_Instance",0);
    void* complete=r.method(cls,"OnVideoAdComplete",1);
    if(!singleton||!complete)return -808;
    void* exception=nullptr;
    void* app=r.invoke(singleton,nullptr,nullptr,&exception);
    if(exception||!app)return -809;
    void* args[]={&adId};
    logStage(@"invoke OnVideoAdComplete adId=2");
    exception=nullptr;
    r.invoke(complete,app,args,&exception);
    if(exception){logStage(@"E810 managed exception");return -810;}
    logStage(@"callback invoked; reward and server acceptance NOT verified");
    return 1;
  }
}
