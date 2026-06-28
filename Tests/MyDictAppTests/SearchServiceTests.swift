import Foundation
@testable import MyDictApp
import MyDictCore
import Testing

@Test func typoStillFindsLikelyWord() {
    let service = SearchService(entries: SeedDictionary.entries)

    let results = service.search("recieve")

    #expect(results.first?.entry.headword == "receive")
}

@Test func prefixSearchRanksPrefixMatches() {
    let service = SearchService(entries: SeedDictionary.entries)

    let results = service.search("pron")

    #expect(results.first?.entry.headword == "pronunciation")
}

@Test func historyBoostCanLiftRecentWords() {
    let service = SearchService(entries: SeedDictionary.entries)

    let baseline = service.search("re")
    let boosted = service.search("re", historyBoosts: ["retrieve": 1.0])

    #expect(baseline.contains { $0.entry.headword == "retrieve" })
    #expect(boosted.first?.entry.headword == "retrieve")
}

@Test func textNormalizerTrimsCaseAndAccents() {
    #expect(TextNormalizer.normalize("  Résumé  ") == "resume")
}

@Test func historyStorePersistsLookups() throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    let store = HistoryStore(fileURL: fileURL)
    let entry = try #require(SeedDictionary.entries.first)

    let recorded = store.record(entry: entry, query: "possble", in: [])
    try store.save(recorded)

    let loaded = store.load()
    #expect(loaded.count == 1)
    #expect(loaded.first?.selectedHeadword == entry.headword)

    try? FileManager.default.removeItem(at: fileURL)
}

@Test func historySearchMatchesOriginalQueryAndSelectedHeadword() {
    let store = HistoryStore()
    let items = [
        LookupHistoryItem(
            wordID: "phone-in",
            queryText: "phone in",
            selectedHeadword: "phone-in"
        ),
        LookupHistoryItem(
            wordID: "receive",
            queryText: "recieve",
            selectedHeadword: "receive"
        )
    ]

    #expect(store.search(items, matching: "phone in").map(\.wordID) == ["phone-in"])
    #expect(store.search(items, matching: "receive").map(\.wordID) == ["receive"])
    #expect(store.search(items, matching: "RECIEVE").map(\.wordID) == ["receive"])
}

@MainActor
@Test func historyByDayCanFilterPastLookups() throws {
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    let store = HistoryStore(fileURL: fileURL)
    try store.save([
        LookupHistoryItem(
            wordID: "phone-in",
            queryText: "phone in",
            selectedHeadword: "phone-in",
            lookedUpAt: Date(timeIntervalSince1970: 1_800)
        ),
        LookupHistoryItem(
            wordID: "receive",
            queryText: "recieve",
            selectedHeadword: "receive",
            lookedUpAt: Date(timeIntervalSince1970: 900)
        )
    ])
    let model = AppModel(historyStore: store)

    let days = model.historyByDay(matching: "phone")

    #expect(days.flatMap(\.words).map(\.wordID) == ["phone-in"])

    try? FileManager.default.removeItem(at: fileURL)
}

@MainActor
@Test func selectingCandidateKeepsOriginalQueryText() {
    let model = AppModel()
    let entry = DictionaryEntry(
        id: "phone-in",
        headword: "phone-in",
        normalized: "phone-in",
        frequency: 1,
        senses: [
            Sense(
                id: "phone-in-1",
                partOfSpeech: "n.",
                definition: "a program in which the audience participates by telephone",
                translation: "观众通过电话参与的节目",
                rank: 1,
                source: "test"
            )
        ],
        pronunciations: [],
        examples: [],
        memoryAid: MemoryAid(breakdown: "", association: "", usage: "", contrast: ""),
        source: "test"
    )
    let candidate = SearchCandidate(entry: entry, score: 1, reason: "test")

    model.query = "phone in"
    model.select(candidate)

    #expect(model.query == "phone in")
    #expect(model.selectedEntry?.headword == "phone-in")
    #expect(model.history.first?.queryText == "phone in")
}

@MainActor
@Test func requestingSearchFocusCanPreserveOrRevealLookupSection() {
    let model = AppModel()
    model.section = .history

    model.requestSearchFocus()

    #expect(model.focusSearchToken == 1)
    #expect(model.section == .history)

    model.requestSearchFocus(revealLookup: true)

    #expect(model.focusSearchToken == 2)
    #expect(model.section == .lookup)
}

@Test func bundledSQLiteDictionaryLoadsEntries() throws {
    let entries = SQLiteDictionaryStore.loadBundledEntries()
    let receive = try #require(entries.first { $0.headword == "receive" })

    #expect(entries.count >= 100_000)
    #expect(receive.source == "WordNet 3.0 + ECDICT")
    #expect(receive.senses.first?.source == "ECDICT")
    #expect(receive.senses.first?.translation.contains("收到") == true)
    #expect(receive.pronunciations.contains { !$0.ipa.isEmpty })
    #expect(receive.examples.isEmpty)
}

@Test func bundledSQLiteDictionaryLoadsFullEntryOnDemand() throws {
    let receive = try #require(SQLiteDictionaryStore.loadBundledEntry(id: "receive"))

    #expect(receive.senses.first?.source == "ECDICT")
    #expect(receive.senses.contains { $0.source == "WordNet 3.0" })
    #expect(receive.examples.count >= 2)
}

@Test func fullEntryLoadsWordRelations() throws {
    let receive = try #require(SQLiteDictionaryStore.loadBundledEntry(id: "receive"))

    let kinds = Set(receive.relations.map(\.kind))
    #expect(kinds.contains(.synonym))
    #expect(kinds.contains(.derivation))
    #expect(kinds.contains(.form))

    // Synonyms come from WordNet and resolve to real headwords for navigation.
    let getSynonym = try #require(receive.relations.first { $0.kind == .synonym && $0.word == "get" })
    #expect(getSynonym.relatedWordID == "get")

    // ECDICT inflections carry a grammatical-role note and exclude the headword.
    let forms = receive.relations.filter { $0.kind == .form }
    #expect(forms.contains { $0.word == "receiving" && !$0.note.isEmpty })
    #expect(forms.allSatisfy { $0.word.lowercased() != "receive" })
}

@Test func lookalikesAreOfflineEditDistanceNeighbours() throws {
    let receive = try #require(SQLiteDictionaryStore.loadBundledEntry(id: "receive"))
    let lookalikes = receive.relations.filter { $0.kind == .lookalike }.map(\.word)

    #expect(lookalikes.contains("deceive"))
}

@Test func rootsCarryMorphologicalMeaning() throws {
    let homage = try #require(SQLiteDictionaryStore.loadBundledEntry(id: "homage"))
    let root = try #require(homage.relations.first { $0.kind == .root })

    #expect(root.word == "hom")
    #expect(root.note.contains("human"))
    // Roots are descriptive, not navigable headwords.
    #expect(root.relatedWordID == nil)
}

@Test func usageNotesGroupConfusableWords() throws {
    let quite = try #require(SQLiteDictionaryStore.loadBundledEntry(id: "quite"))
    let note = try #require(quite.usageNotes.first)

    #expect(note.members.contains("rather"))
    #expect(note.members.contains("quite"))
    #expect(!note.body.isEmpty)
}

@Test func tatoebaAddsBilingualExamples() throws {
    let receive = try #require(SQLiteDictionaryStore.loadBundledEntry(id: "receive"))
    let tatoeba = receive.examples.filter { $0.source == "Tatoeba" }

    #expect(!tatoeba.isEmpty)
    #expect(tatoeba.allSatisfy { !$0.translation.isEmpty })
}

@Test func chineseQueryFindsCEDICTEntry() throws {
    let results = SQLiteDictionaryStore.searchBundledCEDICT(query: "中文")
    let entry = try #require(results.first?.entry)

    #expect(entry.headword == "中文")
    #expect(entry.id.hasPrefix("cedict-"))
    #expect(entry.pronunciations.contains { $0.ipa.contains("wén") })
    #expect(entry.senses.contains { $0.definition.localizedCaseInsensitiveContains("Chinese") })
}

@Test func cedictEntryReloadsByID() throws {
    let results = SQLiteDictionaryStore.searchBundledCEDICT(query: "学习")
    let id = try #require(results.first?.entry.id)
    let reloaded = try #require(SQLiteDictionaryStore.loadBundledCEDICTEntry(id: id))

    #expect(reloaded.headword == "学习")
}

@Test func hanDetectionRoutesChineseInput() {
    #expect(TextNormalizer.containsHan("学习"))
    #expect(TextNormalizer.containsHan("hello 世界"))
    #expect(!TextNormalizer.containsHan("receive"))
}

@Test func indexEntriesOmitRelations() throws {
    let entries = SQLiteDictionaryStore.loadBundledEntries()
    let receive = try #require(entries.first { $0.headword == "receive" })

    // Relations are only populated on the on-demand detail path, matching examples.
    #expect(receive.relations.isEmpty)
}

@Test func wordnetExamplesMentionTheSelectedHeadword() throws {
    let sculptural = try #require(SQLiteDictionaryStore.loadBundledEntry(id: "sculptural"))

    #expect(!sculptural.examples.isEmpty)
    #expect(sculptural.examples.allSatisfy { $0.text.localizedCaseInsensitiveContains("sculptural") })
}

@Test func searchWorksWithSQLiteLoadedEntries() {
    let entries = SQLiteDictionaryStore.loadBundledEntries()
    let service = SearchService(entries: entries)

    #expect(service.search("ambigous").first?.entry.headword == "ambiguous")
}

@Test func sqliteBackedSearchFindsPrefixAndTypos() {
    let prefixResults = SQLiteDictionaryStore.searchBundledEntries(query: "sculp")
    let typoResults = SQLiteDictionaryStore.searchBundledEntries(query: "recieve")

    #expect(prefixResults.contains { $0.entry.headword == "sculptural" || $0.entry.headword == "sculpture" })
    #expect(typoResults.first?.entry.headword == "receive")
}

@Test func largeDictionarySearchStaysResponsive() {
    let clock = ContinuousClock()

    let elapsed = clock.measure {
        _ = SQLiteDictionaryStore.searchBundledEntries(query: "recieve")
        _ = SQLiteDictionaryStore.searchBundledEntries(query: "abandon")
        _ = SQLiteDictionaryStore.searchBundledEntries(query: "context")
        _ = SQLiteDictionaryStore.searchBundledEntries(query: "efficent")
    }

    #expect(elapsed < .milliseconds(500))
}
