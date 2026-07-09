import AppKit

@MainActor
final class DetachedMenuBarWindowController: NSWindowController {
    private let snapshotProvider: () -> SolixSnapshot?
    private let onClose: () -> Void

    init(snapshotProvider: @escaping () -> SolixSnapshot?, onClose: @escaping () -> Void) {
        self.snapshotProvider = snapshotProvider
        self.onClose = onClose
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.title = "SOLIX Leiste"
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = true
        window.backgroundColor = .clear
        window.isOpaque = false
        super.init(window: window)
        rebuild()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showBelowMenuBar(anchor: NSRect?) {
        if let window, !window.isVisible {
            positionBelowMenuBar(anchor: anchor)
        }
        rebuild()
        showWindow(nil)
    }

    func rebuild() {
        guard let window else { return }
        let oldFrame = window.frame
        let view = DetachedMenuBarView(snapshot: snapshotProvider(), onClose: { [weak self] in
            self?.close()
            self?.onClose()
        })
        view.frame = NSRect(origin: .zero, size: oldFrame.size)
        view.autoresizingMask = [.width, .height]
        window.contentView = view
        window.setFrame(oldFrame, display: true)
    }

    private func positionBelowMenuBar(anchor: NSRect?) {
        guard let window else { return }
        let screen = anchor.flatMap { rect in NSScreen.screens.first { $0.frame.intersects(rect) } } ?? NSScreen.main
        guard let screen else { return }

        var frame = window.frame
        let visible = screen.visibleFrame
        if let anchor {
            frame.origin.x = anchor.midX - frame.width / 2
        } else {
            frame.origin.x = visible.maxX - frame.width - 24
        }
        frame.origin.x = min(visible.maxX - frame.width - 8, max(visible.minX + 8, frame.origin.x))
        frame.origin.y = visible.maxY - frame.height - 6
        window.setFrame(frame, display: true)
    }
}

private final class DetachedMenuBarView: NSView {
    private let snapshot: SolixSnapshot?
    private let onClose: () -> Void
    private let settings = AppSettings.shared

    init(snapshot: SolixSnapshot?, onClose: @escaping () -> Void) {
        self.snapshot = snapshot
        self.onClose = onClose
        super.init(frame: NSRect(x: 0, y: 0, width: 640, height: 44))
        wantsLayer = true
        layer?.cornerRadius = 15
        layer?.backgroundColor = barBackground.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
        buildView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildView() {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12

        if let image = appIcon() {
            let imageView = NSImageView(image: image)
            imageView.widthAnchor.constraint(equalToConstant: 24).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 24).isActive = true
            stack.addArrangedSubview(imageView)
        }

        if let snapshot {
            let metrics = settings.barMetrics.isEmpty ? [BarMetric.battery, .solar] : settings.barMetrics
            for metric in metrics {
                stack.addArrangedSubview(metricLabel(metric, snapshot: snapshot))
            }
        } else {
            let label = NSTextField(labelWithString: "SOLIX wartet auf Daten")
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = .secondaryLabelColor
            stack.addArrangedSubview(label)
        }

        let closeButton = NSButton(title: "×", target: self, action: #selector(close))
        closeButton.isBordered = false
        closeButton.font = .systemFont(ofSize: 18, weight: .bold)
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.toolTip = "Abgedockte Leiste schließen."
        closeButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 28).isActive = true

        for view in [stack, closeButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -10),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    private func metricLabel(_ metric: BarMetric, snapshot: SolixSnapshot) -> NSTextField {
        let label = NSTextField(labelWithString: text(for: metric, snapshot: snapshot))
        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        label.textColor = color(for: metric, snapshot: snapshot)
        label.lineBreakMode = .byTruncatingTail
        label.toolTip = metric.title
        return label
    }

    private func text(for metric: BarMetric, snapshot: SolixSnapshot) -> String {
        let prefix = settings.showMetricLabels ? "\(metric.shortTitle) " : ""
        let arrow = settings.showEnergyFlowArrows ? flowArrow(for: metric, snapshot: snapshot) : ""
        switch metric {
        case .battery:
            return "\(arrow)\(prefix)\(snapshot.batteryPercent.map { "\($0)%" } ?? "--%")"
        case .solar:
            return "\(arrow)\(prefix)\(snapshot.solarWatts.map { "\($0)W" } ?? "--W")"
        case .home:
            return "\(prefix)\(snapshot.homeWatts.map { "\($0)W" } ?? "--W")"
        case .grid:
            return "\(arrow)\(prefix)\(signedWatts(snapshot.gridWatts) ?? "--W")"
        case .batteryFlow:
            return "\(arrow)\(prefix)\(signedWatts(snapshot.batteryWatts) ?? "--W")"
        case .flow:
            return flowSummary(snapshot)
        case .today:
            return "\(prefix)\(snapshot.todayKWh.map { String(format: "%.2fkWh", $0) } ?? "--kWh")"
        case .total:
            return "\(prefix)\(snapshot.totalKWh.map { String(format: "%.1fkWh", $0) } ?? "--kWh")"
        case .status:
            return "\(prefix)\(snapshot.status ?? "-")"
        }
    }

    private func flowSummary(_ snapshot: SolixSnapshot) -> String {
        let parts = [BarMetric.solar, .batteryFlow, .grid]
            .map { flowArrow(for: $0, snapshot: snapshot).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "Flow -" : "Flow \(parts.joined(separator: " "))"
    }

    private func flowArrow(for metric: BarMetric, snapshot: SolixSnapshot) -> String {
        switch metric {
        case .solar:
            return (snapshot.solarWatts ?? 0) > 0 ? "⬇ " : ""
        case .grid:
            guard let watts = snapshot.gridWatts else { return "" }
            if watts > 0 { return "⬆ " }
            if watts < 0 { return "⬇ " }
            return ""
        case .batteryFlow:
            guard let watts = snapshot.batteryWatts else { return "" }
            if watts > 0 { return "⬇ " }
            if watts < 0 { return "⬆ " }
            return ""
        default:
            return ""
        }
    }

    private func color(for metric: BarMetric, snapshot: SolixSnapshot) -> NSColor {
        switch metric {
        case .battery:
            guard let percent = snapshot.batteryPercent else { return .secondaryLabelColor }
            if percent <= 20 { return .systemRed }
            if percent <= 45 { return .systemOrange }
            return highContrastGreen
        case .solar:
            return solarColor
        case .home:
            return .systemBlue
        case .grid:
            guard let watts = snapshot.gridWatts else { return .secondaryLabelColor }
            if watts > 0 { return highContrastRed }
            if watts < 0 { return highContrastGreen }
            return .secondaryLabelColor
        case .batteryFlow:
            guard let watts = snapshot.batteryWatts else { return .secondaryLabelColor }
            if watts > 0 { return highContrastGreen }
            if watts < 0 { return highContrastRed }
            return .secondaryLabelColor
        case .flow:
            return highContrastGreen
        case .today:
            return .systemPurple
        case .total:
            return .systemIndigo
        case .status:
            return snapshot.status?.localizedCaseInsensitiveContains("offline") == true ? highContrastRed : highContrastGreen
        }
    }

    private func signedWatts(_ value: Int?) -> String? {
        guard let value else { return nil }
        return value > 0 ? "+\(value)W" : "\(value)W"
    }

    private func appIcon() -> NSImage? {
        let image = Bundle.main.url(forResource: "SolixBar", withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
        image?.size = NSSize(width: 24, height: 24)
        return image
    }

    @objc private func close() {
        onClose()
    }

    private var highContrastGreen: NSColor {
        NSColor(calibratedRed: 0.00, green: 0.58, blue: 0.22, alpha: 1)
    }

    private var highContrastRed: NSColor {
        NSColor(calibratedRed: 0.88, green: 0.08, blue: 0.12, alpha: 1)
    }

    private var solarColor: NSColor {
        NSColor(calibratedRed: 0.78, green: 0.52, blue: 0.00, alpha: 1)
    }

    private var barBackground: NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.10, alpha: 0.96)
                : NSColor(calibratedRed: 0.97, green: 0.985, blue: 0.98, alpha: 0.96)
        }
    }
}
