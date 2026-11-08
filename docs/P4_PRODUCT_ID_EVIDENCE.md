# P4.1 - StoreKit Product ID evidence (read-only)

Source: uploaded decrypted ARM64 Mach-O `Glory of Generals 4`; strings at file offsets 0x5FA57D–0x5FAA75. These are raw binary string observations, **not verified commerce mappings**.

From device `storekit-qa.log`:
- `com.zhangyue.gog3iapmedal5` → purchasing then cancelled (observed transaction)
- `com.zhangyue.gog3iapgeneralpack3` → purchasing then cancelled (observed transaction)

Potential binary identifiers (not confirmed linked to internal `PaySettings.Id` values):

```text
com.zhangyue.gog3iapgeneralpack1
com.zhangyue.gog3iapgeneralpack2
com.zhangyue.gog3iapgeneralpack3
com.zhangyue.gog3iapmedal1
com.zhangyue.gog3iapmedal2
com.zhangyue.gog3iapmedal3
com.zhangyue.gog3iapmedal4
com.zhangyue.gog3iapmedal5
com.zhangyue.gog3iapmedalpackage1
com.zhangyue.gog3iapmedalpackage2
com.zhangyue.gog3iapspecialpackage1
com.zhangyue.gog3iapmedalpackage3
com.zhangyue.gog3iapspecialpackage2
com.zhangyue.gog3iapmedalpackage3a
com.zhangyue.gog3infantrymarshal
com.zhangyue.gog3armoredmarshal
com.zhangyue.gog3artillerymarshal
com.zhangyue.gog3navalmarshal
com.zhangyue.gog3infantrygeneral
com.zhangyue.gog3armoredgeneral
com.zhangyue.gog3artillerygeneral
com.zhangyue.gog3navalgeneral
com.zhangyue.gog3infantrypromotion1
com.zhangyue.gog3infantrypromotion2
com.zhangyue.gog3infantrypromotion3
com.zhangyue.gog3artillerypromotion1
com.zhangyue.gog3artillerypromotion2
com.zhangyue.gog3artillerypromotion3
com.zhangyue.gog3armorpromotion1
com.zhangyue.gog3armorpromotion2
com.zhangyue.gog3armorpromotion3
com.zhangyue.gog3generalpromotion1
com.zhangyue.gog3generalpromotion2
com.zhangyue.gog3generalpromotion3
com.zhangyue.gog3generalspecialpack1
com.zhangyue.gog3generalspecialpack2
com.zhangyue.gog3generalspecialpack3
com.zhangyue.gog3generalspecialpack4
com.zhangyue.gog3generalspecialpack5
```

## Testing status
- P4.1 logs SKPaymentQueue addPayment identifiers without replacing StoreKit success receipts.
- QA ON without a registered game test-build handler does **not** fulfill goods; original payment path is retained.
- No real game grant/save routine is established by the binary string extraction.
