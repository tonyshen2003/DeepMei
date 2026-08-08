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
            }
            .tabViewStyle(.page)
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    // 回到前台时重新向手机要一次最新登录态
                    WatchSessionManager.shared.refresh()
                }
            }
        }
    }
}
