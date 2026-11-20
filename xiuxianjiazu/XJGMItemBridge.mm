#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#import <Foundation/Foundation.h>

// Read-only IL2CPP catalog adapter for the exact game represented by dump.cs.
// Never synthesizes items, never creates GM messages and never edits game data.
extern "C" int XJGMSetEntries(const char *category,const char *json);
extern "C" void XJGMReportExport(const char *category,int result,int saved);
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
// return 1 when an exact ID was found; 0 if absent; -1 when runtime unavailable.
// Must be called from the Unity main thread when the application's IL2CPP runtime is initialized.
extern "C" __attribute__((visibility("default"))) int XJGMQueryItemById(int32_t id) {
  if (id<=0) return 0;
  Runtime r={};
  int stage=resolve(r); if (stage!=1) return stage;
  void *domain=r.domain();
  if (!domain) return -205;
  if (!r.current() && !r.attach(domain)) return -210;
  void *assembly=r.assembly(domain,"Assembly-CSharp");
  if (!assembly) assembly=r.assembly(domain,"Assembly-CSharp.dll");
  if (!assembly) return -206;
  void *image=r.image(assembly);
  if (!image) return -207;
  void *cls=r.fromName(image,"config.export.excel","ItemTmpl");
  if (!cls) return -208;
  void *find=r.method(cls,"Find",1);
  if (!find) return -209;
  void *args[]={&id};
  void *exception=nullptr;
  void *item=r.invoke(find,nullptr,args,&exception);
  if (exception) return -1;
  if (!item) return 0;
  void *nameField=r.field(cls,"name");
  void *idField=r.field(cls,"id");
  if (!nameField || !idField) return -1;
  void *nameObj=nullptr;
  int32_t actualId=0;
  r.fieldValue(nameField,item,&nameObj);
  r.fieldValue(idField,item,&actualId);
  if (!nameObj || actualId!=id) return -1;
  int32_t length=r.stringLength(nameObj);
  const uint16_t* chars=r.stringChars(nameObj);
  if (length<0 || length>4096 || (length>0&&!chars)) return -1;
  NSString *name=[[NSString alloc] initWithCharacters:(const unichar*)chars length:(NSUInteger)length];
  if (!name) return -1;
  NSArray *rows=@[@{@"id":@(actualId),@"name":name}];
  NSData *json=[NSJSONSerialization dataWithJSONObject:rows options:0 error:nil];
  if (!json) return -1;
  NSMutableData *nullTerminated=[json mutableCopy];
  const uint8_t zero=0;
  [nullTerminated appendBytes:&zero length:1];
  return XJGMSetEntries("item",(const char*)nullTerminated.bytes)==1?1:-1;
}


// Exact-game, exact-build GM request bridge.
// Derived from OnClickBtnAdd(0x1B1D610) instruction data flow:
// 0x448B310 = managed typeStr literal slot;
// 0x4479768 = managed route literal slot;
// 0x194ABC8 = IL2CPP metadata initialization helper.
// These are VAs for a Mach-O with __TEXT vmaddr=0; UUID guard is mandatory.
extern "C" void XJGMSetExecutor(int (*executor)(const char*,int32_t,int32_t,const char*));
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
static int sendOriginalItem(int32_t id,int32_t count) {
  if (id<=0 || count<=0) return 0;
  uintptr_t base=exactImageBase();
  if (!base) return 0;
  Runtime r={};
  if (resolve(r)!=1) return 0;
  void* domain=r.domain(); if (!domain) return 0;
  if (!r.current()) r.attach(domain);
  void* assembly=r.assembly(domain,"Assembly-CSharp");
  if (!assembly) assembly=r.assembly(domain,"Assembly-CSharp.dll");
  if (!assembly) return 0;
  void* image=r.image(assembly);
  void* itemCls=r.fromName(image,"config.export.excel","ItemTmpl");
  void* cmdCls=r.fromName(image,"xxjz.game","C2S_GMComand");
  void* appCls=r.fromName(image,"","GameApp");
  if (!itemCls || !cmdCls || !appCls) return 0;
  // Require the ID to exist in game's original catalog, not just the UI.
  void* find=r.method(itemCls,"Find",1);
  void* a[]={&id};
  void* item=nullptr;
  if (!invoke(r,find,nullptr,a,&item) || !item) return 0;
  // Instantiate the original data object and invoke its original mutators.
  using NewObject=void*(*)(void*);
  auto newObject=(NewObject)sym(r.handle,"il2cpp_object_new");
  if (!newObject) return 0;
  void* cmd=newObject(cmdCls);
  if (!cmd || !invoke(r,r.method(cmdCls,".ctor",0),cmd,nullptr)) return 0;
  void* typeLiteral=managedLiteral(base,0x448B310);
  void* routeLiteral=managedLiteral(base,0x4479768);
  if (!typeLiteral || !routeLiteral) return 0;
  void* setArgs[]={typeLiteral};
  if (!invoke(r,r.method(cmdCls,"set_typeStr",1),cmd,setArgs)) return 0;
  void* idArgs[]={&id}; void* countArgs[]={&count};
  auto add=r.method(cmdCls,"AddToParams1",1);
  if (!invoke(r,add,cmd,idArgs) || !invoke(r,add,cmd,countArgs)) return 0;
  void* app=nullptr;
  if (!invoke(r,r.method(appCls,"get_Instance",0),nullptr,nullptr,&app) || !app) return 0;
  void* sendArgs[]={routeLiteral,cmd};
  return invoke(r,r.method(appCls,"Send",2),app,sendArgs) ? 1 : 0;
}
static int execute(const char* kind,int32_t id,int32_t count,const char* argument) {
  if (!kind || strcmp(kind,"item")) return 0; // Other GM actions not audited.
  return sendOriginalItem(id,count);
}
}
__attribute__((constructor)) static void XJGMRegisterRealItemExecutor() {
  XJGMSetExecutor(&execute);
}


// Full, read-only IL2CPP configuration export. Each table remains independent.
// A dictionary's runtime Values collection is copied into a managed typed array.
// No artificial item IDs; JSON persistence is in the application's own Documents.
namespace {
static int exportTable(Runtime &r,void *image,const char *typeName,const char *category,const char *fileName,bool *saved) {
  auto staticGet=(void (*)(void*,void*))sym(r.handle,"il2cpp_field_static_get_value");
  auto objectClass=(void* (*)(void*))sym(r.handle,"il2cpp_object_get_class");
  auto arrayNew=(void* (*)(void*,uintptr_t))sym(r.handle,"il2cpp_array_new");
  auto arrayLength=(uintptr_t (*)(void*))sym(r.handle,"il2cpp_array_length");
  auto unbox=(void* (*)(void*))sym(r.handle,"il2cpp_object_unbox");
  if (!staticGet || !objectClass || !arrayNew || !arrayLength || !unbox) return -101;
  void* cls=r.fromName(image,"config.export.excel",typeName);
  if (!cls) return -208;
  void* getEmpty=r.method(cls,"get_IsConfigsEmpty",0);
  if (!getEmpty) return -209;
  void* exc=nullptr;
  void* boxed=r.invoke(getEmpty,nullptr,nullptr,&exc);
  if (exc || !boxed) return -105;
  if (*(uint8_t*)unbox(boxed)) return -102;
  void* f=r.field(cls,"configs");
  if (!f) return -108;
  void* dict=nullptr;
  staticGet(f,&dict);
  if (!dict) return -103;
  void* dictClass=objectClass(dict);
  if (!dictClass) return -104;
  void* getValues=r.method(dictClass,"get_Values",0);
  if (!getValues) return -104;
  exc=nullptr;
  void* values=r.invoke(getValues,dict,nullptr,&exc);
  if (exc || !values) return -105;
  void* valuesClass=objectClass(values);
  if (!valuesClass) return -104;
  void* getCount=r.method(valuesClass,"get_Count",0);
  void* copyTo=r.method(valuesClass,"CopyTo",2);
  if (!getCount || !copyTo) return -104;
  exc=nullptr;
  void* boxCount=r.invoke(getCount,values,nullptr,&exc);
  if (exc || !boxCount) return -105;
  int32_t count=*(int32_t*)unbox(boxCount);
  if (count<0 || count>250000) return -107;
  void* idField=r.field(cls,"id");
  void* nameField=r.field(cls,"name");
  if (!idField || !nameField) return -108;
  NSMutableArray *entries=[NSMutableArray arrayWithCapacity:(NSUInteger)count];
  if (count) {
    void* array=arrayNew(cls,(uintptr_t)count);
    if (!array) return -107;
    int32_t zero=0;
    void* params[]={array,&zero}; // object pointer, not pointer-to-pointer
    exc=nullptr;
    r.invoke(copyTo,values,params,&exc);
    if (exc || arrayLength(array)!=(uintptr_t)count) return -107;
    // Target is arm64 Unity IL2CPP managed reference array.
    void* const* elements=(void* const*)((uintptr_t)array+0x20);
    for (int32_t n=0;n<count;n++) {
      void* item=elements[n];
      if (!item) continue;
      int32_t ident=0;
      void* managedName=nullptr;
      r.fieldValue(idField,item,&ident);
      r.fieldValue(nameField,item,&managedName);
      if (ident<=0 || !managedName) continue;
      int32_t length=r.stringLength(managedName);
      if (length<0 || length>4096) continue;
      const uint16_t* chars=r.stringChars(managedName);
      if (length && !chars) continue;
      NSString* name=[[NSString alloc] initWithCharacters:(const unichar*)chars length:(NSUInteger)length];
      if (!name) continue;
      [entries addObject:@{@"id":@(ident),@"name":name}];
    }
  }
  [entries sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
    return [a[@"id"] compare:b[@"id"]];
  }];
  NSData* json=[NSJSONSerialization dataWithJSONObject:entries options:0 error:nil];
  if (!json || json.length>8*1024*1024) return -107;
  NSArray *documents=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
  *saved=false;
  if (documents.count) {
    NSString *directory=[documents[0] stringByAppendingPathComponent:@"XiuxianjiazuGM"];
    NSError *error=nil;
    BOOL directoryOK=[[NSFileManager defaultManager] createDirectoryAtPath:directory
                                           withIntermediateDirectories:YES attributes:nil error:&error];
    NSString *path=[directory stringByAppendingPathComponent:[NSString stringWithUTF8String:fileName]];
    if (directoryOK) *saved=[json writeToFile:path options:NSDataWritingAtomic error:&error];
    if (!*saved) NSLog(@"[XJGM] E109 catalog save failed for %@: %@",path,error);
  } else {
    NSLog(@"[XJGM] E109 documents directory unavailable for %s",category);
  }
  NSMutableData *terminated=[json mutableCopy];
  uint8_t nilByte=0; [terminated appendBytes:&nilByte length:1];
  if (!XJGMSetEntries(category,(const char*)terminated.bytes)) return -107;
  return (int)entries.count;
}
static int prepareExport(Runtime &r,void **image) {
  int status=resolve(r);
  if (status!=1) return status;
  void *domain=r.domain();
  if (!domain) return -205;
  if (!r.current() && !r.attach(domain)) return -210;
  void *assembly=r.assembly(domain,"Assembly-CSharp");
  if (!assembly) assembly=r.assembly(domain,"Assembly-CSharp.dll");
  if (!assembly) return -206;
  *image=r.image(assembly);
  return *image?1:-207;
}
}
extern "C" __attribute__((visibility("default"))) int XJGMExportCatalog(const char* category) {
  if (!category) return -1;
  @autoreleasepool {
    Runtime r={}; void* image=nullptr;
    bool saved=false;
    int result=prepareExport(r,&image);
    if (result==1) {
      if (!strcmp(category,"item")) result=exportTable(r,image,"ItemTmpl","item","items.json",&saved);
      else if (!strcmp(category,"skill")) result=exportTable(r,image,"SkillInfo","skill","skills.json",&saved);
      else return -1;
    }
    // Publish every attempt. UI should not need access to NSLog to see failure.
    NSLog(@"[XJGM] catalog=%s result=%d saved=%d",category,result,saved?1:0);
    XJGMReportExport(category,result,saved?1:0);
    return result;
  }
}
// Compatibility for older hosts. Local name filtering is now done by the UI.
extern "C" __attribute__((visibility("default"))) int XJGMSearchItems(const char* query) {
  return XJGMExportCatalog("item");
}
