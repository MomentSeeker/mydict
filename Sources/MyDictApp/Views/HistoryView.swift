import MyDictCore
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        let days = model.historyByDay()

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    SectionHeader("History", icon: "clock.arrow.circlepath")
                    Spacer()
                    Text("\(model.history.count) lookups")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }

                if days.isEmpty {
                    ContentUnavailableView("No lookups yet", systemImage: "clock", description: Text("Words you search will show up here, grouped by day."))
                        .padding(.top, 40)
                } else {
                    ForEach(days) { day in
                        DaySection(day: day)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 720, alignment: .leading)
        }
    }
}

private struct DaySection: View {
    @EnvironmentObject private var model: AppModel
    let day: HistoryDaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(day.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("\(day.words.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                Spacer()
            }

            VStack(spacing: 0) {
                ForEach(Array(day.words.enumerated()), id: \.element.id) { index, word in
                    if index > 0 {
                        Divider().padding(.leading, 14)
                    }
                    HistoryRow(word: word)
                }
            }
            .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.08), lineWidth: 1))
        }
    }
}

private struct HistoryRow: View {
    @EnvironmentObject private var model: AppModel
    let word: HistoryWordSummary

    var body: some View {
        Button {
            model.openWord(wordID: word.wordID, query: word.queryText)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: word.isFavorite ? "star.fill" : "circle.fill")
                    .font(.system(size: word.isFavorite ? 11 : 5))
                    .foregroundStyle(word.isFavorite ? Color.yellow : Color.secondary.opacity(0.4))
                    .frame(width: 12)

                Text(word.headword)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)

                if word.queryText.caseInsensitiveCompare(word.headword) != .orderedSame, !word.queryText.isEmpty {
                    Text(word.queryText)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)

                if word.count > 1 {
                    Text("\(word.count)×")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.10), in: Capsule())
                }

                Text(word.lastLookedUp, format: .dateTime.hour().minute())
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(width: 58, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct RecentWordsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "clock")
                Text("Recent")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)

            if model.recentUniqueEntries(limit: 5).isEmpty {
                Text("No lookups yet")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
            } else {
                ForEach(model.recentUniqueEntries(limit: 5)) { entry in
                    Button {
                        model.select(entry)
                    } label: {
                        HStack {
                            Text(entry.headword)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 28)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(minHeight: 120, alignment: .top)
    }
}
