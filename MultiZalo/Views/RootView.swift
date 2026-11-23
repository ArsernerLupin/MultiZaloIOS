import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var sessionPool: WebViewSessionPool

    @State private var editorMode: AccountEditorMode?
    @State private var showingManagement = false
    @State private var accountPendingReset: ZaloAccount?

    private let zoomPresets: [Double] = [0.70, 0.80, 0.90, 1.00, 1.15]

    private var activeAccount: ZaloAccount? {
        accountStore.activeAccount
    }

    private var activeSession: ManagedWebSession? {
        guard let activeAccount else { return nil }
        return sessionPool.sessions[activeAccount.id]
    }

    var body: some View {
        VStack(spacing: 0) {
            topSwitcherBar

            if let activeSession {
                ActiveSessionStatusOverlay(session: activeSession) {
                    sessionPool.reload(accountID: activeSession.accountID)
                }
            }

            ZStack(alignment: .bottom) {
                if accountStore.accounts.isEmpty {
                    emptyAccountsView
                } else {
                    PersistentWebHostView(
                        sessions: sessionPool.sessions,
                        activeAccountID: accountStore.activeAccountID
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if let toast = sessionPool.toastMessage {
                    Text(toast)
                        .font(.footnote.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.black.opacity(0.82))
                        .clipShape(Capsule())
                        .padding(.bottom, 18)
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: sessionPool.toastMessage)
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            ensureActiveSession()
        }
        .onChange(of: accountStore.activeAccountID) { _, _ in
            ensureActiveSession()
        }
        .sheet(item: $editorMode) { mode in
            AccountEditorSheet(
                mode: mode,
                defaultZoomScale: AccountStore.recommendedZoomScale()
            ) { name, note, color, zoomScale in
                switch mode {
                case .add:
                    let created = accountStore.addAccount(
                        name: name,
                        note: note,
                        color: color,
                        zoomScale: zoomScale
                    )
                    sessionPool.ensureSession(for: created)
                case .edit(var existing):
                    existing.name = name
                    existing.note = note
                    existing.color = color
                    existing.zoomScale = zoomScale
                    accountStore.updateAccount(existing)
                    sessionPool.updateZoom(for: existing.id, zoomScale: zoomScale)
                }
            }
        }
        .sheet(isPresented: $showingManagement) {
            AccountManagementSheet()
        }
        .sheet(item: $sessionPool.pendingShareURL) { item in
            ActivityShareSheet(url: item.url)
        }
        .alert("Đăng xuất & Xóa dữ liệu?", isPresented: Binding(
            get: { accountPendingReset != nil },
            set: { if !$0 { accountPendingReset = nil } }
        )) {
            Button("Hủy", role: .cancel) {
                accountPendingReset = nil
            }
            Button("Xóa dữ liệu", role: .destructive) {
                guard let target = accountPendingReset else { return }
                accountPendingReset = nil
                Task {
                    if let rotated = accountStore.rotateDataStoreID(for: target.id) {
                        await sessionPool.destroySessionAndRemoveData(
                            accountID: target.id,
                            dataStoreID: rotated.oldDataStoreID
                        )
                        if accountStore.activeAccountID == target.id {
                            sessionPool.ensureSession(for: rotated.updatedAccount)
                        }
                        sessionPool.showToast("Đã đăng xuất và xóa dữ liệu của \(target.name)")
                    }
                }
            }
        } message: {
            if let accountPendingReset {
                Text("Phiên đăng nhập Zalo Web của \"\(accountPendingReset.name)\" sẽ bị xóa sạch để đăng nhập tài khoản khác.")
            }
        }
    }

    private var topSwitcherBar: some View {
        HStack(spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(accountStore.accounts) { account in
                            let isSelected = (account.id == accountStore.activeAccountID)
                            Group {
                                if let session = sessionPool.sessions[account.id] {
                                    RunningAccountTabPillView(
                                        account: account,
                                        session: session,
                                        isSelected: isSelected
                                    ) {
                                        accountStore.activeAccountID = account.id
                                    }
                                } else {
                                    IdleAccountTabPillView(
                                        account: account,
                                        isSelected: isSelected
                                    ) {
                                        accountStore.activeAccountID = account.id
                                    }
                                }
                            }
                            .id(account.id)
                            .contextMenu {
                                Button {
                                    editorMode = .edit(account)
                                } label: {
                                    Label("Sửa tài khoản", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    accountPendingReset = account
                                } label: {
                                    Label("Đăng xuất & Xóa dữ liệu", systemImage: "arrow.counterclockwise")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onChange(of: accountStore.activeAccountID) { _, newID in
                    if let newID {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(newID, anchor: .center)
                        }
                    }
                }
            }

            Button {
                editorMode = .add
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Thêm tài khoản Zalo")

            Menu {
                if let activeAccount {
                    Button {
                        sessionPool.reload(accountID: activeAccount.id)
                    } label: {
                        Label("Tải lại trang", systemImage: "arrow.clockwise")
                    }

                    Button {
                        sessionPool.loadHome(accountID: activeAccount.id)
                    } label: {
                        Label("Mở lại chat.zalo.me", systemImage: "house")
                    }

                    Menu {
                        ForEach(zoomPresets, id: \.self) { preset in
                            Button {
                                accountStore.updateZoom(for: activeAccount.id, zoomScale: preset)
                                sessionPool.updateZoom(for: activeAccount.id, zoomScale: preset)
                            } label: {
                                let isCurrent = abs(activeAccount.zoomScale - preset) < 0.01
                                Label(
                                    "\(Int(round(preset * 100)))%",
                                    systemImage: isCurrent ? "checkmark" : "magnifyingglass"
                                )
                            }
                        }
                    } label: {
                        Label(
                            "Thu phóng (\(Int(round(activeAccount.zoomScale * 100)))%)",
                            systemImage: "textformat.size"
                        )
                    }

                    Divider()

                    if sessionPool.runningCount > 1 {
                        Button {
                            sessionPool.hibernateInactiveSessions(keeping: activeAccount.id)
                        } label: {
                            Label("Ngủ đông phiên nền", systemImage: "moon.zzz")
                        }
                    }

                    Button(role: .destructive) {
                        accountPendingReset = activeAccount
                    } label: {
                        Label("Đăng xuất & Xóa dữ liệu tài khoản này", systemImage: "trash")
                    }

                    Divider()
                }

                Button {
                    showingManagement = true
                } label: {
                    Label("Quản lý tài khoản...", systemImage: "person.2.badge.gearshape")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Tùy chọn")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var emptyAccountsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Chưa có tài khoản Zalo nào")
                .font(.headline)

            Text("Thêm tài khoản để đăng nhập nhiều phiên Zalo Web tách biệt và chuyển đổi tức thì.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                editorMode = .add
            } label: {
                Label("Thêm tài khoản Zalo", systemImage: "plus.circle.fill")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func ensureActiveSession() {
        guard let activeAccount else { return }
        sessionPool.ensureSession(for: activeAccount)
    }
}

private struct RunningAccountTabPillView: View {
    let account: ZaloAccount
    @ObservedObject var session: ManagedWebSession
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        AccountTabPillShell(
            account: account,
            isSelected: isSelected,
            isRunning: true,
            isLoading: session.isLoading,
            unreadCount: session.unreadCount,
            onTap: onTap
        )
    }
}

private struct IdleAccountTabPillView: View {
    let account: ZaloAccount
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        AccountTabPillShell(
            account: account,
            isSelected: isSelected,
            isRunning: false,
            isLoading: false,
            unreadCount: 0,
            onTap: onTap
        )
    }
}

private struct AccountTabPillShell: View {
    let account: ZaloAccount
    let isSelected: Bool
    let isRunning: Bool
    let isLoading: Bool
    let unreadCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(account.color.swiftUIColor)
                        .frame(width: 9, height: 9)

                    if isRunning {
                        Circle()
                            .stroke(account.color.swiftUIColor.opacity(0.45), lineWidth: 2)
                            .frame(width: 13, height: 13)
                    }
                }

                Text(account.name)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                    .lineLimit(1)

                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }

                if unreadCount > 0 {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundColor(isSelected ? .white : .primary)
            .background(
                isSelected
                    ? AnyShapeStyle(account.color.swiftUIColor)
                    : AnyShapeStyle(Color(uiColor: .tertiarySystemFill))
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct ActiveSessionStatusOverlay: View {
    @ObservedObject var session: ManagedWebSession
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if session.isLoading {
                ProgressView(value: max(0.08, session.estimatedProgress))
                    .progressViewStyle(.linear)
                    .tint(.accentColor)
            }

            if let errorMessage = session.lastError {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Text(errorMessage)
                        .font(.caption)
                        .lineLimit(2)

                    Spacer()

                    Button("Thử lại", action: onRetry)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemBackground))
                .overlay(alignment: .bottom) {
                    Divider()
                }
            }
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
