//
//  ContentView.swift
//  DeepMei
//
//  Created by 沈孙丰 on 2026/7/23.
//

import SwiftUI
import WebKit

private enum MainTab: Hashable {
    case home
    case library
    case activities
    case camera
    case mine
}

struct ContentView: View {
    @State private var selectedTab: MainTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: - 探索
            HomeNavigationView()
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
            // MARK: - 活动
           // ActivityView()
              //  .tabItem {
             //       Label(
             //           "活动",
            //            systemImage: "calendar"
           //         )
           //     }
           //     .tag(MainTab.activities)
            //MARK: - 导演取景器 (树莓相机)
            /*
            DirectorCameraView()
                .tabItem {
                    Label(
                        "取景器",
                        systemImage: "camera.viewfinder"
                    )
                }
                .tag(MainTab.camera)
            */
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
                    "我的树莓",
                    systemImage: "star.fill"
                )
            }
            .tag(MainTab.mine)
        }
    }
}

// MARK: - 首页

struct HomeNavigationView: View {
    @State private var showRegisterSheet = false
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
                        WebView(
                            url:
                                URL(
                                    string:
                                        "https://shumeiartworks.coze.site?t=\(Date().timeIntervalSince1970)"
                                )!
                        )
                        .ignoresSafeArea()
                        .navigationTitle(
                            "作品播放"
                        )
                        .navigationBarTitleDisplayMode(
                            .inline
                        )
                        .ignoresSafeArea(edges: .bottom)
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
                .padding()
            }
            .navigationTitle("欢迎！")
            .toolbar {
                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    Button {
                        showRegisterSheet = true
                    } label: {
                        Image(
                            systemName:
                                "person.badge.plus"
                        )
                    }
                }
            }
            .sheet(
                isPresented:
                    $showRegisterSheet
            ) {
                NavigationStack {
                    WebView(
                        url:
                            URL(
                                string:
                                    "https://cqbxhfrnwy.coze.site?t=\(Date().timeIntervalSince1970)"
                            )!
                    )
                    .navigationTitle(
                        "活动签到"
                    )
                    .navigationBarTitleDisplayMode(
                        .inline
                    )
                    .toolbar {
                        ToolbarItem(
                            placement:
                                    .topBarLeading
                        ) {
                            Button(
                                "关闭"
                            ) {
                                showRegisterSheet = false
                            }
                        }
                    }
                }
            }
            .onAppear {
                            withAnimation(.easeIn(duration: 1.0)) { // 使用 .easeIn 淡入效果更自然
                                emojiIndex = Int.random(in: 1...49)
                            }
                        }
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
            symbol: "letter",
            articles: [
                Article(
                    title: "用流动的影像传承历史，以不变的温度记录人文——国旗下讲话",
                    subtitle: "王嫣然、第六届组委会集体",
                    fileName: "raspberry-club-speech",
                    symbol: "mic.fill"
                ),
                Article(
                    title: "守温度、传火种、向未来——在树莓社第八届社员大会上的工作报告",
                    subtitle: "杨梓言社长",
                    fileName: "SMS-RC_C8_President_Report_2026",
                    symbol: "text.page"
                ),
                Article(
                    title: "没有任何一帧，可以决定整部电影——树莓社致所有考生的一封信",
                    subtitle: "陈雨馨社长",
                    fileName: "NoFrameDecidesMovie",
                    symbol: "envelope.fill"
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

struct WebView: UIViewRepresentable {
    let url: URL

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
}

#Preview {
    ContentView()
}
