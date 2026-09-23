#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>

static IMP gOrigSetImage = NULL;
static IMP gOrigSetWindowLevel = NULL;
static IMP gOrigDidMoveToWindow = NULL;
static IMP gOrigButtonLayout = NULL;
static BOOL gInstalled = NO;
static NSHashTable<UIWindow *> *gCyberWindows;
static UIImage *gCyberIcon;

static inline UIColor *CyberCyan(void) { return [UIColor colorWithRed:0.00 green:0.93 blue:1.00 alpha:1.0]; }
static inline UIColor *CyberMagenta(void) { return [UIColor colorWithRed:1.00 green:0.12 blue:0.78 alpha:1.0]; }
static inline UIColor *CyberDark(void) { return [UIColor colorWithRed:0.025 green:0.035 blue:0.070 alpha:0.94]; }
static inline UIColor *CyberPanel(void) { return [UIColor colorWithRed:0.055 green:0.075 blue:0.135 alpha:0.94]; }

static BOOL IsSystemWindow(UIWindow *w) {
    NSString *n = NSStringFromClass(w.class).lowercaseString;
    return [n containsString:@"keyboard"] || [n containsString:@"texteffects"] ||
           [n containsString:@"remote"] || [n containsString:@"inputset"] ||
           [n containsString:@"alert"];
}

static BOOL LooksLikeOverlayWindow(UIWindow *w) {
    if (!w || IsSystemWindow(w)) return NO;
    NSString *n = NSStringFromClass(w.class).lowercaseString;
    BOOL named = [n containsString:@"menu"] || [n containsString:@"overlay"] ||
                 [n containsString:@"float"] || [n containsString:@"hack"] ||
                 [n containsString:@"ig"] || [n containsString:@"plugin"];
    BOOL elevated = w.windowLevel > UIWindowLevelNormal + 1.0;
    BOOL compactRoot = w.bounds.size.width > 20 && w.bounds.size.height > 20 &&
                       (w.bounds.size.width < UIScreen.mainScreen.bounds.size.width * 0.98 ||
                        w.bounds.size.height < UIScreen.mainScreen.bounds.size.height * 0.98);
    return named || elevated || compactRoot;
}

static BOOL IsInsideCyberWindow(UIView *v) {
    UIWindow *w = v.window;
    if (!w) return NO;
    if ([gCyberWindows containsObject:w]) return YES;
    if (LooksLikeOverlayWindow(w)) {
        [gCyberWindows addObject:w];
        return YES;
    }
    return NO;
}

static UIImage *MakeCyberIcon(CGSize size) {
    if (size.width < 8 || size.height < 8) size = CGSizeMake(64, 64);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect r = (CGRect){CGPointZero, size};
    CGFloat s = MIN(size.width, size.height);

    CGContextSetFillColorWithColor(c, CyberDark().CGColor);
    CGContextFillEllipseInRect(c, CGRectInset(r, s * 0.04, s * 0.04));

    CGContextSetShadowWithColor(c, CGSizeZero, s * 0.10, CyberCyan().CGColor);
    CGContextSetStrokeColorWithColor(c, CyberCyan().CGColor);
    CGContextSetLineWidth(c, MAX(2.0, s * 0.045));

    CGPoint p[6];
    CGPoint center = CGPointMake(size.width * 0.5, size.height * 0.5);
    CGFloat rad = s * 0.34;
    for (int i=0;i<6;i++) {
        CGFloat a = (CGFloat)M_PI / 3.0 * i - (CGFloat)M_PI / 2.0;
        p[i] = CGPointMake(center.x + cos(a)*rad, center.y + sin(a)*rad);
    }
    CGContextBeginPath(c);
    CGContextMoveToPoint(c, p[0].x, p[0].y);
    for (int i=1;i<6;i++) CGContextAddLineToPoint(c, p[i].x, p[i].y);
    CGContextClosePath(c);
    CGContextStrokePath(c);

    CGContextSetShadowWithColor(c, CGSizeZero, s * 0.08, CyberMagenta().CGColor);
    CGContextSetStrokeColorWithColor(c, CyberMagenta().CGColor);
    CGContextSetLineWidth(c, MAX(1.5, s * 0.03));
    CGContextBeginPath(c);
    CGContextMoveToPoint(c, size.width*0.34, size.height*0.38);
    CGContextAddLineToPoint(c, size.width*0.46, size.height*0.30);
    CGContextAddLineToPoint(c, size.width*0.65, size.height*0.36);
    CGContextMoveToPoint(c, size.width*0.35, size.height*0.62);
    CGContextAddLineToPoint(c, size.width*0.50, size.height*0.70);
    CGContextAddLineToPoint(c, size.width*0.66, size.height*0.59);
    CGContextStrokePath(c);

    CGContextSetShadowWithColor(c, CGSizeZero, s * 0.06, CyberCyan().CGColor);
    CGContextSetFillColorWithColor(c, CyberCyan().CGColor);
    CGContextFillEllipseInRect(c, CGRectMake(size.width*0.45, size.height*0.43, s*0.10, s*0.10));
    CGContextFillEllipseInRect(c, CGRectMake(size.width*0.30, size.height*0.34, s*0.06, s*0.06));
    CGContextFillEllipseInRect(c, CGRectMake(size.width*0.64, size.height*0.55, s*0.06, s*0.06));

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

static BOOL ShouldReplaceImageView(UIImageView *iv, UIImage *incoming) {
    if (!IsInsideCyberWindow(iv)) return NO;
    CGSize s = iv.bounds.size;
    if (s.width < 16 || s.height < 16 || s.width > 160 || s.height > 160) return NO;
    CGFloat ratio = s.width / MAX(s.height, 1.0);
    if (ratio < 0.60 || ratio > 1.67) return NO;
    if (!incoming) return NO;
    return YES;
}

static void ApplyLayer(UIView *v) {
    if (!IsInsideCyberWindow(v)) return;
    CALayer *l = v.layer;
    if (v.bounds.size.width > 24 && v.bounds.size.height > 24) {
        l.cornerRadius = MIN(12.0, MIN(v.bounds.size.width, v.bounds.size.height) * 0.16);
    }

    if ([v isKindOfClass:UILabel.class]) {
        UILabel *x = (UILabel *)v;
        x.textColor = CyberCyan();
        x.layer.shadowColor = CyberCyan().CGColor;
        x.layer.shadowOpacity = 0.30;
        x.layer.shadowRadius = 4.0;
        return;
    }
    if ([v isKindOfClass:UIButton.class]) {
        UIButton *b = (UIButton *)v;
        b.tintColor = CyberCyan();
        b.layer.borderColor = CyberCyan().CGColor;
        b.layer.borderWidth = 0.8;
        return;
    }
    if ([v isKindOfClass:UISwitch.class]) {
        ((UISwitch *)v).onTintColor = CyberCyan();
        ((UISwitch *)v).thumbTintColor = CyberMagenta();
        return;
    }

    UIColor *bg = v.backgroundColor;
    CGFloat r=0,g=0,b=0,a=0;
    if ([bg getRed:&r green:&g blue:&b alpha:&a] && a > 0.25) {
        CGFloat lum = 0.2126*r + 0.7152*g + 0.0722*b;
        if (lum < 0.45) v.backgroundColor = CyberPanel();
    }
}

static void SkinTree(UIView *root) {
    if (!root || !IsInsideCyberWindow(root)) return;
    ApplyLayer(root);
    for (UIView *v in root.subviews) SkinTree(v);
}

static void Cyber_setImage(UIImageView *self, SEL _cmd, UIImage *image) {
    typedef void (*Fn)(id, SEL, UIImage *);
    if (ShouldReplaceImageView(self, image)) {
        CGSize s = self.bounds.size;
        if (!gCyberIcon || fabs(gCyberIcon.size.width - MAX(48,s.width)) > 20) {
            gCyberIcon = MakeCyberIcon(CGSizeMake(MAX(48,s.width), MAX(48,s.height)));
        }
        ((Fn)gOrigSetImage)(self, _cmd, gCyberIcon);
        self.tintColor = CyberCyan();
        self.layer.shadowColor = CyberCyan().CGColor;
        self.layer.shadowOpacity = 0.65;
        self.layer.shadowRadius = 7.0;
        return;
    }
    ((Fn)gOrigSetImage)(self, _cmd, image);
}

static void Cyber_setWindowLevel(UIWindow *self, SEL _cmd, UIWindowLevel level) {
    typedef void (*Fn)(id, SEL, UIWindowLevel);
    ((Fn)gOrigSetWindowLevel)(self, _cmd, level);
    if (LooksLikeOverlayWindow(self)) {
        [gCyberWindows addObject:self];
        dispatch_async(dispatch_get_main_queue(), ^{ SkinTree(self); });
    }
}

static void Cyber_didMoveToWindow(UIView *self, SEL _cmd) {
    typedef void (*Fn)(id, SEL);
    ((Fn)gOrigDidMoveToWindow)(self, _cmd);
    if (IsInsideCyberWindow(self)) ApplyLayer(self);
}

static void Cyber_buttonLayout(UIButton *self, SEL _cmd) {
    typedef void (*Fn)(id, SEL);
    ((Fn)gOrigButtonLayout)(self, _cmd);
    if (IsInsideCyberWindow(self)) {
        ApplyLayer(self);
        if (self.imageView.image && self.imageView.bounds.size.width >= 16 && self.imageView.bounds.size.width <= 96) {
            self.imageView.image = gCyberIcon ?: MakeCyberIcon(CGSizeMake(64,64));
        }
    }
}

static IMP ReplaceMethod(Class cls, SEL sel, IMP imp) {
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return NULL;
    IMP old = method_getImplementation(m);
    method_setImplementation(m, imp);
    return old;
}

static void InstallHooks(void) {
    if (gInstalled) return;
    gInstalled = YES;
    gCyberWindows = [NSHashTable weakObjectsHashTable];
    gCyberIcon = MakeCyberIcon(CGSizeMake(64,64));

    gOrigSetImage = ReplaceMethod(UIImageView.class, @selector(setImage:), (IMP)Cyber_setImage);
    gOrigSetWindowLevel = ReplaceMethod(UIWindow.class, @selector(setWindowLevel:), (IMP)Cyber_setWindowLevel);
    gOrigDidMoveToWindow = ReplaceMethod(UIView.class, @selector(didMoveToWindow), (IMP)Cyber_didMoveToWindow);
    gOrigButtonLayout = ReplaceMethod(UIButton.class, @selector(layoutSubviews), (IMP)Cyber_buttonLayout);

    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (LooksLikeOverlayWindow(w)) {
            [gCyberWindows addObject:w];
            SkinTree(w);
        }
    }
    NSLog(@"[CyberSkin] v1 installed; hooks=%d/%d/%d/%d", !!gOrigSetImage, !!gOrigSetWindowLevel, !!gOrigDidMoveToWindow, !!gOrigButtonLayout);
}

__attribute__((constructor)) static void CyberSkinInit(void) {
    // Delay deliberately: when loaded as a dependency of VIPCrackPlugin, its constructor runs first.
    // Installing on the main queue lets us capture VIPCrackPlugin's final UIKit IMPs and chain them.
    dispatch_async(dispatch_get_main_queue(), ^{ InstallHooks(); });
}
