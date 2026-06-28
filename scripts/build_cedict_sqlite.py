#!/usr/bin/env python3
"""Add a Chinese->English dictionary table from CC-CEDICT.

Parses cedict_ts.u8 into a `cedict` table (simplified / traditional / accented
pinyin / English glosses). Incremental: only creates/replaces the cedict table,
leaving the English dictionary untouched. Offline, CC-BY-SA data.

  python3 scripts/build_cedict_sqlite.py --cedict data/cedict/cedict.txt
"""
import argparse
import re
import sqlite3
from pathlib import Path


LINE_RE = re.compile(r"^(\S+)\s+(\S+)\s+\[([^\]]*)\]\s+/(.*)/\s*$")

TONE_MARKS = {
    "a": "aāáǎà", "e": "eēéěè", "i": "iīíǐì",
    "o": "oōóǒò", "u": "uūúǔù", "ü": "üǖǘǚǜ",
}

SCHEMA = """
DROP TABLE IF EXISTS cedict;
CREATE TABLE cedict (
  id INTEGER PRIMARY KEY,
  simplified TEXT NOT NULL,
  traditional TEXT,
  pinyin TEXT,
  definitions TEXT NOT NULL,
  length INTEGER NOT NULL
);
CREATE INDEX idx_cedict_simplified ON cedict(simplified);
CREATE INDEX idx_cedict_traditional ON cedict(traditional);
"""


def convert_syllable(token: str) -> str:
    match = re.match(r"^([A-Za-zü:]+)([1-5])$", token)
    if not match:
        return token.replace("u:", "ü").replace("U:", "Ü")

    body, tone = match.group(1), int(match.group(2))
    body = body.replace("u:", "ü").replace("U:", "Ü")
    if tone == 5:
        return body

    lower = body.lower()
    if "a" in lower:
        target = "a"
    elif "e" in lower:
        target = "e"
    elif "ou" in lower:
        target = "o"
    else:
        target = next((ch for ch in reversed(lower) if ch in TONE_MARKS), None)
    if target is None:
        return body

    index = lower.rfind(target)
    accent = TONE_MARKS[target][tone]
    original = body[index]
    if original.isupper():
        accent = accent.upper()
    return body[:index] + accent + body[index + 1:]


def convert_pinyin(pinyin: str) -> str:
    return " ".join(convert_syllable(tok) for tok in pinyin.split())


def build(database: Path, cedict: Path) -> None:
    connection = sqlite3.connect(database)
    try:
        connection.executescript(SCHEMA)

        rows = []
        with cedict.open("r", encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("#") or not line.strip():
                    continue
                match = LINE_RE.match(line.rstrip("\n"))
                if not match:
                    continue
                traditional, simplified, pinyin, defs = match.groups()
                definitions = " / ".join(part for part in defs.split("/") if part.strip())
                if not definitions:
                    continue
                rows.append((
                    simplified,
                    traditional,
                    convert_pinyin(pinyin),
                    definitions,
                    len(simplified),
                ))

        connection.executemany(
            """
            INSERT INTO cedict(simplified, traditional, pinyin, definitions, length)
            VALUES (?, ?, ?, ?, ?)
            """,
            rows,
        )
        connection.commit()
        print(f"Inserted {len(rows)} CC-CEDICT entries")
    finally:
        connection.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Add a CC-CEDICT Chinese->English table to a MyDict bundle.")
    parser.add_argument("--database", default="Sources/MyDictCore/Resources/dictionary.sqlite")
    parser.add_argument("--cedict", default="data/cedict/cedict.txt")
    args = parser.parse_args()

    build(Path(args.database), Path(args.cedict))


if __name__ == "__main__":
    main()
