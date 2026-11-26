import Foundation
import UIKit
import CommonCrypto

// MARK: - DJ多多 4.3.7 协议加密（Python djdd_client.py 1:1 移植，实测确认）
//
// data / extra : AES-128-CBC + PKCS7
//   key = MD5("slf2yoDUOr3diocu")  iv = MD5("2mhamCk1helsrT")
// Path（音频文件名）: AES-128-CBC 单块
//   key = MD5("sdf2goDUOdjumogu")  iv = MD5("2ghlmCl1hblsqT")
// ★ 明文用 NSJSONSerialization(prettyPrinted) 风格：{"k" : v}，冒号两侧带空格
// ★ base64 后做 App 风格 URL 编码（+ / = 全部 %XX）
// ★ 不缓存 Sign：列表接口带 Sign 会被判非法返回 403「请升级」

private enum DJddCrypto {

    static func md5(_ text: String) -> [UInt8] {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        var input = Array(text.utf8)
        input.withUnsafeMutableBufferPointer { buf in
            _ = CC_MD5(buf.baseAddress, CC_LONG(buf.count), &digest)
        }
        return digest
    }

    static let apiKey = md5("slf2yoDUOr3diocu")
    static let apiIV = md5("2mhamCk1helsrT")
    static let mediaKey = md5("sdf2goDUOdjumogu")
    static let mediaIV = md5("2ghlmCl1hblsqT")

    static func aesEncrypt(_ plain: [UInt8], key: [UInt8], iv: [UInt8]) throws -> [UInt8] {
        try crypt(plain, key: key, iv: iv, operation: CCOperation(kCCEncrypt))
    }

    static func aesDecrypt(_ cipher: [UInt8], key: [UInt8], iv: [UInt8]) throws -> [UInt8] {
        try crypt(cipher, key: key, iv: iv, operation: CCOperation(kCCDecrypt))
    }

    private static func crypt(_ input: [UInt8], key: [UInt8], iv: [UInt8],
                              operation: CCOperation) throws -> [UInt8] {
        var keyBuf = key, ivBuf = iv, inBuf = input
        var outBuf = [UInt8](repeating: 0, count: input.count + kCCBlockSizeAES128)
        var outLen = 0
        let status = keyBuf.withUnsafeMutableBufferPointer { k in
            ivBuf.withUnsafeMutableBufferPointer { v in
                inBuf.withUnsafeMutableBufferPointer { src in
                    outBuf.withUnsafeMutableBufferPointer { dst in
                        CCCrypt(operation, CCAlgorithm(kCCAlgorithmAES),
                                CCOptions(kCCOptionPKCS7Padding),
                                k.baseAddress, k.count, v.baseAddress,
                                src.baseAddress, src.count,
                                dst.baseAddress, dst.count, &outLen)
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw DJddError.crypto(Int(status)) }
        return Array(outBuf.prefix(outLen))
    }

    /// NSJSONSerialization(prettyPrinted) 风格
    static func prettyJSON(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func encrypt(_ params: [String: Any]) throws -> String {
        let json = try prettyJSON(params)
        let cipher = try aesEncrypt(Array(json.utf8), key: apiKey, iv: apiIV)
        return Data(cipher).base64EncodedString()
    }

    /// App 风格 URL 编码：+ → %2B、/ → %2F、= → %3D，保留 -._~
    static func appURLEncode(_ text: String) -> String {
        var out = ""
        for byte in text.utf8 {
            let ch = Character(UnicodeScalar(byte))
            if ch.isLetter || ch.isNumber || "-._~".contains(ch) {
                out.append(ch)
            } else if ch == " " {
                out += "%20"
            } else {
                out += String(format: "%%%02X", byte)
            }
        }
        return out
    }

    /// Path(16B base64) → 音频文件名，如 "aylgqe.aac"
    static func decryptPath(_ pathB64: String) throws -> String {
        var s = pathB64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var cipher = Data(base64Encoded: s) else { throw DJddError.pathDecode }
        if cipher.count != 16,
           let tail = s.range(of: "[A-Za-z0-9+/]{22}==$", options: .regularExpression) {
            s = String(s[tail.lowerBound...])
            cipher = Data(base64Encoded: s) ?? Data()
        }
        guard cipher.count == 16 else { throw DJddError.pathSize(cipher.count) }
        let plain = try aesDecrypt(Array(cipher), key: mediaKey, iv: mediaIV)
        return String(bytes: plain, encoding: .utf8) ?? ""
    }
}

enum DJddError: LocalizedError {
    case crypto(Int)
    case pathDecode
    case pathSize(Int)
    case http(Int)
    case badJSON
    case noPlayableURL

    var errorDescription: String? {
        switch self {
        case .crypto(let s): return "AES 失败 (status \(s))"
        case .pathDecode: return "Path 不是合法 base64"
        case .pathSize(let n): return "Path 密文须 16 字节，实际 \(n)"
        case .http(let c): return "HTTP \(c)"
        case .badJSON: return "响应不是合法 JSON"
        case .noPlayableURL: return "无法解析播放地址"
        }
    }
}

// MARK: - DJ多多分类

struct DJddCategory: Identifiable, Hashable {
    let id: Int
    let name: String
    let act: String

    var identifier: String { "\(id)-\(act)-\(name)" }

    /// 实测 15 项（act=listtab, data={"PageNo":0,"type":"home"}）
    /// id=0 的项不带 Id，直接用 act 拉列表。
    static let fallback: [DJddCategory] = [
        DJddCategory(id: 0,   name: "最热",     act: "hot"),
        DJddCategory(id: 0,   name: "最新",     act: "new"),
        DJddCategory(id: 105, name: "电音",     act: "homechn"),
        DJddCategory(id: 0,   name: "无损专区", act: "sq"),
        DJddCategory(id: 104, name: "车载",     act: "homechn"),
        DJddCategory(id: 114, name: "粤语",     act: "homechn"),
        DJddCategory(id: 112, name: "彩铃",     act: "homechn"),
        DJddCategory(id: 113, name: "儿歌",     act: "homechn"),
        DJddCategory(id: 107, name: "中文",     act: "homechn"),
        DJddCategory(id: 110, name: "外文",     act: "homechn"),
        DJddCategory(id: 103, name: "伤感",     act: "homechn"),
        DJddCategory(id: 100, name: "3D",       act: "homechn"),
        DJddCategory(id: 101, name: "DJ",       act: "homechn"),
        DJddCategory(id: 115, name: "铃声",     act: "homechn"),
        DJddCategory(id: 108, name: "老歌",     act: "homechn"),
    ]

    /// 搜索聚合使用的 6 个分类（服务端 search 接口未开放）
    static var searchCategories: [DJddCategory] {
        Array(fallback.prefix(6))
    }
}

/// 一个音质档位（act=formats 响应 Formats[] 的一项）
struct DJddFormat: Identifiable, Hashable {
    let quality: Int
    let size: Int
    let bitrate: Int
    let path: String

    var id: Int { quality }

    var fileName: String {
        (try? DJddCrypto.decryptPath(path)) ?? ""
    }

    var tier: DJddQuality { DJddQuality(rawValue: quality) ?? .smooth }

    var sizeText: String {
        guard size > 0 else { return "体积未知" }
        let mb = Double(size) / 1_048_576
        return String(format: "%.1f MB", mb)
    }

    var bitrateText: String {
        bitrate > 0 ? "\(bitrate) kbps" : tier.bitrateText
    }

    var fileExtension: String {
        let ext = (fileName as NSString).pathExtension
        return ext.isEmpty ? "mp3" : ext
    }
}

// MARK: - DJ多多 API 单例

/// DJ多多 4.3.7 平台接入
///
/// 已破解并实测的接口：
/// - 分类 `act=listtab`，data={"PageNo":0,"type":"home"} → 首页 15 项
/// - 列表 `act=<分类Act>`，data={"PageNo":p,"Id":分类Id}，实测 RetCode=200 Count=30
/// - 音质 `act=formats`，data={"Id","Uid","OpenId","Status"} → Formats[]
///   ★ Uid=-1 游客态即可拿到四档
/// - 下载 `CDN/{前缀}/{Id%1000补3位}/{Path解密文件名}`
/// - 搜索 服务端 search 未开放，改为多分类聚合 + 本地过滤
final class DJduoduoAPI {

    static let shared = DJduoduoAPI()

    private let baseURL = "https://api.dianyinduoduo.com"
    private let apiPath = "/v4/getlist.php"

    /// config 下发实测值；备用节点 txcdn.djduoduo.com / hscdn.dianyinduoduo.com
    var cdnHost = "http://bdcdn.djduoduo.com"

    private let formatLock = NSLock()
    private var formatCache: [Int: [DJddFormat]] = [:]

    private init() {}

    // MARK: 通用请求

    private func extraFingerprint() -> [String: Any] {
        [
            "AppId": 121,
            "Language": "en-001",
            "OverSea": false,
            "Ts": Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 86400),
            "VerCode": 4371,
            "OSVer": UIDevice.current.systemVersion,
            "Channel": "App Store_CN",
            "TimeZone": TimeZone.current.identifier,
            "Did": "",
            "Platform": "iOS",
            "Ver": "4.3.7",
        ]
    }

    private func request(_ act: String, params: [String: Any]) async throws -> [String: Any] {
        // ★ 不注入 Sign：实测空 Sign 才稳定，缓存 Sign 会触发 403
        let dataB64 = try DJddCrypto.encrypt(params)
        let extraB64 = try DJddCrypto.encrypt(extraFingerprint())
        let query = "act=\(DJddCrypto.appURLEncode(act))"
            + "&data=\(DJddCrypto.appURLEncode(dataB64))"
            + "&extra=\(DJddCrypto.appURLEncode(extraB64))"
        guard let url = URL(string: baseURL + apiPath + "?" + query) else {
            throw DJddError.badJSON
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 20
        req.setValue("DJDuoduo/4.3.7 (iPhone; iOS 26.0; Scale/3.00)", forHTTPHeaderField: "User-Agent")
        req.setValue("*/*", forHTTPHeaderField: "Accept")
        req.setValue("zh-Hans,zh;q=0.9", forHTTPHeaderField: "Accept-Language")

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            throw DJddError.http(http.statusCode)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DJddError.badJSON
        }
        if let ret = json["RetCode"] as? NSNumber,
           ret.intValue != 200 && ret.intValue != 0 {
            let msg = json["RetMsg"] as? String ?? ""
            throw NSError(domain: "DJduoduoAPI", code: ret.intValue,
                          userInfo: [NSLocalizedDescriptionKey: "RetCode=\(ret.intValue) \(msg)"])
        }
        return json
    }

    // MARK: 接口 1：分类

    func categories() async -> [DJddCategory] {
        do {
            // ★ type="home" → 首页 15 分类；不带/type="ring" 只有彩铃 3 项
            let json = try await request("listtab", params: ["PageNo": 0, "type": "home"])
            let items = json["List"] as? [[String: Any]] ?? []
            let cats = items.compactMap { d -> DJddCategory? in
                let name = d["name"] as? String ?? d["Name"] as? String ?? ""
                guard !name.isEmpty else { return nil }
                return DJddCategory(
                    id: (d["Id"] as? NSNumber)?.intValue ?? 0,
                    name: name,
                    act: d["Act"] as? String ?? "homechn"
                )
            }
            return cats.isEmpty ? DJddCategory.fallback : cats
        } catch {
            return DJddCategory.fallback
        }
    }

    // MARK: 接口 2：列表

    func songs(category: DJddCategory, page: Int = 0) async throws -> DJddSongPage {
        // ★ id=0 的分类（最热/最新/无损专区）只传 act，不能带 Id=0
        var params: [String: Any] = ["PageNo": page]
        if category.id != 0 { params["Id"] = category.id }
        let json = try await request(category.act, params: params)
        let items = json["List"] as? [[String: Any]] ?? []
        let songs = items.compactMap { dict -> Song? in
            let songId = (dict["Id"] as? NSNumber)?.intValue ?? 0
            guard songId != 0 else { return nil }
            let name = dict["Name"] as? String ?? "未知歌曲"
            let durationSeconds = (dict["Duration"] as? NSNumber)?.doubleValue ?? 0
            return Song(
                id: songId,
                name: name,
                artists: dict["User"] as? String ?? "",
                duration: durationSeconds,
                path: dict["Path"] as? String ?? "",
                userId: (dict["UserId"] as? NSNumber)?.intValue ?? 0,
                maxQuality: (dict["MaxQ"] as? NSNumber)?.intValue ?? 2
            )
        }
        let hasMoreFlag = json["HasMore"] as? NSNumber
        let hasMore = hasMoreFlag?.intValue == 1
            || (hasMoreFlag == nil && songs.count >= 25)
        return DJddSongPage(songs: songs, hasMore: hasMore)
    }

    /// 首页默认推荐（最热）
    func recommendSongs(limit: Int = 30) async throws -> [Song] {
        let page = try await songs(category: DJddCategory.fallback[0], page: 0)
        return Array(page.songs.prefix(limit))
    }

    // MARK: 接口 3：音质

    /// 音质档位（act=formats，四参数缺一不可）
    /// ★★ Uid=-1 即游客态，四档全返回；Uid=0 会被判无效 → 401
    func formats(song: Song, uid: Int = -1, openId: String = "",
                 status: Int = 0) async throws -> [DJddFormat] {
        if let cached = cachedFormats(for: song.id) { return cached }
        let json = try await request("formats", params: [
            "Id": song.id,
            "Uid": uid,
            "OpenId": openId,
            "Status": status,
        ])
        // 响应结构：{ "Item": { "Id": ..., "Formats": [...] } }
        let item = json["Item"] as? [String: Any] ?? json
        let items = item["Formats"] as? [[String: Any]] ?? []
        let formats = items.map { d in
            DJddFormat(
                quality: (d["Quality"] as? NSNumber)?.intValue ?? 0,
                size: (d["Size"] as? NSNumber)?.intValue ?? 0,
                bitrate: (d["Bitrate"] as? NSNumber)?.intValue ?? 0,
                path: d["Path"] as? String ?? ""
            )
        }
        if !formats.isEmpty { storeFormats(formats, for: song.id) }
        return formats
    }

    private func cachedFormats(for songID: Int) -> [DJddFormat]? {
        formatLock.lock()
        defer { formatLock.unlock() }
        return formatCache[songID]
    }

    private func storeFormats(_ formats: [DJddFormat], for songID: Int) {
        formatLock.lock()
        formatCache[songID] = formats
        formatLock.unlock()
    }

    /// 指定档位的下载地址：host / 前缀 / (Id % 1000) / 解密文件名
    func downloadURL(format: DJddFormat, song: Song) -> String? {
        let fileName = format.fileName
        guard !fileName.isEmpty else { return nil }
        return "\(cdnHost)/\(format.tier.pathPrefix)/\(String(format: "%03d", song.id % 1000))/\(fileName)"
    }

    /// 默认档位地址（列表 Path 即高品文件名，走 dj 目录）
    func defaultURL(song: Song) -> String? {
        guard !song.path.isEmpty else { return nil }
        let fileName = (try? DJddCrypto.decryptPath(song.path)) ?? ""
        guard !fileName.isEmpty else { return nil }
        return "\(cdnHost)/dj/\(String(format: "%03d", song.id % 1000))/\(fileName)"
    }

    /// 播放地址：优先请求 formats 命中目标档位，失败时回退到列表 Path。
    func streamURL(song: Song, quality: DJddQuality) async -> URL? {
        if let formats = try? await formats(song: song), !formats.isEmpty {
            let picked = formats.first { $0.quality == quality.rawValue }
                ?? formats.filter { $0.quality <= quality.rawValue }.max { $0.quality < $1.quality }
                ?? formats.min { $0.quality < $1.quality }
            if let picked,
               let string = downloadURL(format: picked, song: song),
               let url = URL(string: string) {
                return url
            }
        }
        if let fallback = defaultURL(song: song) {
            return URL(string: fallback)
        }
        return nil
    }

    // MARK: 接口 4：搜索（多分类聚合 + 本地过滤）

    static func localSearch(_ songs: [Song], keyword: String) -> [Song] {
        let kw = keyword.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty else { return [] }
        return songs.filter {
            $0.name.localizedCaseInsensitiveContains(kw)
                || $0.artists.localizedCaseInsensitiveContains(kw)
        }
    }

    /// 搜索：并发拉取 6 个分类首页，按标题 / 上传者本地过滤并去重。
    func searchSongs(keyword: String,
                     categories: [DJddCategory] = DJddCategory.searchCategories,
                     limit: Int = 60) async -> [Song] {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else { return [] }
        var collected: [Song] = []
        await withTaskGroup(of: [Song].self) { group in
            for category in categories {
                group.addTask {
                    let page = try? await self.songs(category: category, page: 0)
                    return page?.songs ?? []
                }
            }
            for await list in group {
                collected.append(contentsOf: list)
            }
        }
        var seen = Set<String>()
        var result: [Song] = []
        for song in Self.localSearch(collected, keyword: kw) {
            guard !seen.contains(song.identityKey) else { continue }
            seen.insert(song.identityKey)
            result.append(song)
            if result.count >= limit { break }
        }
        return result
    }
}