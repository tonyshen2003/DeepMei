//
//  MarkdownArticleView.swift
//  DeepMei
//
//  Markdown文章阅读组件
//

import SwiftUI
import MarkdownUI // 1. 导入第三方库

struct MarkdownArticleView: View {

    let fileName: String

    // 改为直接存储 String 字符串
    @State private var markdownContent: String?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let markdownContent {
                    // 2. 使用 MarkdownUI 组件进行渲染
                    Markdown(markdownContent)
                        .markdownTheme(.gitHub) // 使用预设的 GitHub 样式（可选：.basic 等）
                        .textSelection(.enabled)
                } else if let errorMessage {
                    ContentUnavailableView(
                        "文章加载失败",
                        systemImage: "doc.slash",
                        description: Text(errorMessage)
                    )
                } else {
                    ProgressView("正在加载...")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .navigationTitle(articleTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadMarkdown()
        }
    }

    // MARK: - 标题
    private var articleTitle: String {
        switch fileName {
        case "constitution":
            return "社团章程"
        default:
            return "文章"
        }
    }

    // MARK: - 读取 Markdown 文件
    private func loadMarkdown() {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "md") else {
            errorMessage = """
            找不到文章文件：
            \(fileName).md

            请确认已经加入 Xcode Target Membership
            """
            return
        }

        do {
            // 直接读取为原生的 String 内容
            markdownContent = try String(contentsOf: url, encoding: .utf8)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        MarkdownArticleView(fileName: "constitution")
    }
}
