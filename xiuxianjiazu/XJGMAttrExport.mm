#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h>
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
// Persist the last reached step *before* potentially unsafe managed runtime calls.
// If iOS terminates the process without a crash report, this file survives relaunch.
static void checkpoint(const char *step) {
  NSArray *dirs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
  if (!dirs.count) return;
  NSString *dir=[dirs[0] stringByAppendingPathComponent:@"XiuxianjiazuGM"];
  [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  NSString *file=[dir stringByAppendingPathComponent:@"export-stage.txt"];
  NSString *value=[NSString stringWithFormat:@"P2.2.1 stage=%s",step];
  [value writeToFile:file atomically:YES encoding:NSUTF8StringEncoding error:nil];
  NSLog(@"[XJGMExport] %@",value);
}


static void* findPercentMethodAcrossAssemblies(Runtime &r,void* domain) {
  using Assemblies=const void** (*)(void*,size_t*);
  auto enumerate=(Assemblies)sym(r.handle,"il2cpp_domain_get_assemblies");
  if(!enumerate || !domain)return nullptr;
  size_t count=0;
  const void** assemblies=enumerate(domain,&count);
  if(!assemblies || count==0 || count>512)return nullptr;
  void* matched=nullptr;
  for(size_t i=0;i<count;i++) {
    if(!assemblies[i])continue;
    void* image=r.image((void*)assemblies[i]);
    if(!image)continue;
    void* cls=r.fromName(image,"","AttrHelper");
    if(!cls)continue;
    void* method=r.method(cls,"IsPercentageAttType",1);
    if(!method)continue;
    // Resolve exactly once; ambiguous type matches are unsafe.
    if(matched && method!=matched)return nullptr;
    matched=method;
  }
  return matched;
}
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
  checkpoint("config_field");
  void* f=r.field(cls,"configs");
  if (!f) return -108;
  void* dict=nullptr;
  checkpoint("static_get");
  staticGet(f,&dict);
  // Empty/uninitialized config is a recoverable state; no managed accessor required.
  if (!dict) return -102;
  checkpoint("dictionary_class");
  void* dictClass=objectClass(dict);
  if (!dictClass) return -104;
  checkpoint("get_values_method");
  void* getValues=r.method(dictClass,"get_Values",0);
  if (!getValues) return -104;
  void* exc=nullptr;
  checkpoint("invoke_get_values");
  void* values=r.invoke(getValues,dict,nullptr,&exc);
  if (exc || !values) return -105;
  checkpoint("values_class");
  void* valuesClass=objectClass(values);
  if (!valuesClass) return -104;
  void* getCount=r.method(valuesClass,"get_Count",0);
  void* copyTo=r.method(valuesClass,"CopyTo",2);
  if (!getCount || !copyTo) return -104;
  exc=nullptr;
  checkpoint("invoke_count");
  void* boxCount=r.invoke(getCount,values,nullptr,&exc);
  if (exc || !boxCount) return -105;
  int32_t count=*(int32_t*)unbox(boxCount);
  if (count<0 || count>1000) return -107;
  void* idField=r.field(cls,"id");
  void* nameField=r.field(cls,"name");
  void* valueTypeField=r.field(cls,"valueType");
  void* scoreField=r.field(cls,"score");
  void* standardValueField=r.field(cls,"standardValue");
  void* descFmtField=r.field(cls,"descFmt");
  if(!idField||!nameField||!valueTypeField||!scoreField||!standardValueField||!descFmtField)return -108;
  // Use the game's actual formatting classification rather than the config's
  // valueType: the two differ for several real attributes (8/53/30/31).
  checkpoint("percent_lookup_all_assemblies");
  void *isPercent=findPercentMethodAcrossAssemblies(r,r.domain());
  if(!isPercent)return -114;
  NSMutableArray *entries=[NSMutableArray arrayWithCapacity:(NSUInteger)count];
  if (count) {
    checkpoint("array_new");
    void* array=arrayNew(cls,(uintptr_t)count);
    if (!array) return -107;
    int32_t zero=0;
    void* params[]={array,&zero}; // object pointer, not pointer-to-pointer
    exc=nullptr;
    checkpoint("invoke_copy_to");
    r.invoke(copyTo,values,params,&exc);
    if (exc || arrayLength(array)!=(uintptr_t)count) return -107;
    // Do not dereference the array header or assume its element offset.
    // Use the managed System.Array.GetValue(Int32) API to retrieve a GC-managed object.
    auto getCorlib=(void* (*)())sym(r.handle,"il2cpp_get_corlib");
    auto classMethods=(void* (*)(void*,void**))sym(r.handle,"il2cpp_class_get_methods");
    auto methodName=(const char* (*)(void*))sym(r.handle,"il2cpp_method_get_name");
    auto methodCount=(uint32_t (*)(void*))sym(r.handle,"il2cpp_method_get_param_count");
    auto methodParam=(void* (*)(void*,uint32_t))sym(r.handle,"il2cpp_method_get_param");
    auto typeKind=(int (*)(void*))sym(r.handle,"il2cpp_type_get_type");
    auto assignable=(bool (*)(void*,void*))sym(r.handle,"il2cpp_class_is_assignable_from");
    if (!getCorlib || !classMethods || !methodName || !methodCount ||
        !methodParam || !typeKind || !assignable) return -110;
    void* corlib=getCorlib();
    if (!corlib) return -110;
    void* systemArray=r.fromName(corlib,"System","Array");
    if (!systemArray) return -110;
    void* getValue=nullptr;
    void* iterator=nullptr;
    // There are GetValue(Int32) and GetValue(Int64) overloads.
    // Inspect the signature; never select by name and arity alone.
    while (void* m=classMethods(systemArray,&iterator)) {
      const char* name=methodName(m);
      if (!name || strcmp(name,"GetValue")!=0 || methodCount(m)!=1) continue;
      void* type=methodParam(m,0);
      if (type && typeKind(type)==0x08) { getValue=m; break; } // IL2CPP_TYPE_I4
    }
    if (!getValue) return -110;
    checkpoint("managed_array_getvalue");
    for (int32_t n=0;n<count;n++) {
      if (n<8 || n%64==0) {
        char stage[64]; snprintf(stage,sizeof(stage),"element_%d_getvalue",n);
        checkpoint(stage);
      }
      int32_t index=n;
      void* getArgs[]={&index};
      exc=nullptr;
      void* item=r.invoke(getValue,array,getArgs,&exc);
      if (exc) return -111;
      if (!item) continue;
      if (n<8 || n%64==0) {
        char stage[64]; snprintf(stage,sizeof(stage),"element_%d_verifyclass",n);
        checkpoint(stage);
      }
      void* actualClass=objectClass(item);
      if (!actualClass || !assignable(cls,actualClass)) return -112;
      int32_t ident=0,valueType=0,score=0,standardValue=0;
      void* managedName=nullptr;
      void* managedDesc=nullptr;
      if (n<8 || n%64==0) {
        char stage[64]; snprintf(stage,sizeof(stage),"element_%d_readfields",n);
        checkpoint(stage);
      }
      r.fieldValue(item,idField,&ident);
      r.fieldValue(item,nameField,&managedName);
      // Read all scalar fields through the same proven IL2CPP field API.
      r.fieldValue(item,valueTypeField,&valueType);
      r.fieldValue(item,scoreField,&score);
      r.fieldValue(item,standardValueField,&standardValue);
      r.fieldValue(item,descFmtField,&managedDesc);
      if (ident<0 || !managedName) continue;
      if (n<8 || n%64==0) {
        char stage[64]; snprintf(stage,sizeof(stage),"element_%d_readname",n);
        checkpoint(stage);
      }
      int32_t length=r.stringLength(managedName);
      if (length<0 || length>4096) continue;
      const uint16_t* chars=r.stringChars(managedName);
      if (length && !chars) continue;
      NSString* name=[[NSString alloc] initWithCharacters:(const unichar*)chars length:(NSUInteger)length];
      if (!name) continue;
      NSString *desc=@"";
      if(managedDesc) {
        int32_t len=r.stringLength(managedDesc);
        if(len<0||len>4096)return -113;
        const uint16_t* chars=r.stringChars(managedDesc);
        if(len&&!chars)return -113;
        desc=[[NSString alloc] initWithCharacters:(const unichar*)chars length:(NSUInteger)len]?:@"";
      }
      int32_t attributeId=ident;void *checkArgs[]={&attributeId};
      void *exception=nullptr;
      void *isPercentBox=r.invoke(isPercent,nullptr,checkArgs,&exception);
      if(exception||!isPercentBox)return -115;
      void *percentRaw=unbox(isPercentBox);if(!percentRaw)return -115;
      bool percentage=*(uint8_t*)percentRaw!=0;
      [entries addObject:@{@"id":@(ident),@"name":name,@"valueType":@(valueType),
          @"isPercentage":@(percentage),@"score":@(score),
          @"standardValue":@(standardValue),@"descFmt":desc}];
    }
  }
  [entries sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
    return [a[@"id"] compare:b[@"id"]];
  }];
  checkpoint("json_encode");
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
    checkpoint("json_save");
    if (directoryOK) *saved=[json writeToFile:path options:NSDataWritingAtomic error:&error];
    if (!*saved) NSLog(@"[XJGM] E109 catalog save failed for %@: %@",path,error);
  } else {
    NSLog(@"[XJGM] E109 documents directory unavailable for %s",category);
  }
  if (!*saved) return -109;
  checkpoint("success");
  return (int)entries.count;
}
static int prepareExport(Runtime &r,void **image) {
  checkpoint("resolve_runtime");
  int status=resolve(r);
  if (status!=1) return status;
  void *domain=r.domain();
  if (!domain) return -205;
  if (!r.current() && !r.attach(domain)) return -210;
  checkpoint("resolve_config_image");
  *image=managedImage(r,domain,"gameConfigs.dll");
  return *image?1:-206;
}
}
extern "C" __attribute__((visibility("default"))) int XJGMExportAttributes(void) {
  @autoreleasepool {
    Runtime r={};void* image=nullptr;bool saved=false;
    checkpoint("attr_start");
    int status=prepareExport(r,&image);
    int result=status==1?exportTable(r,image,"UnitAttrTmpl","attr","attributes.json",&saved):status;
    NSLog(@"[XJGM] attribute catalog result=%d saved=%d",result,saved?1:0);
    return result>=0&&!saved?-109:result;
  }
}
