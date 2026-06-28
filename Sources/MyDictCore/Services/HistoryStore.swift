import Foundation

public final class HistoryStore: @unchecked Sendable {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = baseURL
                .appendingPathComponent("MyDict", isDirectory: true)
                .appendingPathComponent("lookup-history.json")
        }

        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() -> [LookupHistoryItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        return (try? decoder.decode([LookupHistoryItem].self, from: data)) ?? []
    }

    public func save(_ items: [LookupHistoryItem]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func record(entry: DictionaryEntry, query: String, in items: [LookupHistoryItem]) -> [LookupHistoryItem] {
        var next = items
        next.insert(LookupHistoryItem(
            wordID: entry.id,
            queryText: query,
            selectedHeadword: entry.headword
        ), at: 0)

        return Array(next.prefix(500))
    }

    public func boosts(from items: [LookupHistoryItem]) -> [String: Double] {
        var counts: [String: Double] = [:]
        for item in items.prefix(100) {
            counts[item.wordID, default: 0] += 1
        }
        return counts.mapValues { min(1, log($0 + 1) / log(6)) }
    }
}
