import MyDictCore
import SwiftUI

struct ReviewView: View {
    @EnvironmentObject private var model: AppModel

    @State private var session: [DictionaryEntry] = []
    @State private var planned = 0
    @State private var index = 0
    @State private var finalized = 0
    @State private var knownCount = 0
    @State private var revealed = false
    @State private var phase: Phase = .idle

    private enum Phase { case idle, reviewing, done }

    var body: some View {
        VStack(spacing: 0) {
            switch phase {
            case .idle:
                startScreen
            case .reviewing:
                if index < session.count {
                    reviewingScreen(entry: session[index])
                } else {
                    Color.clear.onAppear { phase = .done }
                }
            case .done:
                doneScreen
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Start

    private var startScreen: some View {
        let due = model.reviewQueue()
        return VStack(spacing: 0) {
            header(trailing: due.isEmpty ? "" : "\(due.count) due")
            Spacer()
            if due.isEmpty {
                ContentUnavailableView(
                    "All caught up",
                    systemImage: "checkmark.circle",
                    description: Text("Look up some words first — the ones you check most often come up for review here.")
                )
            } else {
                VStack(spacing: 18) {
                    ZStack {
                        Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 88, height: 88)
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    VStack(spacing: 6) {
                        Text("\(due.count) words to review")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Sorted by how often you look them up")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        start(with: due)
                    } label: {
                        Text("Start review").frame(width: 180)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            Spacer()
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: 720, alignment: .leading)
    }

    // MARK: - Reviewing

    private func reviewingScreen(entry: DictionaryEntry) -> some View {
        VStack(spacing: 0) {
            header(trailing: "\(min(finalized + 1, planned)) / \(planned)")

            ProgressView(value: Double(finalized), total: Double(max(planned, 1)))
                .tint(Color.accentColor)
                .padding(.top, 14)

            Spacer(minLength: 12)

            card(entry: entry)

            Spacer(minLength: 12)

            controls(entry: entry)
        }
        .padding(32)
        .frame(maxWidth: 720, maxHeight: .infinity, alignment: .leading)
    }

    private func card(entry: DictionaryEntry) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(entry.headword)
                    .font(.system(size: 40, weight: .bold))
                Button { model.speak(entry) } label: {
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 16))
                }
                .buttonStyle(.borderless)
                Spacer()
            }

            HStack(spacing: 10) {
                if let ipa = entry.pronunciations.first?.ipa, !ipa.isEmpty {
                    Text(ipa)
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(.secondary)
                }
                let count = model.lookupCount(for: entry.id)
                if count > 0 {
                    Label("looked up \(count)×", systemImage: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }

            if revealed {
                Divider().padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 12) {
                    Text(reviewMeaning(for: entry))
                        .font(.system(size: 20, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    if let example = entry.examples.first?.text, !example.isEmpty {
                        Text(example)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !entry.memoryAid.association.isEmpty {
                        Text(entry.memoryAid.association)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .transition(.opacity)
            } else {
                Text("Recall the meaning, then reveal.")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.secondary.opacity(0.10), lineWidth: 1))
    }

    @ViewBuilder
    private func controls(entry: DictionaryEntry) -> some View {
        if revealed {
            HStack(spacing: 10) {
                ratingButton("Again", icon: "arrow.counterclockwise", tint: .red, value: 0, entry: entry)
                ratingButton("Good", icon: "checkmark", tint: .accentColor, value: 1, entry: entry)
                ratingButton("Easy", icon: "hand.thumbsup", tint: .green, value: 2, entry: entry)
            }
        } else {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { revealed = true }
            } label: {
                Label("Reveal", systemImage: "eye").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.space, modifiers: [])
        }
    }

    private func ratingButton(_ title: String, icon: String, tint: Color, value: Int, entry: DictionaryEntry) -> some View {
        Button {
            rate(entry: entry, value: value)
        } label: {
            Label(title, systemImage: icon).frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .buttonStyle(.bordered)
        .tint(tint)
    }

    // MARK: - Done

    private var doneScreen: some View {
        VStack(spacing: 0) {
            header(trailing: "")
            Spacer()
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(Color.green.opacity(0.14)).frame(width: 88, height: 88)
                    Image(systemName: "checkmark").font(.system(size: 38, weight: .bold)).foregroundStyle(.green)
                }
                Text("Session complete")
                    .font(.system(size: 20, weight: .semibold))
                Text("Reviewed \(planned) · \(knownCount) marked easy")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Button {
                    phase = .idle
                } label: {
                    Text("Back").frame(width: 180)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }
            Spacer()
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: 720, alignment: .leading)
    }

    // MARK: - Helpers

    private func header(trailing: String) -> some View {
        HStack {
            SectionHeader("Review", icon: "rectangle.stack")
            Spacer()
            if !trailing.isEmpty {
                Text(trailing)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func start(with due: [DictionaryEntry]) {
        session = due
        planned = due.count
        index = 0
        finalized = 0
        knownCount = 0
        revealed = false
        phase = .reviewing
    }

    private func rate(entry: DictionaryEntry, value: Int) {
        model.reviewResult(for: entry, familiarity: value)
        if value == 0 {
            // Again: see it again later this session, without counting as done.
            session.append(entry)
        } else {
            finalized += 1
            if value == 2 { knownCount += 1 }
        }
        revealed = false
        index += 1
        if index >= session.count {
            phase = .done
        }
    }

    private func reviewMeaning(for entry: DictionaryEntry) -> String {
        guard let sense = entry.senses.first else { return "" }
        return sense.translation.isEmpty ? sense.definition : sense.translation
    }
}
