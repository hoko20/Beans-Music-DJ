import SwiftUI
import UIKit

// MARK: - 主页（发现）

/// 15 分类 + 双列卡片 + 上拉分页。数据全部来自 DJ多多公开接口。
struct DiscoverView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var theme: ThemeStore

    @State private var categories: [DJddCategory] = DJddCategory.fallback
    @State private var selected: DJddCategory = DJddCategory.fallback[0]
    @State private var songs: [Song] = []
    @State private var page = 0
    @State private var hasMore = true
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSearch = false

    private var coverSide: CGFloat {
        let width = UIScreen.main.bounds.width
        return (width - 16 * 2 - 12) / 2
    }

    var body: some View {
        ZStack {
            GlassBackdrop(homeMode: true)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                    header
                    Section {
                        content
                    } header: {
                        categoryBar
                    }
                }
                .padding(.bottom, 92)
            }
            .beansScrollIndicatorsHidden()
            .refreshable { await reload() }
        }
        .task {
            if songs.isEmpty { await reload() }
        }
        .fullScreenCover(isPresented: $showSearch) {
            SearchView()
        }
    }

    // MARK: 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DJ多多")
                        .font(BeansFont.appFont(30, .bold))
                        .foregroundStyle(Color.beansLabel)
                    Text("歌曲 · 分类 · 音质来自 DJ多多公开接口")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer()
                Button {
                    BeansHaptics.tap()
                    showSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .frame(width: 42, height: 42)
                        .background { BeansGlass(shape: Circle()) }
                }
                .buttonStyle(GlassPressButtonStyle())
            }
            Button {
                BeansHaptics.tap()
                showSearch = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text("搜索歌名 / 上传者")
                    Spacer()
                }
                .font(BeansFont.appFont(14))
                .foregroundStyle(Color.beansComment)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: 分类

    private var categoryBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.identifier) { category in
                    let isSelected = category == selected
                    Button {
                        guard category != selected else { return }
                        BeansHaptics.select()
                        selected = category
                        Task { await reload() }
                    } label: {
                        Text(category.name)
                            .font(BeansFont.appFont(13, isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? .white : Color.beansLabel)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                if isSelected {
                                    Capsule().fill(LinearGradient.beansAccent)
                                } else {
                                    BeansGlass(shape: Capsule())
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.beansComment.opacity(0.10))
                        .frame(height: 0.5)
                }
        }
    }

    // MARK: 内容

    @ViewBuilder
    private var content: some View {
        if let errorMessage, songs.isEmpty {
            ErrorStateView(message: errorMessage) {
                Task { await reload() }
            }
            .padding(.horizontal, 16)
        } else if songs.isEmpty && isLoading {
            LoadingStateView()
        } else if songs.isEmpty {
            EmptyStateView(icon: "music.note.list", text: "这个分类暂时没有歌曲")
        } else {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 18
            ) {
                ForEach(Array(songs.enumerated()), id: \.element.identityKey) { index, song in
                    card(song: song, index: index)
                }
            }
            .padding(.horizontal, 16)

            footer
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            if isLoading {
                ProgressView().tint(Color.beansAmber)
            } else if hasMore {
                Text("上拉继续加载 · 每页 30 首")
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
            } else {
                Text("已经到底了")
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .onAppear {
            guard hasMore, !isLoading else { return }
            Task { await loadMore() }
        }
    }

    private func card(song: Song, index: Int) -> some View {
        let isCurrent = player.currentSong?.identityKey == song.identityKey
        return Button {
            BeansHaptics.tap()
            player.play(songs: songs, startAt: index)
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                SongCover(seed: song.coverSeed, size: coverSide, cornerRadius: 16)
                    .overlay {
                        if isCurrent {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.beansAmber, lineWidth: 2)
                        }
                    }
                    .shadow(color: isCurrent ? Color.beansAmber.opacity(0.45) : .clear,
                            radius: isCurrent ? 12 : 0)
                    .overlay(alignment: .topLeading) {
                        if let tag = song.qualityTag {
                            Text(tag)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(.black.opacity(0.35)))
                                .padding(8)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if isCurrent {
                            NowPlayingIndicator()
                                .padding(.horizontal, 7)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(.black.opacity(0.4)))
                                .padding(8)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        Text(song.formattedDuration)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.black.opacity(0.4)))
                            .padding(8)
                    }
                Text(song.name)
                    .font(BeansFont.appFont(13, isCurrent ? .semibold : .medium))
                    .foregroundStyle(isCurrent ? Color.beansAmber : Color.beansLabel)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 36, alignment: .top)
                HStack(spacing: 4) {
                    if isCurrent {
                        Circle()
                            .fill(Color.beansAmber)
                            .frame(width: 4, height: 4)
                        Text("播放中")
                            .font(BeansFont.appFont(10, .semibold))
                            .foregroundStyle(Color.beansAmber)
                    } else {
                        Text(song.artists.isEmpty ? "DJ多多" : song.artists)
                            .font(BeansFont.appFont(11))
                            .foregroundStyle(Color.beansComment)
                    }
                }
                .lineLimit(1)
            }
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.97))
        .contextMenu { menu(for: song) }
        .animation(.easeInOut(duration: 0.2), value: isCurrent)
    }

    @ViewBuilder
    private func menu(for song: Song) -> some View {
        Button {
            player.playNext(song)
        } label: {
            Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
        }
        Button {
            let liked = FavoritesStore.shared.toggle(song)
            ToastCenter.shared.show(liked ? "已收藏" : "已取消收藏")
        } label: {
            Label(FavoritesStore.shared.isLiked(song) ? "取消收藏" : "收藏",
                  systemImage: FavoritesStore.shared.isLiked(song) ? "heart.slash" : "heart")
        }
        Button {
            DownloadStore.shared.download(song: song)
        } label: {
            Label("下载（\(DJddQuality.downloadDefault.title)）", systemImage: "arrow.down.circle")
        }
    }

    // MARK: 数据

    private func reload() async {
        categories = await DJduoduoAPI.shared.categories()
        if !categories.contains(selected), let first = categories.first {
            selected = first
        }
        songs = []
        page = 0
        hasMore = true
        errorMessage = nil
        await loadMore()
    }

    private func loadMore() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await DJduoduoAPI.shared.songs(category: selected, page: page)
            if page == 0 {
                songs = result.songs
            } else {
                let existing = Set(songs.map(\.identityKey))
                songs.append(contentsOf: result.songs.filter { !existing.contains($0.identityKey) })
            }
            hasMore = result.hasMore
            page += 1
            errorMessage = nil
        } catch {
            if page == 0 {
                errorMessage = "加载失败：\(error.localizedDescription)"
            }
        }
    }
}