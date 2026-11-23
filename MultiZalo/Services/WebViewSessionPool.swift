import Foundation
import UIKit
import WebKit

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
final class ManagedWebSession: ObservableObject, Identifiable {
    let accountID: UUID
    let dataStoreID: UUID
    let webView: WKWebView
    let delegate: WebSessionDelegate

    @Published var isLoading: Bool = false
    @Published var estimatedProgress: Double = 0.0
    @Published var pageTitle: String = ""
    @Published var unreadCount: Int = 0
    @Published var lastError: String?

    private var observations: [NSKeyValueObservation] = []

    var id: UUID { accountID }

    init(
        accountID: UUID,
        dataStoreID: UUID,
        webView: WKWebView,
        delegate: WebSessionDelegate
    ) {
        self.accountID = accountID
        self.dataStoreID = dataStoreID
        self.webView = webView
        self.delegate = delegate
        attachObservers()
    }

    func teardown() {
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.removeFromSuperview()
    }

    private func attachObservers() {
        observations.append(
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] _, change in
                let loading = change.newValue ?? false
                Task { @MainActor [weak self] in
                    self?.isLoading = loading
                }
            }
        )

        observations.append(
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] _, change in
                let progress = change.newValue ?? 0.0
                Task { @MainActor [weak self] in
                    self?.estimatedProgress = progress
                }
            }
        )

        observations.append(
            webView.observe(\.title, options: [.initial, .new]) { [weak self] _, change in
                let title = (change.newValue ?? nil) ?? ""
                Task { @MainActor [weak self] in
                    self?.pageTitle = title
                    self?.unreadCount = Self.parseUnreadCount(from: title)
                }
            }
        )
    }

    static func parseUnreadCount(from title: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: #"\((\d+)\)"#) else {
            return 0
        }
        let range = NSRange(title.startIndex..<title.endIndex, in: title)
        guard let match = regex.firstMatch(in: title, range: range),
              match.numberOfRanges > 1,
              let numberRange = Range(match.range(at: 1), in: title),
              let count = Int(title[numberRange]) else {
            return 0
        }
        return count
    }
}

@MainActor
final class WebViewSessionPool: ObservableObject {
    @Published private(set) var sessions: [UUID: ManagedWebSession] = [:]
    @Published var pendingShareURL: IdentifiableURL?
    @Published var toastMessage: String?

    private var toastTask: Task<Void, Never>?

    var runningCount: Int {
        sessions.count
    }

    func isRunning(_ accountID: UUID) -> Bool {
        sessions[accountID] != nil
    }

    @discardableResult
    func ensureSession(for account: ZaloAccount) -> ManagedWebSession {
        if let existing = sessions[account.id], existing.dataStoreID == account.dataStoreID {
            existing.webView.pageZoom = CGFloat(account.zoomScale)
            return existing
        }

        if let stale = sessions.removeValue(forKey: account.id) {
            stale.teardown()
        }

        let dataStore = WKWebsiteDataStore(forIdentifier: account.dataStoreID)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = WebSessionDelegate.desktopUserAgent
        webView.pageZoom = CGFloat(account.zoomScale)
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = true
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground

        let delegate = WebSessionDelegate()
        webView.navigationDelegate = delegate
        webView.uiDelegate = delegate

        let session = ManagedWebSession(
            accountID: account.id,
            dataStoreID: account.dataStoreID,
            webView: webView,
            delegate: delegate
        )

        delegate.onNavigationError = { [weak session] message in
            session?.lastError = message
        }
        delegate.onClearError = { [weak session] in
            session?.lastError = nil
        }
        delegate.onProcessTerminated = { [weak session, weak self] in
            guard let session else { return }
            session.webView.reload()
            self?.showToast("Phiên web vừa được khởi động lại tự động")
        }
        delegate.onDownloadCompleted = { [weak self] fileURL in
            self?.pendingShareURL = IdentifiableURL(url: fileURL)
        }
        delegate.onDownloadFailed = { [weak self] errorMessage in
            self?.showToast("Tải tệp thất bại: \(errorMessage)")
        }

        sessions[account.id] = session
        webView.load(URLRequest(url: WebSessionDelegate.zaloURL))
        return session
    }

    func updateZoom(for accountID: UUID, zoomScale: Double) {
        guard let session = sessions[accountID] else { return }
        session.webView.pageZoom = CGFloat(ZaloAccount.clampedZoom(zoomScale))
    }

    func reload(accountID: UUID) {
        guard let session = sessions[accountID] else { return }
        session.lastError = nil
        if session.webView.url != nil {
            session.webView.reload()
        } else {
            session.webView.load(URLRequest(url: WebSessionDelegate.zaloURL))
        }
    }

    func loadHome(accountID: UUID) {
        guard let session = sessions[accountID] else { return }
        session.lastError = nil
        session.webView.load(URLRequest(url: WebSessionDelegate.zaloURL))
    }

    @discardableResult
    func hibernateInactiveSessions(keeping activeAccountID: UUID?) -> Int {
        let inactiveIDs = sessions.keys.filter { $0 != activeAccountID }
        for id in inactiveIDs {
            if let session = sessions.removeValue(forKey: id) {
                session.teardown()
            }
        }
        if !inactiveIDs.isEmpty {
            showToast("Đã ngủ đông \(inactiveIDs.count) phiên nền để tiết kiệm RAM")
        }
        return inactiveIDs.count
    }

    func destroySessionAndRemoveData(accountID: UUID, dataStoreID: UUID) async {
        if let existing = sessions.removeValue(forKey: accountID) {
            existing.teardown()
        }

        // Wait briefly so WebKit releases file handles held by the destroyed WKWebView
        try? await Task.sleep(nanoseconds: 250_000_000)

        do {
            try await WKWebsiteDataStore.remove(forIdentifier: dataStoreID)
        } catch {
            let store = WKWebsiteDataStore(forIdentifier: dataStoreID)
            let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()
            await store.removeData(ofTypes: allTypes, modifiedSince: .distantPast)
        }
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }
}
