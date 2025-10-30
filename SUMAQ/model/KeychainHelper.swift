//
//  KeychainHelper.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/10/25.

// LOCAL STORAGE STRATEGY # 3 KeyChain : Maria



import Foundation
import Security

final class KeychainHelper {
    static let shared = KeychainHelper() // Local storage: Singleton instance for centralized access.
    private init() {}

    private let service = "com.sumaq.app" // UPDATE: Service identifier for Keychain items.
    private let emailKey = "last_login_email" // UPDATE: Key name for storing email.

    // UPDATE: Saves the last successful login email securely in Keychain.
    func saveLastLoginEmail(_ email: String) {
        guard let data = email.data(using: .utf8) else { return }

        // Remove existing item if any before adding new.
        deleteLastLoginEmail()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: emailKey,
            kSecValueData as String: data
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    // UPDATE: Retrieves the last saved email from Keychain.
    func getLastLoginEmail() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: emailKey,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // UPDATE: Deletes the stored email from Keychain (used on logout if needed).
    func deleteLastLoginEmail() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: emailKey
        ]

        SecItemDelete(query as CFDictionary)
    }
}
