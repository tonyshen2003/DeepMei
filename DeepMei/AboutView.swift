//
//  AboutView.swift
//  DeepMei
//

import SwiftUI

/// 更新入口配置。
private enum UpdateEntry {
    /// TestFlight 公开邀请链接；发布后替换为真实链接（例如 https://testflight.apple.com/join/XXXXXX）。
    /// 为空时回退到 TestFlight 在 App Store 的页面。
    static let testFlightInviteURL: String? = nil
    static let fallbackURL = URL(string: "itms-apps://apps.apple.com/app/id899247664")!
}

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
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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

            // MARK: - 更新入口
            Section {
                Button {
                    openUpdateEntry()
                } label: {
                    Label {
                        Text("检查更新")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.green)
                    }
                }
            } header: {
                Text("更新")
            } footer: {
                Text("新版本通过 TestFlight 分发")
            }

            // MARK: - 致谢
            Section {
                NavigationLink {
                    CreditsView()
                } label: {
                    Label {
                        Text("创作者名单")
                    } icon: {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(.pink)
                    }
                }
            } header: {
                Text("致谢")
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
                    OpenSourceLicensesView()
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
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func openUpdateEntry() {
        let url: URL
        if let invite = UpdateEntry.testFlightInviteURL, let inviteURL = URL(string: invite) {
            url = inviteURL
        } else {
            url = UpdateEntry.fallbackURL
        }
        UIApplication.shared.open(url)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
