#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dispatch/dispatch.h>
#include <string.h>
#include <stdint.h>

// Exact supplied UnityFramework build only. Reject other versions.
static const uint8_t kTargetUUID[16] = {
    0x01,0x61,0x4a,0x27,0xfe,0x69,0x36,0x02,
    0xa3,0xfe,0xc1,0x4d,0xba,0x2b,0xfc,0xb3
};
static const uintptr_t kFetchAnonymousRVA = 0x213E514;
static const uintptr_t kProceedToGameRVA = 0x21386EC;
static BOOL gLogged = NO;

static BOOL HeaderMatches(const struct mach_header *header) {
    if (!header || header->magic != MH_MAGIC_64) return NO;
    const struct mach_header_64 *mh = (const struct mach_header_64 *)header;
    const uint8_t *cursor = (const uint8_t *)(mh + 1);
    for (uint32_t i = 0; i < mh->ncmds; ++i) {
        const struct load_command *lc = (const struct load_command *)cursor;
        if (lc->cmdsize < sizeof(struct load_command)) return NO;
        if (lc->cmd == LC_UUID && lc->cmdsize >= sizeof(struct uuid_command)) {
            return memcmp(((const struct uuid_command *)cursor)->uuid, kTargetUUID, 16) == 0;
        }
        cursor += lc->cmdsize;
    }
    return NO;
}

static const struct mach_header *FindTarget(void) {
    for (uint32_t i = 0; i < _dyld_image_count(); ++i) {
        const char *name = _dyld_get_image_name(i);
        if (!name || !strstr(name, "UnityFramework.framework/UnityFramework")) continue;
        const struct mach_header *mh = _dyld_get_image_header(i);
        if (HeaderMatches(mh)) return mh;
    }
    return NULL;
}

@interface GMGuestProbe : NSObject
@property (nonatomic, retain) UIButton *button;
@property (nonatomic, retain) UIWindow *hostWindow;
+ (instancetype)shared;
- (void)install;
- (void)pressed:(id)sender;
@end

@implementation GMGuestProbe
+ (instancetype)shared {
    static GMGuestProbe *probe;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ probe = [GMGuestProbe new]; });
    return probe;
}
- (void)pressed:(id)sender {
    const struct mach_header *mh = FindTarget();
    if (!mh) return;
    NSLog(@"[GuestMode:probe] tapped; image=%p anonymous_rva=0x%lx proceed_rva=0x%lx; no IL2CPP call performed",
          mh, (unsigned long)kFetchAnonymousRVA, (unsigned long)kProceedToGameRVA);
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"Guest Mode · Probe"
                                            message:@"Target build verified. Guest session initialization is not yet enabled; this version only records diagnostic events."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    UIWindow *window = self.hostWindow;
    UIViewController *vc = window.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    if (vc) [vc presentViewController:alert animated:YES completion:nil];
}
- (void)install {
    NSAssert([NSThread isMainThread], @"UIKit must run on main thread");
    const struct mach_header *mh = FindTarget();
    if (!mh) {
        if (!gLogged) { NSLog(@"[GuestMode:probe] target UUID not found; no hooks or UI installed"); gLogged = YES; }
        return;
    }
    if (self.button && self.button.superview) return;
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) { window = candidate; break; }
        }
        if (window) break;
    }
    if (!window) window = UIApplication.sharedApplication.keyWindow;
    if (!window) return;
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(16, MAX(80, window.bounds.size.height - 126), 138, 42);
    button.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
    button.backgroundColor = [UIColor colorWithRed:0.10 green:0.12 blue:0.16 alpha:0.92];
    button.layer.cornerRadius = 9;
    button.layer.borderWidth = 1;
    button.layer.borderColor = [UIColor colorWithRed:0.96 green:0.59 blue:0.22 alpha:1].CGColor;
    [button setTitle:@"GUEST · PROBE" forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [button addTarget:self action:@selector(pressed:) forControlEvents:UIControlEventTouchUpInside];
    [window addSubview:button];
    self.hostWindow = window;
    self.button = button;
    NSLog(@"[GuestMode:probe] installed; UnityFramework UUID verified, image=%p", mh);
}
@end

__attribute__((constructor)) static void GuestModeConstructor(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[GMGuestProbe shared] install];
        // Scenes may not be available during early injection.
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            [[GMGuestProbe shared] install];
        }];
    });
}
