import Foundation
import Security

enum KeychainStore {
    private static let service = "prowlsh.deskmon"

    enum KeychainError: LocalizedError {
        case saveFailed(OSStatus)
        case dataConversion

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status): "Keychain save failed: \(status)"
            case .dataConversion: "Failed to convert keychain data"
            }
        }
    }

    // MARK: - Generic Operations

    static func save(account: String, data: Data) throws {
        // Delete existing item first to avoid errSecDuplicateItem
        delete(account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - SSH Password

    static func savePassword(_ password: String, for serverID: UUID) throws {
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.dataConversion
        }
        try save(account: "ssh-password-\(serverID.uuidString)", data: data)
    }

    static func loadPassword(for serverID: UUID) -> String? {
        guard let data = load(account: "ssh-password-\(serverID.uuidString)") else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deletePassword(for serverID: UUID) {
        delete(account: "ssh-password-\(serverID.uuidString)")
    }

    // MARK: - SSH Private Key

    static func savePrivateKey(_ keyData: Data, for serverID: UUID) throws {
        try save(account: "ssh-key-\(serverID.uuidString)", data: keyData)
    }

    static func loadPrivateKey(for serverID: UUID) -> Data? {
        load(account: "ssh-key-\(serverID.uuidString)")
    }

    static func deletePrivateKey(for serverID: UUID) {
        delete(account: "ssh-key-\(serverID.uuidString)")
    }

    // MARK: - PIN Hash

    static func savePINHash(_ hash: Data) throws {
        try save(account: "app-lock-pin", data: hash)
    }

    static func loadPINHash() -> Data? {
        load(account: "app-lock-pin")
    }

    static func deletePINHash() {
        delete(account: "app-lock-pin")
    }

    // MARK: - Cleanup

    /// Remove all credentials for a server (password + private key).
    static func deleteAll(for serverID: UUID) {
        deletePassword(for: serverID)
        deletePrivateKey(for: serverID)
    }
}
