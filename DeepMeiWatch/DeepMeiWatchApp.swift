//
//  DeepMeiWatchApp.swift
//  DeepMeiWatch
//
//  Created by 沈孙丰 on 2026/8/7.
//

import SwiftUI

@main
struct DeepMeiWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TabView {
                EmojiWatchView()
                    .tag(0)

                ProfileWatchView()
                    .tag(1)

                MemberQRWatchView()
                    .tag(2)
            }
            // watchOS 10+ 以 Digital Crown 纵向翻页为主，触摸滑动仍可用
            .tabViewStyle(.verticalPage)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    // 回到前台时重新向手机要一次最新登录态
                    WatchSessionManager.shared.refresh()
                }
            }
        }
    }
}
