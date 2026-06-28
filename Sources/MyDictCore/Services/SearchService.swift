import Foundation

public struct SearchService: Sendable {
    private let entries: [DictionaryEntry]
    private let entriesByID: [String: DictionaryEntry]
    private let soundexBuckets: [String: [DictionaryEntry]]
    private let prefixBuckets: [String: [DictionaryEntry]]

    public init(entries: [DictionaryEntry]) {
        self.entries = entries
        self.entriesByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        self.soundexBuckets = Dictionary(grouping: entries, by: { Self.soundex($0.normalized) })
        self.prefixBuckets = Self.buildPrefixBuckets(entries)
    }

    public func search(_ query: String, historyBoosts: [String: Double] = [:], limit: Int = 10) -> [SearchCandidate] {
        let normalizedQuery = TextNormalizer.normalize(query)
        guard !normalizedQuery.isEmpty else {
            return []
        }

        let querySoundex = soundex(normalizedQuery)
        let candidatePool = candidatePool(for: normalizedQuery, querySoundex: querySoundex)

        return candidatePool.compactMap { entry in
            let normalized = entry.normalized
            let editSimilarity = similarity(normalizedQuery, normalized)
            let prefixScore = normalized.hasPrefix(normalizedQuery) ? 1.0 : 0.0
            let containsScore = normalized.contains(normalizedQuery) ? 0.55 : 0.0
            let phoneticScore = querySoundex == soundex(normalized) ? 1.0 : 0.0
            let exactScore = normalized == normalizedQuery ? 1.0 : 0.0
            let historyBoost = historyBoosts[entry.id, default: 0.0]
            let frequencyScore = min(max(entry.frequency, 0), 1)

            let score = exactScore * 0.45
                + editSimilarity * 0.34
                + prefixScore * 0.12
                + containsScore * 0.06
                + phoneticScore * 0.05
                + frequencyScore * 0.03
                + historyBoost * 0.08

            guard score >= 0.25 || prefixScore > 0 || containsScore > 0 else {
                return nil
            }

            return SearchCandidate(entry: entry, score: score, reason: reason(
                exact: exactScore > 0,
                prefix: prefixScore > 0,
                contains: containsScore > 0,
                phonetic: phoneticScore > 0,
                editSimilarity: editSimilarity,
                historyBoost: historyBoost
            ))
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.entry.frequency > rhs.entry.frequency
            }
            return lhs.score > rhs.score
        }
        .prefix(limit)
        .map { $0 }
    }

    public func entry(withID id: String) -> DictionaryEntry? {
        entriesByID[id]
    }

    private func candidatePool(for normalizedQuery: String, querySoundex: String) -> [DictionaryEntry] {
        if entries.count <= 5_000 {
            return entries
        }

        var pool: [String: DictionaryEntry] = [:]
        let queryLength = normalizedQuery.count
        let prefixLength = min(max(queryLength - 1, 1), 4)
        let prefix = String(normalizedQuery.prefix(prefixLength))

        func add(_ entry: DictionaryEntry) {
            pool[entry.id] = entry
        }

        for entry in prefixBuckets[prefix, default: []] {
            if entry.normalized == normalizedQuery
                || entry.normalized.hasPrefix(normalizedQuery)
                || entry.normalized.hasPrefix(prefix) {
                add(entry)
            }
        }

        if queryLength >= 5 {
            let infix = String(normalizedQuery.prefix(3))
            for entry in prefixBuckets[infix, default: []].prefix(1_200) where entry.normalized.contains(normalizedQuery) {
                add(entry)
            }
        }

        for entry in soundexBuckets[querySoundex, default: []].prefix(700) {
            let lengthDelta = abs(entry.normalized.count - queryLength)
            if lengthDelta <= max(2, queryLength / 3) {
                add(entry)
            }
        }

        let maxPoolSize = 2_500
        if pool.count > maxPoolSize {
            return pool.values
                .sorted { $0.frequency > $1.frequency }
                .prefix(maxPoolSize)
                .map { $0 }
        }

        return Array(pool.values)
    }

    private static func buildPrefixBuckets(_ entries: [DictionaryEntry]) -> [String: [DictionaryEntry]] {
        var buckets: [String: [DictionaryEntry]] = [:]

        for entry in entries {
            let normalized = entry.normalized
            guard !normalized.isEmpty else { continue }
            for length in 1...min(4, normalized.count) {
                buckets[String(normalized.prefix(length)), default: []].append(entry)
            }
        }

        return buckets.mapValues { bucket in
            bucket.sorted { lhs, rhs in
                if lhs.frequency == rhs.frequency {
                    return lhs.headword < rhs.headword
                }
                return lhs.frequency > rhs.frequency
            }
        }
    }

    private func reason(
        exact: Bool,
        prefix: Bool,
        contains: Bool,
        phonetic: Bool,
        editSimilarity: Double,
        historyBoost: Double
    ) -> String {
        if exact { return "exact match" }
        if prefix { return "prefix match" }
        if historyBoost > 0 { return "from history" }
        if phonetic { return "sounds close" }
        if contains { return "contains query" }
        if editSimilarity > 0.72 { return "spelling close" }
        return "possible match"
    }

    public static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhs = Array(lhs)
        let rhs = Array(rhs)
        guard !lhs.isEmpty else { return rhs.count }
        guard !rhs.isEmpty else { return lhs.count }

        var previous = Array(0...rhs.count)
        var current = Array(repeating: 0, count: rhs.count + 1)

        for i in 1...lhs.count {
            current[0] = i
            for j in 1...rhs.count {
                let cost = lhs[i - 1] == rhs[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )
            }
            previous = current
        }

        return previous[rhs.count]
    }

    public static func similarity(_ lhs: String, _ rhs: String) -> Double {
        let maxLength = max(lhs.count, rhs.count)
        guard maxLength > 0 else { return 1 }
        let distance = levenshteinDistance(lhs, rhs)
        return max(0, 1 - Double(distance) / Double(maxLength))
    }

    private func similarity(_ lhs: String, _ rhs: String) -> Double {
        Self.similarity(lhs, rhs)
    }

    public static func soundex(_ word: String) -> String {
        let uppercased = word.uppercased().filter(\.isLetter)
        guard let first = uppercased.first else { return "" }

        let codes: [Character: Character] = [
            "B": "1", "F": "1", "P": "1", "V": "1",
            "C": "2", "G": "2", "J": "2", "K": "2", "Q": "2", "S": "2", "X": "2", "Z": "2",
            "D": "3", "T": "3",
            "L": "4",
            "M": "5", "N": "5",
            "R": "6"
        ]

        var result = [first]
        var previousCode = codes[first]

        for character in uppercased.dropFirst() {
            let code = codes[character]
            if let code, code != previousCode {
                result.append(code)
            }
            previousCode = code
        }

        return String(result).padding(toLength: 4, withPad: "0", startingAt: 0).prefix(4).description
    }

    private func soundex(_ word: String) -> String {
        Self.soundex(word)
    }
}
