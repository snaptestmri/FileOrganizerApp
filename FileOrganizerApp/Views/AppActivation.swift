import AppKit

/// Brings the app to the foreground so keyboard input goes to the window, not Terminal.
@MainActor
enum AppActivation {
    static func activate() {
        NSApp.setActivationPolicy(.regular)
        if #available(macOS 14.0, *) {
            NSRunningApplication.current.activate(options: [.activateAllWindows])
        } else {
            NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        }
        NSApp.activate()

        guard let window = NSApp.keyWindow
            ?? NSApp.mainWindow
            ?? NSApp.windows.first(where: { $0.isVisible }) else {
            return
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
