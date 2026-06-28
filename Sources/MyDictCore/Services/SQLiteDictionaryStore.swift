import Foundation
import SQLite3

public enum SQLiteDictionaryStore {
    public static func bundledDatabaseURL() -> URL? {
        Bundle.module.url(forResource: "dictionary", withExtension: "sqlite")
    }

    public static func loadBundledEntries() -> [DictionaryEntry] {
        guard let url = bundledDatabaseURL() else {
            return SeedDictionary.entries
        }

        do {
            let entries = try loadIndexEntries(from: url)
            return entries.isEmpty ? SeedDictionary.entries : entries
        } catch {
            return SeedDictionary.entries
        }
    }

    public static func loadBundledEntry(id: String) -> DictionaryEntry? {
        guard let url = bundledDatabaseURL() else {
            return SeedDictionary.entries.first { $0.id == id }
        }

        return try? loadEntry(id: id, from: url)
    }

    public static func bundledWordCount() -> Int? {
        guard let url = bundledDatabaseURL() else { return nil }

        do {
            let database = try SQLiteDatabase(url: url)
            defer { database.close() }
            return try database.query("SELECT COUNT(*) FROM words") { statement in
                Int(sqlite3_column_int(statement, 0))
            }.first
        } catch {
            return nil
        }
    }

    public static func searchBundledEntries(
        query: String,
        historyBoosts: [String: Double] = [:],
        limit: Int = 10
    ) -> [SearchCandidate] {
        guard let url = bundledDatabaseURL() else {
            return SearchService(entries: SeedDictionary.entries).search(query, historyBoosts: historyBoosts, limit: limit)
        }

        do {
            return try searchEntries(query: query, from: url, historyBoosts: historyBoosts, limit: limit)
        } catch {
            return SearchService(entries: SeedDictionary.entries).search(query, historyBoosts: historyBoosts, limit: limit)
        }
    }

    public static func searchEntries(
        query: String,
        from url: URL,
        historyBoosts: [String: Double] = [:],
        limit: Int = 10
    ) throws -> [SearchCandidate] {
        let normalizedQuery = TextNormalizer.normalize(query)
        guard !normalizedQuery.isEmpty else { return [] }

        let database = try SQLiteDatabase(url: url)
        defer { database.close() }

        let candidates = try searchIndexEntries(
            normalizedQuery: normalizedQuery,
            database: database,
            limit: max(80, limit * 20)
        )

        return SearchService(entries: candidates).search(
            normalizedQuery,
            historyBoosts: historyBoosts,
            limit: limit
        )
    }

    // MARK: - Chinese -> English (CC-CEDICT)

    public static func searchBundledCEDICT(query: String, limit: Int = 12) -> [SearchCandidate] {
        guard let url = bundledDatabaseURL() else { return [] }
        return (try? searchCEDICT(query: query, from: url, limit: limit)) ?? []
    }

    public static func loadBundledCEDICTEntry(id: String) -> DictionaryEntry? {
        guard let url = bundledDatabaseURL() else { return nil }
        return try? loadCEDICTEntry(id: id, from: url)
    }

    public static func searchCEDICT(query: String, from url: URL, limit: Int = 12) throws -> [SearchCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let database = try SQLiteDatabase(url: url)
        defer { database.close() }

        let entries = try cedictQuery(
            database: database,
            sql: """
            SELECT rowid, simplified, traditional, pinyin, definitions
            FROM cedict
            WHERE simplified = ? OR simplified LIKE ? OR traditional = ?
            ORDER BY CASE WHEN simplified = ? THEN 0 ELSE 1 END, length ASC, rowid ASC
            LIMIT ?
            """,
            bindings: [trimmed, trimmed + "%", trimmed, trimmed, String(limit)]
        )

        return entries.enumerated().map { index, entry in
            SearchCandidate(entry: entry, score: 1.0 - Double(index) * 0.01, reason: "中 → 英")
        }
    }

    public static func loadCEDICTEntry(id: String, from url: URL) throws -> DictionaryEntry? {
        guard id.hasPrefix("cedict-"), let rowid = Int(id.dropFirst("cedict-".count)) else { return nil }

        let database = try SQLiteDatabase(url: url)
        defer { database.close() }

        return try cedictQuery(
            database: database,
            sql: """
            SELECT rowid, simplified, traditional, pinyin, definitions
            FROM cedict
            WHERE rowid = ?
            LIMIT 1
            """,
            bindings: [String(rowid)]
        ).first
    }

    private static func cedictQuery(
        database: SQLiteDatabase,
        sql: String,
        bindings: [String]
    ) throws -> [DictionaryEntry] {
        do {
            return try database.query(sql, bindings: bindings) { statement in
                cedictEntry(from: statement)
            }
        } catch {
            return []
        }
    }

    private static func cedictEntry(from statement: OpaquePointer?) -> DictionaryEntry {
        let rowid = text(statement, 0)
        let simplified = text(statement, 1)
        let traditional = text(statement, 2)
        let pinyin = text(statement, 3)
        let definitions = text(statement, 4)
        let id = "cedict-\(rowid)"

        let glosses = definitions
            .components(separatedBy: " / ")
            .filter { !$0.isEmpty }
        let senses = glosses.enumerated().map { index, gloss in
            Sense(
                id: "\(id)-\(index)",
                partOfSpeech: "",
                definition: gloss,
                translation: "",
                rank: index,
                source: "CC-CEDICT"
            )
        }

        var pronunciations: [Pronunciation] = []
        if !pinyin.isEmpty {
            pronunciations.append(Pronunciation(id: "\(id)-py", ipa: pinyin, dialect: "拼音"))
        }
        if !traditional.isEmpty, traditional != simplified {
            pronunciations.append(Pronunciation(id: "\(id)-tr", ipa: traditional, dialect: "繁"))
        }

        return DictionaryEntry(
            id: id,
            headword: simplified,
            normalized: simplified,
            frequency: 0,
            senses: senses,
            pronunciations: pronunciations,
            examples: [],
            memoryAid: MemoryAid(breakdown: "", association: "", usage: "", contrast: ""),
            source: "CC-CEDICT"
        )
    }

    public static func loadEntries(from url: URL) throws -> [DictionaryEntry] {
        let database = try SQLiteDatabase(url: url)
        defer { database.close() }

        let words = try database.query("""
            SELECT id, headword, normalized, frequency, source
            FROM words
            ORDER BY frequency DESC, headword ASC
            """) { statement in
            WordRow(
                id: text(statement, 0),
                headword: text(statement, 1),
                normalized: text(statement, 2),
                frequency: sqlite3_column_double(statement, 3),
                source: text(statement, 4)
            )
        }

        return try words.map { word in
            let senses = try senses(for: word.id, database: database)
            let pronunciations = try pronunciations(for: word.id, database: database)
            let examples = try examples(for: word.id, database: database)
            let memoryAid = try memoryAid(for: word.id, database: database)

            return DictionaryEntry(
                id: word.id,
                headword: word.headword,
                normalized: word.normalized,
                frequency: word.frequency,
                senses: senses,
                pronunciations: pronunciations,
                examples: examples,
                memoryAid: memoryAid,
                source: word.source
            )
        }
    }

    public static func loadIndexEntries(from url: URL) throws -> [DictionaryEntry] {
        let database = try SQLiteDatabase(url: url)
        defer { database.close() }

        return try database.query("""
            SELECT
              w.id,
              w.headword,
              w.normalized,
              w.frequency,
              w.source,
              COALESCE(s.id, w.id || '-preview') AS sense_id,
              COALESCE(s.part_of_speech, '') AS part_of_speech,
              COALESCE(s.definition, '') AS definition,
              COALESCE(s.translation, '') AS translation,
              COALESCE(s.rank, 0) AS rank,
              COALESCE(s.source, w.source) AS sense_source,
              COALESCE(p.id, '') AS pronunciation_id,
              COALESCE(p.ipa, '') AS ipa,
              COALESCE(p.dialect, '') AS dialect
            FROM words w
            LEFT JOIN senses s ON s.id = (
              SELECT id FROM senses WHERE word_id = w.id ORDER BY rank ASC LIMIT 1
            )
            LEFT JOIN pronunciations p ON p.id = (
              SELECT id FROM pronunciations WHERE word_id = w.id ORDER BY dialect ASC LIMIT 1
            )
            ORDER BY w.frequency DESC, w.headword ASC
            """) { statement in
            let wordID = text(statement, 0)
            let pronunciationID = text(statement, 11)
            let ipa = text(statement, 12)
            let dialect = text(statement, 13)

            return DictionaryEntry(
                id: wordID,
                headword: text(statement, 1),
                normalized: text(statement, 2),
                frequency: sqlite3_column_double(statement, 3),
                senses: [
                    Sense(
                        id: text(statement, 5),
                        partOfSpeech: text(statement, 6),
                        definition: text(statement, 7),
                        translation: text(statement, 8),
                        rank: Int(sqlite3_column_int(statement, 9)),
                        source: text(statement, 10)
                    )
                ],
                pronunciations: ipa.isEmpty ? [] : [
                    Pronunciation(
                        id: pronunciationID.isEmpty ? "\(wordID)-preview-pronunciation" : pronunciationID,
                        ipa: ipa,
                        dialect: dialect.isEmpty ? "UK" : dialect
                    )
                ],
                examples: [],
                memoryAid: MemoryAid(breakdown: "", association: "", usage: "", contrast: ""),
                source: text(statement, 4)
            )
        }
    }

    private static func searchIndexEntries(
        normalizedQuery: String,
        database: SQLiteDatabase,
        limit: Int
    ) throws -> [DictionaryEntry] {
        let queryLength = normalizedQuery.count
        let neighborPrefix = String(normalizedQuery.prefix(min(3, max(queryLength, 1))))
        let ftsQuery = "\(escapeFTS(normalizedQuery))*"

        var entriesByID: [String: DictionaryEntry] = [:]

        func add(_ entries: [DictionaryEntry]) {
            for entry in entries {
                entriesByID[entry.id] = entry
            }
        }

        add(try queryWordIndexEntries(
            database: database,
            whereClause: "w.normalized = ?",
            bindings: [normalizedQuery],
            limit: limit
        ))

        add(try queryWordIndexEntries(
            database: database,
            whereClause: "w.normalized >= ? AND w.normalized < ?",
            bindings: [normalizedQuery, upperBound(forPrefix: normalizedQuery)],
            limit: limit
        ))

        add(try queryFTSIndexEntries(
            database: database,
            ftsQuery: ftsQuery,
            limit: limit
        ))

        if neighborPrefix != normalizedQuery {
            add(try queryWordIndexEntries(
                database: database,
                whereClause: "w.normalized >= ? AND w.normalized < ?",
                bindings: [neighborPrefix, upperBound(forPrefix: neighborPrefix)],
                limit: max(limit, 400)
            ))
        }

        return entriesByID.values
            .sorted { lhs, rhs in
                if lhs.frequency == rhs.frequency {
                    return lhs.headword < rhs.headword
                }
                return lhs.frequency > rhs.frequency
            }
    }

    private static func queryWordIndexEntries(
        database: SQLiteDatabase,
        whereClause: String,
        bindings: [String],
        limit: Int
    ) throws -> [DictionaryEntry] {
        try queryIndexEntries(
            database: database,
            sql: """
            SELECT
              w.id,
              w.headword,
              w.normalized,
              w.frequency,
              w.source,
              COALESCE(s.id, w.id || '-preview') AS sense_id,
              COALESCE(s.part_of_speech, '') AS part_of_speech,
              COALESCE(s.definition, '') AS definition,
              COALESCE(s.translation, '') AS translation,
              COALESCE(s.rank, 0) AS rank,
              COALESCE(s.source, w.source) AS sense_source,
              COALESCE(p.id, '') AS pronunciation_id,
              COALESCE(p.ipa, '') AS ipa,
              COALESCE(p.dialect, '') AS dialect
            FROM words w
            LEFT JOIN senses s ON s.id = (
              SELECT id FROM senses WHERE word_id = w.id ORDER BY rank ASC LIMIT 1
            )
            LEFT JOIN pronunciations p ON p.id = (
              SELECT id FROM pronunciations WHERE word_id = w.id ORDER BY dialect ASC LIMIT 1
            )
            WHERE \(whereClause)
            ORDER BY w.frequency DESC, w.headword ASC
            LIMIT ?
            """,
            bindings: bindings + [String(limit)]
        )
    }

    private static func queryFTSIndexEntries(
        database: SQLiteDatabase,
        ftsQuery: String,
        limit: Int
    ) throws -> [DictionaryEntry] {
        try queryIndexEntries(
            database: database,
            sql: """
            SELECT
              w.id,
              w.headword,
              w.normalized,
              w.frequency,
              w.source,
              COALESCE(s.id, w.id || '-preview') AS sense_id,
              COALESCE(s.part_of_speech, '') AS part_of_speech,
              COALESCE(s.definition, '') AS definition,
              COALESCE(s.translation, '') AS translation,
              COALESCE(s.rank, 0) AS rank,
              COALESCE(s.source, w.source) AS sense_source,
              COALESCE(p.id, '') AS pronunciation_id,
              COALESCE(p.ipa, '') AS ipa,
              COALESCE(p.dialect, '') AS dialect
            FROM words_fts f
            JOIN words w ON w.rowid = f.rowid
            LEFT JOIN senses s ON s.id = (
              SELECT id FROM senses WHERE word_id = w.id ORDER BY rank ASC LIMIT 1
            )
            LEFT JOIN pronunciations p ON p.id = (
              SELECT id FROM pronunciations WHERE word_id = w.id ORDER BY dialect ASC LIMIT 1
            )
            WHERE words_fts MATCH ?
            ORDER BY w.frequency DESC, w.headword ASC
            LIMIT ?
            """,
            bindings: [ftsQuery, String(limit)]
        )
    }

    private static func queryIndexEntries(
        database: SQLiteDatabase,
        sql: String,
        bindings: [String]
    ) throws -> [DictionaryEntry] {
        try database.query(sql, bindings: bindings) { statement in
            indexEntry(from: statement)
        }
    }

    private static func indexEntry(from statement: OpaquePointer?) -> DictionaryEntry {
        let wordID = text(statement, 0)
        let pronunciationID = text(statement, 11)
        let ipa = text(statement, 12)
        let dialect = text(statement, 13)

        return DictionaryEntry(
            id: wordID,
            headword: text(statement, 1),
            normalized: text(statement, 2),
            frequency: sqlite3_column_double(statement, 3),
            senses: [
                Sense(
                    id: text(statement, 5),
                    partOfSpeech: text(statement, 6),
                    definition: text(statement, 7),
                    translation: text(statement, 8),
                    rank: Int(sqlite3_column_int(statement, 9)),
                    source: text(statement, 10)
                )
            ],
            pronunciations: ipa.isEmpty ? [] : [
                Pronunciation(
                    id: pronunciationID.isEmpty ? "\(wordID)-preview-pronunciation" : pronunciationID,
                    ipa: ipa,
                    dialect: dialect.isEmpty ? "UK" : dialect
                )
            ],
            examples: [],
            memoryAid: MemoryAid(breakdown: "", association: "", usage: "", contrast: ""),
            source: text(statement, 4)
        )
    }

    public static func loadEntry(id: String, from url: URL) throws -> DictionaryEntry? {
        let database = try SQLiteDatabase(url: url)
        defer { database.close() }

        let words = try database.query("""
            SELECT id, headword, normalized, frequency, source
            FROM words
            WHERE id = ?
            LIMIT 1
            """, bindings: [id]) { statement in
            WordRow(
                id: text(statement, 0),
                headword: text(statement, 1),
                normalized: text(statement, 2),
                frequency: sqlite3_column_double(statement, 3),
                source: text(statement, 4)
            )
        }

        guard let word = words.first else { return nil }

        return DictionaryEntry(
            id: word.id,
            headword: word.headword,
            normalized: word.normalized,
            frequency: word.frequency,
            senses: try senses(for: word.id, database: database),
            pronunciations: try pronunciations(for: word.id, database: database),
            examples: try examples(for: word.id, database: database),
            memoryAid: try memoryAid(for: word.id, database: database),
            relations: try relations(for: word.id, database: database),
            usageNotes: try usageNotes(for: word.id, database: database),
            source: word.source
        )
    }

    private static func senses(for wordID: String, database: SQLiteDatabase) throws -> [Sense] {
        try database.query("""
            SELECT id, part_of_speech, definition, translation, rank, source
            FROM senses
            WHERE word_id = ?
            ORDER BY rank ASC
            """, bindings: [wordID]) { statement in
            Sense(
                id: text(statement, 0),
                partOfSpeech: text(statement, 1),
                definition: text(statement, 2),
                translation: text(statement, 3),
                rank: Int(sqlite3_column_int(statement, 4)),
                source: text(statement, 5)
            )
        }
    }

    private static func pronunciations(for wordID: String, database: SQLiteDatabase) throws -> [Pronunciation] {
        try database.query("""
            SELECT id, ipa, dialect
            FROM pronunciations
            WHERE word_id = ?
            ORDER BY dialect ASC
            """, bindings: [wordID]) { statement in
            Pronunciation(
                id: text(statement, 0),
                ipa: text(statement, 1),
                dialect: text(statement, 2)
            )
        }
    }

    private static func examples(for wordID: String, database: SQLiteDatabase) throws -> [ExampleSentence] {
        try database.query("""
            SELECT id, sentence, translation, source
            FROM examples
            WHERE word_id = ?
            ORDER BY quality_score DESC, id ASC
            """, bindings: [wordID]) { statement in
            ExampleSentence(
                id: text(statement, 0),
                text: text(statement, 1),
                translation: text(statement, 2),
                source: text(statement, 3)
            )
        }
    }

    private static func relations(for wordID: String, database: SQLiteDatabase) throws -> [WordRelation] {
        // The relations table is an optional augmentation; tolerate its absence
        // so detail loading still works against an older bundle.
        do {
            return try database.query("""
                SELECT id, relation_type, related_word, related_word_id, note, source
                FROM relations
                WHERE word_id = ?
                ORDER BY id ASC
                """, bindings: [wordID]) { statement in
                let kind = WordRelation.Kind(rawValue: text(statement, 1))
                let relatedID = text(statement, 3)
                return kind.map { kind in
                    WordRelation(
                        id: text(statement, 0),
                        kind: kind,
                        word: text(statement, 2),
                        relatedWordID: relatedID.isEmpty ? nil : relatedID,
                        note: text(statement, 4),
                        source: text(statement, 5)
                    )
                }
            }.compactMap { $0 }
        } catch {
            return []
        }
    }

    private static func usageNotes(for wordID: String, database: SQLiteDatabase) throws -> [UsageNote] {
        // Optional augmentation table; tolerate its absence.
        do {
            return try database.query("""
                SELECT id, members, body, source
                FROM usage_notes
                WHERE word_id = ?
                ORDER BY id ASC
                """, bindings: [wordID]) { statement in
                let members = text(statement, 1)
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                return UsageNote(
                    id: text(statement, 0),
                    members: members,
                    body: text(statement, 2),
                    source: text(statement, 3)
                )
            }
        } catch {
            return []
        }
    }

    private static func memoryAid(for wordID: String, database: SQLiteDatabase) throws -> MemoryAid {
        let rows = try database.query("""
            SELECT breakdown, association, usage, contrast
            FROM memory_aids
            WHERE word_id = ?
            LIMIT 1
            """, bindings: [wordID]) { statement in
            MemoryAid(
                breakdown: text(statement, 0),
                association: text(statement, 1),
                usage: text(statement, 2),
                contrast: text(statement, 3)
            )
        }

        return rows.first ?? MemoryAid(
            breakdown: "",
            association: "",
            usage: "",
            contrast: ""
        )
    }

    private static func text(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: pointer)
    }

    private static func upperBound(forPrefix prefix: String) -> String {
        prefix + "\u{10FFFF}"
    }

    private static func escapeFTS(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\"", with: "\"\"")
            .split(separator: " ")
            .map { "\"\($0)\"" }
            .joined(separator: " ")
    }
}

private struct WordRow {
    let id: String
    let headword: String
    let normalized: String
    let frequency: Double
    let source: String
}

private final class SQLiteDatabase {
    private var database: OpaquePointer?

    init(url: URL) throws {
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &database, flags, nil) == SQLITE_OK else {
            throw SQLiteError.open(message: message)
        }
    }

    func close() {
        if database != nil {
            sqlite3_close(database)
            database = nil
        }
    }

    func query<T>(
        _ sql: String,
        bindings: [String] = [],
        map: (OpaquePointer?) throws -> T
    ) throws -> [T] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepare(message: message, sql: sql)
        }
        defer { sqlite3_finalize(statement) }

        for (index, value) in bindings.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), value, -1, SQLITE_TRANSIENT)
        }

        var rows: [T] = []
        while true {
            let result = sqlite3_step(statement)
            switch result {
            case SQLITE_ROW:
                rows.append(try map(statement))
            case SQLITE_DONE:
                return rows
            default:
                throw SQLiteError.step(message: message, sql: sql)
            }
        }
    }

    private var message: String {
        guard let database, let error = sqlite3_errmsg(database) else { return "Unknown SQLite error" }
        return String(cString: error)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private enum SQLiteError: Error {
    case open(message: String)
    case prepare(message: String, sql: String)
    case step(message: String, sql: String)
}
