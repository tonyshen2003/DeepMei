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
//  - 其余入口按分组配置分区展示（分组来自飞书「工作台分组配置」表，失败时用内置默认）；
//  - 分组决定图标容器颜色与默认图标；入口可单独覆盖图标，颜色始终跟随分组。
//

import SwiftUI
import UIKit

// MARK: - 工作台主页

struct WorkbenchView: View {
    @State private var activities: [ActivityItem]? = nil
    @State private var groups: [WorkbenchGroup] = defaultGroups
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
                    WorkbenchGrid(activities: activities, groups: groups)
                }
            }
            .navigationTitle("工作台")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            groups = await WorkbenchService.shared.fetchGroups()
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
    let groups: [WorkbenchGroup]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var commonItems: [ActivityItem] {
        activities.filter { $0.common }
    }

    /// 按配置表顺序分组；配置表中未出现的分组排到最后。
    private var grouped: [(WorkbenchGroup, [ActivityItem])] {
        var result: [(WorkbenchGroup, [ActivityItem])] = []
        var remaining = activities.filter { !$0.common }

        for group in groups {
            let items = remaining.filter { $0.group == group.name }
            if !items.isEmpty {
                result.append((group, items))
                remaining.removeAll { $0.group == group.name }
            }
        }

        let unknownNames = Array(Set(remaining.map(\.group))).sorted()
        for name in unknownNames {
            let items = remaining.filter { $0.group == name }
            let fallbackGroup = WorkbenchGroup(name: name, iconKey: "", colorKey: "", sort: groups.count + 1)
            result.append((fallbackGroup, items))
        }

        return result
    }

    /// 自适应列数：iPhone 保持两列；iPad 用更大的最小宽度，避免卡片过小。
    private var columns: [GridItem] {
        let minimum: CGFloat = horizontalSizeClass == .regular ? 220 : 150
        return [GridItem(.adaptive(minimum: minimum), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                if !commonItems.isEmpty {
                    Section {
                        ForEach(commonItems) { item in
                            EntryCard(item: item, common: true, groups: groups)
                        }
                    } header: {
                        SectionHeaderView("常用")
                    }
                }

                ForEach(grouped, id: \.0) { group, items in
                    Section {
                        ForEach(items) { item in
                            EntryCard(item: item, common: false, groups: groups)
                        }
                    } header: {
                        SectionHeaderView(group.name)
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
    let groups: [WorkbenchGroup]

    private var group: WorkbenchGroup? {
        groups.first { $0.name == item.group }
    }

    var body: some View {
        switch item.target {
        case .webView(let url, let title, let hideTopBar, let fullscreenLandscape):
            if let resolvedURL = Self.resolvedWebURL(url) {
                NavigationLink {
                    ImmersiveWebView(
                        url: resolvedURL,
                        title: title,
                        hideTopBar: hideTopBar,
                        fullscreenLandscape: fullscreenLandscape
                    )
                } label: {
                    CardContent(item: item, common: common, group: group)
                }
                .buttonStyle(.plain)
            } else {
                CardContent(item: item, common: common, group: group)
            }

        case .markdown(let fileName, _):
            NavigationLink {
                MarkdownArticleView(fileName: fileName)
            } label: {
                CardContent(item: item, common: common, group: group)
            }
            .buttonStyle(.plain)
        }
    }

    /// 拼接防缓存时间戳，并校验必须是 http/https 链接。
    /// 脏数据（换行符、相对路径、带空格 URL）不会进入 WebView，也不会触发强制解包崩溃。
    private static func resolvedWebURL(_ raw: String) -> URL? {
        let urlString = raw.contains("?")
            ? "\(raw)&t=\(Int(Date().timeIntervalSince1970))"
            : "\(raw)?t=\(Int(Date().timeIntervalSince1970))"
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }
}

// MARK: - 沉浸式网页容器

/// 全屏横屏 / 隐藏导航栏的网页容器。
///
/// iOS 没有 Android 那样的系统返回键，隐藏导航栏后必须提供显式返回出口：
/// 左上角悬浮半透明返回按钮（适配刘海屏安全区），同时保留 iOS 边缘右滑返回手势。
private struct ImmersiveWebView: View {
    let url: URL
    let title: String
    let hideTopBar: Bool
    let fullscreenLandscape: Bool

    var body: some View {
        WebView(url: url)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar(hideTopBar ? .hidden : .visible, for: .navigationBar)
            .modifier(FullscreenLandscapeModifier(enabled: fullscreenLandscape))
            .overlay {
                if hideTopBar {
                    GeometryReader { proxy in
                        VStack {
                            HStack {
                                FloatingBackButton()
                                    .padding(.leading, max(proxy.safeAreaInsets.leading, 12))
                                    .padding(.top, max(proxy.safeAreaInsets.top, 8))
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                }
            }
    }
}

/// 悬浮返回按钮：半透明黑底 + 白色返回箭头。
private struct FloatingBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.45), in: Circle())
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        }
        .accessibilityLabel("返回")
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
    let group: WorkbenchGroup?

    /// 分组颜色 key → 系统色映射（白名单，保证对比度与深色模式适配）。
    private var groupColor: Color {
        switch group?.colorKey {
        case "raspberry", "red": return Color(red: 148 / 255, green: 43 / 255, blue: 56 / 255) // 品牌树莓红 #942B38
        case "blue":       return .blue
        case "green":      return Color(red: 0.12, green: 0.56, blue: 0.25) // 加深绿，保证白图标对比度
        case "darkorange", "orange": return Color(red: 195 / 255, green: 74 / 255, blue: 0) // 加深橙 #C34A00
        case "purple":     return .purple
        default:           return .gray
        }
    }

    /// 图标 key → SF Symbol 映射；入口未填图标时使用分组默认图标。
    private var iconName: String {
        let key = item.iconKey.isEmpty ? (group?.iconKey ?? "") : item.iconKey
        switch key {
        case "event":         return "calendar"
        case "home":          return "house.fill"
        case "cloud":         return "cloud.fill"
        case "book":          return "book.fill"
        case "play":          return "play.circle.fill"
        case "gamecontroller": return "gamecontroller.fill"
        case "film":          return "film.fill"
        case "folder":        return "folder.fill"
        case "link":          return "link"
        default:              return "square.grid.2x2.fill"
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
