import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.set(0.1, forKey: "NSInitialToolTipDelay")
        AppLogger.info("SolixBar \(AppVersion.display) started. Log: \(AppLogger.logURL.path)")
        statusController = StatusController()
        statusController?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusController?.prepareForTermination()
        AppLogger.info("SolixBar terminated.")
    }
}
