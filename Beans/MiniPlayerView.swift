import SwiftUI

/// 底部迷你播放条：播放中常驻，点击展开播放页。
struct MiniPlayerView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    @Binding var showPlayer: Bool
    var compact = false
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    var body: some View {
        let _ = theme.accent
        Button {
            BeansHaptics.tap()
            showPlayer = true
        } label: {
            HStack(spacing: 11) {
                SongCover(seed: player.currentSong?.coverSeed ?? 0, size: 38, cornerRadius: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentSong?.name ?? "")
                        .font(BeansFont.appFont(13, .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        if let tag = player.currentSong?.qualityTag {
                            Text(tag)
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.beansAmber.opacity(0.85)))
                        }
                        Text(player.currentSong?.artists ?? "")
                            .font(BeansFont.appFont(10))
                            .foregroundStyle(Color.beansComment)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 4)
                Button {
                    BeansHaptics.tap()
                    player.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
                Button {
                    BeansHaptics.tap()
                    player.togglePlayPause()
                } label: {
                    PlayPauseMorphIcon(isPlaying: player.isPlaying, size: 16)
                        .foregroundStyle(Color.beansLabel)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
                Button {
                    BeansHaptics.tap()
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
            }
            .padding(.leading, 9)
            .padding(.trailing, 5)
            .padding(.vertical, 4)
            .background {
                if isNativeClean || compact {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.beansGlassFill.opacity(0.85))
                } else {
                    BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
            .overlay(alignment: .bottom) {
                ProgressLine(progress: clock.progress, duration: clock.duration)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 2)
                    .opacity(clock.duration > 0 ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(isNativeClean ? 0.08 : 0.16), radius: 12, y: 6)
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.98))
        .accessibilityLabel("打开播放页")
    }
}