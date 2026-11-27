import SwiftUI
import UIKit

// MARK: - 播放页

/// 单平台播放页：程序化封面 + 节奏光环 + 四档音质。
struct PlayerView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    @ObservedObject private var favorites = FavoritesStore.shared
    @ObservedObject private var downloads = DownloadStore.shared
    @Binding var isPresented: Bool

    @State private var showQuality = false
    @State private var showQueue = false
    @State private var showSleep = false
    @State private var circularCover = UserDefaults.standard.bool(forKey: "beans.player.circularCover")
    @State private var dragOffset: CGFloat = 0
    @State private var scrubPreview: Double?

    private var song: Song? { player.currentSong }

    private var totalDuration: Double {
        max(clock.duration, song?.duration ?? 0)
    }

    /// 下拉关闭进度 0…1
    private var dismissProgress: CGFloat {
        min(max(dragOffset / 380, 0), 1)
    }

    private var coverSide: CGFloat {
        min(UIScreen.main.bounds.width - 76, 360)
    }

    var body: some View {
        ZStack {
            background
                .opacity(1 - Double(dismissProgress))
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
            .scaleEffect(1 - 0.03 * dismissProgress)
        }
        .offset(y: dragOffset)
        .gesture(dismissGesture)
        .presentationBackground(.clear)
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
            Color.black
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
        VStack(spacing: 7) {
            ZStack {
                if let scrubPreview {
                    Text(beansTimeString(scrubPreview))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.beansAmber))
                        .transition(.opacity)
                }
            }
            .frame(height: 18)
            .animation(.easeOut(duration: 0.12), value: scrubPreview != nil)

            SeekBar(progress: clock.progress,
                    duration: totalDuration,
                    onScrub: { value in scrubPreview = value },
                    onSeek: { seconds in
                        player.seek(to: seconds)
                        scrubPreview = nil
                    })
            HStack {
                Text(beansTimeString(scrubPreview ?? clock.progress))
                    .foregroundStyle(scrubPreview == nil ? .white.opacity(0.5) : Color.beansAmber)
                Spacer()
                Text(beansTimeString(totalDuration))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .padding(.top, 24)
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
        .padding(.top, 32)
    }

    // MARK: 次级控制

    /// 音质切换与下载共用同一个面板：入口只保留一个，避免两处逻辑各自为政。
    private var secondaryControls: some View {
        HStack(spacing: 0) {
            secondaryButton(icon: "waveform.circle", title: qualityDownloadTitle) {
                showQuality = true
            }
            secondaryButton(icon: "speedometer", title: rateText) {
                cycleRate()
            }
            secondaryButton(icon: "moon.zzz", title: player.sleepTimerFormatted ?? "定时") {
                showSleep = true
            }
        }
        .padding(.top, 26)
    }

    private var qualityDownloadTitle: String {
        guard let song else { return "音质 · 下载" }
        if downloads.progress(for: song) != nil { return "下载中…" }
        return downloads.isDownloaded(song) ? "音质 · 已下载" : "音质 · 下载"
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
    var onScrub: ((Double?) -> Void)? = nil
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
            .frame(height: dragProgress == nil ? 6 : 8)
            .animation(.easeOut(duration: 0.15), value: dragProgress == nil)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(.white)
                    .frame(width: dragProgress == nil ? 11 : 15,
                           height: dragProgress == nil ? 11 : 15)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .offset(x: max(0, geo.size.width * ratio - (dragProgress == nil ? 5.5 : 7.5)))
                    .animation(.easeOut(duration: 0.15), value: dragProgress == nil)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle().inset(by: -16))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard duration > 0.01 else { return }
                        let x = min(max(value.location.x, 0), geo.size.width)
                        let target = duration * Double(x / geo.size.width)
                        dragProgress = target
                        onScrub?(target)
                    }
                    .onEnded { value in
                        guard duration > 0.01 else { return }
                        let x = min(max(value.location.x, 0), geo.size.width)
                        let target = duration * Double(x / geo.size.width)
                        dragProgress = nil
                        onScrub?(nil)
                        onSeek(target)
                    }
            )
        }
        .frame(height: 18)
    }
}

// MARK: - 音质与下载面板

/// 音质切换与下载合并为一个面板：一行一个档位，左侧选播放、右侧下载。
struct PlayerQualitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var player: PlayerManager
    @ObservedObject private var downloads = DownloadStore.shared
    let song: Song?

    @State private var formats: [DJddFormat] = []
    @State private var loading = true
    @State private var loadFailed = false
    @State private var loadToken = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("音质与下载")
                        .font(BeansFont.appFont(19, .bold))
                        .foregroundStyle(Color.beansLabel)
                    Text("选择播放档位，或直接下载到本机 · 游客态四档可用")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer()
                Button("关闭") { dismiss() }
                    .font(BeansFont.appFont(13, .semibold))
                    .foregroundStyle(Color.beansAmber)
            }

            if let song {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.system(size: 11))
                    Text(song.name)
                        .lineLimit(1)
                }
                .font(BeansFont.appFont(12, .medium))
                .foregroundStyle(Color.beansComment)
            }

            if loading {
                LoadingStateView()
                Spacer(minLength: 0)
            } else if loadFailed {
                VStack(spacing: 12) {
                    Text("音质信息加载失败")
                        .font(BeansFont.appFont(14, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Button {
                        Task { await loadFormats() }
                    } label: {
                        Label("重试", systemImage: "arrow.clockwise")
                            .font(BeansFont.appFont(12, .semibold))
                            .foregroundStyle(Color.beansAmber)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
                Spacer(minLength: 0)
            } else {
                VStack(spacing: 2) {
                    ForEach(DJddQuality.allCases) { row($0) }
                }
                Spacer(minLength: 0)
            }

            Text("下载后可在「音乐库 → 已下载」找到。切换播放档位会从当前进度重新加载。")
                .font(BeansFont.appFont(10))
                .foregroundStyle(Color.beansComment)
        }
        .padding(20)
        .presentationDetents([.height(470), .large])
        .presentationDragIndicator(.visible)
        .task { await loadFormats() }
    }

    private func loadFormats() async {
        guard let song else { loading = false; return }
        let token = loadToken + 1
        loadToken = token
        loading = true
        loadFailed = false
        do {
            let result = try await DJduoduoAPI.shared.formats(song: song)
            guard token == loadToken else { return }
            formats = result
            loading = false
        } catch {
            guard token == loadToken else { return }
            loadFailed = true
            loading = false
        }
    }

    private func row(_ quality: DJddQuality) -> some View {
        let format = formats.first { $0.quality == quality.rawValue }
        let isCurrent = player.playbackQuality == quality
        let progress = song.flatMap { downloads.progress(for: $0) }
        let isDownloading = progress?.quality == quality
        let isDownloaded = song.map {
            downloads.isDownloaded($0) && downloads.track(for: $0)?.qualityRaw == quality.rawValue
        } ?? false
        let available = format != nil

        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(quality.title)
                        .font(BeansFont.appFont(14, .semibold))
                        .foregroundStyle(available ? Color.beansLabel : Color.beansComment)
                    if isCurrent {
                        Text("播放中")
                            .font(BeansFont.appFont(9, .bold))
                            .foregroundStyle(Color.beansAmber)
                    }
                    if isDownloaded {
                        Text("已下载")
                            .font(BeansFont.appFont(9, .bold))
                            .foregroundStyle(Color.beansSage)
                    }
                }
                Text("\(format?.bitrateText ?? quality.bitrateText) · \(quality.container) · \(format?.sizeText ?? "不可用")")
                    .font(BeansFont.appFont(10))
                    .foregroundStyle(Color.beansComment)
                if isDownloading {
                    ProgressView(value: progress?.fraction ?? 0)
                        .tint(Color.beansAmber)
                        .frame(height: 3)
                }
            }
            Spacer(minLength: 4)

            Button {
                guard available else { return }
                player.setPlaybackQuality(quality)
                ToastCenter.shared.show("已切换到 \(quality.title)")
            } label: {
                Text(isCurrent ? "播放中" : "播放")
                    .font(BeansFont.appFont(11, .semibold))
                    .foregroundStyle(isCurrent ? Color.beansComment : Color.beansLabel)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background { BeansGlass(shape: Capsule()) }
            }
            .buttonStyle(.plain)
            .disabled(isCurrent || !available)

            Button {
                guard let song, available else { return }
                downloads.download(song: song, quality: quality)
            } label: {
                Group {
                    if isDownloading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color.beansAmber)
                            .frame(width: 18, height: 18)
                    } else {
                        Image(systemName: isDownloaded ? "checkmark.circle.fill" : "arrow.down.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(isDownloaded ? Color.beansSage : Color.beansAmber)
                    }
                }
                .frame(width: 24)
            }
            .buttonStyle(.plain)
            .disabled(!available || isDownloaded || progress != nil)
        }
        .padding(.vertical, 7)
        .opacity(available ? 1 : 0.5)
    }
}