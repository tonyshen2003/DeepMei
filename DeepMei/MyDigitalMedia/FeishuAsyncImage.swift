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
        .task {
            // 视图出现时异步获取图片
            await loadImage()
        }
    }
    
    // 异步加载逻辑
    private func loadImage() async {
        guard let urlString = urlString, image == nil else { return }
        
        isLoading = true
        do {
            // 调用 MemberService 的下载方法
            if let downloadedImage = try await MemberService.shared.downloadTempMedia(from: urlString){
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
