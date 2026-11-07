#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

// Best-effort process-level Foundation/WebKit boundary rewriting.\n// Case-insensitive replacements; not a universal hook for CFString/C++/WebKit subprocess.
// WARNING: An NSString is a class cluster; this intentionally does NOT hook
// objc_msgSend / every NSString constructor. No edits to existing string objects.

static NSString *Rewrite(NSString *s) {
    if (![s isKindOfClass:NSString.class] || s.length == 0) return s;

    // Case-insensitive, idempotent matching. Do not turn "Adviewer1" into "Adviewer11".
    static NSRegularExpression *plainPattern;
    static NSRegularExpression *hyphenPattern;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = nil;
        plainPattern = [NSRegularExpression regularExpressionWithPattern:@"adviewer(?!1)"
                    options:NSRegularExpressionCaseInsensitive error:&error];
        if (error) NSLog(@"[GlobalAdViewerRewrite] plain regex error: %@", error);
        error = nil;
        hyphenPattern = [NSRegularExpression regularExpressionWithPattern:@"ad-viewer(?!1)"
                     options:NSRegularExpressionCaseInsensitive error:&error];
        if (error) NSLog(@"[GlobalAdViewerRewrite] hyphen regex error: %@", error);
    });

    NSString *result = s;
    if (hyphenPattern) {
        result = [hyphenPattern stringByReplacingMatchesInString:result options:0
                     range:NSMakeRange(0, result.length) withTemplate:@"ad-viewer1"];
    }
    if (plainPattern) {
        result = [plainPattern stringByReplacingMatchesInString:result options:0
                     range:NSMakeRange(0, result.length) withTemplate:@"Adviewer1"];
    }
    if (![result isEqualToString:s]) {
        NSLog(@"[GlobalAdViewerRewrite] %@ -> %@", s, result);
    }
    return result;
}

static BOOL Swap(Class cls, SEL original, SEL replacement, BOOL classMethod) {
    if (!cls) return NO;
    Class target = classMethod ? object_getClass(cls) : cls;
    Method m1 = class_getInstanceMethod(target, original);
    Method m2 = class_getInstanceMethod(target, replacement);
    if (!m1 || !m2) return NO;
    // Only exchange class-local implementations; never mutate a superclass method globally.
    class_addMethod(target, original, method_getImplementation(m1), method_getTypeEncoding(m1));
    m1 = class_getInstanceMethod(target, original);
    method_exchangeImplementations(m1, m2);
    NSLog(@"[GlobalAdViewerRewrite] swizzled %@ %@",
          NSStringFromClass(cls), NSStringFromSelector(original));
    return YES;
}

@interface NSString (GlobalAdViewerRewrite)
+ (instancetype)gav_stringWithUTF8String:(const char *)value;
+ (instancetype)gav_stringWithCString:(const char *)value encoding:(NSStringEncoding)encoding;
@end

@implementation NSString (GlobalAdViewerRewrite)
+ (instancetype)gav_stringWithUTF8String:(const char *)value {
    NSString *s = [self gav_stringWithUTF8String:value];
    return Rewrite(s);
}
+ (instancetype)gav_stringWithCString:(const char *)value encoding:(NSStringEncoding)encoding {
    NSString *s = [self gav_stringWithCString:value encoding:encoding];
    return Rewrite(s);
}
@end

@interface NSURL (GlobalAdViewerRewrite)
+ (instancetype)gav_URLWithString:(NSString *)value;
+ (instancetype)gav_URLWithString:(NSString *)value relativeToURL:(NSURL *)baseURL;
@end

@implementation NSURL (GlobalAdViewerRewrite)
+ (instancetype)gav_URLWithString:(NSString *)value {
    return [self gav_URLWithString:Rewrite(value)];
}
+ (instancetype)gav_URLWithString:(NSString *)value relativeToURL:(NSURL *)baseURL {
    return [self gav_URLWithString:Rewrite(value) relativeToURL:baseURL];
}
@end

@interface WKWebView (GlobalAdViewerRewrite)
- (WKNavigation *)gav_loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;
- (WKNavigation *)gav_loadRequest:(NSURLRequest *)request;
@end

@implementation WKWebView (GlobalAdViewerRewrite)
- (WKNavigation *)gav_loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL {
    return [self gav_loadHTMLString:Rewrite(string) baseURL:baseURL];
}
- (WKNavigation *)gav_loadRequest:(NSURLRequest *)request {
    NSString *oldURL = request.URL.absoluteString;
    NSString *newURL = Rewrite(oldURL);
    if (request && oldURL && ![oldURL isEqualToString:newURL]) {
        NSMutableURLRequest *copy = [request mutableCopy];
        NSURL *url = [NSURL URLWithString:newURL];
        if (url) {
            copy.URL = url;
            return [self gav_loadRequest:copy];
        }
    }
    return [self gav_loadRequest:request];
}
@end

__attribute__((constructor))
static void GlobalAdViewerRewriteInit(void) {
    @autoreleasepool {
        Swap(NSString.class, @selector(stringWithUTF8String:), @selector(gav_stringWithUTF8String:), YES);
        Swap(NSString.class, @selector(stringWithCString:encoding:), @selector(gav_stringWithCString:encoding:), YES);
        Swap(NSURL.class, @selector(URLWithString:), @selector(gav_URLWithString:), YES);
        Swap(NSURL.class, @selector(URLWithString:relativeToURL:),
             @selector(gav_URLWithString:relativeToURL:), YES);
        Swap(WKWebView.class, @selector(loadHTMLString:baseURL:),
             @selector(gav_loadHTMLString:baseURL:), NO);
        Swap(WKWebView.class, @selector(loadRequest:),
             @selector(gav_loadRequest:), NO);
        NSLog(@"[GlobalAdViewerRewrite] loaded; replacements: (?i)adviewer=>Adviewer1, (?i)ad-viewer=>ad-viewer1");
    }
}
