#!/usr/bin/env python3
import argparse
import csv
import sqlite3
from pathlib import Path


SOURCE = "ECDICT"


def normalize(text: str) -> str:
    return "".join(ch.lower() for ch in text.strip().replace("_", " ") if ch.isalpha() or ch in "-' ")


def clean_translation(value: str) -> str:
    lines = []
    for line in value.replace("\\r", "\n").replace("\\n", "\n").splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("[网络]"):
            continue
        lines.append(line)
        if len(lines) >= 8:
            break
    return "\n".join(lines)


def clean_definition(value: str) -> str:
    lines = []
    for line in value.replace("\\r", "\n").replace("\\n", "\n").splitlines():
        line = line.strip()
        if line:
            lines.append(line)
        if len(lines) >= 5:
            break
    return "\n".join(lines)


def preferred_definition(value: str, translation: str) -> str:
    lines = clean_definition(value).splitlines()
    if not lines:
        return ""

    first_translation = translation.lstrip().lower()
    if first_translation.startswith(("vt.", "vi.", "v.", "verb")):
        verb_lines = [line for line in lines if line.lower().startswith("v.")]
        other_lines = [line for line in lines if not line.lower().startswith("v.")]
        return "\n".join(verb_lines + other_lines)

    if first_translation.startswith(("n.", "noun")):
        noun_lines = [line for line in lines if line.lower().startswith("n.")]
        other_lines = [line for line in lines if not line.lower().startswith("n.")]
        return "\n".join(noun_lines + other_lines)

    if first_translation.startswith(("a.", "adj.", "adjective")):
        adjective_lines = [line for line in lines if line.lower().startswith(("a.", "adj."))]
        other_lines = [line for line in lines if not line.lower().startswith(("a.", "adj."))]
        return "\n".join(adjective_lines + other_lines)

    return "\n".join(lines)


def phonetic_to_ipa(value: str) -> str:
    value = value.strip().strip("/")
    return f"/{value}/" if value else ""


def frequency_from_row(row: dict[str, str]) -> float:
    ranks = []
    for key in ("frq", "bnc"):
        try:
            rank = int(row.get(key, "0") or "0")
        except ValueError:
            rank = 0
        if rank > 0:
            ranks.append(rank)

    if not ranks:
        return 0.05

    best = min(ranks)
    return max(0.08, min(0.95, 1.0 - best / 80_000.0))


def existing_word_ids(connection: sqlite3.Connection) -> dict[str, str]:
    return {
        normalized: word_id
        for word_id, normalized in connection.execute("SELECT id, normalized FROM words")
    }


def merge(database: Path, ecdict_csv: Path, insert_extra_limit: int) -> None:
    connection = sqlite3.connect(database)
    connection.execute("PRAGMA foreign_keys = ON")

    try:
        word_ids = existing_word_ids(connection)
        matched = 0
        inserted = 0
        seen: set[str] = set()

        with ecdict_csv.open("r", encoding="utf-8", newline="") as handle:
            reader = csv.DictReader(handle)
            for row in reader:
                headword = (row.get("word") or "").strip()
                normalized = normalize(headword)
                if not normalized or normalized in seen:
                    continue

                translation = clean_translation(row.get("translation", ""))
                definition = preferred_definition(row.get("definition", ""), translation)
                ipa = phonetic_to_ipa(row.get("phonetic", ""))
                if not translation and not definition and not ipa:
                    continue

                seen.add(normalized)
                word_id = word_ids.get(normalized)

                if word_id:
                    matched += 1
                    connection.execute(
                        "UPDATE words SET source = CASE WHEN source LIKE '%ECDICT%' THEN source ELSE source || ' + ECDICT' END WHERE id = ?",
                        (word_id,),
                    )
                    if translation:
                        connection.execute(
                            """
                            INSERT OR REPLACE INTO senses(id, word_id, part_of_speech, definition, translation, rank, source)
                            VALUES (?, ?, ?, ?, ?, -1, ?)
                            """,
                            (
                                f"{word_id}-ecdict-primary",
                                word_id,
                                row.get("pos", ""),
                                definition or translation,
                                translation,
                                SOURCE,
                            ),
                        )
                        connection.execute(
                            """
                            UPDATE senses
                            SET translation = ?
                            WHERE id = (
                              SELECT id FROM senses WHERE word_id = ? ORDER BY rank ASC LIMIT 1
                            )
                            """,
                            (translation, word_id),
                        )
                    if ipa:
                        connection.execute(
                            """
                            INSERT OR REPLACE INTO pronunciations(id, word_id, ipa, dialect, source)
                            VALUES (?, ?, ?, 'UK', ?)
                            """,
                            (f"{word_id}-ecdict", word_id, ipa, SOURCE),
                        )
                    continue

                if inserted >= insert_extra_limit:
                    continue
                if not translation:
                    continue

                inserted += 1
                word_id = normalized.replace(" ", "_")
                suffix = 2
                candidate = word_id
                while connection.execute("SELECT 1 FROM words WHERE id = ?", (candidate,)).fetchone():
                    candidate = f"{word_id}_{suffix}"
                    suffix += 1
                word_id = candidate

                connection.execute(
                    "INSERT INTO words(id, headword, normalized, frequency, source) VALUES (?, ?, ?, ?, ?)",
                    (word_id, headword, normalized, frequency_from_row(row), SOURCE),
                )
                connection.execute(
                    "INSERT INTO words_fts(rowid, headword, normalized) VALUES ((SELECT rowid FROM words WHERE id = ?), ?, ?)",
                    (word_id, headword, normalized),
                )
                connection.execute(
                    """
                    INSERT INTO senses(id, word_id, part_of_speech, definition, translation, rank, source)
                    VALUES (?, ?, ?, ?, ?, 0, ?)
                    """,
                    (
                        f"{word_id}-ecdict-sense-1",
                        word_id,
                        row.get("pos", ""),
                        definition or translation,
                        translation,
                        SOURCE,
                    ),
                )
                if ipa:
                    connection.execute(
                        """
                        INSERT INTO pronunciations(id, word_id, ipa, dialect, source)
                        VALUES (?, ?, ?, 'UK', ?)
                        """,
                        (f"{word_id}-ecdict", word_id, ipa, SOURCE),
                    )

        connection.execute("PRAGMA user_version = 3")
        connection.commit()
        print(f"Merged {matched} existing words, inserted {inserted} ECDICT-only words")
    finally:
        connection.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Merge ECDICT translations into a MyDict SQLite bundle.")
    parser.add_argument("--database", default="Sources/MyDictCore/Resources/dictionary.sqlite")
    parser.add_argument("--ecdict-csv", default="data/ecdict/ecdict.csv")
    parser.add_argument("--insert-extra-limit", type=int, default=20_000)
    args = parser.parse_args()

    merge(Path(args.database), Path(args.ecdict_csv), args.insert_extra_limit)


if __name__ == "__main__":
    main()
