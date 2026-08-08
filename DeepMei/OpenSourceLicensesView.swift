//
//  OpenSourceLicensesView.swift
//  DeepMei
//
//  开源许可（原生 SwiftUI 分组列表，对齐 Android 原生页面的信息结构）
//

import SwiftUI

struct OpenSourceLicensesView: View {
    private let runtimeItems = [
        LicenseItem(
            name: "swift-markdown-ui",
            purpose: "Markdown 渲染",
            version: "2.4.1",
            license: "MIT"
        ),
        LicenseItem(
            name: "NetworkImage",
            purpose: "网络图片加载（依赖）",
            version: "6.0.1",
            license: "MIT"
        ),
        LicenseItem(
            name: "swift-cmark / cmark-gfm",
            purpose: "CommonMark 解析（依赖）",
            version: "0.8.0",
            license: "BSD-2-Clause"
        )
    ]

    var body: some View {
        List {
            // MARK: - 版权头部
            Section {
                VStack(spacing: 8) {
                    Image("ClubLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)

                    Text("DeepMei © 2026 苏州中学树莓社")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("本应用基于 Apple 系统框架开发，并使用了以下开源组件。")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // MARK: - 运行时依赖
            Section("运行时依赖") {
                ForEach(runtimeItems) { item in
                    LabeledContent {
                        Text(item.license)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.tint)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.body)
                            Text("\(item.purpose) · \(item.version)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // MARK: - 构建工具
            Section("构建工具") {
                LabeledContent {
                    Text("Apple")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Xcode / Swift Package Manager")
                            .font(.body)
                        Text("Apple 提供的构建与依赖管理工具")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - 说明与版权
            Section {
                Text("说明：各开源项目的完整许可证文本及版权声明以对应项目仓库发布的 LICENSE 文件为准；如需获取许可证副本或对使用方式有疑问，可通过 contact@szzxshumei.com 联系我们。本页列出的第三方项目与 DeepMei 无任何背书或合作关系。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } footer: {
                Text("© 苏州中学树莓社")
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }
        }
        .navigationTitle("开源许可")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 数据模型
private struct LicenseItem: Identifiable {
    let name: String
    let purpose: String
    let version: String
    let license: String

    var id: String { name }
}

#Preview {
    NavigationStack {
        OpenSourceLicensesView()
    }
}
