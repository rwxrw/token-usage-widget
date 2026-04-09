import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var tracker: UsageTracker
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    @State private var apiKeyInput: String = ""
    @State private var orgIDInput: String = ""
    @State private var showOnboarding: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan") {
                    Picker("Type", selection: $settings.planType) {
                        ForEach(PlanType.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Tracking Mode") {
                    Picker("Mode", selection: $settings.trackingMode) {
                        ForEach(TrackingMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if settings.trackingMode == .web {
                        HStack {
                            Text(settings.hasCompletedOnboarding ? "Logged in" : "Not logged in")
                                .foregroundStyle(settings.hasCompletedOnboarding ? .green : .orange)
                            Spacer()
                            Button("Re-login") { showOnboarding = true }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    } else {
                        SecureField("Anthropic API Key (sk-ant-admin…)", text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                        TextField("Organization ID", text: $orgIDInput)
                            .textFieldStyle(.roundedBorder)
                        Button("Save Credentials") {
                            tracker.updateAPIKey(apiKeyInput, orgID: orgIDInput)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(apiKeyInput.isEmpty || orgIDInput.isEmpty)
                    }
                }

                Section("Polling Interval") {
                    Stepper(
                        "Every \(settings.pollingIntervalMinutes) min",
                        value: $settings.pollingIntervalMinutes,
                        in: 5...60,
                        step: 5
                    )
                    .onChange(of: settings.pollingIntervalMinutes) { _ in
                        tracker.rescheduleTimer()
                    }
                }

                Section {
                    Button("Clear All Credentials", role: .destructive) {
                        tracker.clearCredentials()
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 360, height: 420)
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .environmentObject(tracker)
        }
        .onAppear {
            // Pre-fill with stored values (masked for API key display)
            let storedKey = KeychainService.shared.load(account: "anthropicAPIKey") ?? ""
            apiKeyInput = storedKey.isEmpty ? "" : String(repeating: "•", count: min(storedKey.count, 20))
            orgIDInput  = KeychainService.shared.load(account: "anthropicOrgID") ?? ""
        }
    }
}
