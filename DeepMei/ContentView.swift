import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        TabView {
            // MARK: - Tab 1: 探索 (结合社团资料重新设计)
            HomeNavigationView()
                .tabItem {
                    Label("探索", systemImage: "safari.fill")
                }

            // MARK: - Tab 2: 原生章程页面 (支持 Markdown)
            ConstitutionView()
                .tabItem {
                    Label("章程", systemImage: "book.pages.fill")
                }

            // MARK: - Tab 3: 官网
            WebView(url: URL(string: "https://szzxshumei.com/")!)
                .ignoresSafeArea(edges: .bottom)
                .tabItem {
                    Label("官网", systemImage: "globe.asia.australia.fill")
                }
            
            // MARK: - Tab 4: 树莓酱
            WebView(url: URL(string: "https://raspjam.com/")!)
                .ignoresSafeArea(edges: .bottom)
                .tabItem {
                    Label("树莓酱", systemImage: "star.fill") // 选了一个星星图标代表IP
                }
        }
    }
}

// MARK: - 探索主页 (结合树莓社文化)
struct HomeNavigationView: View {
    @State private var showVideoCover = false
    @State private var showRegisterSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // 社团 Slogan 头图区域
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.system(size: 40))
                            .foregroundColor(.pink)
                        Text("一个关注新时代数字媒体的社团，")
                            .font(.headline)
                        Text("一个以影视创作为核心的艺术创作交流平台。")
                            .font(.headline)
                    }
                    .padding(.vertical, 10)
                    
                    // 1. 名人堂卡片 -> 跳转到原生列表页
                    NavigationLink(destination: HallOfFameView()) {
                        ActionCard(
                            title: "社团名人堂",
                            subtitle: "神人比较多",
                            icon: "person.3.sequence.fill",
                            iconColor: .orange
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 2. 影视作品卡片 -> 弹出全屏播放器
                    Button(action: { showVideoCover = true }) {
                        ActionCard(
                            title: "作品播放",
                            subtitle: "《识茶记》《苏迷》及校运会纪实",
                            icon: "film.fill",
                            iconColor: .blue
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // 3. 文创周边卡片
                    ActionCard(
                        title: "文创与周边",
                        subtitle: "树莓酱IP、定制卡套与原创贴纸",
                        icon: "paintpalette.fill",
                        iconColor: .purple
                    )
                    
                }
                .padding()
            }
            .navigationTitle("树莓社")
            // 右上角添加“招新登记”的快捷入口
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showRegisterSheet = true }) {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            // 绑定全屏影视弹窗
            .fullScreenCover(isPresented: $showVideoCover) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack {
                        Spacer()
                        Text("光影长廊 - 播放器开发中")
                            .foregroundColor(.white)
                        Spacer()
                        Button("关闭") { showVideoCover = false }
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            // 绑定报名登记弹窗 (调用 Web 表单)
            .sheet(isPresented: $showRegisterSheet) {
                NavigationStack {
                    WebView(url: URL(string: "https://cqbxhfrnwy.coze.site/")!)
                        .navigationTitle("社员登记")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("关闭") { showRegisterSheet = false }
                            }
                        }
                }
            }
        }
    }
}

// MARK: - 原生 Markdown 章程页面
struct ConstitutionView: View {
    // 这里是你自己用 Markdown 写的章程内容
    // 使用三个双引号 """ 可以写多行字符串
    let markdownContent: LocalizedStringKey = """
    # 苏州中学树莓社章程
    
    **(草案) 总第10版**
    
    ---
    
    ## 序言
    
    **树莓**谐音数媒，意为数字媒体。树莓社，一个关注于新时代数字媒体的社团，一个以影视创作为核心的艺术创作交流平台。
    
    树莓社的基本发展路线为：领导社员、团结全校、面向社会。以学习交流、创作实践为核心，坚持“百花齐放、百家争鸣”基本方针，坚持**民主集中制原则**，维护影视制作业务的核心地位。
    
    ### 核心业务
    1. 独立创作微电影，参加影视创作比赛；
    2. 拍摄活动短片、纪录片、宣传片；
    3. 校园新闻的拍摄、整合、发布。
    
    > “任何社团活动都必须以章程为根本准则，全体社员都必须承认章程的地位，并自觉维护章程的尊严、保证章程的落实。”
    
    ## 第一章 总纲
    
    **第一条** 本团体的名称为苏州中学树莓社。
    
    **第二条** 本团体的性质：由学生自愿结成的，非营利的，为学生提升自信和传播积极向上的人生观和价值观的学术性学生社团。
    """
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading) {
                    // SwiftUI 原生直接支持解析 LocalizedStringKey 里的 Markdown
                    Text(markdownContent)
                        .lineSpacing(6)
                        .font(.body)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("社团章程")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - 名人堂占位页面
struct HallOfFameView: View {
    var body: some View {
        List {
            Section(header: Text("第一届 (2018-2019)")) {
                Text("马雨璋 (创社社长)")
                Text("沈孙丰 (执行社长 / 联合创始人)")
            }
            Section(header: Text("第三届 (2020-2021)")) {
                Text("朱奕")
            }
            Section(header: Text("第七届 (2025-2026)")) {
                Text("杨梓言")
            }
        }
        .navigationTitle("社团名人堂")
    }
}

// MARK: - 卡片 UI 组件 (保持不变)
struct ActionCard: View {
    var title: String
    var subtitle: String
    var icon: String
    var iconColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(iconColor)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

// MARK: - 原有 WebView (保持不变)
struct WebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {}
}

#Preview {
    ContentView()
}
