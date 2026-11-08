#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>
#import <dispatch/dispatch.h>

// P4.2: Passive tracing of the target app's own IAPHandler.
// Does not synthesize StoreKit transactions, change result codes, or award goods.
static void QAFlowTrace(NSString *message) {
    NSString *line=[NSString stringWithFormat:@"[%@] P4.2 %@\n",[NSDate date],message];
    NSLog(@"[StoreKitQA] %@",message);
    NSString *directory=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    if (!directory) return;
    NSString *path=[directory stringByAppendingPathComponent:@"storekit-qa-flow.log"];
    NSData *data=[line dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle=[NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) { [data writeToFile:path atomically:YES]; return; }
    @try { [handle seekToEndOfFile]; [handle writeData:data]; }
    @catch (NSException *exception) { NSLog(@"[StoreKitQA] flow file write failed %@",exception.name); }
    @finally { [handle closeFile]; }
}

static NSString *QAProductId(SKPaymentTransaction *transaction) {
    if (![transaction isKindOfClass:SKPaymentTransaction.class]) return @"(unexpected type)";
    return transaction.payment.productIdentifier ?: @"(missing)";
}
static void (*sOriginalComplete)(id,SEL,SKPaymentTransaction *)=NULL;
static void (*sOriginalFinish)(id,SEL,SKPaymentTransaction *,BOOL)=NULL;

static void QACompleteTransaction(id target,SEL command,SKPaymentTransaction *transaction) {
    QAFlowTrace([NSString stringWithFormat:@"completeTransaction: product=%@ state=%ld",
                 QAProductId(transaction),(long)transaction.transactionState]);
    if (sOriginalComplete) sOriginalComplete(target,command,transaction);
}
static void QAFinishTransaction(id target,SEL command,SKPaymentTransaction *transaction,BOOL success) {
    QAFlowTrace([NSString stringWithFormat:@"finishTransaction:wasSuccessful: product=%@ successful=%d state=%ld",
                 QAProductId(transaction),success,(long)transaction.transactionState]);
    if (sOriginalFinish) sOriginalFinish(target,command,transaction,success);
}
static void QAInstallIAPFlowTrace(void) {
    Class cls=objc_getClass("IAPHandler");
    if (!cls) {
        QAFlowTrace(@"IAPHandler class unavailable; no hooks installed");
        return;
    }
    SEL complete=@selector(completeTransaction:);
    SEL finish=@selector(finishTransaction:wasSuccessful:);
    Method mComplete=class_getInstanceMethod(cls,complete);
    Method mFinish=class_getInstanceMethod(cls,finish);
    if (mComplete) {
        sOriginalComplete=(void (*)(id,SEL,SKPaymentTransaction *))method_setImplementation(mComplete,(IMP)QACompleteTransaction);
    }
    if (mFinish) {
        sOriginalFinish=(void (*)(id,SEL,SKPaymentTransaction *,BOOL))method_setImplementation(mFinish,(IMP)QAFinishTransaction);
    }
    QAFlowTrace([NSString stringWithFormat:@"IAPHandler installed complete=%d finish=%d",
                 sOriginalComplete!=NULL,sOriginalFinish!=NULL]);
}
__attribute__((constructor)) static void QAFlowTraceEntry(void) {
    dispatch_async(dispatch_get_main_queue(), ^{ QAInstallIAPFlowTrace(); });
}
