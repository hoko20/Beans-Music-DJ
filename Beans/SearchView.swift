import SwiftUI

// MARK: - 流式布局（搜索历史 / 分类胶囊）

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[Subviews.Element]] = [[]]
        var rowWidth: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append(view)
            rowWidth += size.width + spacing
        }
        var height: CGFloat = 0
        for (index, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight + (index == rows.count - 1 ? 0 : spacing)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - 搜索

/// 搜索浮层：无服务端搜索，用「最近搜索 + 分类直达 + 跨分类聚合过滤」实现。
struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var player: PlayerManager
    @ObservedObject private var history = SearchHistoryStore.shared

    @State private var query = ""
    @State private var results: [Song] = []
    @State private var categorySongs: [Song] = []
    @State private var browseCategory: DJddCategory?
    @State private var isSearching = false
    @State private var hasSearched = false
    @FocusState private var focused: Bool

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: 8)]

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        searchField
                        if let browseCategory {
                            categoryHeader(browseCategory)
                            songList(categorySongs)
                        } else if query.trimmingCharacters(in: .whitespaces).isEmpty {
                            recentSection
                            categorySection
                        } else if isSearching {
                            LoadingStateView()
                        } else if !results.isEmpty {
                            resultHeader
                            songList(results)
                        } else if hasSearched {
                            EmptyStateView(icon: "magnifyingglass",
                                           text: "没有找到「\(query)」\n换个关键词，或直接按分类找")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Color.beansAmber)
                }
            }
        }
        .task(id: query) {
            await runSearch()
        }
        .onAppear { focused = true }
    }

    // MARK: 搜索框

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.beansComment)
            TextField("搜索歌名 / 上传者", text: $query)
                .focused($focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { focused = false }
            if !query.isEmpty {
                Button {
                    query = ""
                    browseCategory = nil
                    results = []
                    hasSearched = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.beansComment)
                }
                .buttonStyle(.plain)
            }
        }
        .font(BeansFont.appFont(15))
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background {
            BeansGlass(shape: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
    }

    // MARK: 最近搜索

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !history.history.isEmpty {
                HStack {
                    Text("最近搜索")
                        .font(BeansFont.appFont(15, .bold))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Button("清空") {
                        history.clear()
                        ToastCenter.shared.show("已清空搜索历史")
                    }
                    .font(BeansFont.appFont(12, .medium))
                    .foregroundStyle(Color.beansComment)
                    .buttonStyle(.plain)
                }
                FlowLayout(spacing: 8) {
                    ForEach(history.history, id: \.self) { word in
                        Button {
                            BeansHaptics.tap()
                            query = word
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 10, weight: .medium))
                                Text(word)
                                    .font(BeansFont.appFont(13, .medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(Color.beansLabel)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background { BeansGlass(shape: Capsule()) }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: 分类直达

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("按分类找")
                .font(BeansFont.appFont(15, .bold))
                .foregroundStyle(Color.beansLabel)
            Text("15 个频道，点一下直接浏览")
                .font(BeansFont.appFont(11))
                .foregroundStyle(Color.beansComment)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(DJddCategory.fallback, id: \.identifier) { category in
                    Button {
                        BeansHaptics.select()
                        query = ""
                        openCategory(category)
                    } label: {
                        Text(category.name)
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansLabel)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 12, style: .continuous)) }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func categoryHeader(_ category: DJddCategory) -> some View {
        HStack {
            Text(category.name)
                .font(BeansFont.appFont(19, .bold))
                .foregroundStyle(Color.beansLabel)
            Spacer()
            Button("返回分类") {
                browseCategory = nil
                categorySongs = []
            }
            .font(BeansFont.appFont(12, .medium))
            .foregroundStyle(Color.beansAmber)
            .buttonStyle(.plain)
        }
    }

    private var resultHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("结果 \(results.count)")
                .font(BeansFont.appFont(19, .bold))
                .foregroundStyle(Color.beansLabel)
            Text("标题 / 上传者命中 · 跨 6 个分类聚合")
                .font(BeansFont.appFont(11))
                .foregroundStyle(Color.beansComment)
        }
    }

    private func songList(_ songs: [Song]) -> some View {
        LazyVStack(spacing: 2) {
            ForEach(Array(songs.enumerated()), id: \.element.identityKey) { index, song in
                SongCell(song: song, playbackContext: songs, playbackIndex: index)
            }
        }
    }

    // MARK: 行为

    private func runSearch() async {
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty, browseCategory == nil else { return }
        isSearching = true
        hasSearched = true
        try? await Task.sleep(nanoseconds: 320_000_000)
        guard !Task.isCancelled else { return }
        let found = await DJduoduoAPI.shared.searchSongs(keyword: keyword)
        guard !Task.isCancelled else { return }
        results = found
        isSearching = false
        if !found.isEmpty { SearchHistoryStore.shared.record(keyword) }
    }

    private func openCategory(_ category: DJddCategory) {
        browseCategory = category
        focused = false
        categorySongs = []
        Task {
            if let page = try? await DJduoduoAPI.shared.songs(category: category, page: 0) {
                await MainActor.run { categorySongs = page.songs }
            }
        }
    }
}