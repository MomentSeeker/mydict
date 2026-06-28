import Foundation

public enum TextNormalizer {
    public static func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .filter { $0.isLetter || $0 == "-" || $0 == "'" }
    }

    /// True when the text contains CJK ideographs, used to route a query to the
    /// Chinese-to-English (CC-CEDICT) lookup path.
    public static func containsHan(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||   // CJK Unified Ideographs
            (0x3400...0x4DBF).contains(scalar.value) ||   // Extension A
            (0xF900...0xFAFF).contains(scalar.value)      // Compatibility Ideographs
        }
    }
}
