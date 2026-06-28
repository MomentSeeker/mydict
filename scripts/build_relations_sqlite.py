#!/usr/bin/env python3
"""Augment an existing MyDict SQLite bundle with a `relations` table.

This is an *incremental* migration: it does not rebuild words/senses. It reads
the local WordNet 3.0 data files and the ECDICT csv that were already used to
build the dictionary, extracts word-to-word relations, and writes them into a
fresh `relations` table keyed by the word ids already present in the database.

Relation types produced (all fully offline, no network / no token cost):

  synonym     WordNet synset co-members
  antonym     WordNet `!` lexical pointer
  derivation  WordNet `+` derivationally related form
  form        ECDICT `exchange` inflections (past tense, plural, ...)
"""
import argparse
import csv
import json
import re
import sqlite3
from pathlib import Path


# WordNet adjective lemmas carry syntactic-position markers like "good(p)" or
# "ill(ip)"; strip them for display.
_MARKER = re.compile(r"\([a-z]+\)$")


def clean_lemma(lemma: str) -> str:
    return _MARKER.sub("", lemma).strip()


WORDNET_POS_FILES = {
    "noun": "data.noun",
    "verb": "data.verb",
    "adjective": "data.adj",
    "adverb": "data.adv",
}

# Relation kinds we surface to the user.
SYNONYM = "synonym"        # WordNet synset co-members
ANTONYM = "antonym"        # WordNet `!`
DERIVATION = "derivation"  # WordNet `+`
FORM = "form"              # ECDICT exchange inflections
LOOKALIKE = "lookalike"    # computed: similar spelling (edit distance <= 2)
ROOT = "root"              # ECDICT wordroot.txt morphological roots/affixes

# Per-word caps so the table stays small and the UI stays readable.
CAPS = {SYNONYM: 12, ANTONYM: 8, DERIVATION: 12, FORM: 12, LOOKALIKE: 8, ROOT: 6}

# Only words at least this frequent take part in look-alike matching, which keeps
# the result both small and useful (rare words make noisy neighbours).
LOOKALIKE_MIN_FREQUENCY = 0.2
LOOKALIKE_MIN_LENGTH = 3
LOOKALIKE_MAX_DISTANCE = 2

# ECDICT exchange codes -> human label.
EXCHANGE_LABELS = {
    "p": "过去式",
    "d": "过去分词",
    "i": "现在分词",
    "3": "三单",
    "r": "比较级",
    "t": "最高级",
    "s": "复数",
    "0": "原形",
    "1": "变形",
}

SCHEMA = """
DROP TABLE IF EXISTS relations;
CREATE TABLE relations (
  id INTEGER PRIMARY KEY,
  word_id TEXT NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  relation_type TEXT NOT NULL,
  related_word TEXT NOT NULL,
  related_word_id TEXT,
  note TEXT,
  source TEXT NOT NULL
);
CREATE INDEX idx_relations_word ON relations(word_id);

DROP TABLE IF EXISTS usage_notes;
CREATE TABLE usage_notes (
  id INTEGER PRIMARY KEY,
  word_id TEXT NOT NULL REFERENCES words(id) ON DELETE CASCADE,
  members TEXT NOT NULL,
  body TEXT NOT NULL,
  source TEXT NOT NULL
);
CREATE INDEX idx_usage_notes_word ON usage_notes(word_id);
"""


def normalize(text: str) -> str:
    return "".join(
        ch.lower()
        for ch in text.strip().replace("_", " ")
        if ch.isalpha() or ch in "-' "
    )


# --------------------------------------------------------------------------- #
# WordNet parsing
# --------------------------------------------------------------------------- #

def parse_data_file(path: Path):
    """Yield (offset, ss_type, lemmas, pointers) per synset.

    lemmas: list of surface forms (word index = 1-based position).
    pointers: list of (symbol, target_offset, target_pos, source, target).
    """
    synsets = []
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            if line.startswith("  "):
                continue
            data = line.split("|", 1)[0]
            fields = data.split()
            if len(fields) < 4:
                continue

            offset = fields[0]
            ss_type = fields[2]
            try:
                w_cnt = int(fields[3], 16)
            except ValueError:
                continue

            cursor = 4
            lemmas = []
            ok = True
            for _ in range(w_cnt):
                if cursor + 1 >= len(fields):
                    ok = False
                    break
                lemmas.append(clean_lemma(fields[cursor].replace("_", " ")))
                cursor += 2
            if not ok or cursor >= len(fields):
                continue

            try:
                p_cnt = int(fields[cursor])
            except ValueError:
                continue
            cursor += 1

            pointers = []
            for _ in range(p_cnt):
                if cursor + 3 >= len(fields):
                    break
                symbol = fields[cursor]
                target_offset = fields[cursor + 1]
                target_pos = fields[cursor + 2]
                srctgt = fields[cursor + 3]
                cursor += 4
                try:
                    source = int(srctgt[:2], 16)
                    target = int(srctgt[2:], 16)
                except (ValueError, IndexError):
                    source, target = 0, 0
                pointers.append((symbol, target_offset, target_pos, source, target))

            synsets.append((offset, ss_type, lemmas, pointers))
    return synsets


def load_wordnet(dict_dir: Path):
    all_synsets = []
    index = {}  # (pos_char, offset) -> lemmas
    for filename in WORDNET_POS_FILES.values():
        path = dict_dir / filename
        if not path.exists():
            continue
        synsets = parse_data_file(path)
        for offset, ss_type, lemmas, pointers in synsets:
            index[(ss_type, offset)] = lemmas
        all_synsets.extend(synsets)
    return all_synsets, index


def resolve_synset(index, pos, offset):
    lemmas = index.get((pos, offset))
    if lemmas is not None:
        return lemmas
    # Adjectives appear as both 'a' (head) and 's' (satellite); pointers may use
    # either, so fall back to the sibling type.
    if pos == "a":
        return index.get(("s", offset), [])
    if pos == "s":
        return index.get(("a", offset), [])
    return []


def wordnet_relations(all_synsets, index):
    """Yield (source_lemma, relation_type, related_lemma)."""
    for offset, ss_type, lemmas, pointers in all_synsets:
        # Synonyms: every other lemma in the same synset.
        for i, lemma in enumerate(lemmas):
            for j, other in enumerate(lemmas):
                if i != j:
                    yield lemma, SYNONYM, other

        for symbol, target_offset, target_pos, source, target in pointers:
            if symbol == "!":
                relation = ANTONYM
            elif symbol == "+":
                relation = DERIVATION
            else:
                continue

            target_lemmas = resolve_synset(index, target_pos, target_offset)
            if not target_lemmas:
                continue

            sources = [lemmas[source - 1]] if source else lemmas
            if target:
                if target - 1 < len(target_lemmas):
                    targets = [target_lemmas[target - 1]]
                else:
                    continue
            else:
                targets = target_lemmas

            for src in sources:
                for tgt in targets:
                    yield src, relation, tgt


# --------------------------------------------------------------------------- #
# ECDICT exchange parsing
# --------------------------------------------------------------------------- #

def ecdict_forms(ecdict_csv: Path):
    """Yield (headword, label, form) from the ECDICT `exchange` column."""
    with ecdict_csv.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            headword = (row.get("word") or "").strip()
            exchange = (row.get("exchange") or "").strip()
            if not headword or not exchange:
                continue
            for chunk in exchange.split("/"):
                if ":" not in chunk:
                    continue
                code, _, value = chunk.partition(":")
                value = value.strip()
                label = EXCHANGE_LABELS.get(code)
                if not label or not value:
                    continue
                if value.lower() == headword.lower():
                    continue
                yield headword, label, value


# --------------------------------------------------------------------------- #
# Look-alikes (offline, computed via a SymSpell-style deletion index)
# --------------------------------------------------------------------------- #

def bounded_levenshtein(a: str, b: str, max_distance: int):
    """Levenshtein distance, returning None once it provably exceeds max_distance."""
    la, lb = len(a), len(b)
    if abs(la - lb) > max_distance:
        return None
    previous = list(range(lb + 1))
    for i in range(1, la + 1):
        current = [i] + [0] * lb
        row_best = current[0]
        ai = a[i - 1]
        for j in range(1, lb + 1):
            cost = 0 if ai == b[j - 1] else 1
            current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            if current[j] < row_best:
                row_best = current[j]
        if row_best > max_distance:
            return None
        previous = current
    distance = previous[lb]
    return distance if distance <= max_distance else None


def lookalike_relations(words):
    """Yield (word, related_headword) for visually similar words.

    `words` is a list of (normalized, frequency, headword). Two words are
    candidates when they share a single-character deletion (so their edit
    distance is <= 2); we then confirm the true distance and rank by closeness
    then frequency.
    """
    deletion_index: dict[str, set[str]] = {}

    def deletions(norm: str):
        yield norm
        for i in range(len(norm)):
            yield norm[:i] + norm[i + 1:]

    for norm, _, _ in words:
        for variant in deletions(norm):
            deletion_index.setdefault(variant, set()).add(norm)

    frequency = {norm: freq for norm, freq, _ in words}
    headword = {norm: head for norm, _, head in words}

    for norm, _, _ in words:
        candidates: set[str] = set()
        for variant in deletions(norm):
            candidates |= deletion_index.get(variant, set())
        candidates.discard(norm)

        scored = []
        for candidate in candidates:
            distance = bounded_levenshtein(norm, candidate, LOOKALIKE_MAX_DISTANCE)
            if distance:
                scored.append((distance, -frequency.get(candidate, 0.0), candidate))

        scored.sort()
        for _, _, candidate in scored:
            yield norm, headword.get(candidate, candidate)


# --------------------------------------------------------------------------- #
# Word roots (ECDICT wordroot.txt, a JSON map of root/affix -> example words)
# --------------------------------------------------------------------------- #

def wordroot_relations(wordroot_json: Path):
    """Yield (example_word, root_label, meaning) inverted from the root table."""
    data = json.loads(wordroot_json.read_text(encoding="utf-8"))
    for root_key, entry in data.items():
        if not isinstance(entry, dict):
            continue
        meaning = (entry.get("meaning") or "").strip()
        for example in entry.get("example", []) or []:
            example = str(example).strip()
            if example:
                yield example, root_key, meaning


# --------------------------------------------------------------------------- #
# Usage discrimination groups (ECDICT resemble.txt, 近义辨析)
# --------------------------------------------------------------------------- #

def resemble_groups(resemble_txt: Path):
    """Yield (members, body) groups from resemble.txt.

    Each group starts with `% w1, w2, ...` then a few explanation lines.
    """
    members: list[str] = []
    body_lines: list[str] = []

    def flush():
        body = "\n".join(body_lines).strip()
        if members and body:
            return members[:], body
        return None

    with resemble_txt.open("r", encoding="utf-8") as handle:
        for raw in handle:
            line = raw.rstrip("\n")
            if line.startswith("%"):
                group = flush()
                if group:
                    yield group
                members = [w.strip() for w in line[1:].split(",") if w.strip()]
                body_lines = []
            else:
                body_lines.append(line)

    group = flush()
    if group:
        yield group


# --------------------------------------------------------------------------- #
# Build
# --------------------------------------------------------------------------- #

def build(
    database: Path,
    dict_dir: Path,
    ecdict_csv: Path | None,
    wordroot_json: Path | None,
    resemble_txt: Path | None,
) -> None:
    connection = sqlite3.connect(database)
    connection.execute("PRAGMA foreign_keys = ON")
    try:
        word_ids = {
            normalized: word_id
            for word_id, normalized in connection.execute(
                "SELECT id, normalized FROM words"
            )
        }

        connection.executescript(SCHEMA)

        # (word_id, relation_type) -> set of normalized related words, for caps + dedup.
        seen: dict[tuple[str, str], set[str]] = {}
        rows: list[tuple] = []

        def add(source_lemma: str, relation: str, related: str, note: str, src: str, link: bool = True):
            word_id = word_ids.get(normalize(source_lemma))
            if not word_id:
                return
            related_norm = normalize(related)
            if not related_norm or related_norm == normalize(source_lemma):
                return
            bucket = seen.setdefault((word_id, relation), set())
            if related_norm in bucket:
                return
            if len(bucket) >= CAPS[relation]:
                return
            bucket.add(related_norm)
            rows.append(
                (
                    word_id,
                    relation,
                    related,
                    word_ids.get(related_norm) if link else None,
                    note,
                    src,
                )
            )

        all_synsets, index = load_wordnet(dict_dir)
        for source_lemma, relation, related in wordnet_relations(all_synsets, index):
            add(source_lemma, relation, related, "", "WordNet 3.0")

        if ecdict_csv and ecdict_csv.exists():
            for headword, label, form in ecdict_forms(ecdict_csv):
                add(headword, FORM, form, label, "ECDICT")

        if wordroot_json and wordroot_json.exists():
            for example, root_key, meaning in wordroot_relations(wordroot_json):
                add(example, ROOT, root_key, meaning, "ECDICT wordroot", link=False)

        # Look-alikes are computed from the words already present in the bundle.
        universe = [
            (normalized, frequency, headword)
            for headword, normalized, frequency in connection.execute(
                "SELECT headword, normalized, frequency FROM words "
                "WHERE frequency >= ? AND length(normalized) >= ? "
                "AND normalized NOT LIKE '% %' AND normalized NOT LIKE '%-%'",
                (LOOKALIKE_MIN_FREQUENCY, LOOKALIKE_MIN_LENGTH),
            )
        ]
        for source_norm, related in lookalike_relations(universe):
            add(source_norm, LOOKALIKE, related, "", "MyDict")

        connection.executemany(
            """
            INSERT INTO relations(word_id, relation_type, related_word, related_word_id, note, source)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            rows,
        )

        usage_rows: list[tuple] = []
        if resemble_txt and resemble_txt.exists():
            for members, body in resemble_groups(resemble_txt):
                members_str = ", ".join(members)
                for member in members:
                    word_id = word_ids.get(normalize(member))
                    if word_id:
                        usage_rows.append((word_id, members_str, body, "ECDICT"))
            connection.executemany(
                "INSERT INTO usage_notes(word_id, members, body, source) VALUES (?, ?, ?, ?)",
                usage_rows,
            )

        connection.execute("PRAGMA user_version = 5")
        connection.commit()

        counts = dict(
            connection.execute(
                "SELECT relation_type, COUNT(*) FROM relations GROUP BY relation_type"
            )
        )
        print(f"Wrote {len(rows)} relations: {counts}")
        print(f"Wrote {len(usage_rows)} usage notes")
    finally:
        connection.close()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Add a relations table (synonyms / antonyms / derivations / forms) to a MyDict SQLite bundle."
    )
    parser.add_argument("--database", default="Sources/MyDictCore/Resources/dictionary.sqlite")
    parser.add_argument("--wordnet-dict-dir", default="data/wordnet/WNdb-3.0/dict")
    parser.add_argument("--ecdict-csv", default="data/ecdict/ecdict.csv")
    parser.add_argument("--wordroot-json", default="data/ecdict/wordroot.txt")
    parser.add_argument("--resemble-txt", default="data/ecdict/resemble.txt")
    args = parser.parse_args()

    ecdict = Path(args.ecdict_csv)
    wordroot = Path(args.wordroot_json)
    resemble = Path(args.resemble_txt)
    build(
        Path(args.database),
        Path(args.wordnet_dict_dir),
        ecdict if ecdict.exists() else None,
        wordroot if wordroot.exists() else None,
        resemble if resemble.exists() else None,
    )


if __name__ == "__main__":
    main()
