import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var tracker: UsageTracker
    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    @State private var apiKeyInput: String = ""
    @State private var orgIDInput: String = ""
    @State private var sessionKeyInput: String = ""
    @State private var sessionKeySaved: Bool = false
    @State private var storedOrgID: String = ""

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
                        // Session Key
                        SecureField("Session Key  (sk-ant-sid…)", text: $sessionKeyInput)
                            .textFieldStyle(.roundedBorder)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("How to get your session token:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Text("1. Open **claude.ai** in Safari or Chrome")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("2. Open DevTools (⌥⌘I)")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("3. Go to **Application** → **Cookies** → `claude.ai`")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("4. Copy the value of **sessionKey**")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)

                        HStack {
                            Button(sessionKeySaved ? "Saved ✓" : "Save Session Key") {
                                tracker.setSessionKey(sessionKeyInput)
                                sessionKeySaved = true
                                // Re-read org ID after auto-discovery
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    sessionKeySaved = false
                                    storedOrgID = KeychainService.shared.load(account: "claudeOrgID") ?? ""
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(sessionKeyInput.isEmpty)

                            Spacer()

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(settings.hasCompletedOnboarding ? Color.green : Color.orange)
                                    .frame(width: 8, height: 8)
                                Text(settings.hasCompletedOnboarding ? "Active" : "Not set")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !storedOrgID.isEmpty {
                            HStack(spacing: 4) {
                                Text("Org ID")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                                Text(storedOrgID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
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
                        sessionKeyInput = ""
                        storedOrgID = ""
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 380, height: 480)
        .onAppear {
            let storedKey = KeychainService.shared.load(account: "anthropicAPIKey") ?? ""
            apiKeyInput = storedKey.isEmpty ? "" : String(repeating: "•", count: min(storedKey.count, 20))
            orgIDInput  = KeychainService.shared.load(account: "anthropicOrgID") ?? ""
            storedOrgID = KeychainService.shared.load(account: "claudeOrgID") ?? ""
        }
    }
}
