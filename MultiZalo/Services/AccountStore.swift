import Foundation
import SwiftUI
import UIKit

@MainActor
final class AccountStore: ObservableObject {
    @Published var accounts: [ZaloAccount] = []
    @Published var activeAccountID: UUID? {
        didSet {
            saveActiveAccountID()
        }
    }

    private let accountsKey = "multizalo.accounts.v1"
    private let activeAccountKey = "multizalo.activeAccountID.v1"

    init() {
        loadAccounts()
    }

    static func recommendedZoomScale() -> Double {
        UIDevice.current.userInterfaceIdiom == .phone ? 0.80 : 1.0
    }

    var activeAccount: ZaloAccount? {
        guard let activeAccountID else { return nil }
        return accounts.first(where: { $0.id == activeAccountID })
    }

    @discardableResult
    func addAccount(
        name: String,
        note: String = "",
        color: AccountColor = .blue,
        zoomScale: Double? = nil
    ) -> ZaloAccount {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "Zalo \(accounts.count + 1)" : trimmedName
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedZoom = zoomScale ?? Self.recommendedZoomScale()

        let newAccount = ZaloAccount(
            name: finalName,
            note: trimmedNote,
            color: color,
            zoomScale: resolvedZoom
        )
        accounts.append(newAccount)
        saveAccounts()
        activeAccountID = newAccount.id
        return newAccount
    }

    func updateAccount(_ updated: ZaloAccount) {
        guard let index = accounts.firstIndex(where: { $0.id == updated.id }) else { return }
        var normalized = updated
        let trimmedName = updated.name.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.name = trimmedName.isEmpty ? accounts[index].name : trimmedName
        normalized.note = updated.note.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.zoomScale = ZaloAccount.clampedZoom(updated.zoomScale)

        accounts[index] = normalized
        saveAccounts()
    }

    func updateZoom(for accountID: UUID, zoomScale: Double) {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else { return }
        accounts[index].zoomScale = ZaloAccount.clampedZoom(zoomScale)
        saveAccounts()
    }

    func rotateDataStoreID(for accountID: UUID) -> (updatedAccount: ZaloAccount, oldDataStoreID: UUID)? {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else { return nil }
        let oldDataStoreID = accounts[index].dataStoreID
        accounts[index].dataStoreID = UUID()
        saveAccounts()
        return (accounts[index], oldDataStoreID)
    }

    @discardableResult
    func deleteAccount(id: UUID) -> ZaloAccount? {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = accounts.remove(at: index)
        saveAccounts()

        if activeAccountID == id {
            if accounts.isEmpty {
                activeAccountID = nil
            } else {
                let nextIndex = min(index, accounts.count - 1)
                activeAccountID = accounts[nextIndex].id
            }
        }
        return removed
    }

    func moveAccounts(from offsets: IndexSet, to destination: Int) {
        accounts.move(fromOffsets: offsets, toOffset: destination)
        saveAccounts()
    }

    private func loadAccounts() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: accountsKey),
           let decoded = try? JSONDecoder().decode([ZaloAccount].self, from: data) {
            self.accounts = decoded
        } else {
            let defaultZoom = Self.recommendedZoomScale()
            let initialAccounts = [
                ZaloAccount(name: "Zalo Chính", note: "Tài khoản 1", color: .blue, zoomScale: defaultZoom),
                ZaloAccount(name: "Zalo Phụ", note: "Tài khoản 2", color: .teal, zoomScale: defaultZoom)
            ]
            self.accounts = initialAccounts
            saveAccounts()
        }

        if let savedIDString = defaults.string(forKey: activeAccountKey),
           let savedUUID = UUID(uuidString: savedIDString),
           accounts.contains(where: { $0.id == savedUUID }) {
            self.activeAccountID = savedUUID
        } else {
            self.activeAccountID = accounts.first?.id
        }
        saveActiveAccountID()
    }

    private func saveAccounts() {
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: accountsKey)
        }
    }

    private func saveActiveAccountID() {
        if let activeAccountID {
            UserDefaults.standard.set(activeAccountID.uuidString, forKey: activeAccountKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeAccountKey)
        }
    }
}
