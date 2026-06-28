#!/usr/bin/env python3
"""Slim the bundled dictionary without losing any content.

Run as the final pipeline step. It:
  1. Rebuilds senses / pronunciations / examples with INTEGER primary keys
     (their long synthetic TEXT ids are only runtime list identifiers, so the
     ~30 MB of TEXT autoindexes they cost is pure waste).
  2. Rebuilds the FTS index with detail='none' (drops unused positions/docsize).
  3. VACUUMs to reclaim the freed pages.

`words.id` is intentionally left as TEXT: it is a stable, human-meaningful key
referenced by saved history, foreign keys, and the cedict-id check.

The Swift loaders are unaffected: sqlite3_column_text converts the INTEGER ids
to their textual form automatically.
"""
import argparse
import sqlite3
from pathlib import Path


REBUILDS = [
    # (table, integer-pk column list excluding id, column DDL excluding id)
    (
        "senses",
        "word_id, part_of_speech, definition, translation, rank, source",
        """
        word_id TEXT NOT NULL REFERENCES words(id) ON DELETE CASCADE,
        part_of_speech TEXT,
        definition TEXT NOT NULL,
        translation TEXT,
        rank INTEGER DEFAULT 0,
        source TEXT NOT NULL
        """,
        "ORDER BY word_id, rank",
        "CREATE INDEX idx_senses_word ON senses(word_id);",
    ),
    (
        "pronunciations",
        "word_id, ipa, dialect, audio_url, audio_cache_path, source",
        """
        word_id TEXT NOT NULL REFERENCES words(id) ON DELETE CASCADE,
        ipa TEXT,
        dialect TEXT,
        audio_url TEXT,
        audio_cache_path TEXT,
        source TEXT
        """,
        "ORDER BY word_id",
        "CREATE INDEX idx_pronunciations_word ON pronunciations(word_id);",
    ),
    (
        "examples",
        "word_id, sentence, translation, source, quality_score",
        """
        word_id TEXT NOT NULL REFERENCES words(id) ON DELETE CASCADE,
        sentence TEXT NOT NULL,
        translation TEXT,
        source TEXT NOT NULL,
        quality_score REAL DEFAULT 0
        """,
        "ORDER BY word_id, quality_score DESC",
        "CREATE INDEX idx_examples_word ON examples(word_id);",
    ),
]


def optimize(database: Path) -> None:
    before = database.stat().st_size
    connection = sqlite3.connect(database)
    try:
        connection.execute("PRAGMA foreign_keys = OFF")

        for table, columns, ddl, order, index_sql in REBUILDS:
            connection.executescript(
                f"""
                CREATE TABLE {table}_new (
                  id INTEGER PRIMARY KEY,
                  {ddl.strip()}
                );
                INSERT INTO {table}_new ({columns})
                  SELECT {columns} FROM {table} {order};
                DROP TABLE {table};
                ALTER TABLE {table}_new RENAME TO {table};
                {index_sql}
                """
            )

        # Rebuild FTS without positions/docsize; prefix MATCH still works.
        connection.executescript(
            """
            DROP TABLE IF EXISTS words_fts;
            CREATE VIRTUAL TABLE words_fts USING fts5(
              headword,
              normalized,
              content='words',
              content_rowid='rowid',
              detail='none'
            );
            INSERT INTO words_fts(words_fts) VALUES('rebuild');
            """
        )

        connection.commit()
        connection.execute("VACUUM")
        connection.commit()
    finally:
        connection.close()

    after = database.stat().st_size
    print(f"Optimized: {before/1048576:.1f} MB -> {after/1048576:.1f} MB "
          f"(saved {(before-after)/1048576:.1f} MB)")


def main() -> None:
    parser = argparse.ArgumentParser(description="Slim a MyDict SQLite bundle in place.")
    parser.add_argument("--database", default="Sources/MyDictCore/Resources/dictionary.sqlite")
    args = parser.parse_args()
    optimize(Path(args.database))


if __name__ == "__main__":
    main()
