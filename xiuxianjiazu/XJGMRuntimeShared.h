#pragma once
// Shared IL2CPP runtime adapter used by GM request and config export.
// Included inside each translation unit's anonymous namespace. No global ABI.
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
