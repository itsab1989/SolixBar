import AppKit

@MainActor
final class DetachedMenuBarWindowController: NSWindowController, NSWindowDelegate {
    private let snapshotProvider: () -> SolixSnapshot?
    private let attributedBarProvider: () -> NSAttributedString?
    private let onClose: () -> Void
    private var didNotifyClose = false

    init(
        snapshotProvider: @escaping () -> SolixSnapshot?,
        attributedBarProvider: @escaping () -> NSAttributedString?,
        onClose: @escaping () -> Void
    ) {
        self.snapshotProvider = snapshotProvider
        self.attributedBarProvider = attributedBarProvider
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
        window.delegate = self
        rebuild()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showBelowMenuBar(anchor: NSRect?) {
        rebuild()
        if let window, !window.isVisible {
            positionBelowMenuBar(anchor: anchor)
        }
        showWindow(nil)
    }

    func rebuild() {
        guard let window else { return }
        let attributedText = attributedBarProvider()
        let oldFrame = window.frame
        let targetSize = targetSize(for: attributedText, screen: window.screen)
        let view = DetachedMenuBarView(attributedText: attributedText, snapshot: snapshotProvider(), onClose: { [weak self] in
            self?.closeFromButton()
        })
        view.frame = NSRect(origin: .zero, size: targetSize)
        view.autoresizingMask = [.width, .height]
        window.contentView = view
        var frame = oldFrame
        frame.size = targetSize
        if let screen = window.screen {
            frame.origin.x = min(screen.visibleFrame.maxX - targetSize.width - 8, max(screen.visibleFrame.minX + 8, frame.origin.x))
            frame.origin.y = min(screen.visibleFrame.maxY - targetSize.height - 6, max(screen.visibleFrame.minY + 8, frame.origin.y))
        }
        window.setFrame(frame, display: true)
    }

    func windowWillClose(_ notification: Notification) {
        notifyCloseIfNeeded()
    }

    private func closeFromButton() {
        notifyCloseIfNeeded()
        close()
    }

    private func notifyCloseIfNeeded() {
        guard !didNotifyClose else { return }
        didNotifyClose = true
        onClose()
    }

    private func targetSize(for attributedText: NSAttributedString?, screen: NSScreen?) -> NSSize {
        let textWidth = ceil(attributedText?.size().width ?? 152)
        let iconWidth: CGFloat = AppSettings.shared.showMenuBarIcon ? 34 : 0
        let closeWidth: CGFloat = 46
        let horizontalPadding: CGFloat = 32
        let width = textWidth + iconWidth + closeWidth + horizontalPadding
        let visibleWidth = screen?.visibleFrame.width ?? 900
        return NSSize(width: min(max(width, 260), visibleWidth - 24), height: 44)
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
    private let attributedText: NSAttributedString?
    private let snapshot: SolixSnapshot?
    private let onClose: () -> Void
    private let settings = AppSettings.shared

    init(attributedText: NSAttributedString?, snapshot: SolixSnapshot?, onClose: @escaping () -> Void) {
        self.attributedText = attributedText
        self.snapshot = snapshot
        self.onClose = onClose
        super.init(frame: NSRect(x: 0, y: 0, width: 640, height: 44))
        wantsLayer = true
        layer?.cornerRadius = 16
        layer?.masksToBounds = true
        buildView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildView() {
        let glass = NSVisualEffectView()
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.wantsLayer = true
        glass.layer?.cornerRadius = 16
        glass.layer?.masksToBounds = true
        glass.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glass)

        let border = NSView()
        border.wantsLayer = true
        border.layer?.cornerRadius = 16
        border.layer?.borderWidth = 1
        border.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.62).cgColor
        border.layer?.backgroundColor = NSColor.clear.cgColor
        border.translatesAutoresizingMaskIntoConstraints = false
        addSubview(border)

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10

        if settings.showMenuBarIcon, let image = appIcon() {
            let imageView = NSImageView(image: image)
            imageView.widthAnchor.constraint(equalToConstant: 24).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 24).isActive = true
            stack.addArrangedSubview(imageView)
        }

        if let attributedText, attributedText.length > 0 {
            let label = NSTextField(labelWithString: "")
            label.attributedStringValue = attributedText
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            stack.addArrangedSubview(label)
        } else {
            let label = NSTextField(labelWithString: "SOLIX wartet auf Daten")
            label.font = .systemFont(ofSize: 13, weight: .semibold)
            label.textColor = .secondaryLabelColor
            stack.addArrangedSubview(label)
        }

        if let status = statusText {
            let label = NSTextField(labelWithString: status)
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = isOnline ? .systemGreen : .systemRed
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            label.toolTip = isOnline ? "Live-Daten sind verbunden." : "Keine Live-Daten verbunden."
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
            glass.leadingAnchor.constraint(equalTo: leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            glass.topAnchor.constraint(equalTo: topAnchor),
            glass.bottomAnchor.constraint(equalTo: bottomAnchor),

            border.leadingAnchor.constraint(equalTo: leadingAnchor),
            border.trailingAnchor.constraint(equalTo: trailingAnchor),
            border.topAnchor.constraint(equalTo: topAnchor),
            border.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -10),

            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
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

    private var statusText: String? {
        guard let status = snapshot?.status, !status.isEmpty else { return nil }
        return status.localizedCaseInsensitiveContains("offline") ? "Offline" : "Online"
    }

    private var isOnline: Bool {
        !(snapshot?.status?.localizedCaseInsensitiveContains("offline") ?? false)
    }
}
