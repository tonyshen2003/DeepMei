//
//  WorkbenchView.swift
//  DeepMei
//
//  工作台页面（底部导航「工作台」tab 的独立页面）。
//
//  数据来源：每次启动从飞书 Bitable 拉取（WorkbenchService.fetchActivities），
//  拉取失败时静默降级到 defaultActivities 本地兜底数据。
//
//  页面采用「常用置顶 + 按业务分组」的图标网格（飞书工作台范式）：
//  - common 为 true 的入口进入顶部「常用」区，以高强调背景呈现；
//  - 其余入口按 ServiceGroup 分区展示；
//  - 图标容器用圆角方形 + 品牌语义色（活动=red / 资源=blue / 媒体=green）。
//

import SwiftUI
import UIKit

// MARK: - 工作台主页

struct WorkbenchView: View {
    @State private var activities: [ActivityItem]? = nil
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("正在加载工作台…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let activities, activities.isEmpty {
                    ContentUnavailableView(
                        "暂无内容",
                        systemImage: "square.grid.2x2",
                        description: Text("请在飞书多维表格中添加入口")
                    )
                } else if let activities {
                    WorkbenchGrid(activities: activities)
                }
            }
            .navigationTitle("工作台")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            if let remote = await WorkbenchService.shared.fetchActivities() {
                activities = remote
            } else {
                activities = defaultActivities
            }
            isLoading = false
        }
    }
}

// MARK: - 网格布局

private struct WorkbenchGrid: View {
    let activities: [ActivityItem]

    private var commonItems: [ActivityItem] {
        activities.filter { $0.common }
    }

    private var grouped: [(ServiceGroup, [ActivityItem])] {
        serviceGroupOrder.compactMap { group in
            let items = activities.filter { !$0.common && $0.group == group }
            return items.isEmpty ? nil : (group, items)
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                if !commonItems.isEmpty {
                    Section {
                        ForEach(commonItems) { item in
                            EntryCard(item: item, common: true)
                        }
                    } header: {
                        SectionHeaderView("常用")
                    }
                }

                ForEach(grouped, id: \.0) { group, items in
                    Section {
                        ForEach(items) { item in
                            EntryCard(item: item, common: false)
                        }
                    } header: {
                        SectionHeaderView(group.rawValue)
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - 分组标题

private struct SectionHeaderView: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

// MARK: - 入口卡片（含导航分发）

private struct EntryCard: View {
    let item: ActivityItem
    let common: Bool

    var body: some View {
        switch item.target {
        case .webView(let url, let title, let hideTopBar, let fullscreenLandscape):
            NavigationLink {
                WebView(url: URL(string: url.contains("?") ? "\(url)&t=\(Date().timeIntervalSince1970)" : "\(url)?t=\(Date().timeIntervalSince1970)")!)
                    .ignoresSafeArea(edges: .bottom)
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .tabBar)
                    .toolbar(hideTopBar ? .hidden : .visible, for: .navigationBar)
                    .modifier(FullscreenLandscapeModifier(enabled: fullscreenLandscape))
            } label: {
                CardContent(item: item, common: common)
            }
            .buttonStyle(.plain)

        case .markdown(let fileName, _):
            NavigationLink {
                MarkdownArticleView(fileName: fileName)
                    .toolbar(.hidden, for: .tabBar)
            } label: {
                CardContent(item: item, common: common)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - 全屏横屏模式（适合云游戏等网页）

/// 按需强制横屏、隐藏系统栏并保持屏幕常亮；退出页面时全部还原。
private struct FullscreenLandscapeModifier: ViewModifier {
    let enabled: Bool

    @State private var wasIdleTimerDisabled = false

    func body(content: Content) -> some View {
        content
            .statusBarHidden(enabled)
            .persistentSystemOverlays(enabled ? .hidden : .automatic)
            .onAppear {
                guard enabled else { return }
                wasIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
                UIApplication.shared.isIdleTimerDisabled = true
                requestOrientation(.landscape)
            }
            .onDisappear {
                guard enabled else { return }
                UIApplication.shared.isIdleTimerDisabled = wasIdleTimerDisabled
                requestOrientation(.portrait)
            }
    }

    /// 通过 UIWindowScene 请求旋转（iOS 16+）。
    private func requestOrientation(_ orientation: UIInterfaceOrientationMask) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation)) { _ in }
    }
}

// MARK: - 卡片样式

private struct CardContent: View {
    let item: ActivityItem
    let common: Bool

    /// 分组 → 品牌语义色映射。
    private var groupColor: Color {
        switch item.group {
        case .activity: return .red
        case .resource: return .blue
        case .media:    return .green
        }
    }

    /// 图标 → SF Symbol 映射。
    private var iconName: String {
        switch item.iconKey {
        case "event": return "calendar"
        case "home":  return "house.fill"
        case "cloud": return "cloud.fill"
        case "book":  return "book.fill"
        case "play":  return "play.circle.fill"
        default:      return "square.grid.2x2.fill"
        }
    }

    /// 卡片底色：「常用」用高强调色背景；普通用毛玻璃底。
    private var cardBackground: some ShapeStyle {
        if common {
            return AnyShapeStyle(groupColor.opacity(0.12))
        } else {
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // 图标容器
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(groupColor)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            // 文字
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    WorkbenchView()
}
