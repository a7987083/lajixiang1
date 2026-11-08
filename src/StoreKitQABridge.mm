#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>
#import "StoreKitQABridge.h"
#include <atomic>

static std::atomic<bool> s_localMode(false);
static std::atomic<StoreKitQADeliveryHandler> s_deliver(nullptr);

extern "C" void StoreKitQARegisterDeliveryHandler(StoreKitQADeliveryHandler handler) {
    s_deliver.store(handler);
    NSLog(@"[StoreKitQA] P4 authorized delivery adapter registered=%d",handler!=nullptr);
}
extern "C" void StoreKitQASetLocalMode(bool enabled) {
    s_localMode.store(enabled);
    NSLog(@"[StoreKitQA] P4 local QA mode enabled=%d, adapter=%d",enabled,s_deliver.load()!=nullptr);
}
extern "C" bool StoreKitQAIsLocalMode(void) { return s_localMode.load(); }

@interface SKPaymentQueue (StoreKitQAP4)
- (void)qa_p4_addPayment:(SKPayment *)payment;
@end
@implementation SKPaymentQueue (StoreKitQAP4)
- (void)qa_p4_addPayment:(SKPayment *)payment {
    StoreKitQADeliveryHandler handler=s_deliver.load();
    if (s_localMode.load() && handler && payment.productIdentifier.length) {
        // Only a registered, explicitly authorized adapter can fulfill a QA delivery.
        // Never fake SKPaymentTransaction, receipts or completed/failed transaction callbacks.
        NSString *productId=payment.productIdentifier;
        NSDictionary *payload=@{@"kind":@"localQA",@"productIdentifier":productId,@"quantity":@(payment.quantity),@"isTest":@YES};
        NSData *data=[NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
        NSString *json=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        BOOL ok=json && handler(productId.UTF8String,json.UTF8String);
        NSLog(@"[StoreKitQA] P4 adapter product=%@ result=%d. %@",productId,ok,ok?@"Host test build fulfilled":@"Falling back to original StoreKit");
        if (ok) return;
    }
    [self qa_p4_addPayment:payment];
}
@end

__attribute__((constructor)) static void InstallQAStoreKitP4(void) {
    // Swizzle is inert unless local QA is enabled AND host test build registers an adapter.
    Method original=class_getInstanceMethod(SKPaymentQueue.class,@selector(addPayment:));
    Method replacement=class_getInstanceMethod(SKPaymentQueue.class,@selector(qa_p4_addPayment:));
    if (original && replacement) {
        method_exchangeImplementations(original,replacement);
        NSLog(@"[StoreKitQA] P4 StoreKit entry diagnostic ready, default disabled");
    }
}
