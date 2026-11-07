#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>

// V3: best-effort process-level Foundation/WebKit boundary rewriting with local HTML interception.\n// Case-insensitive replacements; not a universal hook for CFString/C++/WebKit subprocess.
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

@interface NSURLRequest (GlobalAdViewerRewrite)
+ (instancetype)gav_requestWithURL:(NSURL *)URL;
@end

@implementation NSURLRequest (GlobalAdViewerRewrite)
+ (instancetype)gav_requestWithURL:(NSURL *)URL {
    NSString *original = URL.absoluteString;
    NSString *changed = Rewrite(original);
    if (original && ![original isEqualToString:changed]) {
        NSURL *newURL = [NSURL URLWithString:changed];
        if (newURL) URL = newURL;
    }
    return [self gav_requestWithURL:URL];
}
@end

@interface WKWebView (GlobalAdViewerRewrite)
- (WKNavigation *)gav_loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL;
- (WKNavigation *)gav_loadData:(NSData *)data MIMEType:(NSString *)MIMEType
      characterEncodingName:(NSString *)characterEncodingName baseURL:(NSURL *)baseURL;
- (WKNavigation *)gav_loadHTMLString:(NSString *)string baseURL:(NSURL *)baseURL;
- (WKNavigation *)gav_loadRequest:(NSURLRequest *)request;
@end

@implementation WKWebView (GlobalAdViewerRewrite)
- (WKNavigation *)gav_loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL {
    // For local HTML launchers, rewrite actual HTML contents before the WebView parses them.
    // Do not alter the application's source files. Keep the original loader as fallback.
    if (URL.isFileURL && [[URL.path.pathExtension lowercaseString] isEqualToString:@"html"]) {
        NSError *error = nil;
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:URL.path error:&error];
        unsigned long long size = [attrs fileSize];
        if (!error && size > 0 && size <= (4ULL * 1024 * 1024)) {
            NSString *html = [NSString stringWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:&error];
            if (html && !error) {
                NSString *modified = Rewrite(html);
                if (![html isEqualToString:modified]) {
                    NSLog(@"[GlobalAdViewerRewrite] local HTML intercepted: %@", URL.path);
                    return [self gav_loadHTMLString:modified baseURL:[URL URLByDeletingLastPathComponent]];
                }
            }
        }
    }
    return [self gav_loadFileURL:URL allowingReadAccessToURL:readAccessURL];
}
- (WKNavigation *)gav_loadData:(NSData *)data MIMEType:(NSString *)MIMEType
         characterEncodingName:(NSString *)characterEncodingName baseURL:(NSURL *)baseURL {
    if ([[MIMEType lowercaseString] containsString:@"html"] && data.length > 0 && data.length <= 4*1024*1024) {
        NSStringEncoding encoding = NSUTF8StringEncoding;
        if ([[characterEncodingName lowercaseString] isEqualToString:@"utf-16"]) encoding = NSUTF16StringEncoding;
        NSString *html = [[NSString alloc] initWithData:data encoding:encoding];
        if (html) {
            NSString *modified = Rewrite(html);
            if (![html isEqualToString:modified]) {
                NSData *newData = [modified dataUsingEncoding:encoding];
                if (newData) {
                    NSLog(@"[GlobalAdViewerRewrite] loadData HTML rewritten baseURL=%@", baseURL);
                    return [self gav_loadData:newData MIMEType:MIMEType characterEncodingName:characterEncodingName baseURL:baseURL];
                }
            }
        }
    }
    return [self gav_loadData:data MIMEType:MIMEType characterEncodingName:characterEncodingName baseURL:baseURL];
}
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
        Swap(NSURLRequest.class, @selector(requestWithURL:), @selector(gav_requestWithURL:), YES);
        Swap(WKWebView.class, @selector(loadFileURL:allowingReadAccessToURL:),
             @selector(gav_loadFileURL:allowingReadAccessToURL:), NO);
        Swap(WKWebView.class, @selector(loadData:MIMEType:characterEncodingName:baseURL:),
             @selector(gav_loadData:MIMEType:characterEncodingName:baseURL:), NO);
        Swap(WKWebView.class, @selector(loadHTMLString:baseURL:),
             @selector(gav_loadHTMLString:baseURL:), NO);
        Swap(WKWebView.class, @selector(loadRequest:),
             @selector(gav_loadRequest:), NO);
        NSLog(@"[GlobalAdViewerRewrite] loaded; replacements: (?i)adviewer=>Adviewer1, (?i)ad-viewer=>ad-viewer1");
    }
}
