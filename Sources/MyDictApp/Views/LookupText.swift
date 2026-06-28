import AppKit
import SwiftUI

struct LookupText: NSViewRepresentable {
    let text: String
    let font: NSFont
    let color: NSColor
    let lineSpacing: CGFloat
    let prefix: String
    let prefixFont: NSFont?
    let prefixColor: NSColor
    let onLookup: (String) -> Void

    init(
        _ text: String,
        font: NSFont,
        color: NSColor = .labelColor,
        lineSpacing: CGFloat = 3,
        prefix: String = "",
        prefixFont: NSFont? = nil,
        prefixColor: NSColor = .labelColor,
        onLookup: @escaping (String) -> Void
    ) {
        self.text = text
        self.font = font
        self.color = color
        self.lineSpacing = lineSpacing
        self.prefix = prefix
        self.prefixFont = prefixFont
        self.prefixColor = prefixColor
        self.onLookup = onLookup
    }

    func makeNSView(context: Context) -> DoubleClickLookupTextView {
        let textView = DoubleClickLookupTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.onLookup = onLookup
        return textView
    }

    func updateNSView(_ nsView: DoubleClickLookupTextView, context: Context) {
        nsView.onLookup = onLookup
        nsView.textStorage?.setAttributedString(attributedString)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: DoubleClickLookupTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 600
        let bounds = attributedString.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return CGSize(width: width, height: ceil(bounds.height) + 2)
    }

    private var attributedString: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.lineBreakMode = .byWordWrapping

        let result = NSMutableAttributedString()
        if !prefix.isEmpty {
            result.append(NSAttributedString(
                string: "\(prefix) ",
                attributes: [
                    .font: prefixFont ?? font,
                    .foregroundColor: prefixColor,
                    .paragraphStyle: paragraph
                ]
            ))
        }
        result.append(NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        ))
        return result
    }
}

final class DoubleClickLookupTextView: NSTextView {
    var onLookup: ((String) -> Void)?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2, let word = word(at: event.locationInWindow) {
            onLookup?(word)
            return
        }

        super.mouseDown(with: event)
    }

    private func word(at windowPoint: NSPoint) -> String? {
        guard let layoutManager, let textContainer else { return nil }

        var point = convert(windowPoint, from: nil)
        point.x -= textContainerOrigin.x
        point.y -= textContainerOrigin.y

        let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer)
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let nsString = string as NSString
        guard characterIndex < nsString.length else { return nil }

        let allowed = CharacterSet.letters.union(CharacterSet(charactersIn: "-'"))
        var start = characterIndex
        var end = characterIndex

        while start > 0 {
            let scalar = UnicodeScalar(nsString.character(at: start - 1))
            guard let scalar, allowed.contains(scalar) else { break }
            start -= 1
        }

        while end < nsString.length {
            let scalar = UnicodeScalar(nsString.character(at: end))
            guard let scalar, allowed.contains(scalar) else { break }
            end += 1
        }

        guard end > start else { return nil }
        let word = nsString.substring(with: NSRange(location: start, length: end - start))
            .trimmingCharacters(in: CharacterSet(charactersIn: "-'"))

        return word.isEmpty ? nil : word
    }
}
