# P4.2 - Native purchase success path evidence and diagnostics

Target binary: `Glory of Generals 4` (arm64, cryptid=0, SHA256 `5b5138fc1f50cdf08dd9ec4e0b30e8a2736948280e12d699f5d6768095214a5c`).

Static disassembly, ASLR-unslid addresses:

- `IAPHandler completeTransaction:` = `0x100117AD8`.
- `IAPHandler finishTransaction:wasSuccessful:` = `0x1001179CC`.
- `IAPHandler paymentQueue:updatedTransactions:` = `0x100117D7C`.
- `IAPHandler provideContent:` = `0x1001179C8`, **RET only**, not a reward-grant implementation.
- `IAPHandler recordTransaction:` = `0x1001179C4`, **RET only**.
- On completion, `0x100117B10` sets `W3=1` before dispatching the Objective-C call to `finishTransaction:wasSuccessful:`.
- `finishTransaction:` dispatches via `0x100117100`. If there is a callback at singleton `+0x08`, the indirect call occurs at `0x1001171C0 (BLR X8)`.
- `0x10001AA74` obtains the singleton via `0x100116D24`, and `0x10001AA90` registers it with a host object via `0x100106EF0`. This **does not establish** the concrete virtual callback target.

These facts do not establish an award/grant method. A return from `completeTransaction:` cannot by itself prove reward delivery.

P4.2 instrumentation:
- Instrument the existing Objective-C `IAPHandler` methods `completeTransaction:` and `finishTransaction:wasSuccessful:` to **log and forward untouched to the original implementation**.
- Log file: `Documents/storekit-qa-flow.log`.
- Pair with existing `Documents/storekit-qa.log` StoreKit observer logs.
- Does not synthesize `SKPaymentTransaction`, manufacture receipts or invoke success callbacks.
- Does not modify game inventory or save.

Verification status: source committed; CI build result and device execution tracked separately.
