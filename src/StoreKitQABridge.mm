#import <Foundation/Foundation.h>
#import "StoreKitQABridge.h"
#include <atomic>

// Explicit QA dispatch only. StoreKit and transaction callbacks are never intercepted.
static std::atomic<bool> s_localMode(false);
static std::atomic<StoreKitQADeliveryHandler> s_deliver(nullptr);

extern "C" void StoreKitQARegisterDeliveryHandler(StoreKitQADeliveryHandler handler) {
    s_deliver.store(handler);
    NSLog(@"[StoreKitQA] QA game delivery adapter registered=%d",handler!=nullptr);
}
extern "C" void StoreKitQASetLocalMode(bool enabled) {
    s_localMode.store(enabled);
    NSLog(@"[StoreKitQA] QA mode=%d adapter=%d",enabled,s_deliver.load()!=nullptr);
}
extern "C" bool StoreKitQAIsLocalMode(void) { return s_localMode.load(); }
extern "C" bool StoreKitQAHasDeliveryHandler(void) { return s_deliver.load()!=nullptr; }
extern "C" bool StoreKitQADeliverSelectedProduct(const char *productId, const char *rewardJSON) {
    if (!s_localMode.load() || !productId || !*productId || !rewardJSON || !*rewardJSON) return false;
    StoreKitQADeliveryHandler handler=s_deliver.load();
    if (!handler) {
        NSLog(@"[StoreKitQA] Test delivery unavailable: game QA adapter not registered");
        return false;
    }
    return handler(productId,rewardJSON);
}
