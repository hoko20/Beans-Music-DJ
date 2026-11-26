import SwiftUI

/// 列表歌曲行（音乐库 / 历史 / 搜索结果通用）
struct SongCell: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @ObservedObject private var favorites = FavoritesStore.shared
    @ObservedObject private var downloads = DownloadStore.shared
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue

    let song: Song
    var showCover = true
    var playbackContext: [Song] = []
    var playbackIndex: Int?
    var onTap: (() -> Void)?

    @State private var showAddToPlaylist = false
    @State private var showQualityPicker = false

    private var isCurrent: Bool {
        player.currentSong?.identityKey == song.identityKey
    }

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            if showCover {
                SongCover(seed: song.coverSeed, size: 46, cornerRadius: 10)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(song.name)
                        .font(BeansFont.appFont(15, isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? Color.beansAmber : Color.beansLabel)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let tag = song.qualityTag {
                        Text(tag)
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.beansAmber.opacity(0.8)))
                    }
                }
                Text(song.artists.isEmpty ? "DJ多多" : song.artists)
                    .font(BeansFont.appFont(12))
                    .foregroundStyle(Color.beansComment)
                    .lineLimit(1)
                    .truncationMode(.tail)
                if downloads.isDownloaded(song) {
                    Text("已下载")
                        .font(BeansFont.appFont(10, .medium))
                        .foregroundStyle(Color.beansSage)
                }
            }
            Spacer(minLength: 0)
            if isCurrent && player.isPlaying {
                NowPlayingIndicator()
            } else {
                Text(song.formattedDuration)
                    .font(BeansFont.appFont(12, .regular, .monospaced))
                    .foregroundStyle(Color.beansComment)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            if let onTap {
                onTap()
            } else {
                play()
            }
        }
        .contextMenu {
            Button {
                play()
            } label: {
                Label("立即播放", systemImage: "play.fill")
            }
            Button {
                player.playNext(song)
            } label: {
                Label("下一首播放", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            Button {
                let liked = favorites.toggle(song)
                ToastCenter.shared.show(liked ? "已收藏" : "已取消收藏")
            } label: {
                Label(favorites.isLiked(song) ? "取消收藏" : "收藏", systemImage: favorites.isLiked(song) ? "heart.slash" : "heart")
            }
            Button {
                showAddToPlaylist = true
            } label: {
                Label("添加到歌单", systemImage: "text.badge.plus")
            }
            Button {
                showQualityPicker = true
            } label: {
                Label("下载", systemImage: "arrow.down.circle")
            }
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToLocalPlaylistSheet(song: song)
        }
        .sheet(isPresented: $showQualityPicker) {
            DownloadQualitySheet(song: song)
        }
    }

    private func play() {
        if let index = playbackIndex, playbackContext.indices.contains(index) {
            player.play(songs: playbackContext, startAt: index)
        } else if let index = player.queue.firstIndex(where: { $0.identityKey == song.identityKey }) {
            player.playQueueIndex(index)
        } else {
            player.play(songs: [song], startAt: 0)
        }
    }

    var body: some View {
        let _ = theme.accent
        rowContent
            .padding(.horizontal, isNativeClean ? 10 : 0)
            .background {
                if isNativeClean {
                    BeansGlass(shape: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
    }
}

// MARK: - 下载音质选择

struct DownloadQualitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeStore
    let song: Song

    var body: some View {
        let _ = theme.accent
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                SongCover(seed: song.coverSeed, size: 46, cornerRadius: 10)
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.name)
                        .font(BeansFont.appFont(16, .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(1)
                    Text("选择下载音质")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer()
            }
            ForEach(DJddQuality.allCases) { quality in
                Button {
                    DownloadStore.shared.download(song: song, quality: quality)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(quality.title)
                                .font(BeansFont.appFont(15, .medium))
                                .foregroundStyle(Color.beansLabel)
                            Text(quality.summary)
                                .font(BeansFont.appFont(11))
                                .foregroundStyle(Color.beansComment)
                        }
                        Spacer()
                        if quality == DJddQuality.downloadDefault {
                            Text("默认")
                                .font(BeansFont.appFont(10, .semibold))
                                .foregroundStyle(Color.beansAmber)
                        }
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color.beansAmber)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }
}
