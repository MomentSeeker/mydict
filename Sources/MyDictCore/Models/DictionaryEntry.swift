import Foundation

public struct DictionaryEntry: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let headword: String
    public let normalized: String
    public let frequency: Double
    public let senses: [Sense]
    public let pronunciations: [Pronunciation]
    public let examples: [ExampleSentence]
    public let memoryAid: MemoryAid
    public let relations: [WordRelation]
    public let usageNotes: [UsageNote]
    public let source: String

    public init(
        id: String,
        headword: String,
        normalized: String,
        frequency: Double,
        senses: [Sense],
        pronunciations: [Pronunciation],
        examples: [ExampleSentence],
        memoryAid: MemoryAid,
        relations: [WordRelation] = [],
        usageNotes: [UsageNote] = [],
        source: String
    ) {
        self.id = id
        self.headword = headword
        self.normalized = normalized
        self.frequency = frequency
        self.senses = senses
        self.pronunciations = pronunciations
        self.examples = examples
        self.memoryAid = memoryAid
        self.relations = relations
        self.usageNotes = usageNotes
        self.source = source
    }
}

public struct UsageNote: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    /// Words discussed together in this discrimination group (e.g. quite, rather).
    public let members: [String]
    /// The explanation body, including per-word notes; may contain newlines.
    public let body: String
    public let source: String

    public init(id: String, members: [String], body: String, source: String) {
        self.id = id
        self.members = members
        self.body = body
        self.source = source
    }
}

public struct WordRelation: Identifiable, Hashable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case synonym
        case antonym
        case derivation
        case form
        case lookalike
        case root
    }

    public let id: String
    public let kind: Kind
    public let word: String
    /// Word id of the related entry when it exists in the dictionary, for direct
    /// navigation. Nil when the related word is not itself a headword.
    public let relatedWordID: String?
    /// Optional label, e.g. the grammatical role of an inflected form ("过去式").
    public let note: String
    public let source: String

    public init(
        id: String,
        kind: Kind,
        word: String,
        relatedWordID: String? = nil,
        note: String = "",
        source: String
    ) {
        self.id = id
        self.kind = kind
        self.word = word
        self.relatedWordID = relatedWordID
        self.note = note
        self.source = source
    }
}

public struct Sense: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let partOfSpeech: String
    public let definition: String
    public let translation: String
    public let rank: Int
    public let source: String

    public init(
        id: String,
        partOfSpeech: String,
        definition: String,
        translation: String,
        rank: Int,
        source: String
    ) {
        self.id = id
        self.partOfSpeech = partOfSpeech
        self.definition = definition
        self.translation = translation
        self.rank = rank
        self.source = source
    }
}

public struct Pronunciation: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let ipa: String
    public let dialect: String

    public init(id: String, ipa: String, dialect: String) {
        self.id = id
        self.ipa = ipa
        self.dialect = dialect
    }
}

public struct ExampleSentence: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let text: String
    public let translation: String
    public let source: String

    public init(id: String, text: String, translation: String, source: String) {
        self.id = id
        self.text = text
        self.translation = translation
        self.source = source
    }
}

public struct MemoryAid: Hashable, Codable, Sendable {
    public let breakdown: String
    public let association: String
    public let usage: String
    public let contrast: String

    public init(breakdown: String, association: String, usage: String, contrast: String) {
        self.breakdown = breakdown
        self.association = association
        self.usage = usage
        self.contrast = contrast
    }
}
