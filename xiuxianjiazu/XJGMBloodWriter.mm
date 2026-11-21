#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#import <Foundation/Foundation.h>

// Native-world bloodline mutation adapter for the exact user-supplied UnityFramework.
// GSActor.ChangeBloods(id, delta, maxValue) is additive (verified ARM64 0x1E09E3C).
// No guessed GM message, direct object layout write or stale-offset call is used.
extern "C" int XJGMExportActorBloods(int32_t,const char*,int32_t);
extern "C" NSString* XJGMCurrentWorldToken(void);

namespace {
#include "XJGMRuntimeShared.h"

static bool managedCall(Runtime& r,void* method,void* object,void** args,void** output=nullptr) {
    if(!method)return false;
    void* exception=nullptr;
    void* result=r.invoke(method,object,args,&exception);
    if(exception)return false;
    if(output)*output=result;
    return true;
}
static NSString* managedString(Runtime& r,void* managed) {
    if(!managed)return nil;
    int32_t len=r.stringLength(managed);
    if(len<0||len>2048)return nil;
    const uint16_t *chars=r.stringChars(managed);
    if(len&&!chars)return nil;
    return [[NSString alloc] initWithCharacters:(const unichar*)chars length:(NSUInteger)len];
}
static bool boxedInt(Runtime& r,void* boxed,int32_t* out) {
    auto unbox=(void*(*)(void*))sym(r.handle,"il2cpp_object_unbox");
    if(!boxed||!unbox||!out)return false;
    void* raw=unbox(boxed);if(!raw)return false;
    *out=*(int32_t*)raw;return true;
}
static bool boxedBool(Runtime& r,void* boxed,bool* out) {
    auto unbox=(void*(*)(void*))sym(r.handle,"il2cpp_object_unbox");
    if(!boxed||!unbox||!out)return false;
    void* raw=unbox(boxed);if(!raw)return false;
    *out=*(uint8_t*)raw!=0;return true;
}
// Read a fresh user-validated ActorData snapshot on every requested write.
// Do not use previously selected UITableView rows as the mutation precondition.
static int snapshot(int32_t actorId,const char* name,int32_t forceId,int32_t bloodId,
                    int32_t* purity,bool* exists) {
    int count=XJGMExportActorBloods(actorId,name,forceId);
    if(count<0)return -820;
    NSArray* docs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    if(!docs.count)return -821;
    NSString* path=[[docs[0] stringByAppendingPathComponent:@"XiuxianjiazuGM"]
                     stringByAppendingPathComponent:@"actor-bloods.json"];
    NSData* data=[NSData dataWithContentsOfFile:path];
    id obj=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
    NSString* expected=[NSString stringWithUTF8String:name];
    if(![obj isKindOfClass:NSDictionary.class] ||
       ![obj[@"actorId"] isEqual:@(actorId)] ||
       ![obj[@"actorName"] isEqual:expected] ||
       ![obj[@"forceId"] isEqual:@(forceId)] ||
       ![obj[@"bloods"] isKindOfClass:NSArray.class] ||
       [obj[@"bloods"] count]!=(NSUInteger)count)return -821;
    *exists=false;*purity=0;
    for(NSDictionary *entry in obj[@"bloods"]){
        if(![entry isKindOfClass:NSDictionary.class] ||
           ![entry[@"id"] isKindOfClass:NSNumber.class] ||
           ![entry[@"purity"] isKindOfClass:NSNumber.class])return -822;
        if([entry[@"id"] intValue]==bloodId){
            if(*exists)return -823;
            *exists=true;*purity=[entry[@"purity"] intValue];
        }
    }
    return 1;
}
static bool matchesTargetUUID() {
    static const uint8_t required[16]={
        0x31,0x69,0x50,0xD2,0x5C,0xD5,0x32,0xB9,
        0xA2,0xDF,0xFF,0xBF,0x3D,0x3B,0x8D,0x11
    };
    for(uint32_t i=0;i<_dyld_image_count();i++) {
        const char* path=_dyld_get_image_name(i);
        const mach_header* header=_dyld_get_image_header(i);
        if(!path||!header||header->magic!=MH_MAGIC_64||header->cputype!=CPU_TYPE_ARM64)continue;
        NSString *file=[NSString stringWithUTF8String:path];
        if(![file.lastPathComponent isEqualToString:@"UnityFramework"])continue;
        const mach_header_64* hdr=(const mach_header_64*)header;
        const uint8_t* cursor=(const uint8_t*)hdr+sizeof(mach_header_64);
        for(uint32_t n=0;n<hdr->ncmds;n++) {
            const load_command* cmd=(const load_command*)cursor;
            if(cmd->cmdsize<sizeof(load_command))return false;
            if(cmd->cmd==LC_UUID && cmd->cmdsize>=sizeof(uuid_command)) {
                const uuid_command* u=(const uuid_command*)cmd;
                return memcmp(u->uuid,required,16)==0;
            }
            cursor+=cmd->cmdsize;
        }
        return false;
    }
    return false;
}
static int runMutation(int32_t actorId,const char* expectedName,int32_t forceId,
                       int32_t bloodId,int32_t target,int32_t mode) {
    if(!matchesTargetUUID())return -800;
    if(actorId<=0||bloodId<=0||bloodId>32767||!expectedName||!expectedName[0]||
       forceId<0||mode<0||mode>2)return -801;
    if(mode!=2 && (target<1||target>120))return -802;
    NSString *startWorld=XJGMCurrentWorldToken();
    if(!startWorld.length)return -803;
    int32_t current=0;bool exists=false;
    int snapshotCode=snapshot(actorId,expectedName,forceId,bloodId,&current,&exists);
    if(snapshotCode!=1)return snapshotCode;
    if(mode==0 && !exists)return -804; // Set existing purity.
    if(mode==1 && exists)return -805;  // Add only if absent.
    if(mode==2 && !exists)return -806; // Remove only if present.
    if(![startWorld isEqualToString:XJGMCurrentWorldToken()])return -807;
    if(mode==0 && current==target)return 2;

    Runtime r={};if(resolve(r)!=1)return -808;
    void* domain=r.domain();
    if(!domain||(!r.current()&&!r.attach(domain)))return -809;
    void* core=managedImage(r,domain,"gameCore.dll");
    void* config=managedImage(r,domain,"gameConfigs.dll");
    if(!core||!config)return -810;
    void* appCls=r.fromName(core,"","GameApp");
    void* bloodCls=r.fromName(config,"config.export.excel","BloodTmpl");
    if(!appCls||!bloodCls)return -811;
    void* find=r.method(bloodCls,"FindCfg",1);
    void* blood=nullptr;void* findArgs[]={&bloodId};
    if(mode!=2 && (!managedCall(r,find,nullptr,findArgs,&blood)||!blood))return -812;

    void* app=nullptr;
    if(!managedCall(r,r.method(appCls,"get_Instance",0),nullptr,nullptr,&app)||!app)return -813;
    void* worldField=r.field(appCls,"CustomGSWorld");
    if(!worldField)return -814;
    void* world=nullptr;
    r.fieldValue(app,worldField,&world);
    if(!world)return -814;
    // GSWorld and GSActor are not guaranteed to be declared in gameCore.dll.
    // Resolve the classes from the validated live instances rather than
    // assuming an assembly. Validate namespace + name before invoking.
    auto objectClass=(void*(*)(void*))sym(r.handle,"il2cpp_object_get_class");
    auto className=(const char*(*)(void*))sym(r.handle,"il2cpp_class_get_name");
    auto classNamespace=(const char*(*)(void*))sym(r.handle,"il2cpp_class_get_namespace");
    if(!objectClass||!className||!classNamespace)return -815;
    void* worldCls=objectClass(world);
    if(!worldCls || !className(worldCls)||!classNamespace(worldCls)||
       strcmp(className(worldCls),"GSWorld")!=0||
       strcmp(classNamespace(worldCls),"GS")!=0)return -815;
    void* actor=nullptr;void* actorArgs[]={&actorId};
    if(!managedCall(r,r.method(worldCls,"FindActor",1),world,actorArgs,&actor)||!actor)return -816;
    void* actorCls=objectClass(actor);
    if(!actorCls || !className(actorCls)||!classNamespace(actorCls)||
       strcmp(className(actorCls),"GSActor")!=0||
       strcmp(classNamespace(actorCls),"GS")!=0)return -817;
    void* idField=r.field(actorCls,"id");
    if(!idField)return -818;
    int32_t id=0;
    r.fieldValue(actor,idField,&id);
    if(id!=actorId)return -819;
    void* actorName=nullptr;
    if(!managedCall(r,r.method(actorCls,"get_name",0),actor,nullptr,&actorName))return -824;
    NSString *actualName=managedString(r,actorName);
    NSString *wanted=[NSString stringWithUTF8String:expectedName];
    if(!actualName||![actualName isEqualToString:wanted])return -824;
    void* boxForce=nullptr;
    int32_t actualForce=-1;
    if(!managedCall(r,r.method(actorCls,"get_forceId",0),actor,nullptr,&boxForce)||
       !boxedInt(r,boxForce,&actualForce)||actualForce!=forceId)return -825;
    if(![startWorld isEqualToString:XJGMCurrentWorldToken()])return -807;

    // P2.7.4: E835 blocked template-fixed bloodlines before any write.
    // The user explicitly requests removal of these too. Do not treat the
    // game's "fixed" metadata as immutable. Preserve identity/world checks,
    // perform the same managed removal sequence, then require live readback.
    // Game normalization or a later load may still restore fixed entries.
    // The method's second parameter is a delta, not an absolute purity.
    int32_t delta=mode==2?-current:target-current;
    if(delta==0 && mode!=2)return 2;
    int32_t maxValue=120;
    void* args[]={&bloodId,&delta,&maxValue};
    void* change=r.method(actorCls,"ChangeBloods",3);
    if(!change)return -826;
    if(!managedCall(r,change,actor,args))return -827;

    if(mode==2){
        // ChangeBloods(-current) drops purity to 0, but does not remove
        // the key from GSActor.bloodMapData (verified ARM64). Remove via
        // the managed Dictionary.Remove API using the game's normalized key.
        void* getKey=r.method(bloodCls,"GetBloodDataKey",1);
        void* boxKey=nullptr;int32_t key=0;
        if(!managedCall(r,getKey,nullptr,findArgs,&boxKey)||
           !boxedInt(r,boxKey,&key))return -828; // Partial mutation: zeroed, not removed.
        void* bloodMap=nullptr;
        if(!managedCall(r,r.method(actorCls,"GetBloodMapForRead",0),
                        actor,nullptr,&bloodMap)||!bloodMap)return -828;
        void* dictionaryCls=objectClass(bloodMap);
        if(!dictionaryCls)return -828;
        void* removeMethod=r.method(dictionaryCls,"Remove",1);
        void* keyArgs[]={&key};void* boxRemoved=nullptr;bool removed=false;
        if(!managedCall(r,removeMethod,bloodMap,keyArgs,&boxRemoved)||
           !boxedBool(r,boxRemoved,&removed)||!removed)return -829;
        // Normalize derived blood talents after removing the source.
        bool rebuild=true,refresh=true;
        void* normArgs[]={&rebuild,&refresh};
        void* normalized=nullptr;
        void* normalize=r.method(actorCls,"NormalizeBloodTalentsForCurrentBloods",2);
        if(!normalize||!managedCall(r,normalize,actor,normArgs,&normalized))return -830;
    }
    // Re-read through the proven ActorData path. Persistence beyond this
    // process is not claimed; return only if actual value matches.
    int32_t after=0;bool afterExists=false;
    int rc=snapshot(actorId,expectedName,forceId,bloodId,&after,&afterExists);
    if(rc!=1)return -831;
    if(mode==2)return afterExists?-832:1;
    return (afterExists && after==target)?1:-833;
}
}
extern "C" __attribute__((visibility("default"))) int XJGMWriteActorBlood(
    int32_t actorId,const char* expectedName,int32_t forceId,
    int32_t bloodId,int32_t target,int32_t mode){
    @autoreleasepool{return runMutation(actorId,expectedName,forceId,bloodId,target,mode);}
}
