import SwiftUI
import AppKit

@main
struct IrisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let controller = NotchPanelController.shared
        let statusController = StatusDashboardController.shared
        let configuration = IrisLaunchConfiguration(arguments: CommandLine.arguments)
        if configuration.previewsOnboarding {
            OnboardingWindowController.shared.present()
        } else if configuration.previewsSettings {
            statusController.openSettings()
        } else if configuration.previewsStatusDashboard {
            statusController.open(tab: configuration.previewTab ?? .today)
        } else if let previewTab = configuration.previewTab {
            controller.open(tab: previewTab)
        } else {
            OnboardingWindowController.shared.presentIfNeeded()
        }
    }
}
