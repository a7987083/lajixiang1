#include <stdint.h>
#include <string.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#import <Foundation/Foundation.h>

// Native-only search. No fabricated MonoBehaviour or prefab.
// Requires an existing, initialized GMItemBlock belonging to the real game.
extern "C" __attribute__((visibility("default"))) int XJGMNativeItemSearch(const char *utf8) {
  if (!utf8) return -300;
  @autoreleasepool {
    NSString *query=[NSString stringWithUTF8String:utf8];
    if (!query || query.length>256) return -301;
    const char *imagePath=nullptr;
    for (uint32_t i=0;i<_dyld_image_count();++i) {
      const char *path=_dyld_get_image_name(i);
      if (path && [[NSString stringWithUTF8String:path].lastPathComponent isEqualToString:@"UnityFramework"]) {
        imagePath=path; break;
      }
    }
    if (!imagePath) return -302;
    void *h=dlopen(imagePath,RTLD_NOW|RTLD_NOLOAD);
    if (!h) return -302;
#define API(NAME,TYPE) TYPE NAME=(TYPE)dlsym(h,"il2cpp_" #NAME)
    API(domain_get,void*(*)());
    API(domain_assembly_open,void*(*)(void*,const char*));
    API(assembly_get_image,void*(*)(void*));
    API(class_from_name,void*(*)(void*,const char*,const char*));
    API(class_get_type,void*(*)(void*));
    API(type_get_object,void*(*)(void*));
    API(class_get_method_from_name,void*(*)(void*,const char*,int));
    API(class_get_field_from_name,void*(*)(void*,const char*));
    API(field_get_value,void(*)(void*,void*,void*));
    API(runtime_invoke,void*(*)(void*,void*,void**,void**));
    API(string_new_utf16,void*(*)(const uint16_t*,int32_t));
    API(array_length,uintptr_t(*)(void*));
    API(thread_current,void*(*)());
    API(thread_attach,void*(*)(void*));
#undef API
    if (!domain_get||!domain_assembly_open||!assembly_get_image||!class_from_name||
        !class_get_type||!type_get_object||!class_get_method_from_name||
        !class_get_field_from_name||!field_get_value||!runtime_invoke||
        !string_new_utf16||!array_length||!thread_current||!thread_attach) return -303;
    void *domain=domain_get();
    if (!domain) return -304;
    if (!thread_current() && !thread_attach(domain)) return -304;
    void *gameAsm=domain_assembly_open(domain,"gameCore.dll");
    void *unityAsm=domain_assembly_open(domain,"UnityEngine.CoreModule.dll");
    void *tmpAsm=domain_assembly_open(domain,"Unity.TextMeshPro.dll");
    if (!gameAsm||!unityAsm||!tmpAsm) return -305;
    void *gameImage=assembly_get_image(gameAsm), *unityImage=assembly_get_image(unityAsm), *tmpImage=assembly_get_image(tmpAsm);
    if (!gameImage||!unityImage||!tmpImage) return -305;
    void *gmClass=class_from_name(gameImage,"","GMItemBlock");
    void *objectClass=class_from_name(unityImage,"UnityEngine","Object");
    void *inputClass=class_from_name(tmpImage,"TMPro","TMP_InputField");
    if (!gmClass||!objectClass||!inputClass) return -306;
    void *find=class_get_method_from_name(objectClass,"FindObjectsOfType",2);
    void *onSearch=class_get_method_from_name(gmClass,"OnClickBtnSearch",0);
    void *setText=class_get_method_from_name(inputClass,"SetTextWithoutNotify",1);
    if (!find||!onSearch||!setText) return -307;
    void *systemType=type_get_object(class_get_type(gmClass));
    if (!systemType) return -307;
    uint8_t includeInactive=0;
    void *findArgs[]={systemType,&includeInactive};
    void *exception=nullptr;
    void *array=runtime_invoke(find,nullptr,findArgs,&exception);
    if (exception||!array) return -308;
    uintptr_t n=array_length(array);
    if (n==0) return -309; // The native GM view has not been instantiated.
    if (n>32) return -310;
    void *inputField=class_get_field_from_name(gmClass,"inputSearch");
    void *gridField=class_get_field_from_name(gmClass,"itemView");
    void *listField=class_get_field_from_name(gmClass,"list");
    if (!inputField||!gridField||!listField) return -311;
    // IL2CPP arm64 reference array header: 0x20. This is target-specific.
    void **elements=(void**)((uintptr_t)array+0x20);
    void *instance=nullptr,*input=nullptr;
    uint32_t validCount=0;
    for (uintptr_t i=0;i<n;i++) {
      void *candidate=elements[i];
      if (!candidate) continue;
      void *cInput=nullptr,*cGrid=nullptr,*cList=nullptr;
      field_get_value(inputField,candidate,&cInput);
      field_get_value(gridField,candidate,&cGrid);
      field_get_value(listField,candidate,&cList);
      if (!cInput||!cGrid||!cList) continue;
      validCount++;instance=candidate;input=cInput;
    }
    if (!validCount) return -312;
    if (validCount!=1) return -313;
    NSData *utf16=[query dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    if (!utf16 || utf16.length/2 > INT32_MAX) return -314;
    void *managedQuery=string_new_utf16((const uint16_t*)utf16.bytes,(int32_t)(utf16.length/2));
    if (!managedQuery) return -314;
    void *textArgs[]={managedQuery};
    exception=nullptr;
    runtime_invoke(setText,input,textArgs,&exception);
    if (exception) return -315;
    exception=nullptr;
    runtime_invoke(onSearch,instance,nullptr,&exception);
    return exception ? -316 : 1;
  }
}
