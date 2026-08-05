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

    /// 进程内共享的内存图片缓存（URL 作 key）：
    /// 切 tab / 重复查询同一社员时直接命中，避免重复发起网络下载。
    private static let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 300
        return cache
    }()
    
    @State private var image: UIImage? = nil
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let uiImage = image {
                // 加载成功，显示真实图片
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                // 加载中显示进度条
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.3))
            } else {
                // 加载失败或无链接时，显示你之前设计的首字母占位符
                placeholderAvatar
            }
        }
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

        // 第一层：内存缓存命中 → 直接显示，跳过网络请求
        if let cached = Self.imageCache.object(forKey: urlString as NSString) {
            image = cached
            return
        }

        // URL 变化（如切换到另一社员）时先清空旧图，避免残留上一人的头像；
        // 同一 URL 且已有图则直接复用，避免切 tab 回来重复加载
        if image != nil {
            image = nil
        }
        
        isLoading = true
        do {
            // 调用 MemberService 的下载方法
            if let downloadedImage = try await MemberService.shared.downloadTempMedia(from: urlString){
                // 第二层：下载成功后写入内存缓存，供后续秒开
                Self.imageCache.setObject(downloadedImage, forKey: urlString as NSString)
                // 确保 UI 更新在主线程
                await MainActor.run {
                    self.image = downloadedImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run { self.isLoading = false }
            }
        } catch {
            print("抓取图片报错: \(error)")
            await MainActor.run { self.isLoading = false }
        }
    }
    
    
    // 你的首字母占位图设计（复用你之前的逻辑）
    private var placeholderAvatar: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String(placeholderName.prefix(1)))
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
