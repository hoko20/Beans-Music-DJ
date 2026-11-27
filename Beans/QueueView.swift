import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let _ = theme.accent
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                if player.queue.isEmpty {
                    EmptyStateView(icon: "music.note.list", text: "播放队列为空")
                } else {
                    List {
                        Section {
                            ForEach(Array(player.queue.enumerated()), id: \.element.identityKey) { index, song in
                                row(song, index: index)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                            }
                            .onDelete { offsets in
                                let indices = offsets.map { $0 }
                                for index in indices.sorted(by: >) where player.queue.indices.contains(index) {
                                    player.removeFromQueue(at: index)
                                }
                            }
                        } header: {
                            Text(String(format: NSLocalizedString("接下来 (%d 首)", comment: ""), player.queue.count))
                                .font(BeansFont.appFont(11, .semibold))
                                .foregroundStyle(Color.beansComment)
                        }
                    }
                    .beansScrollContentBackgroundHidden()
                    .listStyle(.plain)
                    .listRowSpacing(2)
                    .environment(\.defaultMinListRowHeight, 52)
                }
            }
            .navigationTitle("播放队列")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            player.clearQueue()
                        } label: {
                            Label("清空队列", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .background {
            HighRefreshConfigurator()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func row(_ song: Song, index: Int) -> some View {
        let isCurrent = index == player.currentIndex
        HStack(spacing: 10) {
            SongCover(seed: song.coverSeed, size: 38, cornerRadius: 9)
            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .font(BeansFont.appFont(14, isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? Color.beansAmber : Color.beansLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                Text(song.artists)
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            if isCurrent {
                if player.isPlaying {
                    NowPlayingIndicator()
                } else {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.beansAmber)
                }
            } else {
                Text(song.formattedDuration)
                    .font(BeansFont.appFont(12, .regular, .monospaced))
                    .foregroundStyle(Color.beansComment)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .background {
            BeansGlass(shape: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .onTapGesture {
            if player.queue.indices.contains(index) {
                player.playQueueIndex(index)
            }
        }
    }
}
