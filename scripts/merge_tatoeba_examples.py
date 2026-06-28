#!/usr/bin/env python3
"""Add bilingual (English + Chinese) example sentences from Tatoeba.

Builds English<->Chinese sentence pairs from the Tatoeba per-language exports
and attaches each pair to the content words it contains, writing them into the
existing `examples` table (source = 'Tatoeba'). Offline, CC-BY data.

Inputs (downloaded into data/tatoeba/, see README):
  cmn-eng_links.tsv   cmn_id <tab> eng_id
  cmn_sentences.tsv   id <tab> cmn <tab> text
  eng_sentences.tsv   id <tab> eng <tab> text
"""
import argparse
import re
import sqlite3
from pathlib import Path


SOURCE = "Tatoeba"
MAX_PER_WORD = 5
MIN_LEN = 10
MAX_LEN = 90
WORD_RE = re.compile(r"[A-Za-z][A-Za-z'-]*")

# Grammatical words that would collect noise rather than useful study examples.
STOPWORDS = {
    "the", "a", "an", "and", "or", "but", "if", "of", "to", "in", "on", "at",
    "by", "for", "with", "from", "as", "is", "am", "are", "was", "were", "be",
    "been", "being", "do", "does", "did", "have", "has", "had", "i", "you",
    "he", "she", "it", "we", "they", "me", "him", "her", "us", "them", "my",
    "your", "his", "its", "our", "their", "this", "that", "these", "those",
    "there", "here", "what", "which", "who", "whom", "not", "no", "yes", "so",
    "than", "then", "too", "very", "can", "will", "would", "should", "could",
    "may", "might", "must", "shall", "s", "t", "m", "re", "ve", "ll", "d",
}


def normalize(text: str) -> str:
    return "".join(
        ch.lower() for ch in text.strip() if ch.isalpha() or ch in "-'"
    )


def load_pairs(links: Path, cmn: Path, eng: Path):
    needed_cmn: set[str] = set()
    needed_eng: set[str] = set()
    link_pairs: list[tuple[str, str]] = []
    with links.open("r", encoding="utf-8") as handle:
        for line in handle:
            parts = line.rstrip("\n").split("\t")
            if len(parts) != 2:
                continue
            cmn_id, eng_id = parts
            link_pairs.append((cmn_id, eng_id))
            needed_cmn.add(cmn_id)
            needed_eng.add(eng_id)

    def load_texts(path: Path, needed: set[str]) -> dict[str, str]:
        texts: dict[str, str] = {}
        with path.open("r", encoding="utf-8") as handle:
            for line in handle:
                parts = line.rstrip("\n").split("\t", 2)
                if len(parts) == 3 and parts[0] in needed:
                    texts[parts[0]] = parts[2]
        return texts

    cmn_texts = load_texts(cmn, needed_cmn)
    eng_texts = load_texts(eng, needed_eng)

    for cmn_id, eng_id in link_pairs:
        en = eng_texts.get(eng_id)
        zh = cmn_texts.get(cmn_id)
        if en and zh:
            yield en.strip(), zh.strip()


def merge(database: Path, links: Path, cmn: Path, eng: Path) -> None:
    connection = sqlite3.connect(database)
    try:
        word_ids = {
            normalized: word_id
            for word_id, normalized in connection.execute("SELECT id, normalized FROM words")
        }

        # word_id -> list of (length, english, chinese), kept shortest-first.
        buckets: dict[str, list[tuple[int, str, str]]] = {}
        seen_per_word: dict[str, set[str]] = {}

        for english, chinese in load_pairs(links, cmn, eng):
            length = len(english)
            if length < MIN_LEN or length > MAX_LEN:
                continue
            tokens = {match.group(0).lower() for match in WORD_RE.finditer(english)}
            for token in tokens:
                if token in STOPWORDS or len(token) < 2:
                    continue
                word_id = word_ids.get(normalize(token))
                if not word_id:
                    continue
                seen = seen_per_word.setdefault(word_id, set())
                if english in seen:
                    continue
                bucket = buckets.setdefault(word_id, [])
                bucket.append((length, english, chinese))
                seen.add(english)

        connection.execute("DELETE FROM examples WHERE source = ?", (SOURCE,))

        rows = []
        for word_id, bucket in buckets.items():
            bucket.sort(key=lambda item: item[0])
            for index, (length, english, chinese) in enumerate(bucket[:MAX_PER_WORD]):
                quality = max(0.3, min(0.85, 1.0 - length / 120.0)) - index * 0.01
                rows.append((
                    f"{word_id}-tatoeba-{index}",
                    word_id,
                    english,
                    chinese,
                    SOURCE,
                    quality,
                ))

        connection.executemany(
            """
            INSERT INTO examples(id, word_id, sentence, translation, source, quality_score)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            rows,
        )
        connection.commit()
        print(f"Inserted {len(rows)} Tatoeba examples across {len(buckets)} words")
    finally:
        connection.close()


def main() -> None:
    parser = argparse.ArgumentParser(description="Attach Tatoeba bilingual examples to a MyDict bundle.")
    parser.add_argument("--database", default="Sources/MyDictCore/Resources/dictionary.sqlite")
    parser.add_argument("--links", default="data/tatoeba/cmn-eng_links.tsv")
    parser.add_argument("--cmn", default="data/tatoeba/cmn_sentences.tsv")
    parser.add_argument("--eng", default="data/tatoeba/eng_sentences.tsv")
    args = parser.parse_args()

    merge(Path(args.database), Path(args.links), Path(args.cmn), Path(args.eng))


if __name__ == "__main__":
    main()
