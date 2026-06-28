import AppKit
import MyDictCore
import SwiftUI

struct DetailView: View {
    @EnvironmentObject private var model: AppModel
    let entry: DictionaryEntry?

    var body: some View {
        if let entry {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header(entry)
                    chineseMeanings(entry)
                    englishDefinitions(entry)
                    examples(entry)
                    relations(entry)
                    usage(entry)
                    memoryAid(entry)
                    source(entry)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 28)
                .frame(maxWidth: 680, alignment: .leading)
            }
        } else {
            Color.clear
        }
    }

    // MARK: - Header

    private func header(_ entry: DictionaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(entry.headword)
                    .font(.system(size: 34, weight: .bold))
                    .textSelection(.enabled)

                Spacer(minLength: 0)

                Button {
                    model.speak(entry)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 15, weight: .medium))
                }
                .buttonStyle(.borderless)
                .help("Speak")

                Button {
                    model.toggleFavorite(for: entry)
                } label: {
                    Image(systemName: model.isFavorite(entry) ? "star.fill" : "star")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(model.isFavorite(entry) ? Color.yellow : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help("Favorite")
            }

            if !entry.pronunciations.isEmpty {
                HStack(spacing: 8) {
                    ForEach(entry.pronunciations) { pronunciation in
                        Button {
                            model.speak(entry)
                        } label: {
                            HStack(spacing: 5) {
                                Text(pronunciation.dialect)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(pronunciation.ipa)
                                    .font(.system(size: 14, design: .serif))
                                    .foregroundStyle(.primary)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Speak")
                    }
                }
            }
        }
    }

    // MARK: - Definitions

    private func chineseMeanings(_ entry: DictionaryEntry) -> some View {
        let senses = entry.senses
            .filter { !$0.translation.isEmpty }
            .sorted { $0.rank < $1.rank }

        return Group {
            if !senses.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader("Chinese", icon: "character.book.closed", source: dominantSource(senses))
                        ForEach(Array(senses.enumerated()), id: \.element.id) { index, sense in
                            chineseRow(index: index + 1, total: senses.count, sense: sense, sectionSource: dominantSource(senses))
                        }
                    }
                }
            }
        }
    }

    private func chineseRow(index: Int, total: Int, sense: Sense, sectionSource: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            if total > 1 {
                indexLabel(index).padding(.top, 2)
            }
            LookupText(
                sense.translation,
                font: .systemFont(ofSize: 17, weight: .medium),
                color: .labelColor,
                onLookup: model.lookupInlineWord
            )
        }
    }

    private func englishDefinitions(_ entry: DictionaryEntry) -> some View {
        let senses = entry.senses
            .filter { $0.translation.isEmpty || $0.source.localizedCaseInsensitiveContains("WordNet") }
            .sorted { $0.rank < $1.rank }

        return Group {
            if !senses.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("English", icon: "text.book.closed", source: dominantSource(senses))
                        ForEach(Array(senses.enumerated()), id: \.element.id) { index, sense in
                            englishRow(index: index + 1, sense: sense, sectionSource: dominantSource(senses))
                        }
                    }
                }
            }
        }
    }

    private func englishRow(index: Int, sense: Sense, sectionSource: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            indexLabel(index).padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                LookupText(
                    sense.definition,
                    font: .systemFont(ofSize: 15),
                    color: .labelColor,
                    prefix: posAbbreviation(sense.partOfSpeech),
                    prefixFont: posFont,
                    prefixColor: .controlAccentColor,
                    onLookup: model.lookupInlineWord
                )
                if sense.source != sectionSource { SourceTag(sense.source) }
            }
        }
    }

    // MARK: - Examples

    private func examples(_ entry: DictionaryEntry) -> some View {
        Group {
            if !entry.examples.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Examples", icon: "quote.opening")
                        ForEach(entry.examples.prefix(8)) { example in
                            ExampleBlock(example: example)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Relations

    @ViewBuilder
    private func relations(_ entry: DictionaryEntry) -> some View {
        if !entry.relations.isEmpty {
            let grouped = Dictionary(grouping: entry.relations, by: \.kind)
            VStack(alignment: .leading, spacing: 18) {
                relationGroup(grouped[.synonym], title: "Synonyms", icon: "circle.grid.2x2")
                relationGroup(grouped[.antonym], title: "Antonyms", icon: "arrow.left.arrow.right")
                relationGroup(grouped[.derivation], title: "Related", icon: "point.3.connected.trianglepath.dotted")
                relationGroup(grouped[.form], title: "Forms", icon: "textformat.abc", showNote: true)
                relationGroup(grouped[.lookalike], title: "Look-alikes", icon: "rectangle.on.rectangle")
                relationGroup(grouped[.root], title: "Roots", icon: "leaf", showNote: true, clickable: false)
            }
        }
    }

    @ViewBuilder
    private func relationGroup(
        _ relations: [WordRelation]?,
        title: String,
        icon: String,
        showNote: Bool = false,
        clickable: Bool = true
    ) -> some View {
        if let relations, !relations.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                SectionHeader(title, icon: icon)
                FlowLayout(spacing: 7) {
                    ForEach(relations) { relation in
                        WordChip(
                            word: relation.word,
                            note: showNote ? relation.note : "",
                            clickable: clickable
                        )
                    }
                }
            }
        }
    }

    // MARK: - Usage (近义辨析)

    @ViewBuilder
    private func usage(_ entry: DictionaryEntry) -> some View {
        if !entry.usageNotes.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(entry.usageNotes) { note in
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader("Usage", icon: "lightbulb", source: note.source)
                        let others = note.members.filter {
                            $0.caseInsensitiveCompare(entry.headword) != .orderedSame
                        }
                        if !others.isEmpty {
                            FlowLayout(spacing: 7) {
                                ForEach(others, id: \.self) { member in
                                    WordChip(word: member, note: "", clickable: true)
                                }
                            }
                        }
                        LookupText(
                            note.body,
                            font: .systemFont(ofSize: 14),
                            color: .secondaryLabelColor,
                            lineSpacing: 5,
                            onLookup: model.lookupInlineWord
                        )
                    }
                }
            }
        }
    }

    // MARK: - Memory

    private func memoryAid(_ entry: DictionaryEntry) -> some View {
        let aids: [(String, String)] = [
            ("拆", entry.memoryAid.breakdown),
            ("联", entry.memoryAid.association),
            ("用", entry.memoryAid.usage),
            ("辨", entry.memoryAid.contrast)
        ].filter { !$0.1.isEmpty }

        return Group {
            if !aids.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Memory", icon: "sparkle.magnifyingglass")
                        ForEach(aids, id: \.0) { title, value in
                            MemoryLine(title: title, value: value)
                        }
                    }
                }
            }
        }
    }

    private func source(_ entry: DictionaryEntry) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "archivebox")
            Text(entry.source)
        }
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
    }

    // MARK: - Shared bits

    private func indexLabel(_ index: Int) -> some View {
        Text("\(index)")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.tertiary)
            .frame(width: 15, alignment: .trailing)
    }

    private var posFont: NSFont {
        let base = NSFont.systemFont(ofSize: 14, weight: .semibold)
        return NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
    }

    private func dominantSource(_ senses: [Sense]) -> String {
        senses.first?.source ?? ""
    }

    private func posAbbreviation(_ raw: String) -> String {
        let value = raw.lowercased()
        if value.hasPrefix("noun") { return "n." }
        if value.hasPrefix("verb") { return "v." }
        if value.hasPrefix("adjective") || value.hasPrefix("adj") { return "adj." }
        if value.hasPrefix("adverb") || value.hasPrefix("adv") { return "adv." }
        let leading = value.prefix { $0.isLetter }
        return leading.isEmpty ? "" : "\(leading)."
    }
}

// MARK: - Components

struct SectionHeader: View {
    let title: String
    let icon: String
    let source: String

    init(_ title: String, icon: String, source: String = "") {
        self.title = title
        self.icon = icon
        self.source = source
    }

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
            Text(title.uppercased())
                .kerning(0.6)
            Spacer(minLength: 8)
            if !source.isEmpty {
                Text(source)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
    }
}

private struct ExampleBlock: View {
    @EnvironmentObject private var model: AppModel
    let example: ExampleSentence

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.accentColor.opacity(0.35))
                .frame(width: 3)
                .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 5) {
                LookupText(
                    example.text,
                    font: .systemFont(ofSize: 15),
                    color: .labelColor,
                    onLookup: model.lookupInlineWord
                )
                if !example.translation.isEmpty {
                    LookupText(
                        example.translation,
                        font: .systemFont(ofSize: 13),
                        color: .secondaryLabelColor,
                        onLookup: model.lookupInlineWord
                    )
                }
            }
        }
    }
}

private struct WordChip: View {
    @EnvironmentObject private var model: AppModel
    let word: String
    let note: String
    let clickable: Bool

    var body: some View {
        if clickable {
            Button {
                model.lookupInlineWord(word)
            } label: { content }
            .buttonStyle(.plain)
            .help("Look up \(word)")
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 5) {
            Text(word)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
            if !note.isEmpty {
                Text(note)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            clickable ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.07),
            in: Capsule()
        )
        .overlay(
            Capsule().strokeBorder(
                clickable ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.12),
                lineWidth: 1
            )
        )
        .contentShape(Capsule())
    }
}

/// Wrapping flow layout for variable-width chips (macOS 14+).
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth.isFinite ? maxWidth : x, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct SourceTag: View {
    let source: String

    init(_ source: String) {
        self.source = source
    }

    var body: some View {
        Text(source.isEmpty ? "Local" : source)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.10), in: Capsule())
    }
}

private struct MemoryLine: View {
    @EnvironmentObject private var model: AppModel
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            LookupText(
                value,
                font: .systemFont(ofSize: 14),
                color: .secondaryLabelColor,
                onLookup: model.lookupInlineWord
            )
        }
    }
}
