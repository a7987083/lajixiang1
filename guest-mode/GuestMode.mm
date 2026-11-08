#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dlfcn.h>
#import <dispatch/dispatch.h>
#include <string.h>
#include <stdint.h>

// Target exact original UnityFramework, never the prior incorrectly-patched binary.
static const uint8_t kTargetUUID[16] = {
    0x01,0x61,0x4a,0x27,0xfe,0x69,0x36,0x02,
    0xa3,0xfe,0xc1,0x4d,0xba,0x2b,0xfc,0xb3
};

typedef struct Il2CppDomain Il2CppDomain;
typedef struct Il2CppAssembly Il2CppAssembly;
typedef struct Il2CppImage Il2CppImage;
typedef struct Il2CppClass Il2CppClass;
typedef struct Il2CppType Il2CppType;
typedef struct Il2CppObject Il2CppObject;
typedef struct Il2CppString Il2CppString;
typedef struct MethodInfo MethodInfo;
typedef struct FieldInfo FieldInfo;
typedef Il2CppDomain* (*DomainGetFn)(void);
typedef const Il2CppAssembly** (*AssembliesFn)(const Il2CppDomain*, size_t*);
typedef const Il2CppImage* (*ImageFn)(const Il2CppAssembly*);
typedef Il2CppClass* (*ClassFn)(const Il2CppImage*, const char*, const char*);
typedef const MethodInfo* (*MethodFn)(Il2CppClass*, const char*, int);
typedef FieldInfo* (*FieldFn)(Il2CppClass*, const char*);
typedef const Il2CppType* (*ClassTypeFn)(Il2CppClass*);
typedef Il2CppObject* (*TypeObjectFn)(const Il2CppType*);
typedef Il2CppObject* (*InvokeFn)(const MethodInfo*, void*, void**, Il2CppObject**);
typedef void (*FieldValueFn)(Il2CppObject*, FieldInfo*, void*);
typedef int32_t (*StringLengthFn)(const Il2CppString*);

static const struct mach_header *ExactImage(void) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *n = _dyld_get_image_name(i);
        if (!n || !strstr(n, "UnityFramework.framework/UnityFramework")) continue;
        const struct mach_header_64 *mh = (const struct mach_header_64*)_dyld_get_image_header(i);
        if (!mh || mh->magic != MH_MAGIC_64) return NULL;
        const uint8_t *cur = (const uint8_t*)(mh+1);
        for (uint32_t j=0; j<mh->ncmds; j++) {
            const struct load_command *cmd=(const struct load_command*)cur;
            if (cmd->cmdsize < sizeof(*cmd)) break;
            if (cmd->cmd == LC_UUID && cmd->cmdsize >= sizeof(struct uuid_command)) {
                if (!memcmp(((const struct uuid_command*)cmd)->uuid,kTargetUUID,16)) return (const struct mach_header*)mh;
                return NULL;
            }
            cur += cmd->cmdsize;
        }
    }
    return NULL;
}

#define RESOLVE(name, type) ((type)dlsym(RTLD_DEFAULT, "il2cpp_" #name))
@interface GMGuestSession : NSObject
@property(nonatomic,strong) UIButton *button;
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,assign) Il2CppObject *controller;
@property(nonatomic,assign) FieldInfo *tokenField;
@property(nonatomic,assign) BOOL busy;
@property(nonatomic,assign) NSUInteger generation;
+ (instancetype)shared;
- (void)install;
- (void)start:(id)sender;
@end

@implementation GMGuestSession
+ (instancetype)shared {
    static GMGuestSession *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s=[GMGuestSession new]; });
    return s;
}
- (void)notify:(NSString*)title message:(NSString*)message {
    UIViewController *vc=self.window.rootViewController;
    while (vc.presentedViewController) vc=vc.presentedViewController;
    if (!vc) { NSLog(@"[GuestMode:v2] %@: %@",title,message); return; }
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [vc presentViewController:alert animated:YES completion:nil];
}
- (void)finish:(NSString*)message {
    self.busy=NO;
    self.button.enabled=YES;
    [self.button setTitle:@"GUEST · TEST" forState:UIControlStateNormal];
    [self notify:@"Guest Session" message:message];
}
- (void)poll:(NSUInteger)remaining generation:(NSUInteger)gen {
    if (!self.busy || self.generation != gen) return;
    FieldValueFn fieldValue=RESOLVE(field_get_value,FieldValueFn);
    StringLengthFn strLength=RESOLVE(string_length,StringLengthFn);
    if (!fieldValue || !strLength || !self.controller || !self.tokenField) {
        [self finish:@"IL2CPP session observation unavailable."];
        return;
    }
    Il2CppString *token=NULL;
    fieldValue(self.controller,self.tokenField,&token);
    if (token && strLength(token)>0) {
        NSLog(@"[GuestMode:v2] anonymous token populated; length=%d (content redacted)",strLength(token));
        [self finish:@"Anonymous session token is populated. No membership entitlement has been assumed; game scene transition remains disabled pending lifecycle verification."];
        return;
    }
    if (remaining==0) {
        NSLog(@"[GuestMode:v2] anonymous token timeout; not entering game");
        [self finish:@"Anonymous token was not populated within 12 seconds. Check app logs / network response. No game transition was attempted."];
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{
        [self poll:remaining-1 generation:gen];
    });
}
- (void)start:(id)sender {
    if (self.busy || !ExactImage()) return;
    DomainGetFn domainGet=RESOLVE(domain_get,DomainGetFn);
    AssembliesFn assemblies=RESOLVE(domain_get_assemblies,AssembliesFn);
    ImageFn imageGet=RESOLVE(assembly_get_image,ImageFn);
    ClassFn classGet=RESOLVE(class_from_name,ClassFn);
    MethodFn methodGet=RESOLVE(class_get_method_from_name,MethodFn);
    FieldFn fieldGet=RESOLVE(class_get_field_from_name,FieldFn);
    ClassTypeFn classType=RESOLVE(class_get_type,ClassTypeFn);
    TypeObjectFn typeObject=RESOLVE(type_get_object,TypeObjectFn);
    InvokeFn invoke=RESOLVE(runtime_invoke,InvokeFn);
    if (!domainGet || !assemblies || !imageGet || !classGet || !methodGet ||
        !fieldGet || !classType || !typeObject || !invoke) {
        [self notify:@"Guest Mode" message:@"Required IL2CPP API is unavailable; no method was called."];
        return;
    }
    Il2CppDomain *domain=domainGet();
    size_t count=0;
    const Il2CppAssembly **items=domain ? assemblies(domain,&count):NULL;
    Il2CppClass *controllerClass=NULL;
    Il2CppClass *unityObjectClass=NULL;
    for (size_t i=0; items && i<count; i++) {
        const Il2CppImage *image=imageGet(items[i]);
        if (!image) continue;
        if (!controllerClass) controllerClass=classGet(image,"CRArcadeDemo","Controller");
        if (!unityObjectClass) unityObjectClass=classGet(image,"UnityEngine","Object");
        if (controllerClass && unityObjectClass) break;
    }
    if (!controllerClass || !unityObjectClass) {
        [self notify:@"Guest Mode" message:@"Controller / UnityEngine.Object not found in loaded assemblies."];
        return;
    }
    const MethodInfo *find=methodGet(unityObjectClass,"FindObjectOfType",1);
    const MethodInfo *fetch=methodGet(controllerClass,"FetchAnonymousToken",0);
    FieldInfo *tokenField=fieldGet(controllerClass,"anonymousToken");
    if (!find || !fetch || !tokenField) {
        [self notify:@"Guest Mode" message:@"Required IL2CPP methods / field are missing; no request started."];
        return;
    }
    Il2CppObject *reflectionType=typeObject(classType(controllerClass));
    void *args[]={&reflectionType};
    Il2CppObject *exc=NULL;
    Il2CppObject *instance=invoke(find,NULL,args,&exc);
    if (exc || !instance) {
        NSLog(@"[GuestMode:v2] FindObjectOfType failed exception=%p object=%p",exc,instance);
        [self notify:@"Guest Mode" message:@"Live Controller instance not available; request aborted."];
        return;
    }
    self.controller=instance;
    self.tokenField=tokenField;
    self.busy=YES;
    self.generation++;
    self.button.enabled=NO;
    [self.button setTitle:@"GUEST · CHECKING" forState:UIControlStateNormal];
    NSLog(@"[GuestMode:v2] Controller=%p; invoking anonymous request; no scene override",instance);
    exc=NULL;
    invoke(fetch,instance,NULL,&exc);
    if (exc) {
        NSLog(@"[GuestMode:v2] FetchAnonymousToken exception=%p",exc);
        [self finish:@"FetchAnonymousToken raised a managed exception; game entry not attempted."];
        return;
    }
    [self poll:12 generation:self.generation];
}
- (void)install {
    if (!ExactImage() || self.button.superview) return;
    UIWindow *window=nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *w in ((UIWindowScene*)scene).windows) if (w.isKeyWindow) { window=w; break; }
        if (window) break;
    }
    if (!window) window=UIApplication.sharedApplication.keyWindow;
    if (!window) return;
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    button.frame=CGRectMake(16,MAX(80,window.bounds.size.height-126),160,42);
    button.autoresizingMask=UIViewAutoresizingFlexibleTopMargin|UIViewAutoresizingFlexibleRightMargin;
    button.backgroundColor=[UIColor colorWithRed:0.10 green:0.12 blue:0.16 alpha:0.92];
    button.layer.cornerRadius=9;
    button.layer.borderWidth=1;
    button.layer.borderColor=[UIColor colorWithRed:0.96 green:0.59 blue:0.22 alpha:1].CGColor;
    [button setTitle:@"GUEST · TEST" forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font=[UIFont boldSystemFontOfSize:13];
    [button addTarget:self action:@selector(start:) forControlEvents:UIControlEventTouchUpInside];
    [window addSubview:button];
    self.button=button;
    self.window=window;
    NSLog(@"[GuestMode:v2] exact target verified, button installed");
}
@end

__attribute__((constructor)) static void GuestModeInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GMGuestSession shared] install];
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            [[GMGuestSession shared] install];
        }];
    });
}
