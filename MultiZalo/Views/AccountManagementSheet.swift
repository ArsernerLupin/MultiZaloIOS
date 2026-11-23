import SwiftUI

struct AccountManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var sessionPool: WebViewSessionPool

    @State private var editorMode: AccountEditorMode?
    @State private var accountToReset: ZaloAccount?
    @State private var accountToDelete: ZaloAccount?

    private var backgroundRunningCount: Int {
        guard let activeID = accountStore.activeAccountID else {
            return sessionPool.runningCount
        }
        return sessionPool.sessions.keys.filter { $0 != activeID }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if accountStore.accounts.isEmpty {
                        Text("Chưa có tài khoản nào. Nhấn \"Thêm\" ở góc trên để tạo không gian Zalo mới.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(accountStore.accounts) { account in
                            AccountManagementRow(
                                account: account,
                                isActive: account.id == accountStore.activeAccountID,
                                session: sessionPool.sessions[account.id],
                                onSelect: {
                                    accountStore.activeAccountID = account.id
                                    dismiss()
                                },
                                onEdit: {
                                    editorMode = .edit(account)
                                },
                                onReset: {
                                    accountToReset = account
                                },
                                onDelete: {
                                    accountToDelete = account
                                }
                            )
                        }
                        .onMove(perform: accountStore.moveAccounts)
                    }
                } header: {
                    Text("Danh sách tài khoản (\(accountStore.accounts.count))")
                } footer: {
                    Text("Mỗi tài khoản lưu cookie và bộ nhớ riêng biệt hoàn toàn. Nhấn Edit để kéo thả sắp xếp thứ tự tab.")
                }

                Section {
                    HStack {
                        Label("Phiên đang mở trong RAM", systemImage: "cpu")
                        Spacer()
                        Text("\(sessionPool.runningCount) / \(accountStore.accounts.count)")
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }

                    Button {
                        sessionPool.hibernateInactiveSessions(keeping: accountStore.activeAccountID)
                    } label: {
                        Label("Ngủ đông các phiên nền (Giải phóng RAM)", systemImage: "moon.zzz")
                    }
                    .disabled(backgroundRunningCount == 0)
                } header: {
                    Text("Phiên chạy song song")
                } footer: {
                    Text("Ngủ đông chỉ đóng tab nền để tiết kiệm bộ nhớ, không làm mất phiên đăng nhập của bạn.")
                }
            }
            .navigationTitle("Quản lý tài khoản")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !accountStore.accounts.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        editorMode = .add
                    } label: {
                        Label("Thêm", systemImage: "plus")
                    }
                    Button("Xong") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
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
            .alert("Đăng xuất & Xóa dữ liệu?", isPresented: Binding(
                get: { accountToReset != nil },
                set: { if !$0 { accountToReset = nil } }
            )) {
                Button("Hủy", role: .cancel) {
                    accountToReset = nil
                }
                Button("Xóa dữ liệu", role: .destructive) {
                    guard let target = accountToReset else { return }
                    accountToReset = nil
                    Task {
                        if let rotated = accountStore.rotateDataStoreID(for: target.id) {
                            await sessionPool.destroySessionAndRemoveData(
                                accountID: target.id,
                                dataStoreID: rotated.oldDataStoreID
                            )
                            if accountStore.activeAccountID == target.id {
                                sessionPool.ensureSession(for: rotated.updatedAccount)
                            }
                            sessionPool.showToast("Đã xóa sạch phiên đăng nhập của \(target.name)")
                        }
                    }
                }
            } message: {
                if let accountToReset {
                    Text("Cookie và phiên đăng nhập của \"\(accountToReset.name)\" sẽ bị xóa để đăng nhập tài khoản khác.")
                }
            }
            .alert("Xóa tài khoản?", isPresented: Binding(
                get: { accountToDelete != nil },
                set: { if !$0 { accountToDelete = nil } }
            )) {
                Button("Hủy", role: .cancel) {
                    accountToDelete = nil
                }
                Button("Xóa vĩnh viễn", role: .destructive) {
                    guard let target = accountToDelete else { return }
                    accountToDelete = nil
                    if let removed = accountStore.deleteAccount(id: target.id) {
                        Task {
                            await sessionPool.destroySessionAndRemoveData(
                                accountID: removed.id,
                                dataStoreID: removed.dataStoreID
                            )
                            sessionPool.showToast("Đã xóa tài khoản \(removed.name)")
                        }
                    }
                }
            } message: {
                if let accountToDelete {
                    Text("Tài khoản \"\(accountToDelete.name)\" và toàn bộ dữ liệu đăng nhập riêng của nó sẽ bị xóa khỏi thiết bị.")
                }
            }
        }
    }
}

private struct AccountManagementRow: View {
    let account: ZaloAccount
    let isActive: Bool
    let session: ManagedWebSession?
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onReset: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(account.color.swiftUIColor)
                        .frame(width: 14, height: 14)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(account.name)
                                .font(.body.weight(isActive ? .semibold : .regular))
                                .foregroundColor(.primary)

                            if isActive {
                                Text("Đang xem")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundColor(.accentColor)
                                    .clipShape(Capsule())
                            }
                        }

                        if !account.note.isEmpty {
                            Text(account.note)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let session {
                            RunningSessionStatusLabel(session: session)
                        } else {
                            Text("Chưa mở / Ngủ đông")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Chỉnh sửa", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    onReset()
                } label: {
                    Label("Đăng xuất & Xóa dữ liệu", systemImage: "arrow.counterclockwise")
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Xóa tài khoản", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Xóa", systemImage: "trash")
            }
            Button(action: onEdit) {
                Label("Sửa", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}

private struct RunningSessionStatusLabel: View {
    @ObservedObject var session: ManagedWebSession

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                Text("Đang chạy song song")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.green)
            }

            if session.unreadCount > 0 {
                Text("\(session.unreadCount) tin mới")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
    }
}
