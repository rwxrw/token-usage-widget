import SwiftUI

@main
struct UsageMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window scenes — the app lives entirely in the menu bar.
        // The Settings stub satisfies the SwiftUI App protocol requirement.
        Settings { EmptyView() }
    }
}
