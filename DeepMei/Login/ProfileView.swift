//
//  ProfileView.swift
//  DeepMei
//
//  我的树莓（个人中心，符合 Apple HIG）：底部 Tab + Grouped List（设置页范式）。
//  与 Android 的 M3 Navigation Drawer 对齐功能，但使用 iOS 原生信息架构：
//  - 顶级导航交给 Tab Bar；
//  - 登录卡片、主要功能、法律信息、退出登录都用 List Section 分组呈现。
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject private var loginManager = LoginManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    userHeader
                }

                Section("主要功能") {
                    NavigationLink {
                        MyMemberCardView()
                    } label: {
                        Label("我的社员卡", systemImage: "person.text.rectangle")
                    }
                    // 社员档案：网页版档案，用登录时保存的社员识别码拼链接（与 Android 抽屉入口一致，免二次登录）
                    if loginManager.isLoggedIn, !loginManager.loggedInMemberCode.isEmpty {
                        NavigationLink {
                            WebView(url: archiveURL)
                                .navigationTitle("社员档案")
                                .navigationBarTitleDisplayMode(.inline)
                        } label: {
                            Label("社员档案", systemImage: "folder.fill")
                        }
                    }
                    NavigationLink {
                        CheckInView()
                    } label: {
                        Label("活动签到", systemImage: "person.badge.plus")
                    }
                    NavigationLink {
                        HallOfFameView()
                    } label: {
                        Label("名人堂", systemImage: "trophy.fill")
                    }
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("关于", systemImage: "info.circle.fill")
                    }
                }

                Section("法律信息") {
                    NavigationLink {
                        MarkdownArticleView(fileName: "privacy-policy", title: "隐私政策")
                    } label: {
                        Label("隐私政策", systemImage: "hand.raised.fill")
                    }
                    NavigationLink {
                        MarkdownArticleView(fileName: "user-agreement", title: "用户协议")
                    } label: {
                        Label("用户协议", systemImage: "doc.text.fill")
                    }
                    NavigationLink {
                        OpenSourceLicensesView()
                    } label: {
                        Label("开源许可", systemImage: "shippingbox.fill")
                    }
                }

                if loginManager.isLoggedIn {
                    Section {
                        Button("退出登录", role: .destructive) {
                            LoginManager.shared.logout()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("我的树莓")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    /// 社员档案网页链接：社员识别码作为查询参数（识别码为字母数字，无需转义），
    /// 附带时间戳 `t` 强制刷新，避免 WebView/站点缓存展示旧档案（与作品站、文创入口一致）。
    private var archiveURL: URL {
        var components = URLComponents(string: "https://szzxshumei.com/raspberry-archive/")!
        components.queryItems = [
            URLQueryItem(name: "member", value: loginManager.loggedInMemberCode),
            URLQueryItem(name: "t", value: String(Date().timeIntervalSince1970)),
        ]
        return components.url!
    }

    private var userHeader: some View {
        HStack(spacing: 14) {
            Group {
                if loginManager.isLoggedIn, !loginManager.loggedInAvatarUrl.isEmpty {
                    FeishuAsyncImage(
                        urlString: loginManager.loggedInAvatarUrl,
                        placeholderName: loginManager.loggedInName,
                        contentMode: .fill
                    )
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFill()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(loginManager.isLoggedIn ? loginManager.loggedInName : "未登录")
                        .font(.headline)
                    if loginManager.isLoggedIn {
                        Text("已登录")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                }
                Text(
                    loginManager.isLoggedIn
                        ? loginManager.loggedInIdCode
                        : "登录后可使用社员查询与签到"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if !loginManager.isLoggedIn {
                NavigationLink {
                    LoginView()
                } label: {
                    Text("去登录")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 6)
    }
}
