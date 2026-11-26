import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var player: PlayerManager

    var body: some View {
        ZStack {
            GlassBackdrop()
            if player.history.isEmpty {
                EmptyStateView(icon: "clock.arrow.circlepath", text: "暂无播放历史")
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(player.history.enumerated()), id: \.element.identityKey) { index, song in
                            SongCell(song: song,
                                     playbackContext: player.history,
                                     playbackIndex: index)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)
                }
                .beansScrollIndicatorsHidden()
            }
        }
        .navigationTitle("最近播放")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !player.history.isEmpty {
                    Button("清空") { player.clearHistory() }
                }
            }
        }
    }
}