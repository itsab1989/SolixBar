import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppLogger.info("SolixBar \(AppVersion.display) started. Log: \(AppLogger.logURL.path)")
        statusController = StatusController()
        statusController?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusController?.prepareForTermination()
        AppLogger.info("SolixBar terminated.")
    }
}
