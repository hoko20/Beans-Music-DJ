import SwiftUI
import UIKit

// MARK: - 播放页

/// 单平台播放页：程序化封面 + 节奏光环 + 四档音质。
struct PlayerView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    @ObservedObject private var favorites = FavoritesStore.shared
    @Binding var isPresented: Bool

    @State private var showQuality = false
    @State private var showQueue = false
    @State private var showSleep = false
    @State private var circularCover = UserDefaults.standard.bool(forKey: "beans.player.circularCover")
    @State private var dragOffset: CGFloat = 0

    private var song: Song? { player.currentSong }

    private var coverSide: CGFloat {
        min(UIScreen.main.bounds.width - 76, 360)
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 8)
                cover
                Spacer(minLength: 18)
                songInfo
                seekSection
                controls
                secondaryControls
                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .offset(y: dragOffset)
        .gesture(dismissGesture)
        .sheet(isPresented: $showQuality) {
            PlayerQualitySheet(song: song)
        }
        .sheet(isPresented: $showQueue) { QueueView() }
        .sheet(isPresented: $showSleep) { SleepTimerSheet() }
    }

    // MARK: 背景

    private var background: some View {
        let colors = CoverArt.colors(seed: song?.coverSeed ?? 0, colorScheme: .dark)
        return ZStack {
            LinearGradient(colors: [colors[0].opacity(0.55), Color.black, Color.black],
                           startPoint: .top, endPoint: .bottom)
            DJVisualView(accent: Color.beansAmber, secondary: colors[0],
                         isPlaying: player.isPlaying, intensity: 0.55)
            LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.55)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    // MARK: 顶栏

    private var topBar: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(.white.opacity(0.28))
                .frame(width: 44, height: 5)
                .padding(.top, 6)
            HStack {
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
                Spacer()
                VStack(spacing: 1) {
                    Text("正在播放")
                        .font(BeansFont.appFont(11, .medium))
                        .foregroundStyle(.white.opacity(0.55))
                    if let tag = song?.qualityTag {
                        Text("\(tag) · \(player.playbackQuality.title)")
                            .font(BeansFont.appFont(10, .semibold))
                            .foregroundStyle(Color.beansAmber)
                    }
                }
                Spacer()
                Button {
                    if let song {
                        let liked = favorites.toggle(song)
                        ToastCenter.shared.show(liked ? "已收藏" : "已取消收藏")
                    }
                } label: {
                    Image(systemName: favorites.isLiked(song) ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(favorites.isLiked(song) ? Color.beansAmber : .white.opacity(0.9))
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .contentShape(Rectangle())
    }

    // MARK: 封面

    private var cover: some View {
        SongCover(seed: song?.coverSeed ?? 0, size: coverSide, cornerRadius: circularCover ? coverSide / 2 : 30)
            .shadow(color: .black.opacity(0.45), radius: 30, y: 18)
            .scaleEffect(player.isPlaying ? 1 : 0.97)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: player.isPlaying)
            .overlay {
                if player.isBuffering {
                    ProgressView().tint(.white)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        guard abs(value.translation.height) > abs(value.translation.width) else { return }
                        if value.translation.height < -50 {
                            BeansHaptics.tap()
                            player.next()
                        } else if value.translation.height > 50 {
                            BeansHaptics.tap()
                            player.previous()
                        }
                    }
            )
            .contextMenu {
                Button {
                    circularCover.toggle()
                    UserDefaults.standard.set(circularCover, forKey: "beans.player.circularCover")
                } label: {
                    Label(circularCover ? "方形封面" : "圆形封面", systemImage: "circle.square")
                }
            }
    }

    // MARK: 歌曲信息

    private var songInfo: some View {
        VStack(spacing: 6) {
            Text(song?.name ?? "未在播放")
                .font(BeansFont.appFont(20, .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(song?.artists ?? "DJ多多")
                .font(BeansFont.appFont(13))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
            if player.loadFailed {
                Button("加载失败，点此重试") {
                    player.retryCurrent()
                }
                .font(BeansFont.appFont(12, .semibold))
                .foregroundStyle(Color.beansAmber)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: 进度

    private var seekSection: some View {
        VStack(spacing: 4) {
            SeekBar(progress: clock.progress,
                    duration: max(clock.duration, song?.duration ?? 0)) { seconds in
                player.seek(to: seconds)
            }
            HStack {
                Text(beansTimeString(clock.progress))
                Spacer()
                Text(beansTimeString(max(clock.duration, song?.duration ?? 0)))
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.top, 18)
    }

    // MARK: 主控制

    private var controls: some View {
        HStack(spacing: 26) {
            Button {
                player.togglePlayMode()
                BeansHaptics.select()
            } label: {
                Image(systemName: player.playMode.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .buttonStyle(.plain)

            Button {
                BeansHaptics.tap()
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button {
                BeansHaptics.medium()
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient.beansAccent)
                        .frame(width: 74, height: 74)
                        .shadow(color: Color.beansAmber.opacity(0.5), radius: 16, y: 6)
                    PlayPauseMorphIcon(isPlaying: player.isPlaying, size: 28)
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.95))

            Button {
                BeansHaptics.tap()
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 22)
    }

    // MARK: 次级控制

    private var secondaryControls: some View {
        HStack(spacing: 0) {
            secondaryButton(icon: "waveform", title: player.playbackQuality.title) {
                showQuality = true
            }
            secondaryButton(icon: "speedometer", title: rateText) {
                cycleRate()
            }
            secondaryButton(icon: "moon.zzz", title: player.sleepTimerFormatted ?? "定时") {
                showSleep = true
            }
            secondaryButton(icon: "arrow.down.circle", title: "下载") {
                if let song { DownloadStore.shared.download(song: song) }
            }
        }
        .padding(.top, 18)
    }

    private func secondaryButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(title)
                    .font(BeansFont.appFont(10, .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.75))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var rateText: String { Self.formatRate(player.rate) }

    private static func formatRate(_ value: Double) -> String {
        value == floor(value) ? String(format: "%.1fx", value) : "\(value)x"
    }

    private func cycleRate() {
        let rates: [Double] = [0.75, 1.0, 1.25, 1.5, 2.0]
        let index = rates.firstIndex(of: player.rate) ?? 1
        let next = rates[(index + 1) % rates.count]
        player.setRate(next)
        ToastCenter.shared.show("倍速 \(Self.formatRate(next))")
    }

    // MARK: 下拉关闭

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard value.startLocation.y < 90 else { return }
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { value in
                guard value.startLocation.y < 90 else {
                    dragOffset = 0
                    return
                }
                if value.translation.height > 110 {
                    isPresented = false
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

// MARK: - 进度条

struct SeekBar: View {
    let progress: Double
    let duration: Double
    let onSeek: (Double) -> Void

    @State private var dragProgress: Double?

    private var ratio: Double {
        guard duration > 0.01 else { return 0 }
        let value = dragProgress ?? progress
        return min(max(value / duration, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.18))
                Capsule()
                    .fill(LinearGradient(colors: [Color.beansAmber, Color.beansAmber.opacity(0.6)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(geo.size.width * ratio, 4))
            }
            .frame(height: 6)
            .contentShape(Rectangle().inset(by: -14))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0.01 else { return }
                        let x = min(max(value.location.x, 0), geo.size.width)
                        dragProgress = duration * Double(x / geo.size.width)
                    }
                    .onEnded { value in
                        guard duration > 0.01 else { return }
                        let x = min(max(value.location.x, 0), geo.size.width)
                        let target = duration * Double(x / geo.size.width)
                        dragProgress = nil
                        onSeek(target)
                    }
            )
        }
        .frame(height: 6)
    }
}

// MARK: - 音质与下载面板

struct PlayerQualitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var player: PlayerManager
    @ObservedObject private var downloads = DownloadStore.shared
    let song: Song?

    @State private var formats: [DJddFormat] = []
    @State private var loading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("音质与下载")
                        .font(BeansFont.appFont(19, .bold))
                        .foregroundStyle(Color.beansLabel)
                    Text("游客态 · 四档可用")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .font(BeansFont.appFont(13, .semibold))
                    .foregroundStyle(Color.beansAmber)
            }

            if let song {
                Text(song.name)
                    .font(BeansFont.appFont(13, .medium))
                    .foregroundStyle(Color.beansComment)
                    .lineLimit(1)
            }

            if loading {
                LoadingStateView()
            } else {
                ForEach(DJddQuality.allCases) { quality in
                    row(quality)
                }
            }

            Text("无损体积较大，建议在 Wi-Fi 下载。下载后可在「音乐库 → 已下载」找到。")
                .font(BeansFont.appFont(10))
                .foregroundStyle(Color.beansComment)
            Spacer(minLength: 0)
        }
        .padding(20)
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.visible)
        .task {
            guard let song else { loading = false; return }
            formats = (try? await DJduoduoAPI.shared.formats(song: song)) ?? []
            loading = false
        }
    }

    private func row(_ quality: DJddQuality) -> some View {
        let format = formats.first { $0.quality == quality.rawValue }
        let isCurrent = player.playbackQuality == quality
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(quality.title)
                        .font(BeansFont.appFont(15, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    if isCurrent {
                        Text("播放中")
                            .font(BeansFont.appFont(9, .bold))
                            .foregroundStyle(Color.beansAmber)
                    }
                }
                Text("\(format?.bitrateText ?? quality.bitrateText) · \(quality.container) · \(format?.sizeText ?? "体积未知")")
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
            }
            Spacer()
            Button {
                player.setPlaybackQuality(quality)
                ToastCenter.shared.show("已切换到 \(quality.title)")
            } label: {
                Text("播放")
                    .font(BeansFont.appFont(12, .semibold))
                    .foregroundStyle(isCurrent ? Color.beansComment : Color.beansLabel)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background { BeansGlass(shape: Capsule()) }
            }
            .buttonStyle(.plain)
            .disabled(isCurrent)

            Button {
                if let song { DownloadStore.shared.download(song: song, quality: quality) }
            } label: {
                let downloaded = song.map { downloads.track(for: $0)?.qualityRaw == quality.rawValue } ?? false
                Image(systemName: downloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.beansAmber)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .opacity(format == nil && !loading ? 0.45 : 1)
    }
}