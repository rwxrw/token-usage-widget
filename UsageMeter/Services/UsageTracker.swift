import Foundation
import Combine
import SwiftUI

@MainActor
final class UsageTracker: ObservableObject {
    @Published var currentUsage: UsageData?
    @Published var isRefreshing: Bool = false
    @Published var lastError: String?
    @Published var needsOnboarding: Bool = false

    let webController: WebController
    private let claudeClient: ClaudeClient
    private let apiClient: APIClient
    private let keychain: KeychainService
    private let settings: AppSettings

    private var pollingTimer: AnyCancellable?
    private var fetchTimeoutTask: Task<Void, Never>?

    init(settings: AppSettings = .shared, keychain: KeychainService = .shared) {
        self.settings      = settings
        self.keychain      = keychain
        self.webController = WebController()
        self.claudeClient  = ClaudeClient()
        self.apiClient     = APIClient()

        // Show last-known data immediately on launch
        currentUsage = loadSnapshot()?.data

        // Check if we have what we need to fetch
        let hasSessionKey = keychain.load(account: "claudeSessionKey") != nil
        needsOnboarding = !hasSessionKey && settings.trackingMode == .web

        rescheduleTimer()

        if !needsOnboarding {
            refresh()
        }
    }

    // MARK: - Public

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil

        switch settings.trackingMode {
        case .web:
            Task { @MainActor in
                await fetchFromClaudeAPI()
                isRefreshing = false
            }

        case .api:
            Task { @MainActor in
                await fetchFromAPI()
                isRefreshing = false
            }
        }
    }

    func rescheduleTimer() {
        pollingTimer?.cancel()
        let interval = TimeInterval(settings.pollingIntervalMinutes * 60)
        pollingTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }
    }

    func onboardingCompleted() {
        settings.hasCompletedOnboarding = true
        needsOnboarding = false
        webController.markLoggedIn()
        refresh()
    }

    func setSessionKey(_ key: String) {
        keychain.save(key, account: "claudeSessionKey")
        webController.setSessionCookie(key)
        settings.hasCompletedOnboarding = true
        needsOnboarding = false
        // Auto-discover org ID if not already stored
        if keychain.load(account: "claudeOrgID") == nil {
            Task { @MainActor in
                await discoverAndStoreOrgID(sessionKey: key)
            }
        }
        refresh()
    }

    func updateAPIKey(_ key: String, orgID: String) {
        keychain.save(key, account: "anthropicAPIKey")
        keychain.save(orgID, account: "anthropicOrgID")
        Task { await apiClient.setKey(key) }
    }

    func clearCredentials() {
        keychain.delete(account: "anthropicAPIKey")
        keychain.delete(account: "anthropicOrgID")
        keychain.delete(account: "claudeSessionKey")
        keychain.delete(account: "claudeOrgID")
        settings.hasCompletedOnboarding = false
        needsOnboarding = settings.trackingMode == .web
        currentUsage = nil
    }

    // MARK: - Private

    private func fetchFromClaudeAPI() async {
        guard let sessionKey = keychain.load(account: "claudeSessionKey"),
              !sessionKey.isEmpty else {
            lastError = "Session key not set. Open Settings and paste your sessionKey."
            return
        }

        // Ensure we have an org ID (discover if missing)
        var orgID = keychain.load(account: "claudeOrgID") ?? ""
        if orgID.isEmpty {
            orgID = await discoverAndStoreOrgID(sessionKey: sessionKey) ?? ""
        }
        guard !orgID.isEmpty else {
            lastError = "Could not determine organization ID. Check your session key."
            return
        }

        do {
            let data = try await claudeClient.fetchUsage(sessionKey: sessionKey, orgID: orgID)
            receiveUsage(data)
            print("[UsageMeter] ✓ claude.ai API: session=\(data.sessionUtilization as Any)% weekly=\(data.weeklyUtilization as Any)%")
        } catch {
            lastError = error.localizedDescription
            print("[UsageMeter] ✗ claude.ai API error: \(error)")
        }
    }

    @discardableResult
    private func discoverAndStoreOrgID(sessionKey: String) async -> String? {
        do {
            let orgID = try await claudeClient.discoverOrgID(sessionKey: sessionKey)
            keychain.save(orgID, account: "claudeOrgID")
            print("[UsageMeter] Discovered org ID: \(orgID)")
            return orgID
        } catch {
            print("[UsageMeter] Org discovery failed: \(error)")
            return nil
        }
    }

    private func fetchFromAPI() async {
        let orgID = keychain.load(account: "anthropicOrgID") ?? ""
        guard !orgID.isEmpty else {
            lastError = "Organization ID not set. Go to Settings."
            return
        }
        do {
            let data = try await apiClient.fetchUsageReport(organizationID: orgID)
            receiveUsage(data)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func receiveUsage(_ data: UsageData) {
        currentUsage = data
        persistSnapshot(UsageSnapshot(data: data, persistedAt: Date()))
    }

    // MARK: - Snapshot persistence

    private func persistSnapshot(_ snap: UsageSnapshot) {
        if let encoded = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(encoded, forKey: "lastUsageSnapshot")
        }
    }

    private func loadSnapshot() -> UsageSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: "lastUsageSnapshot") else { return nil }
        return try? JSONDecoder().decode(UsageSnapshot.self, from: data)
    }
}
