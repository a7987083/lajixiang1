#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dispatch/dispatch.h>
#include <string.h>

static const uint8_t kVIPUUID[16] = {0xBA,0x5F,0xE8,0x67,0x6E,0x15,0x3E,0xC5,0xA6,0x8F,0xAE,0x84,0x7E,0x92,0xEF,0x26};
static const uintptr_t kVIPIconDataVA = 0x16678;
static const uintptr_t kVIPThemeColorVA = 0x16680;
static const uintptr_t kVIPOrigColorRedVA = 0x16718;

static uintptr_t gVIPBase = 0;
static BOOL gVIPExactBuild = NO;
static NSData *gCyberPNG = nil;
static UIColor *gCyberTheme = nil;
static UIImage *gCyberIcon = nil;
static dispatch_source_t gReassertTimer = nil;
static IMP gFallbackSetImage = NULL;
static IMP gFallbackDidMove = NULL;
static char kCyberWindowKey;

static BOOL UUIDMatches(const struct mach_header_64 *mh) {
    if (!mh || mh->magic != MH_MAGIC_64) return NO;
    const uint8_t *p = (const uint8_t *)(mh + 1);
    for (uint32_t i=0; i<mh->ncmds; i++) {
        const struct load_command *lc = (const struct load_command *)p;
        if (lc->cmdsize < sizeof(struct load_command)) break;
        if (lc->cmd == LC_UUID && lc->cmdsize >= sizeof(struct uuid_command)) {
            const struct uuid_command *u = (const struct uuid_command *)p;
            return memcmp(u->uuid, kVIPUUID, 16) == 0;
        }
        p += lc->cmdsize;
    }
    return NO;
}

static BOOL ResolveVIPImage(void) {
    if (gVIPExactBuild && gVIPBase) return YES;
    uint32_t count = _dyld_image_count();
    for (uint32_t i=0; i<count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name || !strstr(name, "VIPCrackPlugin")) continue;
        const struct mach_header_64 *mh = (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!UUIDMatches(mh)) continue;
        gVIPBase = (uintptr_t)mh; // supplied dylib __TEXT vmaddr is 0
        gVIPExactBuild = YES;
        NSLog(@"[CyberSkin:v3] exact VIP build found base=%p", (void *)gVIPBase);
        return YES;
    }
    return NO;
}

typedef UIColor *(*ColorRedFn)(id, SEL, CGFloat, CGFloat, CGFloat, CGFloat);
typedef void (*SetImageFn)(id, SEL, UIImage *);

static ColorRedFn VIPRawColorFactory(void) {
    if (!ResolveVIPImage()) return NULL;
    IMP *slot = (IMP *)(gVIPBase + kVIPOrigColorRedVA);
    return slot ? (ColorRedFn)(*slot) : NULL;
}

static UIColor *MakeRawColor(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    ColorRedFn fn = VIPRawColorFactory();
    if (fn) return fn(UIColor.class, @selector(colorWithRed:green:blue:alpha:), r,g,b,a);
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

static UIImage *MakeCyberIcon(CGSize size) {
    CGFloat side = MAX(64.0, MIN(192.0, MAX(size.width, size.height)));
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(side, side), NO, 0.0);
    CGContextRef c = UIGraphicsGetCurrentContext();
    UIColor *cyan = MakeRawColor(0.00,0.93,1.00,1.0);
    UIColor *magenta = MakeRawColor(1.00,0.10,0.78,1.0);
    UIColor *dark = MakeRawColor(0.018,0.026,0.060,0.98);

    CGRect r = CGRectMake(0,0,side,side);
    CGContextSetFillColorWithColor(c, dark.CGColor);
    CGContextFillEllipseInRect(c, CGRectInset(r, side*0.055, side*0.055));

    CGContextSetShadowWithColor(c, CGSizeZero, side*0.09, cyan.CGColor);
    CGContextSetStrokeColorWithColor(c, cyan.CGColor);
    CGContextSetLineWidth(c, MAX(2.0, side*0.045));
    CGPoint p[6]; CGPoint center=CGPointMake(side*0.5,side*0.5); CGFloat rad=side*0.34;
    for(int i=0;i<6;i++){ CGFloat a=(CGFloat)M_PI/3.0*i-(CGFloat)M_PI/2.0; p[i]=CGPointMake(center.x+cos(a)*rad,center.y+sin(a)*rad); }
    CGContextBeginPath(c); CGContextMoveToPoint(c,p[0].x,p[0].y);
    for(int i=1;i<6;i++) CGContextAddLineToPoint(c,p[i].x,p[i].y);
    CGContextClosePath(c); CGContextStrokePath(c);

    CGContextSetShadowWithColor(c, CGSizeZero, side*0.075, magenta.CGColor);
    CGContextSetStrokeColorWithColor(c, magenta.CGColor);
    CGContextSetLineWidth(c, MAX(1.5,side*0.028));
    CGContextMoveToPoint(c,side*0.29,side*0.36); CGContextAddLineToPoint(c,side*0.47,side*0.28); CGContextAddLineToPoint(c,side*0.70,side*0.39);
    CGContextMoveToPoint(c,side*0.29,side*0.64); CGContextAddLineToPoint(c,side*0.50,side*0.73); CGContextAddLineToPoint(c,side*0.71,side*0.59); CGContextStrokePath(c);
    CGContextSetFillColorWithColor(c,cyan.CGColor);
    CGContextFillEllipseInRect(c,CGRectMake(side*0.455,side*0.455,side*0.09,side*0.09));

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

static void EnsureCyberResources(void) {
    if (gCyberPNG && gCyberTheme && gCyberIcon) return;
    UIImage *img = MakeCyberIcon(CGSizeMake(128,128));
    NSData *png = UIImagePNGRepresentation(img);
    UIColor *theme = MakeRawColor(0.00,0.93,1.00,1.0);
    if (!img || !png || !theme) return;
    gCyberIcon = [img retain];
    gCyberPNG = [png retain];
    gCyberTheme = [theme retain];
    NSLog(@"[CyberSkin:v3] resources ready png=%lu", (unsigned long)gCyberPNG.length);
}

static BOOL StoreVIPStrong(uintptr_t va, id obj) {
    if (!ResolveVIPImage() || !obj) return NO;
    id *slot = (id *)(gVIPBase + va);
    if (!slot) return NO;
    if (*slot == obj) return YES;
    objc_storeStrong(slot, obj);
    return *slot == obj;
}

static void ReassertVIPResources(void) {
    if (!ResolveVIPImage()) return;
    EnsureCyberResources();
    if (!gCyberPNG || !gCyberTheme) return;
    BOOL iconOK = StoreVIPStrong(kVIPIconDataVA, gCyberPNG);
    BOOL colorOK = StoreVIPStrong(kVIPThemeColorVA, gCyberTheme);
    static int logBudget = 8;
    if (logBudget-- > 0) {
        id iconNow = *(id *)(gVIPBase + kVIPIconDataVA);
        id colorNow = *(id *)(gVIPBase + kVIPThemeColorVA);
        NSLog(@"[CyberSkin:v3] reassert icon=%d color=%d slots=%p/%p", iconOK, colorOK, iconNow, colorNow);
    }
}

static BOOL IsFallbackMenuWindow(UIWindow *w) {
    if (!w) return NO;
    NSString *n = NSStringFromClass(w.class).lowercaseString;
    if ([n containsString:@"keyboard"] || [n containsString:@"texteffects"] || [n containsString:@"alert"] || [n containsString:@"remote"]) return NO;
    if (w.windowLevel > UIWindowLevelNormal + 0.5) return YES;
    if ([n containsString:@"menu"] || [n containsString:@"overlay"] || [n containsString:@"float"] || [n containsString:@"hack"] || [n containsString:@"plugin"]) return YES;
    return NO;
}

static BOOL IsFallbackTargetView(UIView *v) {
    UIWindow *w=v.window;
    if (!w) return NO;
    if (objc_getAssociatedObject(w,&kCyberWindowKey)) return YES;
    if (IsFallbackMenuWindow(w)) { objc_setAssociatedObject(w,&kCyberWindowKey,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC); return YES; }
    return NO;
}

static void Fallback_setImage(UIImageView *self, SEL _cmd, UIImage *image) {
    SetImageFn prev=(SetImageFn)gFallbackSetImage;
    if (!prev) return;
    if (!gVIPExactBuild && image && IsFallbackTargetView(self)) {
        CGSize s=self.bounds.size;
        if (s.width>=16 && s.height>=16 && s.width<=180 && s.height<=180) {
            CGFloat ratio=s.width/MAX(s.height,1.0);
            if (ratio>0.55 && ratio<1.8) { EnsureCyberResources(); prev(self,_cmd,gCyberIcon ?: image); return; }
        }
    }
    prev(self,_cmd,image);
}

static void Fallback_didMove(UIView *self, SEL _cmd) {
    typedef void(*Fn)(id,SEL); Fn prev=(Fn)gFallbackDidMove; if(prev) prev(self,_cmd);
    if (gVIPExactBuild || !IsFallbackTargetView(self)) return;
    if ([self isKindOfClass:UILabel.class]) ((UILabel *)self).textColor=MakeRawColor(0.00,0.93,1.00,1.0);
    if ([self isKindOfClass:UIButton.class]) { self.layer.borderColor=MakeRawColor(0.00,0.93,1.00,1.0).CGColor; self.layer.borderWidth=0.8; self.layer.cornerRadius=8; }
    if ([self isKindOfClass:UISwitch.class]) ((UISwitch *)self).onTintColor=MakeRawColor(0.00,0.93,1.00,1.0);
}

static IMP ReplaceInstance(Class cls, SEL sel, IMP imp) {
    Method m=class_getInstanceMethod(cls,sel); if(!m) return NULL;
    IMP old=method_getImplementation(m); method_setImplementation(m,imp); return old;
}

static void InstallV3(void) {
    BOOL exact = ResolveVIPImage();
    if (!exact) {
        gFallbackSetImage=ReplaceInstance(UIImageView.class,@selector(setImage:),(IMP)Fallback_setImage);
        gFallbackDidMove=ReplaceInstance(UIView.class,@selector(didMoveToWindow),(IMP)Fallback_didMove);
        NSLog(@"[CyberSkin:v3] VIP not found; fallback hooks=%d/%d",!!gFallbackSetImage,!!gFallbackDidMove);
    }
    EnsureCyberResources();
    ReassertVIPResources();

    gReassertTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
    dispatch_source_set_timer(gReassertTimer, dispatch_time(DISPATCH_TIME_NOW, 100*NSEC_PER_MSEC), 500*NSEC_PER_MSEC, 50*NSEC_PER_MSEC);
    dispatch_source_set_event_handler(gReassertTimer, ^{ ReassertVIPResources(); });
    dispatch_resume(gReassertTimer);
    NSLog(@"[CyberSkin:v3] installed exactVIP=%d", exact);
}

__attribute__((constructor)) static void CyberSkinInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ InstallV3(); });
}
