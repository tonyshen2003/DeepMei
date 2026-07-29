//
//  ActivityData.swift
//  DeepMei
//
//  工作台「内容数据层」——数据模型与本地兜底数据。
//
//  设计目的：把工作台入口与 UI / 导航逻辑解耦，让入口集中管理。
//  日后新增 / 修改 / 删除入口，只需编辑本文件底部的 defaultActivities 列表，
//  不需要改动 WorkbenchView。
//

import Foundation

// MARK: - 跳转目标

/// 入口点击后的跳转目标。用枚举关联值而非裸 URL，使数据层完全不关心导航实现。
enum ActivityTarget: Hashable, Sendable {
    /// 打开网页（外部站点或内部页面，如签到 / 报名页）
    case webView(url: String, title: String)
    /// 打开应用内 Markdown 文章（如活动须知、活动回顾），fileName 不含 .md 扩展名
    case markdown(fileName: String, title: String)
}

// MARK: - 业务分组

/// 入口所属的业务分组，用于在页面内分区展示，并用品牌语义色着色图标容器。
enum ServiceGroup: String, CaseIterable, Sendable {
    case activity = "活动"
    case resource = "资源"
    case media   = "媒体"
}

// MARK: - 入口项

/// 单个入口的数据模型。
///
/// - Parameters:
///   - id:       唯一标识，用于列表 key（建议英文短名，如 "signup"）
///   - title:    入口标题
///   - subtitle: 一句话简介
///   - group:    所属业务分组，决定分区与图标容器配色
///   - common:   是否为高频入口，为 true 时置顶进入「常用」区并以强调卡片呈现
///   - iconKey:  图标关键字，UI 层据此映射为 SF Symbol（event/home/cloud/book/play/apps）
///   - target:   点击跳转目标
struct ActivityItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let group: ServiceGroup
    let common: Bool
    let iconKey: String
    let target: ActivityTarget

    init(id: String, title: String, subtitle: String = "",
         group: ServiceGroup = .activity, common: Bool = false,
         iconKey: String = "apps", target: ActivityTarget) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.group = group
        self.common = common
        self.iconKey = iconKey
        self.target = target
    }
}

// MARK: - 分组展示顺序

/// UI 层按此顺序对各分组做分区展示（活动 → 资源 → 媒体）。
let serviceGroupOrder: [ServiceGroup] = [.activity, .resource, .media]

// MARK: - 本地兜底数据

/// ★★★ 本地兜底数据 —— 网络不可用时的降级方案 ★★★
///
/// 工作台入口的权威数据源已迁移至飞书 Bitable（由 WorkbenchService 拉取）。
/// 本列表仅在以下情况使用：
/// - 首次加载飞书数据失败（网络不可达 / API 异常）
/// - 飞书表为空
///
/// 新增入口的正常流程：在飞书多维表格中添加记录。
/// 如需同步更新兜底数据，修改下面的列表即可。
///
/// 字段速查：
///   group   = ServiceGroup.activity / resource / media
///   common  = true（置顶强调） / false（默认）
///   iconKey = event / home / cloud / book / play / apps（默认）
///   target  = .webView(url: "https://...", title: "标题")
///           | .markdown(fileName: "文件名(不含.md)", title: "标题")
let defaultActivities: [ActivityItem] = [
    // —— 高频入口：置顶「常用」区 ——
    ActivityItem(
        id: "signup",
        title: "活动签到",
        subtitle: "贴 NFC 卡或扫码即可签到，活动现场使用",
        group: .activity,
        common: true,
        iconKey: "event",
        target: .webView(url: "https://cqbxhfrnwy.coze.site", title: "活动签到")
    ),
    // —— 活动分组 ——
    ActivityItem(
        id: "portal",
        title: "活动主页",
        subtitle: "社团活动总入口，报名与动态查看",
        group: .activity,
        iconKey: "home",
        target: .webView(url: "https://47.98.140.63:30000/", title: "活动主页")
    ),
    // —— 资源分组 ——
    ActivityItem(
        id: "webdrive",
        title: "树莓网盘",
        subtitle: "存储",
        group: .resource,
        iconKey: "cloud",
        target: .webView(url: "https://webdrive.szzxshumei.com/", title: "网盘")
    ),
    ActivityItem(
        id: "tech_lib",
        title: "树莓技术库",
        subtitle: "树莓社技术文档与资源库",
        group: .resource,
        iconKey: "book",
        target: .webView(url: "https://docs.szzxshumei.com/", title: "树莓技术库")
    ),
    // —— 媒体分组 ——
    ActivityItem(
        id: "BILI",
        title: "树莓B站",
        subtitle: "欢迎关注收看更多视频",
        group: .media,
        iconKey: "play",
        target: .webView(url: "https://space.bilibili.com/275501702", title: "视频")
    )
]
