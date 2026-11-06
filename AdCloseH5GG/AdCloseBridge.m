#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

@protocol AdCloseBridgeExport <JSExport>
- (NSString *)status;
- (NSString *)closeAd;
@end

@interface AdCloseBridge : NSObject <AdCloseBridgeExport>
@end

@implementation AdCloseBridge

static BOOL IsAdVC(UIViewController *vc) {
    return [NSStringFromClass(vc.class) isEqualToString:@"UnityAds.WebViewContainerViewController"];
}

static UIViewController *SearchVC(UIViewController *vc) {
    if (!vc) return nil;
    if (IsAdVC(vc) && vc.isViewLoaded && vc.view.window) return vc;
    UIViewController *found = SearchVC(vc.presentedViewController);
    if (found) return found;
    for (UIViewController *child in vc.childViewControllers) {
        found = SearchVC(child);
        if (found) return found;
    }
    if ([vc isKindOfClass:UINavigationController.class]) {
        found = SearchVC(((UINavigationController *)vc).visibleViewController);
        if (found) return found;
    }
    return nil;
}

static UIViewController *ActiveAd(void) {
    UIApplication *app = UIApplication.sharedApplication;
    for (UIWindow *window in [app.windows reverseObjectEnumerator]) {
        UIViewController *vc = SearchVC(window.rootViewController);
        if (vc) return vc;
    }
    return nil;
}

static NSString *OnMain(NSString *(^fn)(void)) {
    if (NSThread.isMainThread) return fn();
    __block NSString *out = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{ out = fn(); });
    return out;
}

- (NSString *)status {
    return OnMain(^NSString *{
        UIViewController *vc = ActiveAd();
        if (!vc) return @"NOT_FOUND";
        return [NSString stringWithFormat:@"FOUND %@ modal=%@ window=%@",
                NSStringFromClass(vc.class),
                vc.presentingViewController ? @"YES" : @"NO",
                vc.view.window ? @"YES" : @"NO"];
    });
}

- (NSString *)closeAd {
    return OnMain(^NSString *{
        UIViewController *vc = ActiveAd();
        if (!vc) return @"NOT_FOUND";
        if (vc.isBeingDismissed) return @"ALREADY_DISMISSING";
        if (!vc.presentingViewController) return @"NO_PRESENTER (no change)";
        NSLog(@"[AdCloseBridge] requesting UIKit dismiss: %@", vc);
        [vc dismissViewControllerAnimated:YES completion:^{
            NSLog(@"[AdCloseBridge] dismiss completion: remaining=%@", ActiveAd());
        }];
        return @"DISMISS_REQUESTED (not yet confirmed)";
    });
}
@end
