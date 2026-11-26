import Foundation
import Security

/// Where the development token lives. The Keychain in the app; memory in tests.
protocol AdvisorTokenStoring: Sendable {
    func read() -> String?
    /// An empty token deletes the stored one.
    func write(_ token: String)
}

/// Keeps the development token in the Keychain, on this device only, readable after first unlock.
struct KeychainAdvisorTokenStore: AdvisorTokenStoring {
    var service = "com.balizticzero.app.advisor"
    var account = "developmentToken"

    func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func write(_ token: String) {
        guard !token.isEmpty else {
            SecItemDelete(baseQuery as CFDictionary)
            return
        }
        let data = Data(token.utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

extension AdvisorTokenStoring {
    /// Reads the token, first moving one that an earlier build left in UserDefaults.
    func loadMovingLegacyDefault(key: String, defaults: UserDefaults = .standard) -> String {
        if let legacy = defaults.string(forKey: key) {
            if !legacy.isEmpty, read() == nil {
                write(legacy)
            }
            // Drop the plain copy only once the Keychain holds a token, so a failed write loses nothing.
            if legacy.isEmpty || read() != nil {
                defaults.removeObject(forKey: key)
            } else {
                return legacy
            }
        }
        return read() ?? ""
    }
}
