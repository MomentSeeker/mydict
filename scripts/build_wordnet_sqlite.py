#!/usr/bin/env python3
import argparse
import re
import sqlite3
import tarfile
import urllib.request
from pathlib import Path


WORDNET_URL = "https://wordnetcode.princeton.edu/3.0/WNdb-3.0.tar.gz"
POS_FILES = {
    "noun": "data.noun",
    "verb": "data.verb",
    "adjective": "data.adj",
    "adverb": "data.adv",
}
INDEX_FILES = {
    "noun": "index.noun",
    "verb": "index.verb",
    "adjective": "index.adj",
    "adverb": "index.adv",
}
MAX_SENSES_PER_WORD = 12


SCHEMA = """
PRAGMA journal_mode = DELETE;
PRAGMA foreign_keys = ON;

CREATE TABLE words (
  id TEXT PRIMARY KEY,
  headword TEXT NOT NULL,
  normalized TEXT NOT NULL,
  frequency REAL DEFAULT 0,
  source TEXT NOT NULL
);

CREATE TABLE senses (
  id TEXT PRIMARY KEY,
  word_id TEXT NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  part_of_speech TEXT,
  definition TEXT NOT NULL,
  translation TEXT,
  rank INTEGER DEFAULT 0,
  source TEXT NOT NULL
);

CREATE TABLE pronunciations (
  id TEXT PRIMARY KEY,
  word_id TEXT NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  ipa TEXT,
  dialect TEXT,
  audio_url TEXT,
  audio_cache_path TEXT,
  source TEXT
);

CREATE TABLE examples (
  id TEXT PRIMARY KEY,
  word_id TEXT NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  sentence TEXT NOT NULL,
  translation TEXT,
  source TEXT NOT NULL,
  quality_score REAL DEFAULT 0
);

CREATE TABLE memory_aids (
  word_id TEXT PRIMARY KEY REFERENCES words(id) ON DELETE CASCADE,
  breakdown TEXT,
  association TEXT,
  usage TEXT,
  contrast TEXT
);

CREATE VIRTUAL TABLE words_fts USING fts5(
  headword,
  normalized,
  content='words',
  content_rowid='rowid'
);

CREATE INDEX idx_words_normalized ON words(normalized);
CREATE INDEX idx_senses_word ON senses(word_id);
CREATE INDEX idx_pronunciations_word ON pronunciations(word_id);
CREATE INDEX idx_examples_word ON examples(word_id);
"""


SEED_OVERLAY = {
    "possible": {
        "translation": "可能的；可做到的",
        "ipa": "/ˈpɑːsəbəl/",
        "memory": (
            "poss + ible: able to exist or happen",
            "把它想成一扇还没关上的门：事情仍然有机会发生。",
            "possible solution / possible cause / as soon as possible",
            "possible 强调有可能；probable 更偏向很可能。",
        ),
    },
    "receive": {
        "translation": "收到；接收",
        "ipa": "/rɪˈsiːv/",
        "memory": (
            "re + ceive: take back or take in",
            "记住 i before e 的例外：receive 里是 cei。",
            "receive a message / receive support",
            "receive 是收到；accept 是接受并认可。",
        ),
    },
    "dictionary": {
        "translation": "词典；字典",
        "ipa": "/ˈdɪkʃəneri/",
        "memory": (
            "dict + ion + ary: a place of words that are said or written",
            "dict 表示说，dictionary 就是把词说清楚的地方。",
            "open-source dictionary / dictionary entry",
            "dictionary 是词典；thesaurus 偏同义词词典。",
        ),
    },
}


def normalize(text: str) -> str:
    return "".join(ch.lower() for ch in text.strip().replace("_", " ") if ch.isalpha() or ch in "-' ")


def example_mentions_word(example: str, normalized_word: str) -> bool:
    normalized_example = f" {normalize(example)} "
    normalized_word = normalized_word.strip()
    if not normalized_word:
        return False
    if " " in normalized_word:
        return normalized_word in normalized_example
    return f" {normalized_word} " in normalized_example


def download_wordnet(cache_dir: Path) -> Path:
    cache_dir.mkdir(parents=True, exist_ok=True)
    archive = cache_dir / "WNdb-3.0.tar.gz"
    extract_dir = cache_dir / "WNdb-3.0"

    if not archive.exists():
        print(f"Downloading {WORDNET_URL}")
        urllib.request.urlretrieve(WORDNET_URL, archive)

    expected_file = extract_dir / "dict" / "data.noun"
    if not expected_file.exists():
        print(f"Extracting {archive}")
        extract_dir.mkdir(parents=True, exist_ok=True)
        with tarfile.open(archive) as tar:
            tar.extractall(extract_dir)

    return extract_dir / "dict"


def parse_gloss(gloss: str) -> tuple[str, list[str]]:
    pieces = [piece.strip() for piece in gloss.split(";")]
    definition = pieces[0].strip()
    examples = []

    for piece in pieces[1:]:
        matches = re.findall(r'"([^"]+)"', piece)
        examples.extend(match.strip() for match in matches if match.strip())

    return definition, examples


def parse_data_file(path: Path, part_of_speech: str) -> dict[str, list[dict]]:
    by_word: dict[str, list[dict]] = {}

    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            if not line or line.startswith("  "):
                continue

            data, gloss = line.rstrip("\n").split("|", 1)
            fields = data.split()
            if len(fields) < 5:
                continue

            offset = fields[0]
            word_count = int(fields[3], 16)
            cursor = 4
            lemmas = []
            for _ in range(word_count):
                lemma = fields[cursor].replace("_", " ")
                lemmas.append(lemma)
                cursor += 2

            definition, examples = parse_gloss(gloss.strip())
            for lemma in lemmas:
                normalized = normalize(lemma)
                if not normalized:
                    continue
                by_word.setdefault(normalized, []).append(
                    {
                        "offset": offset,
                        "headword": lemma,
                        "part_of_speech": part_of_speech,
                        "definition": definition,
                        "examples": examples,
                    }
                )

    return by_word


def load_wordnet(dict_dir: Path) -> dict[str, list[dict]]:
    sense_order = load_sense_order(dict_dir)
    words: dict[str, list[dict]] = {}
    for part_of_speech, filename in POS_FILES.items():
        parsed = parse_data_file(dict_dir / filename, part_of_speech)
        for normalized, senses in parsed.items():
            words.setdefault(normalized, []).extend(senses)

    for normalized, senses in words.items():
        senses.sort(key=lambda sense: (
            sense_order.get((normalized, sense["part_of_speech"], sense["offset"]), 9_999),
            sense["part_of_speech"],
            sense["offset"],
        ))
    return words


def load_sense_order(dict_dir: Path) -> dict[tuple[str, str, str], int]:
    order: dict[tuple[str, str, str], int] = {}

    for part_of_speech, filename in INDEX_FILES.items():
        path = dict_dir / filename
        with path.open("r", encoding="utf-8") as handle:
            for line in handle:
                if not line or line.startswith("  "):
                    continue
                fields = line.split()
                if len(fields) < 6:
                    continue

                lemma = fields[0].replace("_", " ")
                normalized = normalize(lemma)
                synset_count = int(fields[2])
                pointer_count = int(fields[3])
                offset_start = 6 + pointer_count
                offsets = fields[offset_start:offset_start + synset_count]

                for rank, offset in enumerate(offsets):
                    order[(normalized, part_of_speech, offset)] = rank

    return order


def frequency_score(sense_count: int, normalized: str) -> float:
    length_bonus = max(0.0, 1.0 - (len(normalized) / 24.0)) * 0.25
    count_bonus = min(0.75, sense_count / 12.0)
    return round(count_bonus + length_bonus, 4)


def build_database(output: Path, words: dict[str, list[dict]]) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    connection = sqlite3.connect(output)
    try:
        connection.executescript(SCHEMA)
        source = "WordNet 3.0"
        word_index = 0

        for normalized in sorted(words):
            senses = words[normalized][:MAX_SENSES_PER_WORD]
            if not senses:
                continue

            headword = senses[0]["headword"]
            word_id = normalized.replace(" ", "_")
            word_index += 1
            connection.execute(
                "INSERT INTO words(id, headword, normalized, frequency, source) VALUES (?, ?, ?, ?, ?)",
                (word_id, headword, normalized, frequency_score(len(words[normalized]), normalized), source),
            )
            connection.execute(
                "INSERT INTO words_fts(rowid, headword, normalized) VALUES ((SELECT rowid FROM words WHERE id = ?), ?, ?)",
                (word_id, headword, normalized),
            )

            overlay = SEED_OVERLAY.get(normalized, {})
            translation = overlay.get("translation", "")
            for rank, sense in enumerate(senses):
                sense_id = f"{word_id}-{sense['part_of_speech']}-{sense['offset']}-{rank}"
                connection.execute(
                    """
                    INSERT INTO senses(id, word_id, part_of_speech, definition, translation, rank, source)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        sense_id,
                        word_id,
                        sense["part_of_speech"],
                        sense["definition"],
                        translation if rank == 0 else "",
                        rank,
                        source,
                    ),
                )

                relevant_examples = [
                    example
                    for example in sense["examples"]
                    if example_mentions_word(example, normalized)
                ]

                for example_index, example in enumerate(relevant_examples[:2], start=1):
                    connection.execute(
                        """
                        INSERT INTO examples(id, word_id, sentence, translation, source, quality_score)
                        VALUES (?, ?, ?, '', ?, ?)
                        """,
                        (
                            f"{sense_id}-example-{example_index}",
                            word_id,
                            example,
                            source,
                            max(0.1, 1.0 - rank * 0.05 - example_index * 0.02),
                        ),
                    )

            if ipa := overlay.get("ipa"):
                connection.execute(
                    """
                    INSERT INTO pronunciations(id, word_id, ipa, dialect, source)
                    VALUES (?, ?, ?, 'US', ?)
                    """,
                    (f"{word_id}-us", word_id, ipa, "Offline seed overlay"),
                )

            if memory := overlay.get("memory"):
                connection.execute(
                    """
                    INSERT INTO memory_aids(word_id, breakdown, association, usage, contrast)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                    (word_id, *memory),
                )

        connection.execute("PRAGMA user_version = 2")
        connection.commit()
        print(f"Wrote {output} with {word_index} words")
    finally:
        connection.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Build MyDict SQLite bundle from WordNet.")
    parser.add_argument("--output", default="Sources/MyDictCore/Resources/dictionary.sqlite")
    parser.add_argument("--cache-dir", default="data/wordnet")
    args = parser.parse_args()

    dict_dir = download_wordnet(Path(args.cache_dir))
    words = load_wordnet(dict_dir)
    build_database(Path(args.output), words)


if __name__ == "__main__":
    main()
