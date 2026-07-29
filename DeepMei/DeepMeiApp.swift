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
                    // 后台预加载工作台数据，切到工作台 tab 时零等待
                    _ = await WorkbenchService.shared.fetchActivities()
                }
        }
    }
}
