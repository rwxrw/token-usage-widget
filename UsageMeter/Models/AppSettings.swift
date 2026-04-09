import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var planType: PlanType {
        didSet { defaults.set(planType.rawValue, forKey: Keys.planType) }
    }
    @Published var trackingMode: TrackingMode {
        didSet { defaults.set(trackingMode.rawValue, forKey: Keys.trackingMode) }
    }
    @Published var pollingIntervalMinutes: Int {
        didSet { defaults.set(pollingIntervalMinutes, forKey: Keys.pollingInterval) }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarded) }
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let planType       = "planType"
        static let trackingMode   = "trackingMode"
        static let pollingInterval = "pollingIntervalMinutes"
        static let onboarded      = "hasCompletedOnboarding"
    }

    private init() {
        planType = PlanType(rawValue: defaults.string(forKey: Keys.planType) ?? "") ?? .pro
        trackingMode = TrackingMode(rawValue: defaults.string(forKey: Keys.trackingMode) ?? "") ?? .web
        let stored = defaults.integer(forKey: Keys.pollingInterval)
        pollingIntervalMinutes = stored > 0 ? stored : 15
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarded)
    }
}
