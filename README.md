# BlazeSDK

[![Version](https://img.shields.io/cocoapods/v/BlazeSDK.svg?style=flat)](https://cocoapods.org/pods/BlazeSDK)
[![License](https://img.shields.io/cocoapods/l/BlazeSDK.svg?style=flat)](https://cocoapods.org/pods/BlazeSDK)
[![Platform](https://img.shields.io/cocoapods/p/BlazeSDK.svg?style=flat)](https://cocoapods.org/pods/BlazeSDK)

The Blaze SDK is an easy-to-use toolkit that allows you to effortlessly integrate and utilize [Breeze 1 Click Checkout](https://breeze.in) & its services into your iOS app.

## Requirements

- iOS 12.0+
- Swift 5.0+
- Xcode 13.0+

## iOS SDK Integration

Follow the below steps to integrate Blaze SDK into your iOS application:

### Step 1: Obtaining the Blaze SDK

BlazeSDK is available through [CocoaPods](https://cocoapods.org). To install it, simply add the following line to your Podfile:

```ruby
pod 'BlazeSDK'
```

Then run:

```bash
pod install
```

### Step 2: Initialize the SDK

**2.1. Import the SDK and create an instance of the `Blaze` class in your view controller.**

```swift
import BlazeSDK

class ViewController: UIViewController {
    let blaze = Blaze()
}
```

**2.2. Initiate the Blaze instance.**

In order to call initiate you need to perform the following steps:

#### 2.2.1: Construct the Initiate Payload

Create a dictionary with the correct parameters to initiate the SDK. This is the data that will be used to initialize the SDK.

```swift
// Create the Initiate data
var initiatePayload: [String: Any] = [:]
initiatePayload["merchantId"] = "<MERCHANT_ID>"
initiatePayload["environment"] = "<ENVIRONMENT>"
initiatePayload["shopUrl"] = "<SHOP_URL>"

// Place Initiate Payload into SDK Payload
var initSDKPayload: [String: Any] = [:]
initSDKPayload["requestId"] = UUID().uuidString
initSDKPayload["service"] = "in.breeze.onecco"
initSDKPayload["payload"] = initiatePayload
```

> **Note:** Obtain values for `merchantId`, `environment` and `shopUrl` from the Breeze team.

#### 2.2.2: Construct the Callback Method

During the user journey the SDK will call the callback method with the result of the SDK operation. You need to implement this method in order to handle the result of the SDK operation.

```swift
func blazeCallbackHandler(event: [String: Any]) {
    if let eventName = event["eventName"] as? String {
        switch eventName {
        // Handle various events according to your desired logic
        default:
            break
        }
    }
}
```

#### 2.2.3: Call the initiate method on the Blaze Instance

Finally, call the initiate method on the Blaze instance with the payload and the callback method. The first parameter is the `UIViewController` context.

```swift
blaze.initiate(
    context: self,
    initiatePayload: initSDKPayload,
    callbackFn: { event in
        self.blazeCallbackHandler(event: event)
    }
)
```

***Combined Example:***

```swift
import BlazeSDK
import UIKit

class ViewController: UIViewController {

    // Create Blaze Instance
    let blaze = Blaze()

    override func viewDidLoad() {
        super.viewDidLoad()
        initiateSDK()
    }

    func initiateSDK() {
        // 2.2.1 Create the Initiate data
        var initiatePayload: [String: Any] = [:]
        initiatePayload["merchantId"] = "<MERCHANT_ID>"
        initiatePayload["environment"] = "<ENVIRONMENT>"
        initiatePayload["shopUrl"] = "<SHOP_URL>"

        // Place Initiate Payload into SDK Payload
        var initSDKPayload: [String: Any] = [:]
        initSDKPayload["requestId"] = UUID().uuidString
        initSDKPayload["service"] = "in.breeze.onecco"
        initSDKPayload["payload"] = initiatePayload

        // 2.2.3 Initiate Blaze SDK
        blaze.initiate(
            context: self,
            initiatePayload: initSDKPayload,
            callbackFn: { event in
                self.blazeCallbackHandler(event: event)
            }
        )
    }

    // 2.2.2: Creating a Callback handler
    func blazeCallbackHandler(event: [String: Any]) {
        if let eventName = event["eventName"] as? String {
            switch eventName {
            // Handle various events according to your desired logic
            default:
                print("Received event: \(eventName)")
            }
        }
    }
}
```

### Step 3: Start Processing Your Requests

Once the SDK is initiated, you can start processing your requests using the initialized instance of the SDK. The SDK will call the callback method with the result of the SDK operation.

#### 3.1: Construct the Process Payload

Create a dictionary payload with the required parameters to process the request. The process payload differs based on the request.

```swift
// 3.1 Create SDK Process Payload
var processPayload: [String: Any] = [:]
processPayload["action"] = "<ACTION>"
// and more parameters required as per the action

// Place Process Payload into SDK Payload
var processSDKPayload: [String: Any] = [:]
processSDKPayload["requestId"] = UUID().uuidString
processSDKPayload["service"] = "in.breeze.onecco"
processSDKPayload["payload"] = processPayload
```

#### 3.2: Call the process method on the Blaze Instance

Call the process method on the Blaze instance with the process payload to start the user journey or a headless flow.

```swift
blaze.process(payload: processSDKPayload)
```

### Step 4: Terminate the SDK

When you are done with the SDK, call the `terminate` method to clean up resources.

```swift
blaze.terminate()
```

### Step 5: UPI Intent Flow Configuration

In order to allow the SDK to launch UPI apps in UPI intent flow, you need to add the following to the `Info.plist` file of your iOS app:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>credpay</string>
    <string>phonepe</string>
    <string>paytmmp</string>
    <string>tez</string>
    <string>paytm</string>
    <string>bhim</string>
    <string>myairtel</string>
    <string>slice-upi</string>
    <string>ppe</string>
    <string>amazonpay</string>
</array>
```

This declares the URL schemes for UPI apps that the SDK may attempt to open. Without this configuration, iOS will not allow the SDK to check for or launch these apps.

| Scheme       | App              |
|--------------|------------------|
| `credpay`    | CRED             |
| `phonepe`    | PhonePe          |
| `paytmmp`    | Paytm            |
| `tez`        | Google Pay       |
| `paytm`      | Paytm            |
| `bhim`       | BHIM             |
| `myairtel`   | Airtel Thanks    |
| `slice-upi`  | Slice            |
| `ppe`        | PhonePe (legacy) |
| `amazonpay`  | Amazon Pay       |

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

```bash
git clone https://github.com/juspay/blaze-sdk-ios.git
cd blaze-sdk-ios/Example
pod install
open BlazeSDK.xcworkspace
```

For the Breeze shopping assistant (`in.breeze.shop`), see [`Example/ShopExample`](Example/ShopExample/README.md).

## License

BlazeSDK is available under the MIT license. See the LICENSE file for more info.
