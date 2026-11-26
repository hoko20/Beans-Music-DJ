import Combine
import Foundation
import UIKit

// MARK: - 下载中心

/// 一首已下载的歌曲（文件保存在「文件」App 的 Beans/BeansDownloads 目录）
struct DownloadedTrack: Identifiable, Codable, Hashable {
    let song: Song
    let qualityRaw: Int
    let fileName: String
    let byteCount: Int64
    let addedAt: Date

    var id: String { song.identityKey }

    var quality: DJddQuality { DJddQuality(rawValue: qualityRaw) ?? .high }

    var fileURL: URL {
        DownloadStore.directory.appendingPathComponent(fileName)
    }

    var sizeText: String { DownloadStore.formattedBytes(byteCount) }
}

/// 进行中的下载
struct DownloadProgress: Identifiable, Equatable {
    let songID: String
    let songName: String
    var received: Int64
    var expected: Int64
    var quality: DJddQuality

    var id: String { songID }

    var fraction: Double {
        guard expected > 0 else { return 0 }
        return min(max(Double(received) / Double(expected), 0), 1)
    }
}

enum DownloadError: LocalizedError {
    case noURL
    case http(Int)
    case notAudio
    case saveFailed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .noURL: return "无法解析下载地址"
        case .http(let code): return "下载失败（HTTP \(code)）"
        case .notAudio: return "返回内容不是有效音频"
        case .saveFailed(let msg): return "保存失败：\(msg)"
        case .unknown(let msg): return msg
        }
    }
}

/// 下载中心：下载四档音质到本机、进度、删除与体积统计。
/// 下载完成后播放器优先播放本地文件，离线也能听。
final class DownloadStore: NSObject, ObservableObject {
    static let shared = DownloadStore()

    @Published private(set) var tracks: [DownloadedTrack] = []
    @Published private(set) var active: [String: DownloadProgress] = [:]
    @Published var lastError: String?

    private let tracksKey = "beans.downloads.tracks.v1"
    private var taskMeta: [Int: (song: Song, quality: DJddQuality)] = [:]
    private var session: URLSession!

    private override init() {
        super.init()
        loadTracks()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60 * 30
        let queue = OperationQueue.main
        queue.maxConcurrentOperationCount = 1
        session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
    }

    // MARK: 目录

    static var directory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BeansDownloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func formattedBytes(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 MB" }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1024 { return String(format: "%.1f GB", mb / 1024) }
        return String(format: "%.1f MB", mb)
    }

    var totalBytes: Int64 { tracks.reduce(0) { $0 + $1.byteCount } }

    var totalSizeText: String { Self.formattedBytes(totalBytes) }

    // MARK: 查询

    func track(for song: Song) -> DownloadedTrack? {
        tracks.first { $0.song.identityKey == song.identityKey }
    }

    func isDownloaded(_ song: Song) -> Bool {
        guard let track = track(for: song) else { return false }
        return FileManager.default.fileExists(atPath: track.fileURL.path)
    }

    func localURL(for song: Song) -> URL? {
        guard let track = track(for: song),
              FileManager.default.fileExists(atPath: track.fileURL.path) else { return nil }
        return track.fileURL
    }

    func progress(for song: Song) -> DownloadProgress? {
        active[song.identityKey]
    }

    // MARK: 下载

    func download(song: Song, quality: DJddQuality? = nil) {
        let wanted = quality ?? DJddQuality.downloadDefault
        guard active[song.identityKey] == nil else { return }
        if isDownloaded(song), track(for: song)?.qualityRaw == wanted.rawValue {
            toast("已在下载中心：\(song.name)")
            return
        }
        active[song.identityKey] = DownloadProgress(
            songID: song.identityKey,
            songName: song.name,
            received: 0,
            expected: 0,
            quality: wanted
        )
        Task { [weak self] in
            guard let self else { return }
            var resolvedQuality = wanted
            var url: URL?
            if let formats = try? await DJduoduoAPI.shared.formats(song: song), !formats.isEmpty {
                let picked = formats.first { $0.quality == wanted.rawValue }
                    ?? formats.filter { $0.quality <= wanted.rawValue }.max { $0.quality < $1.quality }
                    ?? formats.min { $0.quality < $1.quality }
                if let picked,
                   let string = DJduoduoAPI.shared.downloadURL(format: picked, song: song) {
                    url = URL(string: string)
                    resolvedQuality = picked.tier
                }
            }
            if url == nil, let fallback = DJduoduoAPI.shared.defaultURL(song: song) {
                url = URL(string: fallback)
                resolvedQuality = .smooth
            }
            guard let url else {
                await MainActor.run {
                    self.finishWithError(song: song, message: "无法解析下载地址")
                }
                return
            }
            await MainActor.run {
                self.active[song.identityKey]?.quality = resolvedQuality
                self.startDownload(song: song, quality: resolvedQuality, url: url)
            }
        }
    }

    private func startDownload(song: Song, quality: DJddQuality, url: URL) {
        var request = URLRequest(url: url)
        request.setValue("DJDuoduo/4.3.7 (iPhone; iOS 26.0; Scale/3.00)",
                         forHTTPHeaderField: "User-Agent")
        let task = session.downloadTask(with: request)
        taskMeta[task.taskIdentifier] = (song, quality)
        task.resume()
        BeansLogger.shared.log("下载开始：\(song.name)｜\(quality.title)", level: .info)
    }

    private func finishWithError(song: Song, message: String) {
        active.removeValue(forKey: song.identityKey)
        lastError = message
        toast("下载失败：\(message)", duration: 3)
        BeansLogger.shared.log("下载失败：\(song.name)｜\(message)", level: .error)
    }

    // MARK: 本地记录

    private func loadTracks() {
        guard let data = UserDefaults.standard.data(forKey: tracksKey),
              let saved = try? JSONDecoder().decode([DownloadedTrack].self, from: data) else { return }
        tracks = saved.filter { FileManager.default.fileExists(atPath: $0.fileURL.path) }
    }

    private func saveTracks() {
        if let data = try? JSONEncoder().encode(tracks) {
            UserDefaults.standard.set(data, forKey: tracksKey)
        }
    }

    func delete(_ track: DownloadedTrack) {
        try? FileManager.default.removeItem(at: track.fileURL)
        tracks.removeAll { $0.id == track.id }
        saveTracks()
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where tracks.indices.contains(index) {
            delete(tracks[index])
        }
    }

    func deleteAll() {
        for track in tracks {
            try? FileManager.default.removeItem(at: track.fileURL)
        }
        tracks.removeAll()
        saveTracks()
    }

    /// 已下载文件导出（分享面板）
    func exportURL(for track: DownloadedTrack) -> URL? {
        FileManager.default.fileExists(atPath: track.fileURL.path) ? track.fileURL : nil
    }

    /// 主线程提示（下载回调可能来自 URLSession 队列）
    private func toast(_ text: String, duration: Double = 2.2) {
        Task { @MainActor in
            ToastCenter.shared.show(text, duration: duration)
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadStore: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let meta = taskMeta[downloadTask.taskIdentifier] else { return }
        let key = meta.song.identityKey
        guard var progress = active[key] else { return }
        progress.received = totalBytesWritten
        progress.expected = totalBytesExpectedToWrite
        active[key] = progress
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let meta = taskMeta.removeValue(forKey: downloadTask.taskIdentifier) else { return }
        let song = meta.song
        let key = song.identityKey
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200...299).contains(status) else {
            finishWithError(song: song, message: "HTTP \(status)")
            return
        }
        let suggested = downloadTask.response?.suggestedFilename ?? location.lastPathComponent
        let ext = (suggested as NSString).pathExtension
        let safeExtension = ext.isEmpty ? "mp3" : ext
        let baseName = "\(song.name) - \(song.artists)"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let trimmedName = String(baseName.prefix(60))
        let fileName = "\(song.id)-\(meta.quality.rawValue)-\(trimmedName).\(safeExtension)"
        let dest = DownloadStore.directory.appendingPathComponent(fileName)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            // 同曲目换档位时清掉旧文件，避免占用双倍空间
            if let old = tracks.first(where: { $0.id == key }), old.fileURL != dest {
                try? FileManager.default.removeItem(at: old.fileURL)
            }
            try FileManager.default.moveItem(at: location, to: dest)
            let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? NSNumber)?.int64Value ?? 0
            tracks.removeAll { $0.id == key }
            tracks.insert(
                DownloadedTrack(song: song, qualityRaw: meta.quality.rawValue,
                                fileName: fileName, byteCount: size, addedAt: Date()),
                at: 0
            )
            saveTracks()
            active.removeValue(forKey: key)
            toast("已下载：\(song.name)（\(meta.quality.title)）")
            BeansLogger.shared.log("下载完成：\(song.name)｜\(meta.quality.title)", level: .info)
        } catch {
            finishWithError(song: song, message: error.localizedDescription)
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let error else { return }
        guard let meta = taskMeta.removeValue(forKey: task.taskIdentifier) else { return }
        finishWithError(song: meta.song, message: error.localizedDescription)
    }
}