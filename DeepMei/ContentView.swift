//
//  ContentView.swift
//  DeepMei
//
//  Created by 沈孙丰 on 2026/7/23.
//

import SwiftUI
import WebKit

enum MainTab: Hashable {
    case home
    case library
    case activities
    case mine
    case profile
}

struct ContentView: View {
    @State private var selectedTab: MainTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: - 探索
            HomeNavigationView(selectedTab: $selectedTab)
                .tabItem {
                    Label(
                        "首页",
                        systemImage: "safari.fill"
                    )
                }
                .tag(MainTab.home)

            // MARK: - 文章 / 章程
            ArticleListView()
                .tabItem {
                    Label(
                        "树莓文库",
                        systemImage: "book.pages.fill"
                    )
                }
                .tag(MainTab.library)
            // MARK: - 工作台
            WorkbenchView()
                .tabItem {
                    Label(
                        "工作台",
                        systemImage: "square.grid.2x2.fill"
                    )
                }
                .tag(MainTab.activities)
            
            // MARK: - 树莓酱
            MyRaspberryView()
            .ignoresSafeArea()
            .tabItem {
                Label(
                    "社员查询",
                    systemImage: "star.fill"
                )
            }
            .tag(MainTab.mine)

            // MARK: - 我的树莓（个人中心）
            ProfileView()
                .tabItem {
                    Label(
                        "我的树莓",
                        systemImage: "person.circle.fill"
                    )
                }
                .tag(MainTab.profile)
        }
    }
}

// MARK: - 首页

struct HomeNavigationView: View {
    @Binding var selectedTab: MainTab
    @ObservedObject private var loginManager = LoginManager.shared
    @State private var emojiIndex: Int = Int.random(in: 1...49)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 10) {
                        Image("\(emojiIndex)")
                            .resizable() // 自定义图片必须加 resizable 才能调整大小
                            .frame(width: 150,height: 150) // 设置你需要的尺寸
                            .id(emojiIndex)
                            .transition(.asymmetric(
                                insertion: .opacity,
                                removal: .identity
                            ))
                        Text("一个关注新时代数字媒体的社团")
                            .font(.headline)
                        Text("以影视创作为核心的艺术创作交流平台")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical,20)
                    NavigationLink {
                        HallOfFameView()
                    } label: {
                        ActionCard(
                            title: "优秀社团干部",
                            subtitle:
                                "记录历届优秀成员",
                            icon:
                                "person.3.sequence.fill",
                            iconColor:
                                    .orange
                        )
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        WorksBrowserView()
                    } label: {
                        ActionCard(
                            title: "作品播放",
                            subtitle:
                                "《识茶记》《苏迷》及活动影像",
                            icon:
                                "film.fill",
                            iconColor:
                                    .blue
                        )
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        WebView(
                            url:
                                URL(
                                    string:
                                        "https://raspjam.com?t=\(Date().timeIntervalSince1970)"
                                )!
                        )
                        .navigationTitle(
                            "树莓酱专属企划"
                        )
                        .navigationBarTitleDisplayMode(
                            .inline
                        )
                    } label: {
                        ActionCard(
                            title: "文创与周边",
                            subtitle:
                                "树莓酱IP、卡套与原创贴纸",
                            icon:
                                "paintpalette.fill",
                            iconColor:
                                    .purple
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .navigationTitle("欢迎！")
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) {
                        profileAvatarButton
                    }
                    // 关掉系统自动加的椭圆胶囊玻璃，头像用自定义正圆玻璃
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        profileAvatarButton
                    }
                }

                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    NavigationLink {
                        CheckInView()
                    } label: {
                        Image(
                            systemName:
                                "person.badge.plus"
                        )
                    }
                }
            }
            .onAppear {
                withAnimation(.easeIn(duration: 0.6)) {
                    emojiIndex = Int.random(in: 1...49)
                }
            }
        }
    }

    /// 左上角头像按钮：32pt 视觉尺寸 + 44pt 点击区域
    private var profileAvatarButton: some View {
        Button {
            selectedTab = .profile
        } label: {
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
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            .modifier(AvatarCircularGlass())
        }
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel("我的树莓")
    }
}

/// iOS 26 液态玻璃：圆形头像用正圆玻璃容器，替代系统默认的椭圆胶囊。
private struct AvatarCircularGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(4)
                .glassEffect(.regular.interactive(), in: .circle)
        } else {
            content
        }
    }
}

// MARK: - Markdown文章列表

struct Article: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let fileName: String
    let symbol: String
}

struct ArticleCategory: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let articles: [Article]
}

struct ArticleListView: View {
    private let categories: [ArticleCategory] = [
        ArticleCategory(
            name: "社团章程",
            symbol: "book.closed.fill",
            articles: [
                Article(
                    title: "苏州中学树莓社章程",
                    subtitle: "社团核心规章制度",
                    fileName: "constitution",
                    symbol: "doc.text.fill"
                ),
                Article(
                    title: "章程修订记录",
                    subtitle: "历次章程修订历史",
                    fileName: "constitution-revision-history",
                    symbol: "clock.arrow.circlepath"
                ),
                Article(
                    title: "章程附录",
                    subtitle: "机构设置与特别致谢名录",
                    fileName: "constitution-appendices",
                    symbol: "doc.append.fill"
                )
            ]
        ),
        ArticleCategory(
            name: "重要理念",
            symbol: "lightbulb.max.fill",
            articles: [
                Article(
                    title: "树莓派项目介绍树莓社经验分享",
                    subtitle: "周熠嘉、沈孙丰",
                    fileName: "shumei-huanyingci",
                    symbol: "person.2.fill"
                ),
                Article(
                    title: "树莓社2024年国旗下讲话",
                    subtitle: "王嫣然、第六届组委会集体",
                    fileName: "raspberry-club-speech",
                    symbol: "mic.fill"
                ),
                Article(
                    title: "关于保障创作者权益的倡议",
                    subtitle: "王嫣然副社长",
                    fileName: "creator-rights-initiative",
                    symbol: "megaphone.fill"
                ),
                Article(
                    title: "没有任何一帧可以决定整部电影",
                    subtitle: "陈雨馨社长",
                    fileName: "NoFrameDecidesMovie",
                    symbol: "envelope.fill"
                )
            ]
        ),
        ArticleCategory(
            name: "社长工作报告",
            symbol: "doc.richtext.fill",
            articles: [
                Article(
                    title: "第二届社员大会工作报告",
                    subtitle: "刘恩岐社长",
                    fileName: "report-2019-2nd-liuenqi",
                    symbol: "doc.text"
                ),
                Article(
                    title: "第三届社长2021年上半年活动总结报告",
                    subtitle: "朱奕社长",
                    fileName: "report-2021-midyear-zhuyi",
                    symbol: "doc.text"
                ),
                Article(
                    title: "第四届社员大会工作报告",
                    subtitle: "朱奕社长",
                    fileName: "report-2022-annual-zhuyi",
                    symbol: "doc.text"
                ),
                Article(
                    title: "第五届社员大会工作报告",
                    subtitle: "汪翊扬社长等",
                    fileName: "report-2023-5th-wangyiyang",
                    symbol: "doc.text"
                ),
                Article(
                    title: "第六届社员大会社长工作报告",
                    subtitle: "李谦社长",
                    fileName: "report-2023-6th-liqian",
                    symbol: "doc.text"
                ),
                Article(
                    title: "第六届组织委员会工作报告",
                    subtitle: "王嫣然代理社长",
                    fileName: "report-2024-6th-committee-wangyanran",
                    symbol: "doc.text"
                ),
                Article(
                    title: "第八届社员大会社长工作报告",
                    subtitle: "杨梓言社长",
                    fileName: "SMS-RC_C8_President_Report_2026",
                    symbol: "doc.text"
                )
            ]
        )
    ]

    var body: some View {
        NavigationStack {
            Group {
                if categories.isEmpty {
                    ContentUnavailableView(
                        "暂无文章",
                        systemImage: "book.closed",
                        description: Text("内容正在准备中")
                    )
                } else {
                    List {
                        ForEach(categories) { category in
                            Section {
                                ForEach(category.articles) { article in
                                    NavigationLink {
                                        MarkdownArticleView(fileName: article.fileName)
                                    } label: {
                                        Label {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(article.title)
                                                    .font(.headline)
                                                Text(article.subtitle)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                            .padding(.vertical, 2)
                                        } icon: {
                                            Image(systemName: article.symbol)
                                                .symbolRenderingMode(.hierarchical)
                                                .foregroundStyle(Color.accentColor)
                                        }
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("\(article.title)，\(article.subtitle)")
                                    .accessibilityHint("查看文章详情")
                                }
                            } header: {
                                Text(category.name)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("树莓文库")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - 卡片

struct ActionCard: View {
    var title:String
    var subtitle:String
    var icon:String
    var iconColor:Color

    var body: some View {
        HStack(spacing:16) {
            Image(
                systemName:
                    icon
            )
            .font(
                .system(size:24)
            )
            .foregroundStyle(
                .white
            )
            .frame(
                width:56,
                height:56
            )
            .background(
                iconColor
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:16,
                    style:.continuous
                )
            )
            VStack(
                alignment:.leading,
                spacing:5
            ) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(
                        .secondary
                    )
            }
            Spacer()
            Image(
                systemName:
                    "chevron.right"
            )
            .foregroundStyle(
                .tertiary
            )
        }
        .padding(16)
        .background(
            .ultraThinMaterial
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:20,
                style:.continuous
            )
        )
    }
}

// MARK: - WebView

/// WebView 外部链接分发策略（与 Android 版 ExternalLinkPolicy 对齐）。
///
/// 区分两类链接：
/// - http/https 普通网页链接 → 一律留在 WebView 内加载，不走外部；
/// - 网页自带的「打开 App」按钮（如 xhsdiscover://、snssdk:// 等自定义 scheme）
///   → 交给系统拉起对应 App。
///
/// 只有命中白名单的自定义 scheme 才允许外跳，避免任意 scheme 被当作可执行动作。
private enum ExternalLinkPolicy {

    /// 允许拉起外部 App 的自定义 scheme（小红书 / 抖音 / B站 / 微信 / QQ / 微博）。
    private static let customSchemes: Set<String> = [
        "xhsdiscover", "xhs",              // 小红书
        "snssdk1128", "snssdk", "douyin",  // 抖音
        "bilibili",                        // B站
        "weixin",                          // 微信
        "mqq",                             // QQ
        "sinaweibo"                        // 微博
    ]

    /// 判断 URL 是否属于「打开 App」类型的外部链接（仅自定义 scheme，不含 http/https）。
    static func shouldOpenExternally(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return customSchemes.contains(scheme)
    }
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(
        context: Context
    ) -> WKWebView {
        let config = WKWebViewConfiguration()
        // 开启网页缓存
        config.websiteDataStore =
            WKWebsiteDataStore.default()
        // 允许在线播放
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(
            frame: .zero,
            configuration: config
        )
        webView.navigationDelegate = context.coordinator
        // 缓存策略
        let request = URLRequest(
            url: url,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 30
        )
        webView.load(request)
        return webView
    }

    func updateUIView(
        _ uiView: WKWebView,
        context: Context
    ) {
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let targetURL = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // 命中白名单的自定义 scheme：交给系统拉起对应 App，WebView 不再加载
            if ExternalLinkPolicy.shouldOpenExternally(targetURL) {
                UIApplication.shared.open(targetURL) { _ in }
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }
}

// MARK: - 作品播放（原生分类筛选）

struct WorksBrowserView: View {
    private let categories: [(key: String, name: String)] = [
        ("all", "全部作品"),
        ("original", "原创作品"),
        ("events", "校园活动"),
        ("sports", "体育赛事"),
        ("music", "音乐舞蹈"),
        ("news", "校园新闻"),
        ("digital", "数字创意")
    ]

    @State private var selectedCategory = "all"
    @State private var webView: WKWebView?

    var body: some View {
        WorksWKWebView(webView: $webView, selectedCategory: $selectedCategory)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("作品播放")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(categories, id: \.key) { category in
                            Button {
                                selectedCategory = category.key
                                let js = "window.ShumeiBridge && window.ShumeiBridge.setCategory('\(category.key)')"
                                webView?.evaluateJavaScript(js, completionHandler: nil)
                            } label: {
                                if selectedCategory == category.key {
                                    Label(category.name, systemImage: "checkmark")
                                } else {
                                    Text(category.name)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("筛选作品分类")
                }
            }
    }
}

private struct WorksWKWebView: UIViewRepresentable {
    @Binding var webView: WKWebView?
    @Binding var selectedCategory: String

    func makeCoordinator() -> Coordinator {
        Coordinator(webView: $webView, selectedCategory: $selectedCategory)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        let url = URL(string: "https://shumeiartworks.coze.site?t=\(Date().timeIntervalSince1970)")!
        webView.load(
            URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        )

        DispatchQueue.main.async {
            self.webView = webView
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var webView: WKWebView?
        @Binding var selectedCategory: String

        init(webView: Binding<WKWebView?>, selectedCategory: Binding<String>) {
            _webView = webView
            _selectedCategory = selectedCategory
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 隐藏网页自带的分类 Tab（搜索框保留，仍由网页提供），并应用当前选中的分类
            webView.evaluateJavaScript(
                "window.ShumeiBridge && window.ShumeiBridge.hideTabs(true);" +
                    "window.ShumeiBridge && window.ShumeiBridge.setCategory('\(selectedCategory)')",
                completionHandler: nil
            )
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let targetURL = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            if ExternalLinkPolicy.shouldOpenExternally(targetURL) {
                UIApplication.shared.open(targetURL) { _ in }
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }
}

#Preview {
    ContentView()
}
