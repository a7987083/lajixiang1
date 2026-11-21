#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <string.h>
#include <math.h>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>

namespace {
#include "XJGMRuntimeShared.h"

// Only call the original game's Color return helper. No guessed quality palette.
// RuntimeInvoke boxes UnityEngine.Color, a four-float value type (RGBA).
static void* resolveConstants(Runtime &r,void* domain) {
    using Assemblies=const void** (*)(void*,size_t*);
    auto fn=(Assemblies)sym(r.handle,"il2cpp_domain_get_assemblies");
    if(!fn)return nullptr;
    size_t count=0;const void** all=fn(domain,&count);
    if(!all||count==0||count>512)return nullptr;
    void* cls=nullptr;
    for(size_t n=0;n<count;n++){
        if(!all[n])continue;
        void* image=r.image((void*)all[n]);
        if(!image)continue;
        void* candidate=r.fromName(image,"","Constants");
        if(!candidate||!r.method(candidate,"GetItemQualityColor",1))continue;
        if(cls&&cls!=candidate)return nullptr; // ambiguous name
        cls=candidate;
    }
    return cls;
}
static bool findItemQuality(Runtime &r,void* domain,int32_t itemId,int32_t* quality) {
    if(itemId<=0||!quality)return false;
    void* image=managedImage(r,domain,"gameConfigs.dll");
    if(!image)return false;
    void* itemCls=r.fromName(image,"config.export.excel","ItemTmpl");
    if(!itemCls)return false;
    void* find=r.method(itemCls,"Find",1);
    void* qfield=r.field(itemCls,"colorLv");
    if(!find||!qfield)return false;
    void* exception=nullptr;void* args[]={&itemId};
    void* item=r.invoke(find,nullptr,args,&exception);
    if(exception||!item)return false;
    int32_t level=-1;
    r.fieldValue(item,qfield,&level);
    if(level<0||level>30)return false;
    *quality=level;return true;
}
static UIColor* nativeColor(Runtime &r,void* domain,int32_t quality) {
    // The original ARM64 implementation (UnityFramework RVA 0x1AAD8EC)
    // selects the last palette entry when quality exceeds the palette length.
    // Do not impose an invented 30-level upper bound here.
    if(quality<0)return nil;
    void* cls=resolveConstants(r,domain);
    if(!cls)return nil;
    void* method=r.method(cls,"GetItemQualityColor",1);
    auto unbox=(void*(*)(void*))sym(r.handle,"il2cpp_object_unbox");
    if(!method||!unbox)return nil;
    void* args[]={&quality};void* exception=nullptr;
    void* boxed=r.invoke(method,nullptr,args,&exception);
    if(exception||!boxed)return nil;
    float* components=(float*)unbox(boxed);
    if(!components)return nil;
    for(int n=0;n<4;n++)
        if(!isfinite(components[n])||components[n]<0.f||components[n]>1.f)return nil;
    // UI text is legible on our opaque panel regardless of Unity alpha.
    return [UIColor colorWithRed:components[0] green:components[1]
                          blue:components[2] alpha:1.0];
}
}

// kind=0 item, kind=1 skill, kind=2 blood.
// Returns nil for an unknown quality; the menu uses its current Ink() color.
extern "C" __attribute__((visibility("default"))) UIColor* XJGMNativeQualityColor(
    int32_t kind,int32_t id,int32_t quality) {
    @autoreleasepool {
        if(kind<0||kind>2)return nil;
        if(kind==0&&id<=0)return nil;
        if(kind!=0&&quality<0)return nil;
        // Called on the menu's main thread. Keep only successful lookups cached.
        static NSMutableDictionary<NSString*,UIColor*> *cache=nil;
        if(!cache)cache=[NSMutableDictionary dictionary];
        NSString *key=[NSString stringWithFormat:@"%d:%d:%d",kind,id,quality];
        UIColor *cached=cache[key];if(cached)return cached;
        Runtime r={};
        if(resolve(r)!=1)return nil;
        void* domain=r.domain();
        if(!domain||(!r.current()&&!r.attach(domain)))return nil;
        int32_t resolvedQuality=quality;
        if(kind==0&&!findItemQuality(r,domain,id,&resolvedQuality))return nil;
        UIColor *color=nativeColor(r,domain,resolvedQuality);
        if(color)cache[key]=color;
        // BloodTmpl.quality does not necessarily share ItemTmpl.colorLv
        // semantics. Keep a one-time diagnostic per blood ID to distinguish
        // native API failure from a valid but visually unsuitable mapping.
        if(kind==2){
            static NSMutableSet<NSString*>* reported=nil;
            if(!reported)reported=[NSMutableSet set];
            if(![reported containsObject:key]){
                [reported addObject:key];
                CGFloat red=0,green=0,blue=0,alpha=0;
                BOOL rgb=color&&[color getRed:&red green:&green blue:&blue alpha:&alpha];
                NSLog(@"[XJGMQuality] blood id=%d quality=%d native=%@ rgba=(%.3f,%.3f,%.3f,%.3f)",
                    id,quality,rgb?@"OK":@"UNAVAILABLE",red,green,blue,alpha);
            }
        }
        return color;
    }
}
