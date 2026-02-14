import CryptoKit
import Foundation
import os

enum LockScope: String, Codable {
    case off          // No PIN required
    case menuBarOnly  // Only the popover
    case windowOnly   // Only the main window
    case both         // Both surfaces
}

enum LockSurface {
    case menuBar
    case window
}

@MainActor
@Observable
final class AppLockManager {
    var scope: LockScope = .off {
        didSet { UserDefaults.standard.set(scope.rawValue, forKey: "appLockScope") }
    }

    /// Whether each surface is currently locked.
    private(set) var menuBarLocked = false
    private(set) var windowLocked = false

    /// Number of consecutive failed PIN attempts.
    private(set) var failedAttempts = 0

    /// If non-nil, the user is in cooldown and must wait.
    private(set) var cooldownEnd: Date?

    var isPINSet: Bool { KeychainStore.loadPINHash() != nil }

    private static let log = Logger(subsystem: "prowlsh.deskmon", category: "AppLock")
    private static let maxAttempts = 5
    private static let cooldownDuration: TimeInterval = 30
    private static let saltLength = 16

    init() {
        if let raw = UserDefaults.standard.string(forKey: "appLockScope"),
           let saved = LockScope(rawValue: raw) {
            scope = saved
        }
        lockAllSurfaces()
    }

    // MARK: - Lock/Unlock

    func isLocked(_ surface: LockSurface) -> Bool {
        guard isPINSet else { return false }
        switch surface {
        case .menuBar:
            return (scope == .menuBarOnly || scope == .both) && menuBarLocked
        case .window:
            return (scope == .windowOnly || scope == .both) && windowLocked
        }
    }

    /// Attempt to unlock a surface with a PIN.
    func unlock(_ surface: LockSurface, pin: String) -> Bool {
        // Check cooldown
        if let end = cooldownEnd, Date() < end {
            return false
        }
        cooldownEnd = nil

        guard verifyPIN(pin) else {
            failedAttempts += 1
            if failedAttempts >= Self.maxAttempts {
                cooldownEnd = Date().addingTimeInterval(Self.cooldownDuration)
                Self.log.warning("PIN cooldown triggered after \(Self.maxAttempts) failed attempts")
                // Reset counter after cooldown
                Task {
                    try? await Task.sleep(for: .seconds(Self.cooldownDuration))
                    self.failedAttempts = 0
                    self.cooldownEnd = nil
                }
            }
            return false
        }

        failedAttempts = 0
        switch surface {
        case .menuBar: menuBarLocked = false
        case .window: windowLocked = false
        }
        return true
    }

    /// Lock a specific surface (called on dismiss, sleep/wake, idle).
    func lock(_ surface: LockSurface) {
        guard isPINSet else { return }
        switch surface {
        case .menuBar:
            if scope == .menuBarOnly || scope == .both { menuBarLocked = true }
        case .window:
            if scope == .windowOnly || scope == .both { windowLocked = true }
        }
    }

    /// Lock all surfaces (called on init, sleep/wake).
    func lockAllSurfaces() {
        guard isPINSet else { return }
        if scope == .menuBarOnly || scope == .both { menuBarLocked = true }
        if scope == .windowOnly || scope == .both { windowLocked = true }
    }

    // MARK: - PIN Management

    /// Set a new PIN. Stores a salted SHA-256 hash in Keychain.
    func setPIN(_ pin: String) throws {
        let salt = generateSalt()
        let hash = hashPIN(pin, salt: salt)
        // Store salt + hash together
        var data = salt
        data.append(hash)
        try KeychainStore.savePINHash(data)
        lockAllSurfaces()
        Self.log.info("PIN set")
    }

    /// Remove the PIN entirely.
    func removePIN() {
        KeychainStore.deletePINHash()
        menuBarLocked = false
        windowLocked = false
        failedAttempts = 0
        cooldownEnd = nil
        Self.log.info("PIN removed")
    }

    /// Verify a PIN against the stored hash.
    func verifyPIN(_ pin: String) -> Bool {
        guard let stored = KeychainStore.loadPINHash(),
              stored.count > Self.saltLength else { return false }
        let salt = stored.prefix(Self.saltLength)
        let storedHash = stored.dropFirst(Self.saltLength)
        let inputHash = hashPIN(pin, salt: Data(salt))
        return inputHash == Data(storedHash)
    }

    // MARK: - Private

    private func generateSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: Self.saltLength)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    private func hashPIN(_ pin: String, salt: Data) -> Data {
        var input = salt
        input.append(Data(pin.utf8))
        let digest = SHA256.hash(data: input)
        return Data(digest)
    }
}
