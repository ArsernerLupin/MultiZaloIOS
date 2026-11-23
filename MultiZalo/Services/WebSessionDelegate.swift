import Foundation
import UIKit
import WebKit

@MainActor
final class WebSessionDelegate: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    static let zaloURL = URL(string: "https://chat.zalo.me")!
    static let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"

    var onNavigationError: ((String) -> Void)?
    var onClearError: (() -> Void)?
    var onProcessTerminated: (() -> Void)?
    var onDownloadCompleted: ((URL) -> Void)?
    var onDownloadFailed: ((String) -> Void)?

    private var downloadDestinations: [ObjectIdentifier: URL] = [:]

    private let zaloDomainSuffixes = [
        "zalo.me",
        "zaloapp.com",
        "zalo.vn",
        "zdn.vn",
        "zadn.vn",
        "zing.vn",
        "zalo.cloud"
    ]

    private func isZaloDomain(_ host: String) -> Bool {
        let lowercased = host.lowercased()
        return zaloDomainSuffixes.contains { suffix in
            lowercased == suffix || lowercased.hasSuffix("." + suffix)
        }
    }

    private func isBlockedAppStoreRedirect(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        if ["zalo", "zaloapp", "itms-apps", "itms-appss"].contains(scheme) {
            return true
        }
        let host = url.host?.lowercased() ?? ""
        return host == "apps.apple.com" || host == "itunes.apple.com"
    }

    // MARK: - WKNavigationDelegate

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }

        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if isBlockedAppStoreRedirect(url) {
            decisionHandler(.cancel)
            return
        }

        let scheme = url.scheme?.lowercased() ?? ""
        if ["about", "blob", "data", "javascript"].contains(scheme) {
            decisionHandler(.allow)
            return
        }

        if scheme == "http" || scheme == "https" {
            let host = url.host ?? ""
            if navigationAction.targetFrame?.isMainFrame == true,
               navigationAction.navigationType == .linkActivated,
               !isZaloDomain(host) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
            return
        }

        if (scheme == "tel" || scheme == "mailto"), navigationAction.navigationType == .linkActivated {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.cancel)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        onClearError?()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        onProcessTerminated?()
    }

    private func handleNavigationError(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        // WebKitErrorFrameLoadInterruptedByPolicyChange (102) occurs normally when switching to download or external open
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 {
            return
        }
        onNavigationError?(error.localizedDescription)
    }

    // MARK: - WKUIDelegate

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let url = navigationAction.request.url else {
            return nil
        }
        if isBlockedAppStoreRedirect(url) {
            return nil
        }

        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "http" || scheme == "https" {
            let host = url.host ?? ""
            if isZaloDomain(host) {
                webView.load(navigationAction.request)
            } else {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        return nil
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        guard let presenter = topMostViewController() else {
            completionHandler()
            return
        }
        let alert = UIAlertController(title: "MultiZalo", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler()
        })
        presenter.present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        guard let presenter = topMostViewController() else {
            completionHandler(false)
            return
        }
        let alert = UIAlertController(title: "MultiZalo", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in
            completionHandler(false)
        })
        alert.addAction(UIAlertAction(title: "Đồng ý", style: .default) { _ in
            completionHandler(true)
        })
        presenter.present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        guard let presenter = topMostViewController() else {
            completionHandler(nil)
            return
        }
        let alert = UIAlertController(title: "MultiZalo", message: prompt, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = defaultText
        }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in
            completionHandler(nil)
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        presenter.present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        if isZaloDomain(origin.host) {
            decisionHandler(.prompt)
        } else {
            decisionHandler(.deny)
        }
    }

    private func topMostViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        let keyWindow = activeScene?.windows.first(where: { $0.isKeyWindow }) ?? activeScene?.windows.first
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }

    // MARK: - WKDownloadDelegate

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let fileManager = FileManager.default
        let downloadDir = fileManager.temporaryDirectory.appendingPathComponent("MultiZaloDownloads", isDirectory: true)

        do {
            try fileManager.createDirectory(at: downloadDir, withIntermediateDirectories: true)
        } catch {
            completionHandler(nil)
            return
        }

        let baseFilename = (suggestedFilename as NSString).lastPathComponent
        let sanitized = baseFilename
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safeFilename = sanitized.isEmpty ? "zalo_download" : sanitized

        var destinationURL = downloadDir.appendingPathComponent(safeFilename)
        let ext = destinationURL.pathExtension
        let stem = destinationURL.deletingPathExtension().lastPathComponent
        var counter = 1

        while fileManager.fileExists(atPath: destinationURL.path) {
            let candidateName = ext.isEmpty ? "\(stem)_\(counter)" : "\(stem)_\(counter).\(ext)"
            destinationURL = downloadDir.appendingPathComponent(candidateName)
            counter += 1
        }

        downloadDestinations[ObjectIdentifier(download)] = destinationURL
        completionHandler(destinationURL)
    }

    func downloadDidFinish(_ download: WKDownload) {
        let key = ObjectIdentifier(download)
        guard let destinationURL = downloadDestinations.removeValue(forKey: key) else { return }
        onDownloadCompleted?(destinationURL)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        let key = ObjectIdentifier(download)
        downloadDestinations.removeValue(forKey: key)
        onDownloadFailed?(error.localizedDescription)
    }
}
