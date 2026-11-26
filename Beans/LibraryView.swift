import SwiftUI

// MARK: - 音乐库

enum LibraryRoute: Hashable {
    case favorites
    case downloads
    case history
    case playlists
}

struct LibraryView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @ObservedObject private var favorites = FavoritesStore.shared
    @ObservedObject private var downloads = DownloadStore.shared
    @ObservedObject private var library = LocalLibraryStore.shared
    @State private var path: [LibraryRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                GlassBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("音乐库")
                            .font(BeansFont.appFont(30, .bold))
                            .foregroundStyle(Color.beansLabel)
                            .padding(.top, 8)

                        entryGrid

                        if !favorites.djduoduoFavoriteSongs.isEmpty {
                            recentFavorites
                        } else {
                            EmptyStateView(icon: "heart", text: "还没有收藏，去主页听听看")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationDestination(for: LibraryRoute.self) { route in
                switch route {
                case .favorites: FavoritesListView()
                case .downloads: DownloadCenterView()
                case .history: HistoryView()
                case .playlists: PlaylistsView()
                }
            }
        }
    }

    // MARK: 入口卡

    private var entryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                  spacing: 12) {
            entryCard(title: "红心收藏",
                      value: "\(favorites.djduoduoFavoriteSongs.count)",
                      detail: "首",
                      icon: "heart.fill",
                      tint: Color(red: 0.93, green: 0.35, blue: 0.45),
                      route: .favorites)
            entryCard(title: "已下载",
                      value: downloads.totalSizeText,
                      detail: "\(downloads.tracks.count) 首",
                      icon: "arrow.down.circle.fill",
                      tint: Color.beansSage,
                      route: .downloads)
            entryCard(title: "最近播放",
                      value: "\(player.history.count)",
                      detail: "首",
                      icon: "clock.arrow.circlepath",
                      tint: Color(red: 0.39, green: 0.71, blue: 0.96),
                      route: .history)
            entryCard(title: "我的歌单",
                      value: "\(library.playlists.count)",
                      detail: "个",
                      icon: "music.note.list",
                      tint: Color.beansAmber,
                      route: .playlists)
        }
    }

    private func entryCard(title: String, value: String, detail: String,
                           icon: String, tint: Color, route: LibraryRoute) -> some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(tint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.beansComment)
                }
                Text(title)
                    .font(BeansFont.appFont(12, .medium))
                    .foregroundStyle(Color.beansComment)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(BeansFont.appFont(22, .bold, .rounded))
                        .foregroundStyle(Color.beansLabel)
                    Text(detail)
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.98))
    }

    // MARK: 最近红心

    private var recentFavorites: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "最近红心", trailing: "全部 \(favorites.djduoduoFavoriteSongs.count)") {
                path.append(.favorites)
            }
            let recent = Array(favorites.djduoduoFavoriteSongs.prefix(5))
            VStack(spacing: 4) {
                ForEach(Array(recent.enumerated()), id: \.element.identityKey) { index, song in
                    SongCell(song: song,
                             playbackContext: favorites.djduoduoFavoriteSongs,
                             playbackIndex: index)
                }
            }
            Text("收藏、歌单均为本地数据，卸载即丢失，建议定期备份")
                .font(BeansFont.appFont(10))
                .foregroundStyle(Color.beansComment)
                .padding(.top, 4)
        }
    }
}

// MARK: - 红心收藏

struct FavoritesListView: View {
    @EnvironmentObject private var player: PlayerManager
    @ObservedObject private var favorites = FavoritesStore.shared

    var body: some View {
        ZStack {
            GlassBackdrop()
            if favorites.djduoduoFavoriteSongs.isEmpty {
                EmptyStateView(icon: "heart", text: "还没有收藏")
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(favorites.djduoduoFavoriteSongs.enumerated()),
                                id: \.element.identityKey) { index, song in
                            SongCell(song: song,
                                     playbackContext: favorites.djduoduoFavoriteSongs,
                                     playbackIndex: index)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        _ = favorites.toggle(song)
                                    } label: {
                                        Label("取消收藏", systemImage: "heart.slash")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .beansScrollIndicatorsHidden()
            }
        }
        .navigationTitle("红心收藏")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("播放全部") {
                    player.play(songs: favorites.djduoduoFavoriteSongs, startAt: 0)
                }
                .disabled(favorites.djduoduoFavoriteSongs.isEmpty)
            }
        }
    }
}

// MARK: - 下载中心

struct DownloadCenterView: View {
    @EnvironmentObject private var player: PlayerManager
    @ObservedObject private var downloads = DownloadStore.shared
    @State private var shareFile: ShareFileItem?

    private var freeSpaceText: String {
        let values = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        )
        let free = (values?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        return DownloadStore.formattedBytes(free)
    }

    var body: some View {
        ZStack {
            GlassBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summary
                    if !downloads.active.isEmpty {
                        activeSection
                    }
                    if downloads.tracks.isEmpty {
                        EmptyStateView(icon: "arrow.down.circle", text: "还没有下载，长按歌曲即可下载")
                    } else {
                        trackSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .beansScrollIndicatorsHidden()
        }
        .navigationTitle("下载中心")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !downloads.tracks.isEmpty {
                    Menu {
                        Button("清空下载", role: .destructive) {
                            downloads.deleteAll()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(item: $shareFile) { item in
            ShareSheet(items: [item.url])
        }
    }

    private var summary: some View {
        HStack(spacing: 16) {
            summaryItem(value: "\(downloads.tracks.count)", title: "首已下载")
            summaryItem(value: downloads.totalSizeText, title: "占用空间")
            summaryItem(value: freeSpaceText, title: "可用空间")
        }
        .padding(16)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous)) }
    }

    private func summaryItem(value: String, title: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(BeansFont.appFont(19, .bold, .rounded))
                .foregroundStyle(Color.beansLabel)
            Text(title)
                .font(BeansFont.appFont(10))
                .foregroundStyle(Color.beansComment)
        }
        .frame(maxWidth: .infinity)
    }

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("进行中")
                .font(BeansFont.appFont(15, .bold))
                .foregroundStyle(Color.beansLabel)
            ForEach(Array(downloads.active.values)) { progress in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(songName(for: progress.songID))
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansLabel)
                            .lineLimit(1)
                        ProgressView(value: progress.fraction)
                            .tint(Color.beansAmber)
                        Text("\(progress.quality.title) · \(Int(progress.fraction * 100))%")
                            .font(BeansFont.appFont(10))
                            .foregroundStyle(Color.beansComment)
                    }
                }
                .padding(12)
                .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
            }
        }
    }

    private var trackSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("已下载")
                .font(BeansFont.appFont(15, .bold))
                .foregroundStyle(Color.beansLabel)
            ForEach(Array(downloads.tracks.enumerated()), id: \.element.id) { index, track in
                HStack(spacing: 12) {
                    SongCover(seed: track.song.coverSeed, size: 44, cornerRadius: 9)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.song.name)
                            .font(BeansFont.appFont(14, .medium))
                            .foregroundStyle(Color.beansLabel)
                            .lineLimit(1)
                        Text("\(track.quality.title) · \(track.sizeText)")
                            .font(BeansFont.appFont(10))
                            .foregroundStyle(Color.beansComment)
                    }
                    Spacer()
                    Menu {
                        Button {
                            player.play(songs: downloads.tracks.map(\.song), startAt: index)
                        } label: {
                            Label("播放", systemImage: "play.fill")
                        }
                        Button {
                            if let url = downloads.exportURL(for: track) {
                                shareFile = ShareFileItem(url: url)
                            }
                        } label: {
                            Label("导出 / 分享", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive) {
                            downloads.delete(track)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(Color.beansComment)
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .onTapGesture {
                    player.play(songs: downloads.tracks.map(\.song), startAt: index)
                }
            }
        }
    }

    private func songName(for songID: String) -> String {
        downloads.active[songID]?.songName
            ?? downloads.tracks.first { $0.id == songID }?.song.name
            ?? "正在下载"
    }
}

// MARK: - 我的歌单

struct PlaylistsView: View {
    @ObservedObject private var library = LocalLibraryStore.shared
    @State private var newName = ""
    @State private var showCreate = false

    var body: some View {
        ZStack {
            GlassBackdrop()
            ScrollView {
                VStack(spacing: 10) {
                    if library.playlists.isEmpty {
                        EmptyStateView(icon: "music.note.list", text: "还没有歌单，点右上角新建")
                    }
                    ForEach(library.playlists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlistID: playlist.id)
                        } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(LinearGradient.beansAccent)
                                    .frame(width: 48, height: 48)
                                    .overlay {
                                        Image(systemName: "music.note.list")
                                            .foregroundStyle(.white)
                                    }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(playlist.name)
                                        .font(BeansFont.appFont(15, .semibold))
                                        .foregroundStyle(Color.beansLabel)
                                    Text(beansSongCountText(playlist.songs.count))
                                        .font(BeansFont.appFont(11))
                                        .foregroundStyle(Color.beansComment)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.beansComment)
                            }
                            .padding(12)
                            .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 16, style: .continuous)) }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                library.deletePlaylist(id: playlist.id)
                            } label: {
                                Label("删除歌单", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .beansScrollIndicatorsHidden()
        }
        .navigationTitle("我的歌单")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("新建歌单", isPresented: $showCreate) {
            TextField("歌单名称", text: $newName)
            Button("创建") {
                let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                library.createPlaylist(name: name)
                newName = ""
            }
            Button("取消", role: .cancel) { newName = "" }
        }
    }
}

struct PlaylistDetailView: View {
    @EnvironmentObject private var player: PlayerManager
    @ObservedObject private var library = LocalLibraryStore.shared
    let playlistID: UUID

    private var playlist: LocalPlaylist? {
        library.playlists.first { $0.id == playlistID }
    }

    var body: some View {
        ZStack {
            GlassBackdrop()
            if let playlist, !playlist.songs.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(playlist.songs.enumerated()), id: \.element.identityKey) { index, song in
                            SongCell(song: song,
                                     playbackContext: playlist.songs,
                                     playbackIndex: index)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        library.removeSong(playlistID: playlistID,
                                                           songIdentity: song.identityKey)
                                    } label: {
                                        Label("移出歌单", systemImage: "minus.circle")
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .beansScrollIndicatorsHidden()
            } else {
                EmptyStateView(icon: "music.note.list", text: "歌单还是空的")
            }
        }
        .navigationTitle(playlist?.name ?? "歌单")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("播放全部") {
                    guard let playlist else { return }
                    player.play(songs: playlist.songs, startAt: 0)
                }
                .disabled(playlist?.songs.isEmpty ?? true)
            }
        }
    }
}