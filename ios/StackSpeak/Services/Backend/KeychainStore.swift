import Foundation
import Security

/// Minimal Keychain wrapper for small, device-bound secrets (the Supabase
/// refresh token). Uses a generic-password item keyed by `service` + `account`.
///
/// Why Keychain over `UserDefaults`: the refresh token is a real-account
/// credential — losing it just forces a re-login, but leaking it (UserDefaults
/// is an unencrypted plist, readable from an unencrypted device backup) lets
/// someone mint sessions. `…ThisDeviceOnly` accessibility keeps it off iCloud
/// Keychain / encrypted backups, so it never leaves the device it was issued on.
///
/// `Sendable` (only immutable `String`s) so the `SupabaseBackendService` actor
/// can hold one. Apple frameworks only (no SPM), per CLAUDE.md.
struct KeychainStore: Sendable {
    let service: String

    init(service: String = "com.stackspeak.supabase") {
        self.service = service
    }

    /// Stores `value`, replacing any existing item for `account`. Storing `nil`
    /// deletes the item.
    func set(_ value: String?, for account: String) {
        guard let value else { delete(account); return }
        let data = Data(value.utf8)

        var query = baseQuery(account)
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        // Update in place when present, else add — avoids a duplicate-item error.
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            query.merge(attributes) { _, new in new }
            SecItemAdd(query as CFDictionary, nil)
        }
    }

    /// Returns the stored string for `account`, or nil if absent/unreadable.
    func get(_ account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    func delete(_ account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }

    private func baseQuery(_ account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
    }
}
