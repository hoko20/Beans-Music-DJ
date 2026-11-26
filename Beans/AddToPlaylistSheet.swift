import SwiftUI

/// 把歌曲加入本地歌单
struct AddToLocalPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var library = LocalLibraryStore.shared
    let song: Song

    @State private var newName = ""
    @State private var showCreate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                SongCover(seed: song.coverSeed, size: 44, cornerRadius: 10)
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.name)
                        .font(BeansFont.appFont(16, .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(1)
                    Text("添加到本地歌单")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer()
            }

            if library.playlists.isEmpty && !showCreate {
                EmptyStateView(icon: "music.note.list", text: "还没有歌单，先建一个吧")
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(library.playlists) { playlist in
                        Button {
                            library.addSong(song, to: playlist.id)
                            ToastCenter.shared.show("已加入「\(playlist.name)」")
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(LinearGradient.beansAccent)
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.name)
                                        .font(BeansFont.appFont(15))
                                        .foregroundStyle(Color.beansLabel)
                                    Text(beansSongCountText(playlist.songs.count))
                                        .font(BeansFont.appFont(11))
                                        .foregroundStyle(Color.beansComment)
                                }
                                Spacer()
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.beansAmber)
                            }
                            .padding(10)
                            .background {
                                BeansGlass(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if showCreate {
                HStack(spacing: 8) {
                    TextField("歌单名称", text: $newName)
                        .textFieldStyle(.roundedBorder)
                    Button("创建") {
                        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        let playlist = library.createPlaylist(name: name)
                        library.addSong(song, to: playlist.id)
                        ToastCenter.shared.show("已创建「\(name)」并加入")
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.beansAmber)
                }
            } else {
                Button {
                    showCreate = true
                } label: {
                    Label("新建歌单", systemImage: "plus.circle")
                        .font(BeansFont.appFont(15, .medium))
                        .foregroundStyle(Color.beansAmber)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}