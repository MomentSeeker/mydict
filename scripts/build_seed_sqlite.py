#!/usr/bin/env python3
import sqlite3
import sys
from pathlib import Path


ENTRIES = [
    {
        "word": "possible",
        "frequency": 0.88,
        "ipa": "/ˈpɑːsəbəl/",
        "pos": "adjective",
        "definition": "Able to be done or achieved; capable of happening.",
        "translation": "可能的；可做到的",
        "examples": [
            ("It is possible to finish the work today.", "今天完成这项工作是可能的。"),
            ("Choose the simplest possible explanation first.", "先选择最简单的可能解释。"),
        ],
        "memory": (
            "poss + ible: able to exist or happen",
            "把它想成一扇还没关上的门：事情仍然有机会发生。",
            "possible solution / possible cause / as soon as possible",
            "possible 强调有可能；probable 更偏向很可能。",
        ),
    },
    {
        "word": "probable",
        "frequency": 0.62,
        "ipa": "/ˈprɑːbəbəl/",
        "pos": "adjective",
        "definition": "Likely to happen or to be true.",
        "translation": "很可能的；大概的",
        "examples": [
            ("Rain is probable later this evening.", "今晚晚些时候很可能下雨。"),
            ("The probable cause was a configuration error.", "可能原因是配置错误。"),
        ],
        "memory": (
            "prob + able: able to be proved or tested",
            "probable 像概率条已经偏高，不只是有可能。",
            "probable cause / probable outcome",
            "probable 比 possible 的把握更高。",
        ),
    },
    {
        "word": "necessary",
        "frequency": 0.86,
        "ipa": "/ˈnesəseri/",
        "pos": "adjective",
        "definition": "Required to be done, achieved, or present.",
        "translation": "必要的；必需的",
        "examples": [
            ("Sleep is necessary for memory and focus.", "睡眠对记忆和专注是必要的。"),
            ("Make only the necessary changes.", "只做必要的修改。"),
        ],
        "memory": (
            "necess + ary: something needful",
            "necessary 是清单上不能划掉的那一项。",
            "necessary condition / if necessary / necessary step",
            "necessary 是必须；important 是重要但不一定必须。",
        ),
    },
    {
        "word": "receive",
        "frequency": 0.80,
        "ipa": "/rɪˈsiːv/",
        "pos": "verb",
        "definition": "To get or accept something that is sent or given.",
        "translation": "收到；接收",
        "examples": [
            ("You will receive a confirmation email.", "你会收到一封确认邮件。"),
            ("The app can receive updates offline later.", "这个应用稍后可以离线接收更新。"),
        ],
        "memory": (
            "re + ceive: take back or take in",
            "记住 i before e 的例外：receive 里是 cei。",
            "receive a message / receive support",
            "receive 是收到；accept 是接受并认可。",
        ),
    },
    {
        "word": "retrieve",
        "frequency": 0.58,
        "ipa": "/rɪˈtriːv/",
        "pos": "verb",
        "definition": "To find and bring back information or an object.",
        "translation": "取回；检索",
        "examples": [
            ("The search index retrieves similar words quickly.", "搜索索引能快速检索相似词。"),
            ("She retrieved the file from the archive.", "她从归档中取回了文件。"),
        ],
        "memory": (
            "re + trieve: bring back again",
            "retrieve 像从抽屉里把东西重新拿回来。",
            "retrieve data / retrieve a file",
            "retrieve 偏取回；search 偏寻找过程。",
        ),
    },
    {
        "word": "dictionary",
        "frequency": 0.72,
        "ipa": "/ˈdɪkʃəneri/",
        "pos": "noun",
        "definition": "A reference source that lists words and explains their meanings.",
        "translation": "词典；字典",
        "examples": [
            ("A good dictionary should be fast and trustworthy.", "一本好词典应该快速且可信。"),
            ("The dictionary keeps a local history of looked-up words.", "词典会在本地保留查过的词。"),
        ],
        "memory": (
            "dict + ion + ary: a place of words that are said or written",
            "dict 表示说，dictionary 就是把词说清楚的地方。",
            "open-source dictionary / dictionary entry",
            "dictionary 是词典；thesaurus 偏同义词词典。",
        ),
    },
    {
        "word": "pronunciation",
        "frequency": 0.54,
        "ipa": "/prəˌnʌnsiˈeɪʃən/",
        "pos": "noun",
        "definition": "The way in which a word is spoken.",
        "translation": "发音；读法",
        "examples": [
            ("Tap the phonetic symbol to hear the pronunciation.", "点击音标即可听到发音。"),
            ("Pronunciation can vary between regions.", "发音可能因地区而异。"),
        ],
        "memory": (
            "pro + nunc + iation: the act of saying aloud",
            "pronunciation 不是 pronounciation，中间没有第二个 o。",
            "clear pronunciation / British pronunciation",
            "pronunciation 是名词；pronounce 是动词。",
        ),
    },
    {
        "word": "memory",
        "frequency": 0.78,
        "ipa": "/ˈmeməri/",
        "pos": "noun",
        "definition": "The ability to store and remember information.",
        "translation": "记忆；记忆力",
        "examples": [
            ("Review strengthens long-term memory.", "复习能加强长期记忆。"),
            ("A vivid image can make a word easier to keep in memory.", "鲜明的画面能让单词更容易记住。"),
        ],
        "memory": (
            "memor + y: related to remembering",
            "memory 像一个本地缓存，复习会让它更稳定。",
            "memory aid / long-term memory",
            "memory 是能力或内容；memo 是备忘录。",
        ),
    },
    {
        "word": "concise",
        "frequency": 0.48,
        "ipa": "/kənˈsaɪs/",
        "pos": "adjective",
        "definition": "Giving a lot of information clearly in few words.",
        "translation": "简洁的；简明的",
        "examples": [
            ("The interface should stay concise.", "界面应该保持简洁。"),
            ("Write a concise definition for each sense.", "为每个义项写一个简明定义。"),
        ],
        "memory": (
            "con + cise: cut together, trimmed down",
            "concise 像把多余的句子修剪掉。",
            "concise explanation / concise design",
            "concise 是信息密度高；short 只是短。",
        ),
    },
    {
        "word": "review",
        "frequency": 0.76,
        "ipa": "/rɪˈvjuː/",
        "pos": "verb/noun",
        "definition": "To look at or study something again.",
        "translation": "复习；回顾；审查",
        "examples": [
            ("Review words before they fade from memory.", "在单词从记忆里变淡前复习。"),
            ("The history view makes review easier.", "历史视图让回顾更容易。"),
        ],
        "memory": (
            "re + view: see again",
            "review 就是再看一次。",
            "review history / weekly review",
            "review 是回看；revise 更强调修改或备考复习。",
        ),
    },
    {
        "word": "abandon",
        "frequency": 0.61,
        "ipa": "/əˈbændən/",
        "pos": "verb",
        "definition": "To leave something behind or stop doing it.",
        "translation": "放弃；抛弃",
        "examples": [
            ("Do not abandon the plan after one failed attempt.", "不要因为一次失败就放弃计划。"),
            ("The team abandoned the old design.", "团队放弃了旧设计。"),
        ],
        "memory": (
            "a + bandon: leave from one's control",
            "abandon 像把一个方案从桌面上拿开，不再继续。",
            "abandon a plan / abandon an idea",
            "abandon 更彻底；pause 只是暂停。",
        ),
    },
    {
        "word": "accurate",
        "frequency": 0.67,
        "ipa": "/ˈækjərət/",
        "pos": "adjective",
        "definition": "Correct and free from mistakes.",
        "translation": "准确的；精确的",
        "examples": [
            ("An accurate dictionary needs reliable sources.", "准确的词典需要可靠来源。"),
            ("The result is accurate enough for daily use.", "这个结果对日常使用足够准确。"),
        ],
        "memory": (
            "accur + ate: done with care",
            "accurate 像刻度尺对齐到正确位置。",
            "accurate result / accurate translation",
            "accurate 强调正确；precise 强调精细。",
        ),
    },
    {
        "word": "ambiguous",
        "frequency": 0.47,
        "ipa": "/æmˈbɪɡjuəs/",
        "pos": "adjective",
        "definition": "Having more than one possible meaning.",
        "translation": "含糊的；有歧义的",
        "examples": [
            ("The word is ambiguous without context.", "没有上下文时这个词有歧义。"),
            ("Avoid ambiguous labels in the interface.", "界面中避免含糊的标签。"),
        ],
        "memory": (
            "ambi + guous: going both ways",
            "ambi 表示两边，ambiguous 就像路牌指向两个方向。",
            "ambiguous meaning / ambiguous sentence",
            "ambiguous 是多义不清；vague 是笼统模糊。",
        ),
    },
    {
        "word": "efficient",
        "frequency": 0.70,
        "ipa": "/ɪˈfɪʃənt/",
        "pos": "adjective",
        "definition": "Working well without wasting time or effort.",
        "translation": "高效的",
        "examples": [
            ("Local search makes the app efficient.", "本地搜索让应用更高效。"),
            ("The workflow is efficient for repeated lookups.", "这个流程适合反复查词。"),
        ],
        "memory": (
            "ef + fic + ient: making something happen",
            "efficient 像一条直达路线，少绕路。",
            "efficient search / efficient workflow",
            "efficient 强调少浪费；effective 强调有效。",
        ),
    },
    {
        "word": "offline",
        "frequency": 0.57,
        "ipa": "/ˌɔːfˈlaɪn/",
        "pos": "adjective/adverb",
        "definition": "Not connected to or using the internet.",
        "translation": "离线的；不联网的",
        "examples": [
            ("The basic dictionary works offline.", "基础词典可以离线工作。"),
            ("Offline data avoids repeated network calls.", "离线数据避免重复网络请求。"),
        ],
        "memory": (
            "off + line: away from the network line",
            "offline 是把网线拔掉后仍能工作。",
            "offline mode / offline dictionary",
            "offline 不联网；local 强调在本机。",
        ),
    },
    {
        "word": "similar",
        "frequency": 0.74,
        "ipa": "/ˈsɪmələr/",
        "pos": "adjective",
        "definition": "Almost the same but not exactly the same.",
        "translation": "相似的；类似的",
        "examples": [
            ("The app recalls similar words when spelling is wrong.", "拼写错误时应用会召回相似词。"),
            ("These two words have similar meanings.", "这两个词意思相近。"),
        ],
        "memory": (
            "simil + ar: like or resembling",
            "similar 像两张不完全一样但很像的照片。",
            "similar word / similar meaning",
            "similar 是相似；same 是相同。",
        ),
    },
    {
        "word": "source",
        "frequency": 0.75,
        "ipa": "/sɔːrs/",
        "pos": "noun",
        "definition": "The place where something comes from.",
        "translation": "来源；出处",
        "examples": [
            ("Each definition should keep its source.", "每条释义都应该保留来源。"),
            ("Open-source data keeps the app affordable.", "开源数据让应用保持低成本。"),
        ],
        "memory": (
            "source: origin or starting point",
            "source 像一条河的源头。",
            "data source / open source",
            "source 是来源；resource 是可用资源。",
        ),
    },
    {
        "word": "token",
        "frequency": 0.51,
        "ipa": "/ˈtoʊkən/",
        "pos": "noun",
        "definition": "A unit of text processed by a language model, or a small sign of something.",
        "translation": "令牌；文本计费单位；象征",
        "examples": [
            ("The offline flow does not consume tokens.", "离线流程不会消耗 token。"),
            ("A token can represent part of a word.", "一个 token 可以表示单词的一部分。"),
        ],
        "memory": (
            "token: a small piece that stands for something",
            "token 像被机器拿来计数的一小片文字。",
            "token usage / API token",
            "token 是处理单位；word 是自然语言里的词。",
        ),
    },
    {
        "word": "explain",
        "frequency": 0.82,
        "ipa": "/ɪkˈspleɪn/",
        "pos": "verb",
        "definition": "To make something clear or easy to understand.",
        "translation": "解释；说明",
        "examples": [
            ("The detail view explains the word with examples.", "详情页用例句解释单词。"),
            ("Can you explain the difference?", "你能解释区别吗？"),
        ],
        "memory": (
            "ex + plain: make plain or clear",
            "explain 就是把折起来的信息摊平。",
            "explain clearly / explain a word",
            "explain 是解释；describe 是描述。",
        ),
    },
    {
        "word": "context",
        "frequency": 0.79,
        "ipa": "/ˈkɑːntekst/",
        "pos": "noun",
        "definition": "The words, facts, or situation around something that help explain it.",
        "translation": "上下文；语境；背景",
        "examples": [
            ("Context often decides which meaning is right.", "上下文常常决定哪个意思是正确的。"),
            ("Examples give a word useful context.", "例句给单词提供有用语境。"),
        ],
        "memory": (
            "con + text: woven together with the text",
            "context 像单词周围的环境光。",
            "in context / context clue",
            "context 是语境；content 是内容。",
        ),
    },
]


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


def normalize(text: str) -> str:
    return "".join(ch.lower() for ch in text.strip() if ch.isalpha() or ch in "-'")


def build(output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    connection = sqlite3.connect(output)
    try:
        connection.executescript(SCHEMA)

        for entry in ENTRIES:
            word = entry["word"]
            normalized = normalize(word)
            source = "Offline SQLite seed dictionary"
            connection.execute(
                "INSERT INTO words(id, headword, normalized, frequency, source) VALUES (?, ?, ?, ?, ?)",
                (word, word, normalized, entry["frequency"], source),
            )
            connection.execute(
                "INSERT INTO words_fts(rowid, headword, normalized) VALUES ((SELECT rowid FROM words WHERE id = ?), ?, ?)",
                (word, word, normalized),
            )
            connection.execute(
                """
                INSERT INTO senses(id, word_id, part_of_speech, definition, translation, rank, source)
                VALUES (?, ?, ?, ?, ?, 0, ?)
                """,
                (
                    f"{word}-sense-1",
                    word,
                    entry["pos"],
                    entry["definition"],
                    entry["translation"],
                    source,
                ),
            )
            connection.execute(
                """
                INSERT INTO pronunciations(id, word_id, ipa, dialect, source)
                VALUES (?, ?, ?, 'US', ?)
                """,
                (f"{word}-us", word, entry["ipa"], source),
            )
            for index, (sentence, translation) in enumerate(entry["examples"], start=1):
                connection.execute(
                    """
                    INSERT INTO examples(id, word_id, sentence, translation, source, quality_score)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (
                        f"{word}-example-{index}",
                        word,
                        sentence,
                        translation,
                        source,
                        1.0 / index,
                    ),
                )
            connection.execute(
                """
                INSERT INTO memory_aids(word_id, breakdown, association, usage, contrast)
                VALUES (?, ?, ?, ?, ?)
                """,
                (word, *entry["memory"]),
            )

        connection.execute("PRAGMA user_version = 1")
        connection.commit()
    finally:
        connection.close()


def main() -> None:
    output = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("Sources/MyDictCore/Resources/dictionary.sqlite")
    build(output)
    print(f"Wrote {output}")


if __name__ == "__main__":
    main()
