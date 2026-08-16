//
//  MarkdownArticleView.swift
//  DeepMei
//
//  Markdown文章阅读组件
//

import SwiftUI
import MarkdownUI // 需通过 Swift Package Manager 添加：https://github.com/gonzalezreal/swift-markdown-ui

struct MarkdownArticleView: View {
    
    // MARK: - 页面加载状态定义
    private enum LoadState: Equatable {
        case loading
        case loaded(String)
        case failed(String)
    }

    let fileName: String
    var title: String? = nil

    @State private var loadState: LoadState = .loading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                switch loadState {
                case .loading:
                    loadingView
                    
                case .loaded(let content):
                    markdownContentView(content)
                    
                case .failed(let errorText):
                    errorView(message: errorText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            // iPad 大屏阅读宽度上限：正文最长 720pt 居中，避免行长过长难读；手机宽度不足时行为不变
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(articleTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if case .loaded(let content) = loadState {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: articleShareText(content)) {
                        Label("分享文章", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityLabel("分享文章")
                }
            }
        }
        .task(id: fileName) { // 当 fileName 改变时自动重新重新执行 Task
            await loadMarkdownAsync()
        }
    }
}

// MARK: - 子视图组件 (Subviews)
private extension MarkdownArticleView {
    
    // 1. Markdown 渲染主内容
    func markdownContentView(_ content: String) -> some View {
        Markdown(content)
            // 自定义中英文排版体验（在 gitHub 基础样式上调整）
            .markdownTheme(
                .gitHub
                .text {
                    ForegroundColor(.primary)
                    FontSize(16)
                }
            )
            .textSelection(.enabled)
            // 如果希望图片支持适应屏幕宽度，可以加以下控制：
            .markdownImageProvider(.asset)
    }

    // 2. 加载中视图
    var loadingView: some View {
        HStack {
            Spacer()
            ProgressView("正在加载文章...")
                .controlSize(.regular)
                .padding(.top, 60)
            Spacer()
        }
    }

    // 3. 错误或空文件提示视图
    func errorView(message: String) -> some View {
        ContentUnavailableView(
            "文章加载失败",
            systemImage: "doc.slash.fill",
            description: Text(message)
        )
        .padding(.top, 40)
    }
}

// MARK: - 业务逻辑 & 异步读取
private extension MarkdownArticleView {
    
    // 动态计算页面标题
    var articleTitle: String {
        if let title {
            return title
        }
        switch fileName {
        case "constitution":
            return "苏州中学树莓社章程"
        case "constitution-revision-history":
            return "章程修订记录"
        case "constitution-appendices":
            return "章程附录"
        case "shumei-huanyingci":
            return "树莓派项目介绍树莓社经验分享"
        case "raspberry-club-speech":
            return "树莓社2024年国旗下讲话"
        case "SMS-RC_C8_President_Report_2026":
            return "树莓社第七届社长工作报告"
        case "NoFrameDecidesMovie":
            return "没有任何一帧可以决定整部电影"
        default:
            return "文章"
        }
    }

    /// 分享文本：标题 + 正文（保留 Markdown 原始内容，便于对方复制存档）。
    func articleShareText(_ content: String) -> String {
        "\(articleTitle)\n\n\(content)"
    }

    // 异步加载本地文件，避免 UI 阻塞
    @MainActor
    func loadMarkdownAsync() async {
        loadState = .loading
        
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "md") else {
            let errorMsg = """
            找不到文章文件：\(fileName).md
            请确认文件已正确加入项目目录及 Xcode Target Membership。
            """
            loadState = .failed(errorMsg)
            return
        }

        // 使用 Task.detached 抛到后台线程读取文件，防止大 Markdown 文本读取时阻塞 Main Thread
        let result: Result<String, Error> = await Task.detached(priority: .userInitiated) {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                return .success(content)
            } catch {
                return .failure(error)
            }
        }.value

        // 回到 MainActor 更新 @State
        switch result {
        case .success(let text):
            // 防止读取空文本引发页面空白
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            loadState = trimmed.isEmpty ? .failed("文章内容为空。") : .loaded(text)
        case .failure(let error):
            loadState = .failed("读取出现异常：\(error.localizedDescription)")
        }
    }
}

// MARK: - Xcode Previews
#Preview("错误路径 - 找不到文件") {
    NavigationStack {
        MarkdownArticleView(fileName: "non_existent_file")
    }
}

#Preview("正确渲染预期") {
    NavigationStack {
        // 由于没有真实的 md，我们在 Preview 里可以用系统支持的主题先看大概样式
        ScrollView {
            Markdown("""
            # 社团章程
            
            欢迎阅读 **DeepMei** 社团的相关规则以及核心精神：
            
            1. **创作至上**：用影像和数字媒体发声
            2. **团结协助**：在各环节密切配合
            
            > **注意**：章程最终解释权归社团管理部门所有。
            """)
            .markdownTheme(.gitHub)
            .padding(20)
        }
        .navigationTitle("社团章程")
        .navigationBarTitleDisplayMode(.inline)
    }
}
