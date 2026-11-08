#pragma once
// Explicit test-build adapter ABI. Implemented by StoreKitQA.dylib.
#ifdef __cplusplus
extern "C" {
#endif
typedef bool (*StoreKitQADeliveryHandler)(const char *productId, const char *rewardJSON);
// Register only from an authorized test build. Return true ONLY after game test-save delivery succeeds.
void StoreKitQARegisterDeliveryHandler(StoreKitQADeliveryHandler handler);
void StoreKitQASetLocalMode(bool enabled);
bool StoreKitQAIsLocalMode(void);
#ifdef __cplusplus
}
#endif
