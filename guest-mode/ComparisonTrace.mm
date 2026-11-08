#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <dispatch/dispatch.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

typedef struct I_Domain I_Domain;
typedef struct I_Assembly I_Assembly;
typedef struct I_Image I_Image;
typedef struct I_Class I_Class;
typedef struct I_Type I_Type;
typedef struct I_Object I_Object;
typedef struct I_Method I_Method;
typedef struct I_Field I_Field;
typedef I_Domain* (*domain_get_t)(void);
typedef const I_Assembly** (*assemblies_t)(const I_Domain*,size_t*);
typedef const I_Image* (*assembly_image_t)(const I_Assembly*);
typedef I_Class* (*class_name_t)(const I_Image*,const char*,const char*);
typedef const I_Type* (*class_type_t)(I_Class*);
typedef I_Object* (*type_object_t)(const I_Type*);
typedef const I_Method* (*method_name_t)(I_Class*,const char*,int);
typedef I_Field* (*field_name_t)(I_Class*,const char*);
typedef I_Object* (*invoke_t)(const I_Method*,void*,void**,I_Object**);
typedef void (*field_value_t)(I_Object*,I_Field*,void*);
typedef int32_t (*string_length_t)(const void*);
#define IL(name,T) ((T)dlsym(RTLD_DEFAULT,"il2cpp_" #name))

static NSString *gPhase=@"NORMAL";
static NSString *gLast=@"";
static uint64_t gCounter=0;
static double gStarted=0;

static void CompareWrite(NSString *message) {
    NSString *line=[NSString stringWithFormat:@"%.3f phase=%@ %@\n",
      [[NSDate date] timeIntervalSince1970],gPhase,message];
    NSLog(@"[GuestMode:compare] %@",message);
    NSString *doc=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    if (!doc) return;
    NSString *path=[doc stringByAppendingPathComponent:@"GuestModeCompare.log"];
    NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:path];
    if (!h) { [line writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; return; }
    @try {
        [h seekToEndOfFile];
        [h writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    } @catch(NSException *ex) {
        NSLog(@"[GuestMode:compare] file append exception=%@",ex.name);
    } @finally { [h closeFile]; }
}

static I_Object *FindController(I_Class **outClass) {
    domain_get_t domainGet=IL(domain_get,domain_get_t);
    assemblies_t assemblies=IL(domain_get_assemblies,assemblies_t);
    assembly_image_t imageGet=IL(assembly_get_image,assembly_image_t);
    class_name_t classGet=IL(class_from_name,class_name_t);
    class_type_t classType=IL(class_get_type,class_type_t);
    type_object_t typeObj=IL(type_get_object,type_object_t);
    method_name_t methodGet=IL(class_get_method_from_name,method_name_t);
    invoke_t invoke=IL(runtime_invoke,invoke_t);
    if (!domainGet || !assemblies || !imageGet || !classGet || !classType || !typeObj || !methodGet || !invoke)
        return NULL;
    I_Domain *domain=domainGet();
    size_t count=0;
    const I_Assembly **items=domain ? assemblies(domain,&count):NULL;
    I_Class *ctrl=NULL,*obj=NULL;
    for (size_t i=0; items && i<count; i++) {
        const I_Image *im=imageGet(items[i]);
        if (!im) continue;
        if (!ctrl) ctrl=classGet(im,"CRArcadeDemo","Controller");
        if (!obj) obj=classGet(im,"UnityEngine","Object");
        if (ctrl && obj) break;
    }
    if (!ctrl || !obj) return NULL;
    if (outClass) *outClass=ctrl;
    I_Object *type=typeObj(classType(ctrl));
    if (!type) return NULL;
    const I_Method *find=methodGet(obj,"FindObjectOfType",2);
    I_Object *exc=NULL;
    I_Object *found=NULL;
    if (find) {
        uint8_t includeInactive=1;
        void *args[]={type,&includeInactive};
        found=invoke(find,NULL,args,&exc);
    }
    if (exc || !found) {
        find=methodGet(obj,"FindObjectOfType",1);
        if (!find) return NULL;
        void *args[]={type};
        exc=NULL;
        found=invoke(find,NULL,args,&exc);
    }
    if (exc) return NULL;
    return found;
}

static void Snapshot(void) {
    I_Class *klass=NULL;
    I_Object *controller=FindController(&klass);
    NSString *snapshot=@"controller=absent";
    field_name_t field=IL(class_get_field_from_name,field_name_t);
    field_value_t get=IL(field_get_value,field_value_t);
    string_length_t length=IL(string_length,string_length_t);
    if (controller && klass && field && get && length) {
        I_Field *tier=field(klass,"subscriptionTier");
        I_Field *source=field(klass,"sourceId");
        I_Field *view=field(klass,"currentView");
        I_Field *token=field(klass,"anonymousToken");
        int32_t tv=INT32_MIN,sv=INT32_MIN;
        I_Object *vv=NULL,*tok=NULL;
        if(tier) get(controller,tier,&tv);
        if(source) get(controller,source,&sv);
        if(view) get(controller,view,&vv);
        if(token) get(controller,token,&tok);
        int tokenLen=tok ? length(tok):0;
        // Only metadata, never the token or account identifiers.
        snapshot=[NSString stringWithFormat:@"controller=present tier=%d source=%d view=%p token_present=%d token_len=%d",
          tv,sv,vv,tokenLen>0,tokenLen];
    }
    if (![snapshot isEqualToString:gLast] || (gCounter%10)==0) {
        CompareWrite(snapshot);
        gLast=snapshot;
    }
    gCounter++;
}
static void Tick(void) {
    Snapshot();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),
                   dispatch_get_main_queue(),^{Tick();});
}
__attribute__((constructor)) static void GuestCompareInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        gStarted=[[NSDate date] timeIntervalSince1970];
        CompareWrite([NSString stringWithFormat:@"PROCESS_START pid=%d trace_id=%.3f",getpid(),gStarted]);
        NSNotificationCenter *c=[NSNotificationCenter defaultCenter];
        [c addObserverForName:@"GMGuestStarted" object:nil queue:[NSOperationQueue mainQueue]
                  usingBlock:^(NSNotification *note) {
            gPhase=@"GUEST";
            gLast=@"";
            CompareWrite(@"MARKER guest button invoked");
        }];
        [c addObserverForName:UIApplicationWillResignActiveNotification object:nil
                      queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            CompareWrite(@"UIApplicationWillResignActive");
        }];
        [c addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil
                      queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            CompareWrite(@"UIApplicationDidEnterBackground");
        }];
        [c addObserverForName:UIApplicationWillEnterForegroundNotification object:nil
                      queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            CompareWrite(@"UIApplicationWillEnterForeground");
        }];
        [c addObserverForName:UIApplicationDidBecomeActiveNotification object:nil
                      queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            CompareWrite(@"UIApplicationDidBecomeActive");
            gLast=@"";
        }];
        Tick();
    });
}
