import Combine
import Foundation

/// 收藏管理（红心）：DJ多多本地持久化，无云端接口。
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    /// DJ多多红心收藏（本地持久化）
    @Published private(set) var djduoduoFavoriteSongs: [Song] = []

    private let defaults = UserDefaults.standard
    private let djduoduoKey = "beans.fav.djduoduo.v1"

    private init() {
        djduoduoFavoriteSongs = Self.loadSongs(djduoduoKey)
    }

    /// 该歌曲是否已收藏
    func isLiked(_ song: Song?) -> Bool {
        guard let song else { return false }
        return djduoduoFavoriteSongs.contains { $0.identityKey == song.identityKey }
    }

    /// 切换收藏状态（本地持久化，无云端同步）
    @discardableResult
    func toggle(_ song: Song) -> Bool {
        let liked = !isLiked(song)
        updateDJduoduo(song, liked: liked)
        return liked
    }

    /// 用备份数据整体替换收藏（配置恢复用）
    func replaceAll(_ songs: [Song]) {
        djduoduoFavoriteSongs = songs
        saveSongs(songs, key: djduoduoKey)
    }

    private func updateDJduoduo(_ song: Song, liked: Bool) {
        if liked {
            djduoduoFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
            djduoduoFavoriteSongs.insert(song, at: 0)
        } else {
            djduoduoFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
        }
        saveSongs(djduoduoFavoriteSongs, key: djduoduoKey)
    }

    private static func loadSongs(_ key: String) -> [Song] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([Song].self, from: data) else { return [] }
        return saved
    }

    private func saveSongs(_ songs: [Song], key: String) {
        if let data = try? JSONEncoder().encode(songs) {
            defaults.set(data, forKey: key)
        }
    }
}
