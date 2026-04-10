import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let tracker = UsageTracker()
    private let settings = AppSettings.shared
    private var iconCancellable: AnyCancellable?
    private var onboardingCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt-and-suspenders: Info.plist has LSUIElement=YES, this reinforces it
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()

        // Update menu bar icon whenever usage fraction changes
        iconCancellable = tracker.$currentUsage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] usage in
                self?.updateIcon(fraction: usage?.fraction ?? 0)
            }

        // Auto-open onboarding if needed
        if tracker.needsOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showPopover()
            }
        }
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon(fraction: 0)
        statusItem.button?.action = #selector(handleStatusItemClick(_:))
        statusItem.button?.target = self
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.toolTip = "UsageMeter — Claude usage tracker"
    }

    private func updateIcon(fraction: Double) {
        statusItem.button?.image = MenuBarIcon.image(fraction: fraction)
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(refreshAction), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit UsageMeter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func refreshAction() {
        tracker.refresh()
    }

    // MARK: - Popover

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 360)
        popover.behavior = .transient
        popover.animates = true

        let rootView = PopoverView()
            .environmentObject(tracker)
            .environmentObject(settings)

        popover.contentViewController = NSHostingController(rootView: rootView)
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }
}
