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

    var errorDescription: String? {
        switch self {
        case .crypto(let s): return "AES 失败 (status \(s))"
        case .pathDecode: return "Path 不是合法 base64"
        case .pathSize(let n): return "Path 密文须 16 字节，实际 \(n)"
        case .http(let c): return "HTTP \(c)"
        case .badJSON: return "响应不是合法 JSON"
        }
    }
}

// MARK: - DJ多多分类

struct DJddCategory: Identifiable, Hashable {
    let id: Int
    let name: String
    let act: String

    var identifier: String { "\(id)" }

    static let fallback: [DJddCategory] = [
        DJddCategory(id: 112, name: "最热", act: "homechn"),
        DJddCategory(id: 115, name: "最新", act: "homechn"),
        DJddCategory(id: 116, name: "彩铃", act: "homechn"),
    ]
}

// MARK: - DJ多多 API 单例

/// DJ多多 4.3.7 平台接入
///
/// 已破解并实测的接口：
/// - 分类 `act=listtab`，data={"PageNo":0}（★ 不能带 type，否则 Count=0）
/// - 列表 `act=<分类Act>`，data={"PageNo":p,"Id":分类Id}，实测 RetCode=200 Count=30
/// - 下载 `CDN_HOST/dj/{Id%1000补3位}/{Path解密文件名}`，实测 206 + ftyp mp42
/// - 封面 `CDN_HOST/v/cover/{Id%1000补3位}/{UserId}/{Cover}`（反汇编模板）
/// - 搜索 服务端 search act 参数未破解，用本地过滤兜底
/// - 歌词 服务端 lyric 是独立第五套密钥，已停止分析；本地 LRC 由 Beans 的 LyricParser 处理
final class DJduoduoAPI {

    static let shared = DJduoduoAPI()

    private let baseURL = "https://api.dianyinduoduo.com"
    private let apiPath = "/v4/getlist.php"

    /// config 下发实测值；备用节点 txcdn.djduoduo.com / hscdn.dianyinduoduo.com
    var cdnHost = "http://bdcdn.djduoduo.com"

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
            let json = try await request("listtab", params: ["PageNo": 0])
            let items = json["List"] as? [[String: Any]] ?? []
            let cats = items.map { d in
                DJddCategory(
                    id: (d["Id"] as? NSNumber)?.intValue ?? 0,
                    name: d["name"] as? String ?? d["Name"] as? String ?? "未命名",
                    act: d["Act"] as? String ?? "homechn"
                )
            }
            return cats.isEmpty ? DJddCategory.fallback : cats
        } catch {
            return DJddCategory.fallback
        }
    }

    // MARK: 接口 2：列表

    func songs(category: DJddCategory, page: Int = 0) async throws -> [Song] {
        let json = try await request(category.act, params: [
            "PageNo": page,
            "Id": category.id,
        ])
        let items = json["List"] as? [[String: Any]] ?? []
        return items.compactMap { dict in
            let songId = (dict["Id"] as? NSNumber)?.intValue ?? 0
            guard songId != 0 else { return nil }
            let name = dict["Name"] as? String ?? "未知歌曲"
            let path = dict["Path"] as? String ?? ""
            let cover = dict["Cover"] as? String ?? ""
            let userId = (dict["UserId"] as? NSNumber)?.intValue ?? 0
            let durationMs = (dict["Duration"] as? NSNumber)?.doubleValue ?? 0
            return Song(
                id: songId,
                name: name,
                artists: dict["User"] as? String ?? "",
                album: "DJ多多",
                coverURL: coverURL(songId: songId, userId: userId, cover: cover),
                duration: durationMs > 1000 ? durationMs / 1000 : durationMs,
                source: .djduoduo,
                djduoduoPath: path,
                djduoduoUserId: userId
            )
        }
    }

    /// 首页默认推荐（最热）
    func recommendSongs(limit: Int = 30) async throws -> [Song] {
        try await songs(category: DJddCategory.fallback[0], page: 0)
    }

    // MARK: 接口 3：下载 / 封面 URL（反汇编 0x100065834：`%@/%@/%03d/%@`）

    func downloadURL(song: Song) -> String? {
        let path = song.djduoduoPath ?? ""
        if path.hasPrefix("http://") || path.hasPrefix("https://") { return path }
        let fileName = (try? DJddCrypto.decryptPath(path)) ?? ""
        guard !fileName.isEmpty else { return nil }
        return "\(cdnHost)/dj/\(String(format: "%03d", song.id % 1000))/\(fileName)"
    }

    func downloadURL(songID: Int, path: String) -> String? {
        let fileName = (try? DJddCrypto.decryptPath(path)) ?? ""
        guard !fileName.isEmpty else { return nil }
        return "\(cdnHost)/dj/\(String(format: "%03d", songID % 1000))/\(fileName)"
    }

    private func coverURL(songId: Int, userId: Int, cover: String) -> URL? {
        guard !cover.isEmpty else { return nil }
        if cover.hasPrefix("http") { return URL(string: cover) }
        return URL(string: "\(cdnHost)/v/cover/\(String(format: "%03d", songId % 1000))/\(userId)/\(cover)")
    }

    // MARK: 接口 4：搜索（本地过滤服务端已加载列表）

    static func localSearch(_ songs: [Song], keyword: String) -> [Song] {
        let kw = keyword.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty else { return songs }
        return songs.filter {
            $0.name.localizedCaseInsensitiveContains(kw)
                || $0.artists.localizedCaseInsensitiveContains(kw)
        }
    }

    /// 搜索页调用：拉最热/最新/彩铃三分类后本地过滤
    func searchSongs(keyword: String, limit: Int = 30) async throws -> [Song] {
        var all: [Song] = []
        for cat in DJddCategory.fallback {
            if let list = try? await songs(category: cat, page: 0) {
                all.append(contentsOf: list)
            }
            if all.count >= limit { break }
        }
        return Array(Self.localSearch(all, keyword: keyword).prefix(limit))
    }

    /// 歌词：服务端是独立密钥链路，已停止分析；返回空串交给 Beans 的 LyricParser
    func lyric(song: Song) -> String { "" }
}
