import MyDictCore
import SwiftUI

struct CandidateListView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                if model.candidates.isEmpty, !model.query.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundStyle(.tertiary)
                        Text("No local match")
                            .font(.system(size: 14, weight: .semibold))
                        Text("The offline dictionary does not contain a close match yet.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                } else {
                    ForEach(model.candidates) { candidate in
                        CandidateRow(candidate: candidate, isSelected: candidate.id == model.highlightedCandidateID)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.select(candidate)
                            }
                        }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 2)
        }
    }
}

private struct CandidateRow: View {
    let candidate: SearchCandidate
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(candidate.entry.headword)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(candidate.reason)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(candidate.entry.senses.first?.translation ?? candidate.entry.senses.first?.definition ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("\(Int(candidate.score * 100))")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
    }
}
