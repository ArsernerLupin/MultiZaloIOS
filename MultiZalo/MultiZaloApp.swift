import SwiftUI

@main
struct MultiZaloApp: App {
    @StateObject private var accountStore = AccountStore()
    @StateObject private var sessionPool = WebViewSessionPool()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(accountStore)
                .environmentObject(sessionPool)
        }
    }
}
