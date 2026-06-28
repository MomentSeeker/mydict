# MyDict

Offline-first macOS dictionary app prototype. The default app does not call an LLM, cloud TTS, or any paid API.

## Run

```bash
swift run MyDictApp
```

## Test

```bash
swift test
```

## Current MVP

- Native SwiftUI macOS app
- Blue dictionary app icon assets under `Assets/AppIcon`
- Bundled offline SQLite dictionary built from WordNet 3.0 and ECDICT
- 447k+ offline word entries, 612k+ senses, and 79k+ example sentences
- English-to-Chinese definitions from ECDICT
- English-to-English definitions and examples from WordNet
- Lightweight search index with on-demand full entry loading
- SQLite-backed FTS/prefix candidate recall with typo reranking
- Seed SQLite generation script for lightweight fixture builds
- WordNet SQLite generation script for the production dictionary bundle
- Fuzzy candidate recall for misspelled words
- Keyboard candidate navigation with up/down and return
- Empty default lookup state until the user starts typing
- Confirming a candidate preserves the typed query while showing the selected headword
- Candidate hover does not change the current result
- Word detail view with meaning, IPA, examples, and memory aid
- Separate Chinese meanings, English definitions, examples, and source labels
- Double-click an English word in the detail area to look it up
- Clickable pronunciation using macOS system speech
- Local lookup history saved under Application Support
- Favorite and basic review flow
- Explicit offline/no-token status in the UI

## Offline By Default

These features work without network or token usage:

- Search
- Similar-word recall
- Definitions
- IPA display
- System TTS pronunciation
- Examples (incl. Tatoeba bilingual English+Chinese sentences)
- Synonyms, antonyms, derived words, and inflected forms
- Look-alike words (offline edit-distance neighbours) and morphological roots
- Chinese → English lookup (CC-CEDICT): type Chinese to search
- Lookup history
- Review
- Basic memory aids

Future online features should stay optional and cached, such as dictionary data updates, Wiktionary audio downloads, iCloud sync, or user-configured cloud TTS.

## Free Enhancement Sources

- Examples: WordNet and ECDICT details; later Tatoeba can be added offline.
- Synonyms and derived words: WordNet lexical relations.
- Roots, similar-looking words, and inflections: ECDICT wordroot, resemble, exchange, and lemma data.
- Etymology and richer pronunciation: Wiktionary data through Wiktextract/Kaikki.
- Collocations and replacement suggestions: local corpus statistics or optional free APIs only if cached and explicitly enabled.

## Project Layout

```text
Sources/MyDictCore
  Models
  Resources
  Services
Sources/MyDictApp
  Views
Tests/MyDictAppTests
docs
scripts
```

## Next Steps

1. Add Kaikki/Wiktionary import for IPA and richer pronunciations.
2. Add CC-CEDICT as a separate Chinese-to-English dictionary package.
3. Add stronger SymSpell/BK-tree typo indexes for harder misspellings.
4. Add dictionary package update/install UI.
5. Add a real spaced-repetition scheduler.
6. Add a global hotkey helper if the app is packaged outside Swift Package Manager.

## Rebuild The Bundled Dictionary

```bash
python3 scripts/build_seed_sqlite.py Sources/MyDictCore/Resources/dictionary.sqlite
```

## Rebuild The WordNet Dictionary

```bash
python3 scripts/build_wordnet_sqlite.py \
  --output Sources/MyDictCore/Resources/dictionary.sqlite \
  --cache-dir data/wordnet

python3 scripts/merge_ecdict_sqlite.py \
  --database Sources/MyDictCore/Resources/dictionary.sqlite \
  --ecdict-csv data/ecdict/ecdict.csv \
  --insert-extra-limit 300000
```

## Add Word Relations

Incrementally adds a `relations` table to an existing bundle. It does not rebuild
words/senses, so it can be re-run on its own and is fully offline. Run it after
the WordNet + ECDICT steps above:

```bash
python3 scripts/build_relations_sqlite.py \
  --database Sources/MyDictCore/Resources/dictionary.sqlite \
  --wordnet-dict-dir data/wordnet/WNdb-3.0/dict \
  --ecdict-csv data/ecdict/ecdict.csv \
  --wordroot-json data/ecdict/wordroot.txt \
  --resemble-txt data/ecdict/resemble.txt
```

Relation types produced (all offline, no network at runtime, no token cost):

| Type        | Source                                            | UI section   |
| ----------- | ------------------------------------------------- | ------------ |
| synonym     | WordNet synset co-members                         | Synonyms     |
| antonym     | WordNet `!` pointer                                | Antonyms     |
| derivation  | WordNet `+` derivationally related forms          | Related      |
| form        | ECDICT `exchange` inflections (past tense, ...)   | Forms        |
| lookalike   | Computed edit-distance ≤ 2 neighbours (freq ≥ 0.2)| Look-alikes  |
| root        | ECDICT `wordroot.txt` roots/affixes               | Roots        |

It also builds a `usage_notes` table from ECDICT `resemble.txt` (近义辨析:
groups of confusable words with Chinese discrimination notes), shown as the
"Usage" section.

`wordroot.txt` and `resemble.txt` are extra ECDICT resources (not in the main
csv). Download them once into `data/ecdict/`; the script skips whichever is
absent:

```bash
curl -fsSL https://raw.githubusercontent.com/skywind3000/ECDICT/master/wordroot.txt \
  -o data/ecdict/wordroot.txt
curl -fsSL https://raw.githubusercontent.com/skywind3000/ECDICT/master/resemble.txt \
  -o data/ecdict/resemble.txt
```

All relations except roots surface as clickable chips that look the word up;
roots are shown as descriptive labels (root + meaning).

## Add Bilingual Examples (Tatoeba)

Attaches English+Chinese example sentences (CC-BY) to the words they contain,
written into the `examples` table (source `Tatoeba`). Download the three
per-language exports once into `data/tatoeba/`:

```bash
base=https://downloads.tatoeba.org/exports/per_language
curl -fsSL $base/cmn/cmn-eng_links.tsv.bz2 | bunzip2 > data/tatoeba/cmn-eng_links.tsv
curl -fsSL $base/cmn/cmn_sentences.tsv.bz2 | bunzip2 > data/tatoeba/cmn_sentences.tsv
curl -fsSL $base/eng/eng_sentences.tsv.bz2 | bunzip2 > data/tatoeba/eng_sentences.tsv

python3 scripts/merge_tatoeba_examples.py
```

## Add Chinese → English (CC-CEDICT)

Builds a `cedict` table (simplified / traditional / accented pinyin / English
glosses, CC-BY-SA). Typing Chinese in the search box routes to this table.

```bash
curl -fsSL "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz" \
  | gunzip > data/cedict/cedict.txt
python3 scripts/build_cedict_sqlite.py
```

## Slim The Bundle (final step)

After all the build/merge steps, run the optimizer to drop wasted TEXT-primary-key
autoindexes (senses/pronunciations/examples become INTEGER-keyed), strip unused
FTS ranking data, and VACUUM. Lossless — no content removed. Saves ~60 MB:

```bash
python3 scripts/optimize_sqlite.py
```

## Package As A Standalone .app

Build a real, double-clickable `MyDict.app` (with icon and `Info.plist`) into
`dist/`. Offline, no Apple signing identity required (ad-hoc signed so it runs
locally):

```bash
./scripts/package_app.sh          # -> dist/MyDict.app
open dist/MyDict.app
```

The icon is generated by `scripts/make_appicon.swift`. The 244 MB dictionary is
embedded in the bundle, so the app is fully self-contained and offline.
