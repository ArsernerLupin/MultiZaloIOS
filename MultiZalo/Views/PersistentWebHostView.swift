import SwiftUI
import UIKit
import WebKit

final class WebHostContainerView: UIView {
    var attachedViews: [UUID: WKWebView] = [:]
}

struct PersistentWebHostView: UIViewRepresentable {
    let sessions: [UUID: ManagedWebSession]
    let activeAccountID: UUID?

    func makeUIView(context: Context) -> WebHostContainerView {
        let container = WebHostContainerView()
        container.backgroundColor = .systemBackground
        return container
    }

    func updateUIView(_ uiView: WebHostContainerView, context: Context) {
        // Remove destroyed or rotated WKWebView instances
        for (accountID, attachedWebView) in uiView.attachedViews {
            if sessions[accountID]?.webView !== attachedWebView {
                attachedWebView.removeFromSuperview()
                uiView.attachedViews.removeValue(forKey: accountID)
            }
        }

        // Attach newly created live WKWebView instances
        for (accountID, session) in sessions {
            let webView = session.webView
            if uiView.attachedViews[accountID] !== webView {
                webView.translatesAutoresizingMaskIntoConstraints = false
                uiView.addSubview(webView)
                NSLayoutConstraint.activate([
                    webView.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
                    webView.trailingAnchor.constraint(equalTo: uiView.trailingAnchor),
                    webView.topAnchor.constraint(equalTo: uiView.topAnchor),
                    webView.bottomAnchor.constraint(equalTo: uiView.bottomAnchor)
                ])
                uiView.attachedViews[accountID] = webView
            }
        }

        // Toggle visibility & interaction without destroying parallel web sessions
        for (accountID, webView) in uiView.attachedViews {
            let isActive = (accountID == activeAccountID)
            if !isActive && !webView.isHidden {
                webView.endEditing(true)
            }
            webView.isHidden = !isActive
            webView.isUserInteractionEnabled = isActive
            if isActive {
                uiView.bringSubviewToFront(webView)
            }
        }
    }
}
