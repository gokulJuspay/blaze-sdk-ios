import BlazeSDK
import UIKit

class ViewController: UIViewController, UITextViewDelegate {

    static let storageKey = "blaze-shop-example"
    static let primaryColor = UIColor(red: 0x8B / 255, green: 0x5C / 255, blue: 0xF6 / 255, alpha: 1)

    var blaze: Blaze?

    let initiateEditor = UITextView()
    let processEditor = UITextView()
    let errorLabel = UILabel()
    lazy var processButton = makeButton("Process SDK", action: #selector(processSDK), primary: true)
    let logView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setUpViews()
        applySettings(loadSettings())
    }

    func createSDKPayload(payload: [String: Any]) -> [String: Any] {
        var sdkPayload = [String: Any]()
        sdkPayload["requestId"] = UUID().uuidString
        sdkPayload["service"] = "in.breeze.shop"
        sdkPayload["payload"] = payload
        return sdkPayload
    }

    func createInitiatePayload() -> [String: Any] {
        var initiatePayload = [String: Any]()
        initiatePayload["action"] = "initiate"
        initiatePayload["publisherId"] = "demo"
        initiatePayload["environment"] = "beta"
        return initiatePayload
    }

    func createProcessPayload() -> [String: Any] {
        var processPayload = [String: Any]()
        processPayload["action"] = "launch"
        return processPayload
    }

    func defaultSettings() -> [String: String] {
        return [
            "initiate": prettyJSON(createSDKPayload(payload: createInitiatePayload())),
            "process": prettyJSON(createSDKPayload(payload: createProcessPayload())),
        ]
    }

    func loadSettings() -> [String: String] {
        let saved = UserDefaults.standard.dictionary(forKey: ViewController.storageKey) as? [String: String] ?? [:]
        return defaultSettings().merging(saved) { _, saved in saved }
    }

    func applySettings(_ settings: [String: String]) {
        initiateEditor.text = settings["initiate"]
        processEditor.text = settings["process"]
    }

    func saveSettings() {
        let settings = ["initiate": initiateEditor.text ?? "", "process": processEditor.text ?? ""]
        UserDefaults.standard.set(settings, forKey: ViewController.storageKey)
    }

    func textViewDidChange(_ textView: UITextView) {
        saveSettings()
    }

    func log(direction: String, eventName: String, eventData: [String: Any]?) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let data = eventData.map(prettyJSON) ?? ""
        logView.text = "\(time) \(direction) \(eventName)\n\(data)\n\n" + logView.text
    }

    func showError(_ message: String?) {
        errorLabel.text = message
        errorLabel.isHidden = message == nil
    }

    func readPayload(_ editor: UITextView, name: String) -> [String: Any]? {
        showError(nil)
        do {
            if let payload = try JSONSerialization.jsonObject(with: Data(editor.text.utf8)) as? [String: Any] {
                return payload
            }
            showError("\(name): expected a JSON object")
        } catch {
            showError("\(name): \(error.localizedDescription)")
        }
        return nil
    }

    func prettyJSON(_ json: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        else {
            return "\(json)"
        }
        return String(decoding: data, as: UTF8.self)
    }

    @objc func initiateSDK() {
        guard let payload = readPayload(initiateEditor, name: "Initiate payload") else { return }
        terminateSDK()
        // A terminated Blaze ignores initiate, so each initiate needs a new instance.
        let blaze = Blaze()
        self.blaze = blaze
        log(direction: "→", eventName: "initiate", eventData: payload)
        blaze.initiate(
            context: self, initiatePayload: payload,
            callbackFn: { [weak self] event in
                // Callbacks can arrive off the main thread.
                DispatchQueue.main.async {
                    self?.onSDKEvent(event)
                }
            })
    }

    func onSDKEvent(_ event: [String: Any]) {
        let eventName = (event["payload"] as? [String: Any])?["eventName"] as? String ?? "callback"
        log(direction: "←", eventName: eventName, eventData: event)
        if eventName == "initiate" {
            setProcessEnabled(true)
        }
    }

    @objc func processSDK() {
        guard let payload = readPayload(processEditor, name: "Process payload") else { return }
        log(direction: "→", eventName: "process", eventData: payload)
        blaze?.process(payload: payload)
    }

    @objc func terminateSDK() {
        guard let blaze = blaze else { return }
        log(direction: "→", eventName: "terminate", eventData: nil)
        blaze.terminate()
        self.blaze = nil
        setProcessEnabled(false)
    }

    // process() before the initiate callback can crash: Blaze creates its web view asynchronously.
    func setProcessEnabled(_ enabled: Bool) {
        processButton.isEnabled = enabled
        processButton.alpha = enabled ? 1 : 0.5
    }

    @objc func resetPayloads() {
        UserDefaults.standard.removeObject(forKey: ViewController.storageKey)
        applySettings(defaultSettings())
        showError(nil)
    }

    @objc func clearLog() {
        logView.text = ""
    }

    func setUpViews() {
        for editor in [initiateEditor, processEditor, logView] {
            editor.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
            editor.autocapitalizationType = .none
            editor.autocorrectionType = .no
            editor.spellCheckingType = .no
            editor.smartQuotesType = .no
            editor.smartDashesType = .no
            editor.smartInsertDeleteType = .no
            editor.layer.borderWidth = 1
            editor.layer.borderColor = UIColor.separator.cgColor
            editor.layer.cornerRadius = 8
        }
        initiateEditor.delegate = self
        processEditor.delegate = self
        logView.isEditable = false

        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        setProcessEnabled(false)

        let buttons = UIStackView(arrangedSubviews: [
            makeButton("Initiate SDK", action: #selector(initiateSDK), primary: true),
            processButton,
            makeButton("Terminate SDK", action: #selector(terminateSDK)),
            makeButton("Reset", action: #selector(resetPayloads)),
        ])
        buttons.axis = .vertical
        buttons.spacing = 8

        let messagesHeader = UIStackView(arrangedSubviews: [
            makeLabel("Messages"), makeButton("Clear", action: #selector(clearLog)),
        ])
        messagesHeader.distribution = .equalSpacing

        let stack = UIStackView(arrangedSubviews: [
            makeLabel("Initiate payload"), initiateEditor,
            makeLabel("Process payload"), processEditor,
            errorLabel, buttons, messagesHeader, logView,
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .onDrag
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)

        let dismissKeyboard = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        dismissKeyboard.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(dismissKeyboard)

        let bottomAnchor: NSLayoutYAxisAnchor
        if #available(iOS 15.0, *) {
            bottomAnchor = view.keyboardLayoutGuide.topAnchor
        } else {
            bottomAnchor = view.bottomAnchor
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            initiateEditor.heightAnchor.constraint(equalToConstant: 200),
            processEditor.heightAnchor.constraint(equalToConstant: 150),
            logView.heightAnchor.constraint(equalToConstant: 300),
        ])
    }

    func makeLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .headline)
        return label
    }

    func makeButton(_ title: String, action: Selector, primary: Bool = false) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.addTarget(view, action: #selector(UIView.endEditing(_:)), for: .touchUpInside)
        button.addTarget(self, action: action, for: .touchUpInside)
        if primary {
            button.backgroundColor = ViewController.primaryColor
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 8
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        }
        return button
    }

}
