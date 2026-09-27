import Foundation
import Security

enum RevenueCatIdentityStore {
    private static let account = "revenuecat-app-user-id"
    private static let service = "\(Bundle.main.bundleIdentifier ?? "com.fuyao.comsuable").identity"

    /// The custom identifier survives a normal reinstall because it is stored in Keychain.
    /// StoreKit current entitlements independently cover verified Apple Account purchases.
    static func appUserID() throws -> String {
        if let existingID = try read() { return existingID }

        let newID = "homepassport_\(UUID().uuidString.lowercased())"
        do {
            try save(newID)
            return newID
        } catch IdentityError.duplicateItem {
            guard let existingID = try read() else {
                throw IdentityError.unavailable(errSecDuplicateItem)
            }
            return existingID
        }
    }

    private static func read() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let identifier = String(data: data, encoding: .utf8),
                  !identifier.isEmpty else {
                throw IdentityError.invalidStoredValue
            }
            return identifier
        case errSecItemNotFound:
            return nil
        default:
            throw IdentityError.unavailable(status)
        }
    }

    private static func save(_ identifier: String) throws {
        var query = baseQuery
        query[kSecValueData as String] = Data(identifier.utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        switch status {
        case errSecSuccess: return
        case errSecDuplicateItem: throw IdentityError.duplicateItem
        default: throw IdentityError.unavailable(status)
        }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private enum IdentityError: Error {
        case duplicateItem
        case invalidStoredValue
        case unavailable(OSStatus)
    }
}
