//
//  DeepMeiApp.swift
//  DeepMei
//
//  Created by 沈孙丰 on 2026/7/23.
//

import SwiftUI

@main
struct DeepMeiApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
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
        }
    }
}
