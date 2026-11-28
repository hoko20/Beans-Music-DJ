import ImageIO
import UIKit

/// 复用本地图片解码结果，避免设置页/歌词页滚动时反复从磁盘解码大图。
/// 两套缓存都带容量上限：壁纸原图按 MB 计很占内存，缩略图单独走降采样缓存。
enum BeansImageFileCache {
    /// 全尺寸解码缓存（壁纸预览 / 实际背景）
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 8
        cache.totalCostLimit = 80 * 1024 * 1024
        return cache
    }()

    /// 缩略图缓存：只保存降采样后的小图，几十张也只有几 MB
    private static let thumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 80
        cache.totalCostLimit = 16 * 1024 * 1024
        return cache
    }()

    static func image(at path: String) -> UIImage? {
        guard !path.isEmpty else { return nil }
        let key = path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        cache.setObject(image, forKey: key, cost: cost(of: image))
        return image
    }

    /// 缩略图：用 ImageIO 直接把文件解码到目标像素，不经过全尺寸解码，
    /// 避免壁纸条里每张 1600px 大图各占约 10MB 内存。
    static func thumbnail(at path: String, maxPixelSize: CGFloat) -> UIImage? {
        guard !path.isEmpty, maxPixelSize > 0 else { return nil }
        let pixel = max(1, Int(maxPixelSize.rounded()))
        let key = "\(path)#\(pixel)" as NSString
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: pixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let image = UIImage(cgImage: cgImage)
        thumbnailCache.setObject(image, forKey: key, cost: cost(of: image))
        return image
    }

    static func remove(_ path: String) {
        guard !path.isEmpty else { return }
        cache.removeObject(forKey: path as NSString)
    }

    static func removeAll() {
        cache.removeAllObjects()
        thumbnailCache.removeAllObjects()
    }

    /// 解码后的像素占用（大致等于 width × height × 4 字节）
    private static func cost(of image: UIImage) -> Int {
        let pixels = image.size.width * image.size.height * image.scale * image.scale
        return max(1, Int(pixels * 4))
    }
}