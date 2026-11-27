import SwiftUI

/// 底部迷你播放条：播放中常驻，点击信息区展开播放页。
/// 布局分为三层：封面 / 歌曲信息（可点开播放页）/ 控制区（上一首·播放·下一首）。
/// 各层各自独立的点击目标，外层的整卡点击不会误触底层列表。
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

    // 卡片统一高度：比原版更高，信息与控制区有充足呼吸空间
    private let cardHeight: CGFloat = 64
    private let corner: CGFloat = 20

    var body: some View {
        let _ = theme.accent
        ZStack(alignment: .bottom) {
            // 1) 卡片主体：独立背景 + contentShape，整块区域吸收点击，杜绝穿透到底层歌曲
            HStack(spacing: 12) {
                // 封面
                SongCover(seed: player.currentSong?.coverSeed ?? 0, size: 44, cornerRadius: 10)

                // 信息区：单独按钮，点击打开播放页
                Button {
                    openPlayer()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(player.currentSong?.name ?? "")
                            .font(BeansFont.appFont(14, .semibold))
                            .foregroundStyle(Color.beansLabel)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            if let tag = player.currentSong?.qualityTag {
                                Text(tag)
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.beansAmber.opacity(0.85)))
                            }
                            Text(player.currentSong?.artists ?? "")
                                .font(BeansFont.appFont(11))
                                .foregroundStyle(Color.beansComment)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // 控制区：带独立的底色，和信息区在视觉与点击上彻底分层
                HStack(spacing: 2) {
                    controlButton(icon: "backward.fill", size: 14) {
                        player.previous()
                    }
                    controlButton(isPlayPause: true) {
                        player.togglePlayPause()
                    }
                    controlButton(icon: "forward.fill", size: 14) {
                        player.next()
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 5)
                .background {
                    Capsule().fill(Color.beansLabel.opacity(isNativeClean ? 0.06 : 0.09))
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 7)
            .frame(height: cardHeight)
            .background {
                if isNativeClean || compact {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(Color.beansGlassFill.opacity(0.94))
                } else {
                    BeansGlass(shape: RoundedRectangle(cornerRadius: corner, style: .continuous))
                }
            }
            .overlay(alignment: .bottom) {
                ProgressLine(progress: clock.progress, duration: clock.duration)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 3)
                    .opacity(clock.duration > 0 ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .shadow(color: .black.opacity(isNativeClean ? 0.10 : 0.18), radius: 14, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .onTapGesture { openPlayer() }
            .accessibilityLabel("打开播放页")
        }
    }

    private func openPlayer() {
        BeansHaptics.tap()
        showPlayer = true
    }

    @ViewBuilder
    private func controlButton(icon: String? = nil, size: CGFloat = 14, isPlayPause: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            Group {
                if isPlayPause {
                    PlayPauseMorphIcon(isPlaying: player.isPlaying, size: 17)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: size, weight: .semibold))
                }
            }
            .foregroundStyle(Color.beansLabel)
            .frame(width: 38, height: 38)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
