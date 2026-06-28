import Foundation
import MyDictCore

@MainActor
final class AppModel: ObservableObject {
    enum Section: String, CaseIterable, Identifiable {
        case lookup
        case history
        case review

        var id: String { rawValue }

        var title: String {
            switch self {
            case .lookup: "Lookup"
            case .history: "History"
            case .review: "Review"
            }
        }

        var icon: String {
            switch self {
            case .lookup: "magnifyingglass"
            case .history: "clock.arrow.circlepath"
            case .review: "rectangle.stack"
            }
        }
    }

    @Published var query = "" {
        didSet { scheduleSearch() }
    }
    @Published private(set) var candidates: [SearchCandidate] = []
    @Published private(set) var highlightedCandidateID: String?
    @Published private(set) var selectedEntry: DictionaryEntry?
    @Published private(set) var history: [LookupHistoryItem] = []
    @Published private(set) var dictionaryStatus = "Loading full dictionary..."
    @Published private(set) var entryCount = SeedDictionary.entries.count
    @Published var section: Section = .lookup
    @Published var focusSearchToken = 0
    @Published var historySearchText = ""

    private var entries = SeedDictionary.entries
    private var searchService: SearchService
    private var detailLoadTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var usesSQLiteSearch = false
    private let historyStore: HistoryStore
    private let speechService = SpeechService()

    init(historyStore: HistoryStore = HistoryStore()) {
        self.historyStore = historyStore
        searchService = SearchService(entries: entries)
        history = historyStore.load()
        loadFullDictionary()
    }

    /// Debounced, off-main-thread search. Runs on every keystroke without
    /// blocking typing: cancels any in-flight search, waits briefly, then does
    /// the SQLite work on a background task and applies results on the main actor.
    private func scheduleSearch() {
        searchTask?.cancel()

        let current = query
        guard !current.isEmpty else {
            candidates = []
            highlightedCandidateID = nil
            selectedEntry = nil
            detailLoadTask?.cancel()
            return
        }

        let boosts = historyStore.boosts(from: history)
        let useSQLite = usesSQLiteSearch
        let seedEntries = entries

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(110))
            if Task.isCancelled { return }

            let results = await Task.detached(priority: .userInitiated) {
                performSearch(query: current, useSQLite: useSQLite, seedEntries: seedEntries, boosts: boosts)
            }.value

            if Task.isCancelled { return }
            guard let self, self.query == current else { return }
            self.applyCandidates(results)
        }
    }

    private func applyCandidates(_ results: [SearchCandidate]) {
        candidates = results

        guard !results.isEmpty else {
            highlightedCandidateID = nil
            selectedEntry = nil
            detailLoadTask?.cancel()
            return
        }

        let targetID = highlightedCandidateID.flatMap { id in
            results.contains { $0.id == id } ? id : nil
        } ?? results.first!.id
        highlightedCandidateID = targetID

        // Already showing this word (possibly with full detail) — don't downgrade it.
        if selectedEntry?.id == targetID { return }

        if let candidate = results.first(where: { $0.id == targetID }) {
            selectedEntry = candidate.entry
            scheduleDetailLoad(for: candidate.entry)
        }
    }

    func select(_ candidate: SearchCandidate) {
        let queryText = query
        highlightedCandidateID = candidate.id
        select(candidate.entry, queryText: queryText, loadFullDetail: true)
    }

    func select(_ entry: DictionaryEntry, queryText: String? = nil, loadFullDetail: Bool = false) {
        let detailedEntry = loadFullDetailIfAvailable(for: entry, shouldLoad: loadFullDetail)
        section = .lookup
        let queryValue = queryText?.isEmpty == false ? queryText! : detailedEntry.headword
        history = historyStore.record(entry: detailedEntry, query: queryValue, in: history)
        try? historyStore.save(history)
        detailLoadTask?.cancel()
        // Pin the highlight to this word so list refreshes keep the full detail
        // instead of downgrading it.
        highlightedCandidateID = detailedEntry.id
        selectedEntry = detailedEntry
    }

    func preview(_ candidate: SearchCandidate) {
        highlightedCandidateID = candidate.id
        selectedEntry = candidate.entry
        section = .lookup
        scheduleDetailLoad(for: candidate.entry)
    }

    func confirmHighlightedCandidate() {
        if let candidate = highlightedCandidate() ?? candidates.first {
            select(candidate)
            return
        }
        // Enter pressed before the debounced search produced candidates — search now.
        let results = performSearch(
            query: query,
            useSQLite: usesSQLiteSearch,
            seedEntries: entries,
            boosts: historyStore.boosts(from: history)
        )
        if let first = results.first { select(first) }
    }

    func moveCandidateSelection(by delta: Int) {
        guard !candidates.isEmpty else { return }

        let currentIndex = highlightedCandidateID.flatMap { id in
            candidates.firstIndex { $0.id == id }
        } ?? 0

        let nextIndex = min(max(currentIndex + delta, 0), candidates.count - 1)
        preview(candidates[nextIndex])
    }

    func requestSearchFocus(revealLookup: Bool = false) {
        if revealLookup {
            section = .lookup
        }
        focusSearchToken += 1
    }

    private func highlightedCandidate() -> SearchCandidate? {
        guard let highlightedCandidateID else { return nil }
        return candidates.first { $0.id == highlightedCandidateID }
    }

    func selectHistoryItem(_ item: LookupHistoryItem) {
        guard let entry = entry(withID: item.wordID) else { return }
        query = item.selectedHeadword
        select(entry, queryText: item.queryText, loadFullDetail: true)
    }

    func toggleFavorite(for entry: DictionaryEntry) {
        var hasExisting = false
        history = history.map { item in
            guard item.wordID == entry.id else { return item }
            hasExisting = true
            var next = item
            next.isFavorite.toggle()
            return next
        }

        if !hasExisting {
            var item = LookupHistoryItem(wordID: entry.id, queryText: entry.headword, selectedHeadword: entry.headword)
            item.isFavorite = true
            history.insert(item, at: 0)
        }

        try? historyStore.save(history)
    }

    func isFavorite(_ entry: DictionaryEntry) -> Bool {
        history.contains { $0.wordID == entry.id && $0.isFavorite }
    }

    func reviewResult(for entry: DictionaryEntry, familiarity: Int) {
        history = history.map { item in
            guard item.wordID == entry.id else { return item }
            var next = item
            next.familiarity = familiarity
            return next
        }
        try? historyStore.save(history)
    }

    // MARK: - History grouping

    func lookupCount(for wordID: String) -> Int {
        history.reduce(0) { $0 + ($1.wordID == wordID ? 1 : 0) }
    }

    var isFilteringHistory: Bool {
        !historySearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func historyLookupCount(matching searchText: String? = nil) -> Int {
        historyItems(matching: searchText).count
    }

    func historyByDay(matching searchText: String? = nil) -> [HistoryDaySummary] {
        let calendar = Calendar.current
        let totals = history.reduce(into: [String: Int]()) { $0[$1.wordID, default: 0] += 1 }
        let favorites = Set(history.filter(\.isFavorite).map(\.wordID))
        let visibleItems = historyItems(matching: searchText)

        let grouped = Dictionary(grouping: visibleItems) { calendar.startOfDay(for: $0.lookedUpAt) }

        return grouped.map { day, items in
            var seen = Set<String>()
            var words: [HistoryWordSummary] = []
            for item in items.sorted(by: { $0.lookedUpAt > $1.lookedUpAt }) where !seen.contains(item.wordID) {
                seen.insert(item.wordID)
                words.append(HistoryWordSummary(
                    id: "\(Int(day.timeIntervalSince1970))-\(item.wordID)",
                    wordID: item.wordID,
                    headword: item.selectedHeadword,
                    queryText: item.queryText,
                    count: totals[item.wordID] ?? 1,
                    lastLookedUp: item.lookedUpAt,
                    isFavorite: favorites.contains(item.wordID)
                ))
            }
            return HistoryDaySummary(date: day, title: Self.dayTitle(for: day, calendar: calendar), words: words)
        }
        .sorted { $0.date > $1.date }
    }

    private func historyItems(matching searchText: String? = nil) -> [LookupHistoryItem] {
        historyStore.search(history, matching: searchText ?? historySearchText)
    }

    func openWord(wordID: String, query: String) {
        guard let entry = entry(withID: wordID) else { return }
        self.query = entry.headword
        select(entry, queryText: query, loadFullDetail: true)
    }

    private static func dayTitle(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }

        let formatter = DateFormatter()
        if calendar.component(.year, from: day) == calendar.component(.year, from: Date()) {
            formatter.dateFormat = "EEEE, MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: day)
    }

    // MARK: - Review queue

    /// Words still worth reviewing, ordered so the ones you look up most often
    /// (i.e. keep forgetting) come first.
    func reviewQueue(limit: Int = 20) -> [DictionaryEntry] {
        let totals = history.reduce(into: [String: Int]()) { $0[$1.wordID, default: 0] += 1 }
        let familiarity = Dictionary(grouping: history, by: \.wordID)
            .compactMapValues { $0.map(\.familiarity).min() }
        let lastSeen = Dictionary(grouping: history, by: \.wordID)
            .compactMapValues { $0.map(\.lookedUpAt).max() }

        let candidates = totals.keys
            .filter { (familiarity[$0] ?? 0) < 2 }
            .sorted { lhs, rhs in
                let lc = totals[lhs] ?? 0
                let rc = totals[rhs] ?? 0
                if lc != rc { return lc > rc }
                return (lastSeen[lhs] ?? .distantPast) > (lastSeen[rhs] ?? .distantPast)
            }
            .prefix(limit)

        return candidates.compactMap { entry(withID: $0) }
    }

    func recentUniqueEntries(limit: Int = 30) -> [DictionaryEntry] {
        var seen = Set<String>()
        var result: [DictionaryEntry] = []

        for item in history where !seen.contains(item.wordID) {
            guard let entry = entry(withID: item.wordID) else { continue }
            seen.insert(item.wordID)
            result.append(entry)
            if result.count >= limit { break }
        }

        return result
    }

    func reviewEntries() -> [DictionaryEntry] {
        let reviewed = Dictionary(grouping: history, by: \.wordID).compactMapValues { items in
            items.map(\.familiarity).min()
        }

        return recentUniqueEntries(limit: 50)
            .filter { reviewed[$0.id, default: 0] < 2 }
    }

    func speakSelectedWord() {
        guard let selectedEntry else { return }
        speak(selectedEntry)
    }

    func speak(_ entry: DictionaryEntry) {
        speechService.speak(entry.headword)
    }

    func lookupInlineWord(_ word: String) {
        let normalized = TextNormalizer.normalize(word)
        guard !normalized.isEmpty else { return }

        query = normalized
        // Deliberate navigation (double-click / chip): resolve immediately rather
        // than waiting for the debounced list to catch up.
        let results = performSearch(
            query: normalized,
            useSQLite: usesSQLiteSearch,
            seedEntries: entries,
            boosts: historyStore.boosts(from: history)
        )
        if let best = results.first {
            select(best)
        }
    }

    private func loadFullDictionary() {
        Task.detached(priority: .userInitiated) {
            let wordCount = SQLiteDictionaryStore.bundledWordCount()

            await MainActor.run {
                self.entryCount = wordCount ?? SeedDictionary.entries.count
                self.usesSQLiteSearch = wordCount != nil
                self.dictionaryStatus = self.usesSQLiteSearch
                    ? "WordNet + ECDICT offline"
                    : "Seed dictionary"
                self.scheduleSearch()
            }
        }
    }

    private func loadFullDetailIfAvailable(for entry: DictionaryEntry, shouldLoad: Bool) -> DictionaryEntry {
        guard shouldLoad else { return entry }
        // CC-CEDICT candidates already carry their full content.
        if entry.id.hasPrefix("cedict-") { return entry }
        return SQLiteDictionaryStore.loadBundledEntry(id: entry.id) ?? entry
    }

    private func entry(withID id: String) -> DictionaryEntry? {
        if id.hasPrefix("cedict-") {
            return SQLiteDictionaryStore.loadBundledCEDICTEntry(id: id)
        }
        if usesSQLiteSearch {
            return SQLiteDictionaryStore.loadBundledEntry(id: id)
        }
        return searchService.entry(withID: id)
    }

    private func scheduleDetailLoad(for entry: DictionaryEntry) {
        detailLoadTask?.cancel()
        // CC-CEDICT entries are complete already; nothing extra to load.
        if entry.id.hasPrefix("cedict-") { return }

        detailLoadTask = Task { [entryID = entry.id] in
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }

            let detailedEntry = await Task.detached(priority: .utility) {
                SQLiteDictionaryStore.loadBundledEntry(id: entryID)
            }.value

            guard !Task.isCancelled,
                  let detailedEntry,
                  self.selectedEntry?.id == entryID else {
                return
            }

            self.selectedEntry = detailedEntry
        }
    }
}

/// Pure search entry point, safe to call off the main actor.
private func performSearch(
    query: String,
    useSQLite: Bool,
    seedEntries: [DictionaryEntry],
    boosts: [String: Double]
) -> [SearchCandidate] {
    // Chinese input routes to the CC-CEDICT (Chinese -> English) path.
    if TextNormalizer.containsHan(query) {
        return SQLiteDictionaryStore.searchBundledCEDICT(query: query)
    }
    if useSQLite {
        return SQLiteDictionaryStore.searchBundledEntries(query: query, historyBoosts: boosts)
    }
    return SearchService(entries: seedEntries).search(query, historyBoosts: boosts)
}

struct HistoryDaySummary: Identifiable {
    var id: String { "\(Int(date.timeIntervalSince1970))" }
    let date: Date
    let title: String
    let words: [HistoryWordSummary]
}

struct HistoryWordSummary: Identifiable {
    let id: String
    let wordID: String
    let headword: String
    let queryText: String
    let count: Int
    let lastLookedUp: Date
    let isFavorite: Bool
}
