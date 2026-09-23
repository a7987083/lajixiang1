#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <dispatch/dispatch.h>
#include <string.h>

static const uint8_t kVIPUUID[16] = {0xBA,0x5F,0xE8,0x67,0x6E,0x15,0x3E,0xC5,0xA6,0x8F,0xAE,0x84,0x7E,0x92,0xEF,0x26};
static const uintptr_t kVIPThemeColorVA = 0x16680;
static const uintptr_t kVIPOrigColorRedVA = 0x16718;
static const uintptr_t kVIPOrigColorHueVA = 0x16720;
static const uintptr_t kVIPOrigColorCGVA  = 0x16728;
static const uintptr_t kVIPOrigSetImageVA = 0x16748;

static intptr_t gVIPSlide = 0;
static BOOL gVIPExactBuild = NO;
static IMP gPrevSetImage = NULL;
static IMP gPrevDidMoveToWindow = NULL;
static IMP gPrevColorRed = NULL;
static IMP gPrevColorHue = NULL;
static IMP gPrevColorCG = NULL;
static NSHashTable<UIWindow *> *gTargetWindows;
static UIImage *gCyberIcon64;
static char kCyberTargetKey;

static BOOL UUIDMatches(const struct mach_header_64 *mh) {
    if (!mh || mh->magic != MH_MAGIC_64) return NO;
    const uint8_t *p = (const uint8_t *)(mh + 1);
    for (uint32_t i=0; i<mh->ncmds; i++) {
        const struct load_command *lc = (const struct load_command *)p;
        if (lc->cmd == LC_UUID && lc->cmdsize >= sizeof(struct uuid_command)) {
            const struct uuid_command *u = (const struct uuid_command *)p;
            return memcmp(u->uuid, kVIPUUID, 16) == 0;
        }
        if (lc->cmdsize < sizeof(struct load_command)) break;
        p += lc->cmdsize;
    }
    return NO;
}

static void ResolveVIPImage(void) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i=0; i<count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name || !strstr(name, "VIPCrackPlugin")) continue;
        const struct mach_header_64 *mh = (const struct mach_header_64 *)_dyld_get_image_header(i);
        if (!UUIDMatches(mh)) continue;
        gVIPSlide = _dyld_get_image_vmaddr_slide(i);
        gVIPExactBuild = YES;
        NSLog(@"[CyberSkin] exact VIP build found slide=0x%llx", (unsigned long long)gVIPSlide);
        return;
    }
    gVIPExactBuild = NO;
    gVIPSlide = 0;
    NSLog(@"[CyberSkin] exact VIP build not found; safe fallback mode");
}

static inline IMP VIPStoredIMP(uintptr_t preferredVA) {
    if (!gVIPExactBuild) return NULL;
    IMP *slot = (IMP *)(gVIPSlide + preferredVA);
    return slot ? *slot : NULL;
}

static inline UIColor *VIPThemeColor(void) {
    if (!gVIPExactBuild) return nil;
    id __unsafe_unretained *slot = (id __unsafe_unretained *)(gVIPSlide + kVIPThemeColorVA);
    return slot ? *slot : nil;
}

typedef UIColor *(*ColorRedFn)(id, SEL, CGFloat, CGFloat, CGFloat, CGFloat);
typedef UIColor *(*ColorHueFn)(id, SEL, CGFloat, CGFloat, CGFloat, CGFloat);
typedef UIColor *(*ColorCGFn)(id, SEL, CGColorRef);
typedef void (*SetImageFn)(id, SEL, UIImage *);

static UIColor *RawColor(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    ColorRedFn fn = (ColorRedFn)VIPStoredIMP(kVIPOrigColorRedVA);
    if (fn) return fn(UIColor.class, @selector(colorWithRed:green:blue:alpha:), r,g,b,a);
    return [UIColor systemCyanColor];
}
static inline UIColor *CyberCyan(void) { return RawColor(0.00,0.93,1.00,1.0); }
static inline UIColor *CyberMagenta(void) { return RawColor(1.00,0.12,0.78,1.0); }
static inline UIColor *CyberDark(void) { return RawColor(0.025,0.035,0.070,0.96); }
static inline UIColor *CyberPanel(void) { return RawColor(0.055,0.075,0.135,0.96); }

static UIImage *MakeCyberIcon(CGSize size) {
    CGFloat side = MAX(48.0, MIN(160.0, MAX(size.width, size.height)));
    size = CGSizeMake(side, side);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat s = side;
    CGRect r = CGRectMake(0,0,s,s);

    CGContextSetFillColorWithColor(c, CyberDark().CGColor);
    CGContextFillEllipseInRect(c, CGRectInset(r, s*0.055, s*0.055));
    CGContextSetShadowWithColor(c, CGSizeZero, s*0.10, CyberCyan().CGColor);
    CGContextSetStrokeColorWithColor(c, CyberCyan().CGColor);
    CGContextSetLineWidth(c, MAX(2.0,s*0.045));
    CGPoint p[6];
    CGPoint center = CGPointMake(s*0.5,s*0.5);
    CGFloat rad=s*0.34;
    for(int i=0;i<6;i++) { CGFloat a=(CGFloat)M_PI/3.0*i-(CGFloat)M_PI/2.0; p[i]=CGPointMake(center.x+cos(a)*rad,center.y+sin(a)*rad); }
    CGContextBeginPath(c); CGContextMoveToPoint(c,p[0].x,p[0].y);
    for(int i=1;i<6;i++) CGContextAddLineToPoint(c,p[i].x,p[i].y);
    CGContextClosePath(c); CGContextStrokePath(c);

    CGContextSetShadowWithColor(c, CGSizeZero, s*0.08, CyberMagenta().CGColor);
    CGContextSetStrokeColorWithColor(c, CyberMagenta().CGColor);
    CGContextSetLineWidth(c, MAX(1.5,s*0.03));
    CGContextMoveToPoint(c,s*0.30,s*0.36); CGContextAddLineToPoint(c,s*0.47,s*0.28); CGContextAddLineToPoint(c,s*0.70,s*0.39);
    CGContextMoveToPoint(c,s*0.29,s*0.64); CGContextAddLineToPoint(c,s*0.50,s*0.73); CGContextAddLineToPoint(c,s*0.71,s*0.59); CGContextStrokePath(c);
    CGContextSetFillColorWithColor(c,CyberCyan().CGColor);
    CGContextFillEllipseInRect(c,CGRectMake(s*0.455,s*0.455,s*0.09,s*0.09));
    UIImage *img=UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

static BOOL SameThemeColor(UIColor *out) {
    UIColor *vip = VIPThemeColor();
    if (!out || !vip) return NO;
    if (out == vip) return YES;
    CGColorRef a=out.CGColor, b=vip.CGColor;
    return a && b && CGColorEqualToColor(a,b);
}

static UIColor *Cyber_colorWithRed(id self, SEL _cmd, CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    ColorRedFn prev=(ColorRedFn)gPrevColorRed;
    UIColor *out=prev ? prev(self,_cmd,r,g,b,a) : nil;
    if (SameThemeColor(out)) return CyberCyan();
    return out;
}
static UIColor *Cyber_colorWithHue(id self, SEL _cmd, CGFloat h, CGFloat s, CGFloat br, CGFloat a) {
    ColorHueFn prev=(ColorHueFn)gPrevColorHue;
    UIColor *out=prev ? prev(self,_cmd,h,s,br,a) : nil;
    if (SameThemeColor(out)) return CyberCyan();
    return out;
}
static UIColor *Cyber_colorWithCGColor(id self, SEL _cmd, CGColorRef cg) {
    ColorCGFn prev=(ColorCGFn)gPrevColorCG;
    UIColor *out=prev ? prev(self,_cmd,cg) : nil;
    if (SameThemeColor(out)) return CyberCyan();
    return out;
}

static void ApplySkin(UIView *v) {
    if (!v) return;
    if ([v isKindOfClass:UILabel.class]) {
        UILabel *x=(UILabel *)v; x.textColor=CyberCyan(); x.layer.shadowColor=CyberCyan().CGColor; x.layer.shadowOpacity=0.28; x.layer.shadowRadius=4.0;
    } else if ([v isKindOfClass:UIButton.class]) {
        UIButton *b=(UIButton *)v; b.tintColor=CyberCyan(); b.layer.borderColor=CyberCyan().CGColor; b.layer.borderWidth=0.8; b.layer.cornerRadius=8.0;
    } else if ([v isKindOfClass:UISwitch.class]) {
        UISwitch *s=(UISwitch *)v; s.onTintColor=CyberCyan(); s.thumbTintColor=CyberMagenta();
    } else {
        UIColor *bg=v.backgroundColor; CGFloat r=0,g=0,b=0,a=0;
        if ([bg getRed:&r green:&g blue:&b alpha:&a] && a>0.30) {
            CGFloat lum=0.2126*r+0.7152*g+0.0722*b;
            if (lum<0.35) v.backgroundColor=CyberPanel();
        }
    }
    for (UIView *c in v.subviews) ApplySkin(c);
}

static void MarkTargetView(UIView *v) {
    if (!v) return;
    objc_setAssociatedObject(v, &kCyberTargetKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIWindow *w=v.window;
    if (w) {
        [gTargetWindows addObject:w];
        dispatch_async(dispatch_get_main_queue(), ^{ ApplySkin(w); });
    }
}

static void Cyber_setImage(UIImageView *self, SEL _cmd, UIImage *incoming) {
    SetImageFn prev=(SetImageFn)gPrevSetImage;
    if (!prev) return;
    prev(self,_cmd,incoming);
    if (!gVIPExactBuild || !incoming) return;

    UIImage *after=self.image;
    if (!after || after==incoming) return;

    SetImageFn base=(SetImageFn)VIPStoredIMP(kVIPOrigSetImageVA);
    if (!base || base==(SetImageFn)Cyber_setImage) return;
    CGSize s=self.bounds.size;
    if (s.width<12 || s.height<12 || s.width>220 || s.height>220) return;
    CGFloat ratio=s.width/MAX(s.height,1.0);
    if (ratio<0.50 || ratio>2.0) return;

    UIImage *cyber = (s.width<90 && s.height<90 && gCyberIcon64) ? gCyberIcon64 : MakeCyberIcon(s);
    base(self,_cmd,cyber);
    MarkTargetView(self);
}

static void Cyber_didMoveToWindow(UIView *self, SEL _cmd) {
    typedef void (*Fn)(id,SEL);
    Fn prev=(Fn)gPrevDidMoveToWindow;
    if (prev) prev(self,_cmd);
    if (objc_getAssociatedObject(self,&kCyberTargetKey) && self.window) {
        [gTargetWindows addObject:self.window];
        dispatch_async(dispatch_get_main_queue(), ^{ ApplySkin(self.window); });
    }
}

static IMP ReplaceInstance(Class cls, SEL sel, IMP imp) {
    Method m=class_getInstanceMethod(cls,sel); if(!m) return NULL;
    IMP old=method_getImplementation(m); method_setImplementation(m,imp); return old;
}
static IMP ReplaceClass(Class cls, SEL sel, IMP imp) {
    Class meta=object_getClass(cls); Method m=class_getClassMethod(cls,sel); if(!m) return NULL;
    IMP old=method_getImplementation(m); method_setImplementation(m,imp); (void)meta; return old;
}

static void InstallHooks(void) {
    ResolveVIPImage();
    gTargetWindows=[NSHashTable weakObjectsHashTable];
    gCyberIcon64=MakeCyberIcon(CGSizeMake(64,64));

    gPrevSetImage=ReplaceInstance(UIImageView.class,@selector(setImage:),(IMP)Cyber_setImage);
    gPrevDidMoveToWindow=ReplaceInstance(UIView.class,@selector(didMoveToWindow),(IMP)Cyber_didMoveToWindow);
    gPrevColorRed=ReplaceClass(UIColor.class,@selector(colorWithRed:green:blue:alpha:),(IMP)Cyber_colorWithRed);
    gPrevColorHue=ReplaceClass(UIColor.class,@selector(colorWithHue:saturation:brightness:alpha:),(IMP)Cyber_colorWithHue);
    gPrevColorCG=ReplaceClass(UIColor.class,@selector(colorWithCGColor:),(IMP)Cyber_colorWithCGColor);

    NSLog(@"[CyberSkin] v2 installed exactVIP=%d hooks image=%d color=%d/%d/%d", gVIPExactBuild, !!gPrevSetImage, !!gPrevColorRed, !!gPrevColorHue, !!gPrevColorCG);
}

__attribute__((constructor)) static void CyberSkinInit(void) {
    // All dyld constructors finish before the first main-queue turn. This intentionally installs after VIPCrackPlugin,
    // so our previous IMPs are VIP's hooks rather than UIKit's originals, avoiding hook cycles.
    dispatch_async(dispatch_get_main_queue(), ^{ InstallHooks(); });
}
