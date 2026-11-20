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
static bool resolve(Runtime& r) {
  memset(&r,0,sizeof(r));
  // UnityFramework is usually loaded through dyld before the menu is opened.
  for (uint32_t i=0;i<_dyld_image_count();++i) {
    const char* name=_dyld_get_image_name(i);
    if (name && strstr(name,"UnityFramework")) {
      r.handle=dlopen(name,RTLD_NOW|RTLD_NOLOAD);
      if (r.handle) break;
    }
  }
  if (!r.handle) return false;
  r.domain=(DomainGet)sym(r.handle,"il2cpp_domain_get");
  r.assembly=(DomainAssemblyOpen)sym(r.handle,"il2cpp_domain_assembly_open");
  r.image=(AssemblyGetImage)sym(r.handle,"il2cpp_assembly_get_image");
  r.fromName=(ClassFromName)sym(r.handle,"il2cpp_class_from_name");
  r.method=(ClassGetMethod)sym(r.handle,"il2cpp_class_get_method_from_name");
  r.invoke=(RuntimeInvoke)sym(r.handle,"il2cpp_runtime_invoke");
  r.field=(ClassGetField)sym(r.handle,"il2cpp_class_get_field_from_name");
  r.fieldValue=(FieldGetValue)sym(r.handle,"il2cpp_field_get_value");
  r.stringLength=(StringLength)sym(r.handle,"il2cpp_string_length");
  r.stringChars=(StringChars)sym(r.handle,"il2cpp_string_chars");
  r.current=(ThreadCurrent)sym(r.handle,"il2cpp_thread_current");
  r.attach=(ThreadAttach)sym(r.handle,"il2cpp_thread_attach");
  return r.domain && r.assembly && r.image && r.fromName && r.method &&
         r.invoke && r.field && r.fieldValue && r.stringLength && r.stringChars &&
         r.current && r.attach;
}
}
// return 1 when an exact ID was found; 0 if absent; -1 when runtime unavailable.
// Must be called from the Unity main thread when the application's IL2CPP runtime is initialized.
extern "C" __attribute__((visibility("default"))) int XJGMQueryItemById(int32_t id) {
  if (id<=0) return 0;
  Runtime r={};
  if (!resolve(r)) return -1;
  void *domain=r.domain();
  if (!domain) return -1;
  if (!r.current()) r.attach(domain);
  void *assembly=r.assembly(domain,"Assembly-CSharp");
  if (!assembly) assembly=r.assembly(domain,"Assembly-CSharp.dll");
  if (!assembly) return -1;
  void *image=r.image(assembly);
  void *cls=r.fromName(image,"config.export.excel","ItemTmpl");
  if (!cls) return -1;
  void *find=r.method(cls,"Find",1);
  if (!find) return -1;
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
  if (!resolve(r)) return 0;
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
  void* setArgs[]={&typeLiteral};
  if (!invoke(r,r.method(cmdCls,"set_typeStr",1),cmd,setArgs)) return 0;
  void* idArgs[]={&id}; void* countArgs[]={&count};
  auto add=r.method(cmdCls,"AddToParams1",1);
  if (!invoke(r,add,cmd,idArgs) || !invoke(r,add,cmd,countArgs)) return 0;
  void* app=nullptr;
  if (!invoke(r,r.method(appCls,"get_Instance",0),nullptr,nullptr,&app) || !app) return 0;
  void* sendArgs[]={&routeLiteral,&cmd};
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
