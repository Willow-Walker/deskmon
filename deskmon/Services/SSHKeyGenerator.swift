import Citadel
import Crypto
import Foundation
import os

/// Generates ed25519 SSH key pairs and installs public keys on remote servers.
enum SSHKeyGenerator {

    private static let log = Logger(subsystem: "prowlsh.deskmon", category: "SSHKeyGenerator")

    /// Generated key pair — private key data for Keychain storage plus the public key string for authorized_keys.
    struct KeyPair: Sendable {
        /// Raw 32-byte ed25519 private key seed for Keychain storage.
        let privateKeyData: Data
        /// The Curve25519 signing key (for Citadel auth).
        let privateKey: Curve25519.Signing.PrivateKey
        /// OpenSSH-formatted public key line (e.g. "ssh-ed25519 AAAA... deskmon@mac").
        let authorizedKeysLine: String
    }

    /// Generate a new ed25519 key pair.
    static func generateKeyPair() -> KeyPair {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKeyData = privateKey.publicKey.rawRepresentation

        // Build OpenSSH-format public key: "ssh-ed25519 <base64> <comment>"
        // The base64 payload is: [4-byte type-length]["ssh-ed25519"][4-byte key-length][32-byte key]
        let keyType = "ssh-ed25519"
        let keyTypeBytes = Array(keyType.utf8)

        var blob = Data()
        // Type string length (big-endian UInt32)
        var typeLen = UInt32(keyTypeBytes.count).bigEndian
        blob.append(Data(bytes: &typeLen, count: 4))
        blob.append(Data(keyTypeBytes))
        // Key data length
        var keyLen = UInt32(publicKeyData.count).bigEndian
        blob.append(Data(bytes: &keyLen, count: 4))
        blob.append(publicKeyData)

        let base64Key = blob.base64EncodedString()
        let authorizedKeysLine = "\(keyType) \(base64Key) deskmon"

        log.info("Generated ed25519 key pair")

        return KeyPair(
            privateKeyData: Data(privateKey.rawRepresentation),
            privateKey: privateKey,
            authorizedKeysLine: authorizedKeysLine
        )
    }

    /// Reconstruct a Curve25519 signing key from stored raw representation.
    static func privateKey(from data: Data) throws -> Curve25519.Signing.PrivateKey {
        try Curve25519.Signing.PrivateKey(rawRepresentation: data)
    }

    /// Install a public key on the remote server via SSH exec.
    /// Appends to ~/.ssh/authorized_keys if not already present.
    static func installPublicKey(
        on sshManager: SSHManager,
        authorizedKeysLine: String
    ) async throws {
        // Escape single quotes in the key line
        let escapedKey = authorizedKeysLine.replacingOccurrences(of: "'", with: "'\\''")

        let command = """
        mkdir -p ~/.ssh && \
        chmod 700 ~/.ssh && \
        touch ~/.ssh/authorized_keys && \
        chmod 600 ~/.ssh/authorized_keys && \
        grep -qF '\(escapedKey)' ~/.ssh/authorized_keys 2>/dev/null || \
        echo '\(escapedKey)' >> ~/.ssh/authorized_keys
        """

        log.info("Installing public key on remote server")
        let output = try await sshManager.executeCommand(command)
        if !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            log.info("Key install output: \(output)")
        }
        log.info("Public key installed successfully")
    }
}
