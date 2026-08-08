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

    @State private var image: UIImage? = nil
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let uiImage = image {
                // 加载成功：Color.clear 承接提案尺寸，图片 scaledToFill 覆盖绘制，
                // 外层 clipped 把超出 layout bounds 的部分裁掉，杜绝溢出遮挡。
                Color.clear
                    .overlay {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
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
        .task(id: urlString) {
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
        // 内存 / 磁盘 / 网络由 ImageCacheManager 统一处理（稳定键 + 并发去重）
        let downloadedImage = await ImageCacheManager.shared.image(for: urlString)
        await MainActor.run {
            self.isLoading = false
            if let downloadedImage {
                self.image = downloadedImage
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
                Text(placeholderText ?? String(placeholderName.prefix(1)))
                    .font(.system(size: side * 0.45, weight: .bold))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundColor(.white)
            }
        }
    }
}
