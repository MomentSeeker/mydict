import Foundation

public struct LookupHistoryItem: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let wordID: String
    public let queryText: String
    public let selectedHeadword: String
    public let lookedUpAt: Date
    public var isFavorite: Bool
    public var familiarity: Int

    public init(
        id: UUID = UUID(),
        wordID: String,
        queryText: String,
        selectedHeadword: String,
        lookedUpAt: Date = Date(),
        isFavorite: Bool = false,
        familiarity: Int = 0
    ) {
        self.id = id
        self.wordID = wordID
        self.queryText = queryText
        self.selectedHeadword = selectedHeadword
        self.lookedUpAt = lookedUpAt
        self.isFavorite = isFavorite
        self.familiarity = familiarity
    }
}
