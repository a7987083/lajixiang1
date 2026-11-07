#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>
#include <stdlib.h>
#include <string.h>

// Diagnostic-only Unity Ads callback monitor. No reward/state spoofing.
typedef NS_ENUM(NSInteger, UACPKind) {
    UACPKindComplete = 1,
    UACPKindStart = 2,
    UACPKindFailed = 3
};

typedef struct {
    Class cls;
    SEL selector;
    IMP original;
    UACPKind kind;
} UACPEntry;

static UACPEntry gEntries[512];
static size_t gEntryCount = 0;
static NSObject *gGuard;

static IMP UACPOriginal(id obj, SEL selector) {
    IMP result = NULL;
    @synchronized (gGuard) {
        for (size_t i = 0; i < gEntryCount; i++) {
            if (gEntries[i].cls == object_getClass(obj) &&
                gEntries[i].selector == selector) {
                result = gEntries[i].original;
                break;
            }
        }
        if (!result) {
            // Allow inherited calls if the runtime uses a subclass instance.
            for (Class cls = class_getSuperclass(object_getClass(obj)); cls; cls = class_getSuperclass(cls)) {
                for (size_t i = 0; i < gEntryCount; i++) {
                    if (gEntries[i].cls == cls && gEntries[i].selector == selector) {
                        result = gEntries[i].original;
                        break;
                    }
                }
                if (result) break;
            }
        }
    }
    return result;
}

static void UACPComplete(id obj, SEL selector, NSString *placement, NSInteger finishState) {
    NSLog(@"[UACP] COMPLETE class=%@ placement=%@ finishState=%ld (unmodified)",
          NSStringFromClass(object_getClass(obj)), placement, (long)finishState);
    IMP imp = UACPOriginal(obj, selector);
    if (imp) ((void (*)(id, SEL, NSString *, NSInteger))imp)(obj, selector, placement, finishState);
}

static void UACPStart(id obj, SEL selector, NSString *placement) {
    NSLog(@"[UACP] START class=%@ placement=%@",
          NSStringFromClass(object_getClass(obj)), placement);
    IMP imp = UACPOriginal(obj, selector);
    if (imp) ((void (*)(id, SEL, NSString *))imp)(obj, selector, placement);
}

static void UACPFailed(id obj, SEL selector, NSString *placement, NSInteger error, NSString *message) {
    NSLog(@"[UACP] FAILED class=%@ placement=%@ error=%ld message=%@",
          NSStringFromClass(object_getClass(obj)), placement, (long)error, message);
    IMP imp = UACPOriginal(obj, selector);
    if (imp) ((void (*)(id, SEL, NSString *, NSInteger, NSString *))imp)(obj, selector, placement, error, message);
}

static BOOL UACPTypesMatch(Method method, UACPKind kind) {
    unsigned int expected = kind == UACPKindFailed ? 5 : (kind == UACPKindStart ? 3 : 4);
    if (method_getNumberOfArguments(method) != expected) return NO;
    char type[64] = {0};
    method_getArgumentType(method, 2, type, sizeof(type));
    if (type[0] != '@') return NO;
    if (kind != UACPKindStart) {
        memset(type, 0, sizeof(type));
        method_getArgumentType(method, 3, type, sizeof(type));
        if (!strchr("cCsSiIlLqQB", type[0])) return NO;
    }
    if (kind == UACPKindFailed) {
        memset(type, 0, sizeof(type));
        method_getArgumentType(method, 4, type, sizeof(type));
        if (type[0] != '@') return NO;
    }
    return YES;
}

static void UACPInstall(Class cls, Method method, UACPKind kind) {
    SEL selector = method_getName(method);
    @synchronized (gGuard) {
        for (size_t i = 0; i < gEntryCount; ++i) {
            if (gEntries[i].cls == cls && gEntries[i].selector == selector) return;
        }
        if (gEntryCount == sizeof(gEntries) / sizeof(gEntries[0])) {
            NSLog(@"[UACP] hook table full");
            return;
        }
        if (!UACPTypesMatch(method, kind)) {
            NSLog(@"[UACP] skip incompatible signature %@ %@ encoding=%s",
                  NSStringFromClass(cls), NSStringFromSelector(selector), method_getTypeEncoding(method));
            return;
        }
        IMP replacement = kind == UACPKindFailed ? (IMP)UACPFailed
                        : kind == UACPKindStart  ? (IMP)UACPStart : (IMP)UACPComplete;
        IMP original = method_getImplementation(method);
        if (original == replacement) return;
        gEntries[gEntryCount++] = (UACPEntry){ cls, selector, original, kind };
        method_setImplementation(method, replacement);
    }
    NSLog(@"[UACP] hooked %@ %@", NSStringFromClass(cls), NSStringFromSelector(selector));
}

static void UACPScan(void) {
    int count = objc_getClassList(NULL, 0);
    if (count <= 0 || count > 100000) return;
    Class *classes = (Class *)calloc((size_t)count, sizeof(Class));
    if (!classes) return;
    count = objc_getClassList(classes, count);
    for (int i = 0; i < count; i++) {
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(classes[i], &methodCount);
        for (unsigned int j = 0; j < methodCount; j++) {
            SEL sel = method_getName(methods[j]);
            const char *name = sel_getName(sel);
            if (strcmp(name, "unityAdsShowComplete:withFinishState:") == 0 ||
                strcmp(name, "unityAdsDidFinish:withFinishState:") == 0) {
                UACPInstall(classes[i], methods[j], UACPKindComplete);
            } else if (strcmp(name, "unityAdsShowStart:") == 0 ||
                       strcmp(name, "unityAdsDidStart:") == 0) {
                UACPInstall(classes[i], methods[j], UACPKindStart);
            } else if (strcmp(name, "unityAdsShowFailed:withError:withMessage:") == 0) {
                UACPInstall(classes[i], methods[j], UACPKindFailed);
            }
        }
        free(methods);
    }
    free(classes);
}

__attribute__((constructor))
static void UACPInit(void) {
    gGuard = [NSObject new];
    NSLog(@"[UACP] callback monitor loaded; rewards and states remain untouched");
    dispatch_async(dispatch_get_main_queue(), ^{
        UACPScan();
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                                        dispatch_get_main_queue());
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
                                  5 * NSEC_PER_SEC, NSEC_PER_SEC);
        dispatch_source_set_event_handler(timer, ^{ UACPScan(); });
        dispatch_resume(timer);
        // Dispatch sources are retained by their event-handling infrastructure.
        (void)timer;
    });
}
