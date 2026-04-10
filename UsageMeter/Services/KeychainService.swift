import Foundation

/// Stores credentials in UserDefaults (no Keychain prompts).
final class KeychainService {
    static let shared = KeychainService()
    private let defaults = UserDefaults.standard
    private let prefix = "com.usagemeter."
    private init() {}

    @discardableResult
    func save(_ value: String, account: String) -> Bool {
        defaults.set(value, forKey: prefix + account)
        return true
    }

    func load(account: String) -> String? {
        defaults.string(forKey: prefix + account)
    }

    @discardableResult
    func delete(account: String) -> Bool {
        defaults.removeObject(forKey: prefix + account)
        return true
    }
}
