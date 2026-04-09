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
    private let apiClient: APIClient
    private let keychain: KeychainService
    private let settings: AppSettings

    private var pollingTimer: AnyCancellable?
    private var webCancellable: AnyCancellable?
    private var fetchTimeoutTask: Task<Void, Never>?

    init(settings: AppSettings = .shared, keychain: KeychainService = .shared) {
        self.settings      = settings
        self.keychain      = keychain
        self.webController = WebController()
        self.apiClient     = APIClient()

        // Show last-known data immediately on launch
        currentUsage = loadSnapshot()?.data

        // Wire up web interception results
        webCancellable = webController.usageDataSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                self?.receiveUsage(data)
                self?.fetchTimeoutTask?.cancel()
                self?.isRefreshing = false
            }

        // Configure API key
        if let key = keychain.load(account: "anthropicAPIKey") {
            Task { await apiClient.setKey(key) }
        }

        needsOnboarding = !settings.hasCompletedOnboarding && settings.trackingMode == .web
        rescheduleTimer()

        // Kick off first fetch only if onboarding is done
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
            // Load page; result arrives via webCancellable sink
            webController.fetchLatestUsage()
            // Safety timeout: if no data within 30s, stop spinner
            fetchTimeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if !Task.isCancelled {
                    isRefreshing = false
                    if currentUsage == nil {
                        lastError = "No usage data found. Make sure you're logged in."
                    }
                }
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

    func updateAPIKey(_ key: String, orgID: String) {
        keychain.save(key, account: "anthropicAPIKey")
        keychain.save(orgID, account: "anthropicOrgID")
        Task { await apiClient.setKey(key) }
    }

    func clearCredentials() {
        keychain.delete(account: "anthropicAPIKey")
        keychain.delete(account: "anthropicOrgID")
        settings.hasCompletedOnboarding = false
        needsOnboarding = settings.trackingMode == .web
        currentUsage = nil
    }

    // MARK: - Private

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
