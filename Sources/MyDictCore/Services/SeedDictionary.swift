import Foundation

public enum SeedDictionary {
    public static let entries: [DictionaryEntry] = [
        entry(
            "possible",
            frequency: 0.88,
            ipa: "/ˈpɑːsəbəl/",
            partOfSpeech: "adjective",
            definition: "Able to be done or achieved; capable of happening.",
            translation: "可能的；可做到的",
            examples: [
                ("It is possible to finish the work today.", "今天完成这项工作是可能的。"),
                ("Choose the simplest possible explanation first.", "先选择最简单的可能解释。")
            ],
            breakdown: "poss + ible: able to exist or happen",
            association: "把它想成一扇还没关上的门：事情仍然有机会发生。",
            usage: "possible solution / possible cause / as soon as possible",
            contrast: "possible 强调有可能；probable 更偏向很可能。"
        ),
        entry(
            "probable",
            frequency: 0.62,
            ipa: "/ˈprɑːbəbəl/",
            partOfSpeech: "adjective",
            definition: "Likely to happen or to be true.",
            translation: "很可能的；大概的",
            examples: [
                ("Rain is probable later this evening.", "今晚晚些时候很可能下雨。"),
                ("The probable cause was a configuration error.", "可能原因是配置错误。")
            ],
            breakdown: "prob + able: able to be proved or tested",
            association: "probable 像概率条已经偏高，不只是有可能。",
            usage: "probable cause / probable outcome",
            contrast: "probable 比 possible 的把握更高。"
        ),
        entry(
            "necessary",
            frequency: 0.86,
            ipa: "/ˈnesəseri/",
            partOfSpeech: "adjective",
            definition: "Required to be done, achieved, or present.",
            translation: "必要的；必需的",
            examples: [
                ("Sleep is necessary for memory and focus.", "睡眠对记忆和专注是必要的。"),
                ("Make only the necessary changes.", "只做必要的修改。")
            ],
            breakdown: "necess + ary: something needful",
            association: "necessary 是清单上不能划掉的那一项。",
            usage: "necessary condition / if necessary / necessary step",
            contrast: "necessary 是必须；important 是重要但不一定必须。"
        ),
        entry(
            "receive",
            frequency: 0.8,
            ipa: "/rɪˈsiːv/",
            partOfSpeech: "verb",
            definition: "To get or accept something that is sent or given.",
            translation: "收到；接收",
            examples: [
                ("You will receive a confirmation email.", "你会收到一封确认邮件。"),
                ("The app can receive updates offline later.", "这个应用稍后可以离线接收更新。")
            ],
            breakdown: "re + ceive: take back or take in",
            association: "记住 i before e 的例外：receive 里是 cei。",
            usage: "receive a message / receive support",
            contrast: "receive 是收到；accept 是接受并认可。"
        ),
        entry(
            "retrieve",
            frequency: 0.58,
            ipa: "/rɪˈtriːv/",
            partOfSpeech: "verb",
            definition: "To find and bring back information or an object.",
            translation: "取回；检索",
            examples: [
                ("The search index retrieves similar words quickly.", "搜索索引能快速检索相似词。"),
                ("She retrieved the file from the archive.", "她从归档中取回了文件。")
            ],
            breakdown: "re + trieve: bring back again",
            association: "retrieve 像从抽屉里把东西重新拿回来。",
            usage: "retrieve data / retrieve a file",
            contrast: "retrieve 偏取回；search 偏寻找过程。"
        ),
        entry(
            "dictionary",
            frequency: 0.72,
            ipa: "/ˈdɪkʃəneri/",
            partOfSpeech: "noun",
            definition: "A reference source that lists words and explains their meanings.",
            translation: "词典；字典",
            examples: [
                ("A good dictionary should be fast and trustworthy.", "一本好词典应该快速且可信。"),
                ("The dictionary keeps a local history of looked-up words.", "词典会在本地保留查过的词。")
            ],
            breakdown: "dict + ion + ary: a place of words that are said or written",
            association: "dict 表示说，dictionary 就是把词说清楚的地方。",
            usage: "open-source dictionary / dictionary entry",
            contrast: "dictionary 是词典；thesaurus 偏同义词词典。"
        ),
        entry(
            "pronunciation",
            frequency: 0.54,
            ipa: "/prəˌnʌnsiˈeɪʃən/",
            partOfSpeech: "noun",
            definition: "The way in which a word is spoken.",
            translation: "发音；读法",
            examples: [
                ("Tap the phonetic symbol to hear the pronunciation.", "点击音标即可听到发音。"),
                ("Pronunciation can vary between regions.", "发音可能因地区而异。")
            ],
            breakdown: "pro + nunc + iation: the act of saying aloud",
            association: "pronunciation 不是 pronounciation，中间没有第二个 o。",
            usage: "clear pronunciation / British pronunciation",
            contrast: "pronunciation 是名词；pronounce 是动词。"
        ),
        entry(
            "memory",
            frequency: 0.78,
            ipa: "/ˈmeməri/",
            partOfSpeech: "noun",
            definition: "The ability to store and remember information.",
            translation: "记忆；记忆力",
            examples: [
                ("Review strengthens long-term memory.", "复习能加强长期记忆。"),
                ("A vivid image can make a word easier to keep in memory.", "鲜明的画面能让单词更容易记住。")
            ],
            breakdown: "memor + y: related to remembering",
            association: "memory 像一个本地缓存，复习会让它更稳定。",
            usage: "memory aid / long-term memory",
            contrast: "memory 是能力或内容；memo 是备忘录。"
        ),
        entry(
            "concise",
            frequency: 0.48,
            ipa: "/kənˈsaɪs/",
            partOfSpeech: "adjective",
            definition: "Giving a lot of information clearly in few words.",
            translation: "简洁的；简明的",
            examples: [
                ("The interface should stay concise.", "界面应该保持简洁。"),
                ("Write a concise definition for each sense.", "为每个义项写一个简明定义。")
            ],
            breakdown: "con + cise: cut together, trimmed down",
            association: "concise 像把多余的句子修剪掉。",
            usage: "concise explanation / concise design",
            contrast: "concise 是信息密度高；short 只是短。"
        ),
        entry(
            "review",
            frequency: 0.76,
            ipa: "/rɪˈvjuː/",
            partOfSpeech: "verb/noun",
            definition: "To look at or study something again.",
            translation: "复习；回顾；审查",
            examples: [
                ("Review words before they fade from memory.", "在单词从记忆里变淡前复习。"),
                ("The history view makes review easier.", "历史视图让回顾更容易。")
            ],
            breakdown: "re + view: see again",
            association: "review 就是再看一次。",
            usage: "review history / weekly review",
            contrast: "review 是回看；revise 更强调修改或备考复习。"
        ),
        entry(
            "abandon",
            frequency: 0.61,
            ipa: "/əˈbændən/",
            partOfSpeech: "verb",
            definition: "To leave something behind or stop doing it.",
            translation: "放弃；抛弃",
            examples: [
                ("Do not abandon the plan after one failed attempt.", "不要因为一次失败就放弃计划。"),
                ("The team abandoned the old design.", "团队放弃了旧设计。")
            ],
            breakdown: "a + bandon: leave from one's control",
            association: "abandon 像把一个方案从桌面上拿开，不再继续。",
            usage: "abandon a plan / abandon an idea",
            contrast: "abandon 更彻底；pause 只是暂停。"
        ),
        entry(
            "accurate",
            frequency: 0.67,
            ipa: "/ˈækjərət/",
            partOfSpeech: "adjective",
            definition: "Correct and free from mistakes.",
            translation: "准确的；精确的",
            examples: [
                ("An accurate dictionary needs reliable sources.", "准确的词典需要可靠来源。"),
                ("The result is accurate enough for daily use.", "这个结果对日常使用足够准确。")
            ],
            breakdown: "accur + ate: done with care",
            association: "accurate 像刻度尺对齐到正确位置。",
            usage: "accurate result / accurate translation",
            contrast: "accurate 强调正确；precise 强调精细。"
        ),
        entry(
            "ambiguous",
            frequency: 0.47,
            ipa: "/æmˈbɪɡjuəs/",
            partOfSpeech: "adjective",
            definition: "Having more than one possible meaning.",
            translation: "含糊的；有歧义的",
            examples: [
                ("The word is ambiguous without context.", "没有上下文时这个词有歧义。"),
                ("Avoid ambiguous labels in the interface.", "界面中避免含糊的标签。")
            ],
            breakdown: "ambi + guous: going both ways",
            association: "ambi 表示两边，ambiguous 就像路牌指向两个方向。",
            usage: "ambiguous meaning / ambiguous sentence",
            contrast: "ambiguous 是多义不清；vague 是笼统模糊。"
        ),
        entry(
            "efficient",
            frequency: 0.7,
            ipa: "/ɪˈfɪʃənt/",
            partOfSpeech: "adjective",
            definition: "Working well without wasting time or effort.",
            translation: "高效的",
            examples: [
                ("Local search makes the app efficient.", "本地搜索让应用更高效。"),
                ("The workflow is efficient for repeated lookups.", "这个流程适合反复查词。")
            ],
            breakdown: "ef + fic + ient: making something happen",
            association: "efficient 像一条直达路线，少绕路。",
            usage: "efficient search / efficient workflow",
            contrast: "efficient 强调少浪费；effective 强调有效。"
        ),
        entry(
            "offline",
            frequency: 0.57,
            ipa: "/ˌɔːfˈlaɪn/",
            partOfSpeech: "adjective/adverb",
            definition: "Not connected to or using the internet.",
            translation: "离线的；不联网的",
            examples: [
                ("The basic dictionary works offline.", "基础词典可以离线工作。"),
                ("Offline data avoids repeated network calls.", "离线数据避免重复网络请求。")
            ],
            breakdown: "off + line: away from the network line",
            association: "offline 是把网线拔掉后仍能工作。",
            usage: "offline mode / offline dictionary",
            contrast: "offline 不联网；local 强调在本机。"
        ),
        entry(
            "similar",
            frequency: 0.74,
            ipa: "/ˈsɪmələr/",
            partOfSpeech: "adjective",
            definition: "Almost the same but not exactly the same.",
            translation: "相似的；类似的",
            examples: [
                ("The app recalls similar words when spelling is wrong.", "拼写错误时应用会召回相似词。"),
                ("These two words have similar meanings.", "这两个词意思相近。")
            ],
            breakdown: "simil + ar: like or resembling",
            association: "similar 像两张不完全一样但很像的照片。",
            usage: "similar word / similar meaning",
            contrast: "similar 是相似；same 是相同。"
        ),
        entry(
            "source",
            frequency: 0.75,
            ipa: "/sɔːrs/",
            partOfSpeech: "noun",
            definition: "The place where something comes from.",
            translation: "来源；出处",
            examples: [
                ("Each definition should keep its source.", "每条释义都应该保留来源。"),
                ("Open-source data keeps the app affordable.", "开源数据让应用保持低成本。")
            ],
            breakdown: "source: origin or starting point",
            association: "source 像一条河的源头。",
            usage: "data source / open source",
            contrast: "source 是来源；resource 是可用资源。"
        ),
        entry(
            "token",
            frequency: 0.51,
            ipa: "/ˈtoʊkən/",
            partOfSpeech: "noun",
            definition: "A unit of text processed by a language model, or a small sign of something.",
            translation: "令牌；文本计费单位；象征",
            examples: [
                ("The offline flow does not consume tokens.", "离线流程不会消耗 token。"),
                ("A token can represent part of a word.", "一个 token 可以表示单词的一部分。")
            ],
            breakdown: "token: a small piece that stands for something",
            association: "token 像被机器拿来计数的一小片文字。",
            usage: "token usage / API token",
            contrast: "token 是处理单位；word 是自然语言里的词。"
        ),
        entry(
            "explain",
            frequency: 0.82,
            ipa: "/ɪkˈspleɪn/",
            partOfSpeech: "verb",
            definition: "To make something clear or easy to understand.",
            translation: "解释；说明",
            examples: [
                ("The detail view explains the word with examples.", "详情页用例句解释单词。"),
                ("Can you explain the difference?", "你能解释区别吗？")
            ],
            breakdown: "ex + plain: make plain or clear",
            association: "explain 就是把折起来的信息摊平。",
            usage: "explain clearly / explain a word",
            contrast: "explain 是解释；describe 是描述。"
        ),
        entry(
            "context",
            frequency: 0.79,
            ipa: "/ˈkɑːntekst/",
            partOfSpeech: "noun",
            definition: "The words, facts, or situation around something that help explain it.",
            translation: "上下文；语境；背景",
            examples: [
                ("Context often decides which meaning is right.", "上下文常常决定哪个意思是正确的。"),
                ("Examples give a word useful context.", "例句给单词提供有用语境。")
            ],
            breakdown: "con + text: woven together with the text",
            association: "context 像单词周围的环境光。",
            usage: "in context / context clue",
            contrast: "context 是语境；content 是内容。"
        )
    ]

    private static func entry(
        _ word: String,
        frequency: Double,
        ipa: String,
        partOfSpeech: String,
        definition: String,
        translation: String,
        examples: [(String, String)],
        breakdown: String,
        association: String,
        usage: String,
        contrast: String
    ) -> DictionaryEntry {
        DictionaryEntry(
            id: word,
            headword: word,
            normalized: TextNormalizer.normalize(word),
            frequency: frequency,
            senses: [
                Sense(
                    id: "\(word)-sense-1",
                    partOfSpeech: partOfSpeech,
                    definition: definition,
                    translation: translation,
                    rank: 0,
                    source: "Offline seed dictionary"
                )
            ],
            pronunciations: [
                Pronunciation(id: "\(word)-us", ipa: ipa, dialect: "US")
            ],
            examples: examples.enumerated().map { index, pair in
                ExampleSentence(
                    id: "\(word)-example-\(index + 1)",
                    text: pair.0,
                    translation: pair.1,
                    source: "Offline seed examples"
                )
            },
            memoryAid: MemoryAid(
                breakdown: breakdown,
                association: association,
                usage: usage,
                contrast: contrast
            ),
            source: "Offline seed dictionary"
        )
    }
}
