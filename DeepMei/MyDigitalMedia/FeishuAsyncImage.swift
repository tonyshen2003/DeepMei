//
//  Untitled.swift
//  DeepMei
//
//  Created by 沈孙丰 on 2026/7/26.
//

import SwiftUI

struct FeishuAsyncImage: View {
    let urlString: String?
    let placeholderName: String // 用于显示首字母占位符
    var contentMode: ContentMode = .fill
    var placeholderText: String? = nil
    // 用不透明系统色保证白字对比度（浅色模式下也满足可读性要求）
    var placeholderColors: [Color] = [Color.indigo, Color.purple]
    // 需要时用系统图标替代首字/文字占位（如照片墙失败态）
    var placeholderSystemImage: String? = nil
    // 失败后是否稍等再自动重试一次（适合详情页照片等重试成本较低的图片）
    var autoRetry: Bool = false
    // 外部希望强制重新加载（如下拉刷新重试失败图）时递增此值即可
    var retryNonce: Int = 0

    @State private var image: UIImage? = nil
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let uiImage = image {
                // 加载成功：Color.clear 承接提案尺寸，按调用方要求的 contentMode 绘制
                //（fill 时外层 clipped 裁掉超出部分；fit 时完整显示，不裁切）。
                Color.clear
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    }
                    .clipped()
            } else if isLoading {
                // 加载中显示进度条
                ProgressView()
                    .tint(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemFill))
            } else {
                // 加载失败或无链接时，显示你之前设计的首字母占位符
                placeholderAvatar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: "\(urlString ?? "")#\(retryNonce)") {
            // 视图出现时异步获取图片
            await loadImage()
        }
    }
    
    // 异步加载逻辑
    private func loadImage() async {
        guard let urlString = urlString else {
            // 无 URL：确保显示占位符
            image = nil
            return
        }

        // URL 变化（如切换到另一社员）时先清空旧图，避免残留上一人的头像；
        if image != nil {
            image = nil
        }
        
        isLoading = true
        let attempts = autoRetry ? 2 : 1
        for attempt in 0..<attempts {
            guard !Task.isCancelled else { return }
            // 内存 / 磁盘 / 网络由 ImageCacheManager 统一处理（稳定键 + 并发去重）
            let downloadedImage = await ImageCacheManager.shared.image(for: urlString)
            guard !Task.isCancelled else { return }
            if let downloadedImage {
                await MainActor.run {
                    self.isLoading = false
                    self.image = downloadedImage
                }
                return
            }
            if autoRetry, attempt == 0 {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
        if !Task.isCancelled {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    
    // 你的首字母占位图设计（复用你之前的逻辑）
    private var placeholderAvatar: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: placeholderColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                if let placeholderSystemImage {
                    Image(systemName: placeholderSystemImage)
                        .font(.system(size: side * 0.3, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    Text(placeholderText ?? String(placeholderName.prefix(1)))
                        .font(.system(size: side * 0.45, weight: .bold))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .foregroundColor(.white)
                }
            }
        }
    }
}
