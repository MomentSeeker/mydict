import Foundation

public struct SearchCandidate: Identifiable, Hashable, Sendable {
    public let id: String
    public let entry: DictionaryEntry
    public let score: Double
    public let reason: String

    public init(entry: DictionaryEntry, score: Double, reason: String) {
        self.id = entry.id
        self.entry = entry
        self.score = score
        self.reason = reason
    }
}
