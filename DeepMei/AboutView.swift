//
//  AboutView.swift
//  DeepMei
//

import SwiftUI

struct AboutView: View {
    private var versionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
    }

    var body: some View {
        List {
            // MARK: - 头部信息
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)

                    Text("树莓社")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("DeepMei")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("版本 \(versionString)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // MARK: - 社团简介
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("苏州中学树莓社是一个关注新时代数字媒体的社团，以影视创作为核心，致力于打造艺术创作交流平台。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("社团简介")
            }

            // MARK: - 功能入口
            Section {
                NavigationLink {
                    MarkdownArticleView(fileName: "privacy-policy", title: "隐私政策")
                } label: {
                    Label {
                        Text("隐私政策")
                    } icon: {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.blue)
                    }
                }

                NavigationLink {
                    MarkdownArticleView(fileName: "user-agreement", title: "用户协议")
                } label: {
                    Label {
                        Text("用户协议")
                    } icon: {
                        Image(systemName: "doc.text.fill")
                            .foregroundStyle(.orange)
                    }
                }

                NavigationLink {
                    MarkdownArticleView(fileName: "open-source-licenses", title: "开源许可")
                } label: {
                    Label {
                        Text("开源许可")
                    } icon: {
                        Image(systemName: "shippingbox.fill")
                            .foregroundStyle(.purple)
                    }
                }
            } header: {
                Text("法律信息")
            }

            // MARK: - 联系方式
            Section {
                Button {
                    if let url = URL(string: "mailto:contact@szzxshumei.com") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label {
                        Text("contact@szzxshumei.com")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.green)
                    }
                }
            } header: {
                Text("联系我们")
            } footer: {
                Text("苏州中学树莓社")
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
