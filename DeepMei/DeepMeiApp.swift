//
//  DeepMeiApp.swift
//  DeepMei
//
//  Created by 沈孙丰 on 2026/7/23.
//

import SwiftUI

@main
struct DeepMeiApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .task {
                    // 把手机端当前登录态同步给 Apple Watch
                    WatchSessionManager.shared.syncLoginState()

                    // 启动时并行预取，让第一次进入各页面即可命中缓存：
                    // 1. 工作台入口列表（切到工作台 tab 时零等待）
                    // 2. 社员资料快照（首次查询直接命中本地缓存，秒开 / 离线可用）
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask {
                            _ = await WorkbenchService.shared.fetchActivities()
                        }
                        group.addTask {
                            // 快照不存在或超过 24h 才刷新，避免每次启动都打全量接口
                            if !(await MemberSnapshotCache.shared.isFresh()) {
                                _ = await MemberSnapshotCache.shared.refresh()
                            }
                        }
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        // 回到前台时重试同步（手表 App 可能刚刚安装完成）
                        WatchSessionManager.shared.syncLoginState()
                    }
                }
        }
    }
}

/// 根门禁：未登录时整屏只显示登录页；登录成功后由 LoginManager 状态自动切回主界面。
/// （只做“挡在最前面”这一件事，不改变各页面原有的登录提示逻辑。）
struct AppRootView: View {
    @ObservedObject private var loginManager = LoginManager.shared

    var body: some View {
        if loginManager.isLoggedIn {
            ContentView()
        } else {
            LoginGateView()
        }
    }
}

/// 登录门：把现有登录表单放在 NavigationStack 根（没有可返回的上一页），
/// 登录成功置位 isLoggedIn 后，AppRootView 会自动替换为主界面。
struct LoginGateView: View {
    var body: some View {
        NavigationStack {
            LoginView()
        }
    }
}
