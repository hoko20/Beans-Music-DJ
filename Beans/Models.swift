import Foundation

// MARK: - DJ多多音质档位

/// DJ多多四档音质：0 流畅 / 1 标准 / 2 高品 / 3 无损。
/// 档位同时决定 CDN 目录前缀（dj / dj_nq / dj_hq / dj_sq）。
enum DJddQuality: Int, CaseIterable, Identifiable, Sendable {
    case smooth = 0
    case standard = 1
    case high = 2
    case lossless = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .smooth: return "流畅"
        case .standard: return "标准"
        case .high: return "高品"
        case .lossless: return "无损"
        }
    }

    /// 列表卡片角标（列表接口 MaxQ 字段）
    var tag: String {
        switch self {
        case .smooth: return "LQ"
        case .standard: return "NQ"
        case .high: return "HQ"
        case .lossless: return "SQ"
        }
    }

    /// CDN 路径前缀
    var pathPrefix: String {
        switch self {
        case .smooth: return "dj"
        case .standard: return "dj_nq"
        case .high: return "dj_hq"
        case .lossless: return "dj_sq"
        }
    }

    var container: String {
        switch self {
        case .smooth, .standard: return "AAC"
        case .high: return "MP3"
        case .lossless: return "FLAC"
        }
    }

    var bitrateText: String {
        switch self {
        case .smooth: return "80 kbps"
        case .standard: return "128 kbps"
        case .high: return "320 kbps"
        case .lossless: return "1155 kbps"
        }
    }

    var summary: String { "\(bitrateText) · \(container)" }

    static let playbackKey = "beans.djdd.playbackQuality"
    static let downloadKey = "beans.djdd.downloadQuality"

    /// 默认播放音质（高品 320K）
    static var playbackDefault: DJddQuality {
        let raw = UserDefaults.standard.object(forKey: playbackKey) as? Int
        return raw.flatMap(DJddQuality.init(rawValue:)) ?? .high
    }

    /// 默认下载音质（高品 320K）
    static var downloadDefault: DJddQuality {
        let raw = UserDefaults.standard.object(forKey: downloadKey) as? Int
        return raw.flatMap(DJddQuality.init(rawValue:)) ?? .high
    }

    /// 从高到低的降级链
    var fallbackChain: [DJddQuality] {
        Array(DJddQuality.allCases.filter { $0.rawValue <= rawValue }.sorted { $0.rawValue > $1.rawValue })
    }
}

// MARK: - 歌曲

/// 歌曲（DJ多多单平台）。
struct Song: Identifiable, Hashable, Codable {
    let id: Int
    let name: String
    let artists: String
    let duration: TimeInterval
    /// DJ多多 Path（16 字节 base64 密文，运行时解密成音频文件名）
    let path: String
    /// 上传者 UserId
    let userId: Int
    /// 列表接口 MaxQ：该歌曲可用的最高音质档位
    let maxQuality: Int

    var identityKey: String { "djduoduo-\(id)" }

    var coverSeed: Int { id }

    var formattedDuration: String {
        let total = max(0, Int(duration))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    var maxQualityTier: DJddQuality? { DJddQuality(rawValue: maxQuality) }

    /// 卡片角标；未知档位时不显示
    var qualityTag: String? {
        guard maxQuality > 0 else { return nil }
        return DJddQuality(rawValue: maxQuality)?.tag
    }

    init(id: Int, name: String, artists: String, duration: TimeInterval,
         path: String, userId: Int, maxQuality: Int = 2) {
        self.id = id
        self.name = name
        self.artists = artists
        self.duration = duration
        self.path = path
        self.userId = userId
        self.maxQuality = maxQuality
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, artists, duration, path, maxQuality
        case legacyPath = "djduoduoPath"
        case userId
        case legacyUserId = "djduoduoUserId"
        case album, source, coverURL, fee
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        artists = try c.decodeIfPresent(String.self, forKey: .artists) ?? ""
        duration = try c.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        path = try c.decodeIfPresent(String.self, forKey: .path)
            ?? c.decodeIfPresent(String.self, forKey: .legacyPath)
            ?? ""
        userId = try c.decodeIfPresent(Int.self, forKey: .userId)
            ?? c.decodeIfPresent(Int.self, forKey: .legacyUserId)
            ?? 0
        maxQuality = try c.decodeIfPresent(Int.self, forKey: .maxQuality) ?? 2
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(artists, forKey: .artists)
        try c.encode(duration, forKey: .duration)
        try c.encode(path, forKey: .path)
        try c.encode(userId, forKey: .userId)
        try c.encode(maxQuality, forKey: .maxQuality)
    }
}

// MARK: - 分页

struct DJddSongPage {
    let songs: [Song]
    let hasMore: Bool
}