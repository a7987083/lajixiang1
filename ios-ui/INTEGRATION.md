# TrollSkinUI — reusable UIKit source library

Minimum deployment target: iOS 13.0. Objective-C with UIKit / Foundation / CoreGraphics.

## Files to integrate
- `TrollSkinUI.h` — public factory
- `TrollSkinUI.m` — controller and shared UI implementation
- `TSComponents.inc`, `TSSearch.inc`, `TSPages.inc` — implementation includes consumed by TrollSkinUI.m

Compile **TrollSkinUI.m only** plus the three includes as local files. Do not compile `main.m` in another application: it is the demo-only UIApplicationMain entry.

## Use inside an existing app
```objc
#import "TrollSkinUI.h"
UIViewController *ui = [TrollSkinUI createRootViewController];
// For example, present ui or use it as a scene's rootViewController.
[self presentViewController:ui animated:YES completion:nil];
```

Avoid replacing an existing app's UIWindow/root controller unless that is your intended integration. The current floating tab bar changes the rootViewController within its window on tab selection; therefore **presenting as a child or modal is not yet independently isolated**. For reliable reuse today, install the returned controller as the root in a dedicated window. Proper container-aware navigation is tracked as follow-up work.

## Build
The GitHub Actions matrix compiles `libTrollSkinUI.a` for arm64, with iOS 13.0 minimum deployment, using both Xcode 16 and Xcode 26 toolchains. The demo app links against that library. Unsigned IPA and archive are uploaded as CI artifacts.

All app, package, plugin and system-management actions in this library are placeholders, not OS integrations. App icons are SF Symbols placeholders.

## Stable reference
The controller's method bodies are compared with pre-refactor commit `d265c98942454587e4cd42deec929f5c6fa7af10` through `tests/test_source_equivalence.py`. This is structural/source regression evidence, not proof of simulator or real-device behavior.
