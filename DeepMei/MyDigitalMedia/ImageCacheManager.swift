//
//  ImageCacheManager.swift
//  DeepMei
//
//  飞书图片缓存：稳定缓存键（file_token）+ 内存 / 磁盘两级缓存 + 同 URL 并发去重。
//  与 Android FeishuImageFetcher 对齐：快照刷新导致 tmp_url 变化时仍能命中同一份缓存。
//

import Foundation
import UIKit

/// 生成稳定的图片缓存键。
///
/// 飞书附件由 `file_token` 唯一标识（内容不可变，换图会产生新 token），
/// 快照里的 tmp_url 带有随数据表版本变化的 `rev` 参数，直接用 URL 当缓存键会导致同一张图被重复下载。
internal func stableImageCacheKey(_ urlString: String) -> String {
    if urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return urlString
    }
    guard let url = URL(string: urlString),
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return urlString
    }

    // batch_get_tmp_download_url 格式：?file_tokens=XXX&extra=...
    if let fileTokens = components.queryItems?.first(where: { $0.name == "file_tokens" })?.value,
       !fileTokens.isEmpty {
        return "lark:\(fileTokens)"
    }

    // 飞书直接下载 URL 格式：/drive/v1/medias/{file_token}/download
    let segments = url.pathComponents
    if let mediasIndex = segments.firstIndex(of: "medias"),
       mediasIndex + 1 < segments.count {
        let token = segments[mediasIndex + 1]
        if !token.isEmpty && token != "batch_get_tmp_download_url" {
            return "lark:\(token)"
        }
    }

    return urlString
}

/// 图片缓存管理器：内存 NSCache + 磁盘文件缓存 + 下载任务去重。
@MainActor
final class ImageCacheManager {
    static let shared = ImageCacheManager()

    private let memory = NSCache<NSString, UIImage>()
    private var downloads: [String: Task<UIImage?, Never>] = [:]
    private let diskDirectory: URL

    private init() {
        memory.countLimit = 300
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        diskDirectory = caches.appendingPathComponent("DeepMeiImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
    }

    /// 取图：内存 → 磁盘 → 网络（同 key 并发只下载一次），成功路径会自动回填缓存。
    func image(for urlString: String) async -> UIImage? {
        guard !urlString.isEmpty else { return nil }
        // 只接受 http/https，脏数据（如换行符、相对路径）直接跳过，避免网络层刷错误日志。
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        let key = stableImageCacheKey(urlString)

        if let cached = memory.object(forKey: key as NSString) {
            return cached
        }

        if let data = await readDiskData(key: key), let image = UIImage(data: data) {
            memory.setObject(image, forKey: key as NSString)
            return image
        }

        if let existing = downloads[key] {
            return await existing.value
        }

        let task = Task { [weak self] () -> UIImage? in
            guard let self else { return nil }
            guard let image = try? await MemberService.shared.downloadTempMedia(from: urlString) else {
                return nil
            }
            self.memory.setObject(image, forKey: key as NSString)
            await self.writeDisk(image: image, key: key)
            return image
        }
        downloads[key] = task
        let image = await task.value
        downloads[key] = nil
        return image
    }

    /// 同步读取内存缓存中的图片（用于分享卡等需要立即渲染、等不了异步加载的场景）。
    func cachedImage(for urlString: String) -> UIImage? {
        guard !urlString.isEmpty else { return nil }
        let key = stableImageCacheKey(urlString)
        return memory.object(forKey: key as NSString)
    }

    // MARK: - 磁盘缓存

    private func diskURL(forKey key: String) -> URL {
        let safe = String(key.map { $0.isLetter || $0.isNumber ? $0 : "_" }.prefix(80))
        return diskDirectory.appendingPathComponent("img_\(safe).dat")
    }

    private func readDiskData(key: String) async -> Data? {
        let url = diskURL(forKey: key)
        return await Task.detached(priority: .utility) {
            try? Data(contentsOf: url)
        }.value
    }

    private func writeDisk(image: UIImage, key: String) async {
        let data = image.jpegData(compressionQuality: 0.85) ?? image.pngData()
        guard let data else { return }
        let url = diskURL(forKey: key)
        await Task.detached(priority: .utility) {
            try? data.write(to: url, options: .atomic)
        }.value
        pruneIfNeeded()
    }

    /// 磁盘缓存上限：600 个文件 / 300MB，超出时按最旧优先清理。
    private func pruneIfNeeded() {
        let resourceKeys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: diskDirectory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        )) ?? []

        let totalSize = files.reduce(Int64(0)) { partial, url in
            partial + Int64(((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize) ?? 0)
        }
        let maxSize: Int64 = 300 * 1024 * 1024
        let maxCount = 600
        guard files.count > maxCount || totalSize > maxSize else { return }

        let sorted = files.sorted { lhs, rhs in
            let l = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let r = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return l < r
        }

        var size = totalSize
        var count = files.count
        for file in sorted {
            guard count > maxCount || size > maxSize else { break }
            let fileSize = Int64(((try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize) ?? 0)
            try? FileManager.default.removeItem(at: file)
            count -= 1
            size -= fileSize
        }
    }
}
