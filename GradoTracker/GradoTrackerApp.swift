import SwiftUI
import WebKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@main
struct GradoTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            TrackerWebView()
        }
    }
}

#if os(macOS)
struct TrackerWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let webView = makeTrackerWebView()
        webView.setValue(false, forKey: "drawsBackground")
        loadTracker(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}
}
#else
struct TrackerWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = makeTrackerWebView()
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.937, green: 0.949, blue: 0.961, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        loadTracker(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
#endif

private func makeTrackerWebView() -> WKWebView {
    let contentController = WKUserContentController()
    let bridge = TrackerWebViewBridge()
    contentController.add(bridge, name: "trackerStorage")
    contentController.addUserScript(WKUserScript(
        source: TrackerWebViewBridge.storageScript,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    ))

    let configuration = WKWebViewConfiguration()
    configuration.userContentController = contentController
    let webView = WKWebView(frame: .zero, configuration: configuration)
    bridge.webView = webView
    webView.uiDelegate = bridge
    return webView
}

private final class TrackerWebViewBridge: NSObject, WKScriptMessageHandler, WKUIDelegate {
    weak var webView: WKWebView?
    private let storagePrefix = "mi-grado.web-storage."

    static let storageScript = """
    (() => {
      let sequence = 0;
      const waiting = new Map();
      const send = (operation, key, value) => new Promise(resolve => {
        const id = ++sequence;
        waiting.set(id, resolve);
        window.webkit.messageHandlers.trackerStorage.postMessage({id, operation, key, value});
      });
      window.storage = {
        get: key => send('get', key),
        set: (key, value) => send('set', key, value),
        __resolve: (id, result) => {
          const resolve = waiting.get(id);
          if (resolve) { waiting.delete(id); resolve(result); }
        }
      };
    })();
    """

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let id = body["id"] as? Int,
              let operation = body["operation"] as? String,
              let key = body["key"] as? String else { return }

        let result: Any
        switch operation {
        case "get":
            if let value = UserDefaults.standard.string(forKey: storagePrefix + key) {
                result = ["value": value]
            } else {
                result = NSNull()
            }
        case "set":
            if let value = body["value"] as? String {
                UserDefaults.standard.set(value, forKey: storagePrefix + key)
            }
            result = true
        default:
            result = NSNull()
        }

        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else { return }
        webView?.evaluateJavaScript("window.storage.__resolve(\(id), \(json))")
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "Aceptar")
        alert.runModal()
        completionHandler()
        #else
        presentAlert(message: message, on: webView, confirm: false) { _ in completionHandler() }
        #endif
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "Aceptar")
        alert.addButton(withTitle: "Cancelar")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
        #else
        presentAlert(message: message, on: webView, confirm: true, completion: completionHandler)
        #endif
    }

    #if os(iOS)
    private func presentAlert(message: String, on webView: WKWebView, confirm: Bool, completion: @escaping (Bool) -> Void) {
        guard var presenter = webView.window?.rootViewController else { completion(false); return }
        while let presented = presenter.presentedViewController { presenter = presented }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        if confirm {
            alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel) { _ in completion(false) })
        }
        alert.addAction(UIAlertAction(title: "Aceptar", style: .default) { _ in completion(true) })
        presenter.present(alert, animated: true)
    }
    #endif
}

private func loadTracker(in webView: WKWebView) {
    guard let page = Bundle.main.url(forResource: "MiGrado", withExtension: "html") else {
        webView.loadHTMLString(
            "<html lang='es'><meta name='viewport' content='width=device-width, initial-scale=1'><body style='font:16px -apple-system;padding:24px'>No se encontró la pantalla de Mi grado.</body></html>",
            baseURL: nil
        )
        return
    }

    webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
}
