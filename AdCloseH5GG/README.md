# H5GG Unity Ads close diagnostics

This independent test plugin uses the installed H5GG menu. It does NOT inject H5GG itself and does not synthesize ad rewards.

Place `AdCloseBridge.dylib` and `H5Menu.html` inside the app bundle alongside your existing H5GG injection. If an existing H5GG menu already uses H5Menu.html, integrate the two buttons instead of replacing it.

Test 1: detect UnityAds.WebViewContainerViewController.
Test 2: invoke UIKit modal dismiss only if the controller has a presenter.

No actual ad completion is simulated. Device validation is required.
