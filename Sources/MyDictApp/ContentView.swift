import MyDictCore
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(isSearchFocused: $isSearchFocused)
                .frame(width: 330)

            Divider()

            Group {
                switch model.section {
                case .lookup:
                    DetailView(entry: model.selectedEntry)
                case .history:
                    HistoryView()
                case .review:
                    ReviewView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isSearchFocused = true
            }
        }
        .onChange(of: model.focusSearchToken) {
            model.section = .lookup
            isSearchFocused = true
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState.Binding var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 10) {
                sectionPicker
                offlineBadge
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $model.query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        model.confirmHighlightedCandidate()
                    }
                    .onKeyPress(.downArrow) {
                        model.moveCandidateSelection(by: 1)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        model.moveCandidateSelection(by: -1)
                        return .handled
                    }
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 14)

            CandidateListView()

            Divider()
                .padding(.horizontal, 14)

            RecentWordsView()
        }
        .padding(.vertical, 14)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sectionPicker: some View {
        HStack(spacing: 6) {
            ForEach(AppModel.Section.allCases) { section in
                Button {
                    model.section = section
                } label: {
                    Image(systemName: section.icon)
                        .frame(width: 28, height: 26)
                }
                .buttonStyle(.borderless)
                .help(section.title)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(model.section == section ? Color.accentColor.opacity(0.16) : Color.clear)
                )
            }
            Spacer()
        }
        .padding(.horizontal, 14)
    }

    private var offlineBadge: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 11, weight: .semibold))
                Text("Offline · No token")
                    .font(.system(size: 11, weight: .semibold))
            }
            Text("\(model.entryCount.formatted()) words")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .help(model.dictionaryStatus)
    }
}
