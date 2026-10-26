# Shop journey example (in.breeze.shop)

```bash
cd Example/ShopExample
pod install
open ShopExample.xcworkspace
```

Run the `ShopExample` scheme. The two editors hold the exact payloads passed to `blaze.initiate(context:initiatePayload:callbackFn:)` and `blaze.process(payload:)`. Edits are saved; **Reset** restores the defaults.

1. **Initiate SDK**: set `payload.publisherId` (required) and `payload.environment` (`beta`, `release` or `dev`).
2. **Process SDK** (enabled after the `initiate` callback) with `{"action": "launch"}` opens the journey over the app.
3. **Terminate SDK** releases it. Every message is logged under **Messages**.

Calling `process` before the `initiate` callback can crash the SDK. A terminated `Blaze` can't be re-initiated, so create a new `Blaze()`. Callbacks can arrive off the main thread. See [`ViewController.swift`](ShopExample/ViewController.swift).
