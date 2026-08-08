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
    case webView(url: String, title: String, hideTopBar: Bool = false, fullscreenLandscape: Bool = false)
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
        subtitle: "贴NFC卡或扫码即可签到",
        group: .activity,
        common: true,
        iconKey: "event",
        target: .webView(url: "https://cqbxhfrnwy.coze.site", title: "活动签到")
    ),
    ActivityItem(
        id: "zhaoxin",
        title: "树莓招新",
        subtitle: "加入树莓谢谢喵",
        group: .activity,
        common: true,
        iconKey: "home",
        target: .webView(url: "https://szzxshumei.feishu.cn/share/base/form/shrcnw0A0uJ63KnhABpKyBJfLJV", title: "树莓招新")
    ),
    // —— 活动分组 ——
    ActivityItem(
        id: "questionnaire",
        title: "树莓酱问卷",
        subtitle: "分享你对文创的想法",
        group: .activity,
        iconKey: "event",
        target: .webView(url: "https://szzxshumei.feishu.cn/share/base/form/shrcnh1MRrXQ19SJx7KmzRmI5Rd", title: "树莓酱问卷")
    ),
    ActivityItem(
        id: "coming_of_age",
        title: "高三成人礼",
        subtitle: "照片合集",
        group: .activity,
        iconKey: "event",
        target: .webView(url: "https://szzxshumei.com/post/2026/2026-coming-of-age-ceremony/", title: "高三成人礼")
    ),
    ActivityItem(
        id: "sports_2019",
        title: "2019运动会",
        subtitle: "照片直播",
        group: .activity,
        iconKey: "play",
        target: .webView(url: "https://m.inmuu.com/v1/photolive/news/143862", title: "2019运动会")
    ),
    ActivityItem(
        id: "cloud_genshin",
        title: "云原神",
        subtitle: "",
        group: .activity,
        iconKey: "apps",
        target: .webView(url: "https://ys.mihoyo.com/cloud/#/", title: "云原神", hideTopBar: true, fullscreenLandscape: true)
    ),
    ActivityItem(
        id: "cloud_starrail",
        title: "云·星穹铁道",
        subtitle: "",
        group: .activity,
        iconKey: "apps",
        target: .webView(url: "https://sr.mihoyo.com/cloud/#/", title: "云·星穹铁道", hideTopBar: true, fullscreenLandscape: true)
    ),
    ActivityItem(
        id: "arknights",
        title: "明日方舟",
        subtitle: "",
        group: .activity,
        iconKey: "apps",
        target: .webView(url: "https://cg.163.com/static/game/mrfz?sourcepage=cg&show=mrfz&back=https%3A%2F%2Fcg.163.com%2Findex.html%23%2Fsearch%3Fkey%3D%25E6%2598%258E%25E6%2597%25A5%25E6%2596%25B9%25E8%2588%259F", title: "明日方舟", hideTopBar: true, fullscreenLandscape: true)
    ),
    ActivityItem(
        id: "cloud_zzz",
        title: "云绝区零",
        subtitle: "",
        group: .activity,
        iconKey: "apps",
        target: .webView(url: "https://zzz.mihoyo.com/cloud/#/", title: "云绝区零", hideTopBar: true, fullscreenLandscape: true)
    ),
    ActivityItem(
        id: "tedx_2020",
        title: "Tedxsuzhou2020",
        subtitle: "",
        group: .activity,
        iconKey: "cloud",
        target: .webView(url: "https://muuau2np7o.zhaopianzhibo.com/v1/photolive/news/697599", title: "Tedxsuzhou2020")
    ),
    ActivityItem(
        id: "school_115",
        title: "115校庆",
        subtitle: "",
        group: .activity,
        iconKey: "cloud",
        target: .webView(url: "https://muuky2nnda.zhaopianzhibo.com/v1/photolive/news/229601", title: "115校庆")
    ),
    ActivityItem(
        id: "olympic_2021",
        title: "2021奥体运动会",
        subtitle: "",
        group: .activity,
        iconKey: "cloud",
        target: .webView(url: "https://m.inmuu.com/v1/photolive/news/1322531", title: "2021奥体运动会")
    ),
    // —— 资源分组 ——
    ActivityItem(
        id: "webdrive",
        title: "树莓网盘",
        subtitle: "存储（好像坏了）",
        group: .resource,
        iconKey: "cloud",
        target: .webView(url: "https://webdrive.szzxshumei.com/", title: "树莓网盘")
    ),
    ActivityItem(
        id: "tech_lib",
        title: "树莓技术库",
        subtitle: "树莓社技术文档与资源库",
        group: .resource,
        iconKey: "book",
        target: .webView(url: "https://docs.szzxshumei.com/", title: "树莓技术库")
    ),
    ActivityItem(
        id: "aiccrop",
        title: "aiccrop",
        subtitle: "",
        group: .resource,
        iconKey: "cloud",
        target: .webView(url: "https://auth.aiccrop.com/", title: "aiccrop")
    ),
    ActivityItem(
        id: "szzx1000",
        title: "苏州中学官网",
        subtitle: "",
        group: .resource,
        iconKey: "cloud",
        target: .webView(url: "https://www.szzx1000.cn/", title: "苏州中学官网")
    ),
    // —— 媒体分组 ——
    ActivityItem(
        id: "website",
        title: "社团官网",
        subtitle: "szzxshumei.com",
        group: .media,
        iconKey: "home",
        target: .webView(url: "https://szzxshumei.com", title: "社团官网")
    ),
    ActivityItem(
        id: "bili",
        title: "树莓B站",
        subtitle: "欢迎关注收看更多视频",
        group: .media,
        iconKey: "play",
        target: .webView(url: "https://space.bilibili.com/275501702", title: "视频")
    ),
    ActivityItem(
        id: "raspjam",
        title: "树莓酱官网",
        subtitle: "关注树莓酱",
        group: .media,
        iconKey: "cloud",
        target: .webView(url: "https://raspjam.com/", title: "树莓酱官网")
    ),
    ActivityItem(
        id: "xhs",
        title: "树莓酱酱酱",
        subtitle: "小红书",
        group: .media,
        iconKey: "cloud",
        target: .webView(url: "https://xhslink.cn/m/5jNVMA3I7AG", title: "树莓酱酱酱")
    ),
    ActivityItem(
        id: "douyin",
        title: "苏中学生传媒",
        subtitle: "抖音",
        group: .media,
        iconKey: "apps",
        target: .webView(url: "https://v.douyin.com/K4-bCE1NmTA/", title: "苏中学生传媒")
    )
]
