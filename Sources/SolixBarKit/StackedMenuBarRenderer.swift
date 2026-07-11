import AppKit

/// Zweizeilige Kompaktanzeige für die Menüleiste: zwei Reihen à 9 pt
/// Monospace-Ziffern mit kleinen Metrik-Glyphen — halbiert die Breite bei
/// gleicher oder höherer Informationsdichte (bewährtes Muster, vgl. iStat
/// Menus). Gezeichnet über einen NSImage-DrawingHandler, damit dynamische
/// Theme-Farben zur Zeichenzeit gegen die tatsächliche Menüleisten-Appearance
/// aufgelöst werden.
@MainActor
enum StackedMenuBarRenderer {
    struct Entry {
        let symbolName: String
        let text: String
        let role: ColorRole
    }

    static func image(entries: [Entry], scale: Double, showWarning: Bool) -> NSImage? {
        guard !entries.isEmpty else { return nil }
        let half = (entries.count + 1) / 2
        let rows = [Array(entries.prefix(half)), Array(entries.dropFirst(half))]
            .filter { !$0.isEmpty }

        let fontSize = round(9 * scale)
        let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold)
        let glyphSize = round(8 * scale)
        let entryGap = round(7 * scale)
        let glyphGap = round(2 * scale)
        let height: CGFloat = 22

        func rowWidth(_ row: [Entry]) -> CGFloat {
            var width: CGFloat = 0
            for (index, entry) in row.enumerated() {
                if index > 0 { width += entryGap }
                width += glyphSize + glyphGap
                width += ceil((entry.text as NSString).size(withAttributes: [.font: font]).width)
            }
            return width
        }

        let warningWidth: CGFloat = showWarning ? round(11 * scale) : 0
        let width = ceil((rows.map(rowWidth).max() ?? 0) + warningWidth) + 2

        let size = NSSize(width: width, height: height)
        return NSImage(size: size, flipped: false) { _ in
            let rowHeight = height / CGFloat(rows.count)
            for (rowIndex, row) in rows.enumerated() {
                // Reihen von oben nach unten, vertikal in ihrer Hälfte zentriert.
                let rowCenterY = height - rowHeight * (CGFloat(rowIndex) + 0.5)
                var x: CGFloat = 1
                for (index, entry) in row.enumerated() {
                    if index > 0 { x += entryGap }
                    let color = Theme.color(entry.role)
                    if let glyph = NSImage(systemSymbolName: entry.symbolName, accessibilityDescription: nil)?
                        .withSymbolConfiguration(.init(pointSize: glyphSize, weight: .bold)) {
                        let tinted = tint(glyph, with: color)
                        let glyphRect = NSRect(
                            x: x,
                            y: rowCenterY - glyphSize / 2,
                            width: glyphSize,
                            height: glyphSize
                        )
                        tinted.draw(in: glyphRect, from: .zero, operation: .sourceOver, fraction: 1)
                        x += glyphSize + glyphGap
                    }
                    let attributes: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: color
                    ]
                    let textSize = (entry.text as NSString).size(withAttributes: attributes)
                    (entry.text as NSString).draw(
                        at: NSPoint(x: x, y: rowCenterY - textSize.height / 2),
                        withAttributes: attributes
                    )
                    x += ceil(textSize.width)
                }
            }
            if showWarning {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: round(9 * scale), weight: .bold),
                    .foregroundColor: Theme.color(.batteryMedium)
                ]
                ("⚠" as NSString).draw(
                    at: NSPoint(x: width - warningWidth, y: height / 2 - round(6 * scale)),
                    withAttributes: attributes
                )
            }
            return true
        }
    }

    private static func tint(_ image: NSImage, with color: NSColor) -> NSImage {
        let copy = image.copy() as? NSImage ?? image
        copy.isTemplate = false
        copy.lockFocus()
        color.set()
        NSRect(origin: .zero, size: copy.size).fill(using: .sourceAtop)
        copy.unlockFocus()
        return copy
    }
}
