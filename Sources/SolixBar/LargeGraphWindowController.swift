import AppKit

@MainActor
final class LargeGraphWindowController: NSWindowController {
    private let graphProvider: () -> [SolixHistorySample]

    init(graphProvider: @escaping () -> [SolixHistorySample]) {
        self.graphProvider = graphProvider
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 430),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SOLIX Verlauf"
        window.center()
        super.init(window: window)
        rebuild()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func rebuild() {
        let graph = HistoryGraphView(
            samples: graphProvider(),
            rangeTitle: AppSettings.shared.historyRange.title,
            size: NSSize(width: 680, height: 360)
        )
        graph.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(graph)
        NSLayoutConstraint.activate([
            graph.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            graph.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            graph.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            graph.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20)
        ])
        window?.contentView = container
    }
}
