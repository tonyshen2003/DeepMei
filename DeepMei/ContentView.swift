//
//  ContentView.swift
//  DeepMei
//
//  Created by 沈孙丰 on 2026/7/23.
//

import SwiftUI
import WebKit


struct ContentView: View {
    var body: some View {
        TabView {
            // MARK: - 探索
            HomeNavigationView()
                .tabItem {
                    Label(
                        "探索",
                        systemImage: "safari.fill"
                    )
                }



            // MARK: - 文章 / 章程

            ArticleListView()
                .tabItem {
                    Label(
                        "文章",
                        systemImage: "book.pages.fill"
                    )
                }
            // MARK: - 官网

            WebView(
                url: URL(
                    string: "https://szzxshumei.com/"
                )!
            )
            .ignoresSafeArea(edges: .bottom)
            .tabItem {
                Label(
                    "官网",
                    systemImage: "globe.asia.australia.fill"
                )
            }



            // MARK: - 树莓酱

            WebView(
                url: URL(
                    string: "https://raspjam.com/"
                )!
            )
            .ignoresSafeArea()
            .tabItem {
                Label(
                    "树莓酱",
                    systemImage: "star.fill"
                )
            }

        }

    }
}




// MARK: - 首页

struct HomeNavigationView: View {


    @State private var showVideoCover = false

    @State private var showRegisterSheet = false



    var body: some View {


        NavigationStack {


            ScrollView {


                VStack(spacing: 20) {



                    VStack(spacing: 10) {


                        Image(systemName: "camera.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(.pink)


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







                    Button {


                        showVideoCover = true


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


            .navigationTitle("树莓社")



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





            .fullScreenCover(
                isPresented:
                    $showVideoCover
            ) {


                ZStack {


                    Color.black
                        .ignoresSafeArea()



                    VStack {


                        Spacer()



                        Text(
                            "光影长廊\n播放器开发中"
                        )
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                        Spacer()

                        Button(
                            "关闭"
                        ) {

                            showVideoCover = false

                        }

                        .buttonStyle(.borderedProminent)



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
                                "https://cqbxhfrnwy.coze.site/"
                            )!
                    )


                    .navigationTitle(
                        "社员登记"
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


        }


    }

}







// MARK: - Markdown文章列表

struct ArticleListView: View {


    var body: some View {


        NavigationStack {


            List {


                NavigationLink {


                    MarkdownArticleView(
                        fileName:
                            "constitution"
                    )


                } label: {


                    Label(
                        "苏州中学树莓社章程",
                        systemImage:
                            "doc.text"
                    )

                }



            }


            .navigationTitle(
                "文章"
            )

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
