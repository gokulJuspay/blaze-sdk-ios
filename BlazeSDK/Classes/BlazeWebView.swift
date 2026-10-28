import UIKit
import WebKit

private class SafeAreaWebView: WKWebView {

    var onSafeAreaChange: (() -> Void)?

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        onSafeAreaChange?()
    }
}

class BlazeWebView: NSObject, WKScriptMessageHandler {

    private var webView: SafeAreaWebView!
    private var isWebViewReady: Bool = false
    private var consumingBackPress: Bool = false
    private var eventQueue: [String: [String: Any]] = [:]
    private var context: UIViewController
    private weak var container: UIView?
    private var initiatePayload: [String: Any]
    private var callbackFn: ([String: Any]) -> Void
    private var isTerminated: Bool = false
    private var lastSafeMargin: SafeMargin?

    init(
        context: UIViewController, initiatePayload: [String: Any],
        container: UIView?,
        callbackFn: @escaping ([String: Any]) -> Void
    ) {
        self.context = context
        self.initiatePayload = initiatePayload
        self.container = container
        self.callbackFn = callbackFn
        super.init()

        let contentController = WKUserContentController()
        contentController.add(self, name: "Native")

        let config = WKWebViewConfiguration()
        config.userContentController = contentController

        self.webView = SafeAreaWebView(frame: .zero, configuration: config)
        self.webView.navigationDelegate = self
        self.webView.scrollView.contentInsetAdjustmentBehavior = .never
        self.webView.onSafeAreaChange = { [weak self] in
            self?.sendSafeMarginIfChanged()
        }

        self.sendEvent(event: "initiate", payload: initiatePayload)
        self.loadFrame()
    }

    private func loadFrame() {
        let fallbackUrl = getBaseUrl(payload: initiatePayload)
        BlazeConfig.shared.resolveFrameUrl(
            service: getService(payload: initiatePayload),
            environment: getEnvironment(payload: initiatePayload)
        ) { [weak self] frameUrl in
            guard let self = self, !self.isTerminated,
                let url = URL(string: frameUrl ?? fallbackUrl)
            else {
                return
            }
            self.webView.load(URLRequest(url: url))
        }
    }

    func process(payload: [String: Any]) {
        self.sendEvent(event: "process", payload: payload)
    }

    func terminate() {
        self.sendEvent(event: "terminate", payload: [:])
        self.isTerminated = true
        DispatchQueue.main.async {
            self.webView.removeFromSuperview()
        }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {

        guard let event = message.body as? String else { return }
        let eventJson = safeParseJson(jsonString: event)

        let eventName = eventJson["eventName"] as? String ?? ""
        let eventData = eventJson["eventData"] as? String ?? ""
        let eventDataJson = safeParseJson(jsonString: eventData)

        if eventName == "appReady" {
            sendInitiate()
        }
        if eventName == "callbackEvent" {
            self.callbackFn(eventDataJson)
        }
        if eventName == "consumeBackPress" {
            consumingBackPress = true
        }
        if eventName == "releaseBackPress" {
            consumingBackPress = false
        }
        if eventName == "renderView" {
            renderView()
        }
        if eventName == "hideView" {
            hideView()
        }
        if eventName == "invokeMethod" {
            handleInvokeMethod(eventDataJson)
        }
    }

    private func sendEvent(event: String, payload: [String: Any]) {

        let eventMessage: [String: Any] = [
            "eventName": event,
            "eventData": payload,
            "source": "blaze",
        ]

        runOnMain {
            if self.isWebViewReady {
                let jsonData = try? JSONSerialization.data(
                    withJSONObject: eventMessage)
                let jsonString = String(data: jsonData!, encoding: .utf8)!
                self.webView.evaluateJavaScript(
                    "onSDKEvent(JSON.stringify(\(jsonString)))")
            } else {
                self.eventQueue[event] = payload
            }
        }
    }

    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private func drainEventQueue() {
        let pendingEvents = eventQueue
        eventQueue.removeAll()
        for (event, payload) in pendingEvents {
            sendEvent(event: event, payload: payload)
        }
    }

    private func sendInitiate() {
        if isTerminated {
            return
        }
        let safeMargin = getSafeMargin()
        lastSafeMargin = safeMargin
        if var initiate = eventQueue["initiate"], var payload = initiate["payload"] as? [String: Any] {
            payload["_sdkParams"] = SdkParams(safeMargin: safeMargin).toJson()
            initiate["payload"] = payload
            eventQueue["initiate"] = initiate
        }
        isWebViewReady = true
        drainEventQueue()
    }

    private func sendSafeMarginIfChanged() {
        if isTerminated || lastSafeMargin == nil {
            return
        }
        let safeMargin = getSafeMargin()
        if safeMargin != lastSafeMargin {
            lastSafeMargin = safeMargin
            sendEvent(event: "_sdkParams", payload: SdkParams(safeMargin: safeMargin).toJson())
        }
    }

    private func getContainer() -> UIView {
        return self.container ?? self.context.view.window ?? self.context.view
    }

    private func renderView() {
        DispatchQueue.main.async {
            if self.container == nil && self.context.view.window == nil {
                print("BlazeSDK: host view has no window, falling back to the view controller's view.")
            }
            let host = self.getContainer()

            self.webView.frame = host.bounds
            self.webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            host.addSubview(self.webView)
        }
    }

    private func getSafeMargin() -> SafeMargin {
        let view: UIView = self.webView.window != nil ? self.webView : getContainer()
        let insets = view.safeAreaInsets
        return SafeMargin(
            top: Int(insets.top.rounded()),
            right: Int(insets.right.rounded()),
            bottom: Int(insets.bottom.rounded()),
            left: Int(insets.left.rounded())
        )
    }

    private func hideView() {
        DispatchQueue.main.async {
            self.webView.removeFromSuperview()
            self.webView.frame = .zero
        }
    }

    func openApp(payload: String) -> String {
        if let appURL = URL(string: payload),
            UIApplication.shared.canOpenURL(appURL)
        {
            UIApplication.shared.open(appURL, options: [:])
        }
        return "unknonw"
    }

    private func getFromStorage(key: String) -> String? {
        return UserDefaults.standard.string(forKey: key)
    }

    private func canOpen(payload: String) -> Bool {
        if let appURL = URL(string: payload) {
            return UIApplication.shared.canOpenURL(appURL)
        }
        return false
    }

    private func saveToStorage(key: String, value: String) -> Bool {
        UserDefaults.standard.set(value, forKey: key)
        return true
    }

    private func handleInvokeMethod(_ eventData: [String: Any]) {
        guard let methodName = eventData["methodName"] as? String,
            let requestId = eventData["requestId"] as? String,
            let params = eventData["params"] as? String
        else {
            return
        }

        let paramsJson = safeParseJson(jsonString: params)

        var invokeResult: [String: Any] = [
            "requestId": requestId, "methodName": methodName,
        ]

        switch methodName {
        case "saveToStorage":
            if let key = paramsJson["key"] as? String,
                let value = paramsJson["value"] as? String
            {
                invokeResult["methodResult"] = saveToStorage(
                    key: key, value: value)
            }
        case "openApp":
            if let intentUri = paramsJson["intentUri"] as? String {
                invokeResult["methodResult"] = openApp(payload: intentUri)
            }
        case "getFromStorage":
            if let key = paramsJson["key"] as? String {
                let value = getFromStorage(key: key)
                invokeResult["methodResult"] = ["key": key, "value": value]
            }
        case "canOpen":
            if let payload = paramsJson["payload"] as? String {
                invokeResult["methodResult"] = canOpen(payload: payload)
            }
        default:
            invokeResult["methodResult"] = "Method not found"
        }

        sendEvent(event: "invokeMethodResult", payload: invokeResult)
    }

}

extension BlazeWebView: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if isUPIIntentUri(url), canOpen(payload: url.absoluteString) {
            let _ = openApp(payload: url.absoluteString)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}
