//
//  ExternalLinkPolicy.swift
//  DeepMei
//
//  WebView 外部链接分发策略（与 Android 版 ExternalLinkPolicy 对齐）。
//
//  区分两类链接：
//  - http/https 普通网页链接 → 一律留在 WebView 内加载，不走外部；
//  - 网页自带的「打开 App」按钮（如 xhsdiscover://、snssdk:// 等自定义 scheme）
//    → 交给系统拉起对应 App。
//
//  只有命中白名单的自定义 scheme 才允许外跳，避免任意 scheme 被当作可执行动作。
//

import Foundation

enum ExternalLinkPolicy {

    /// 允许拉起外部 App 的自定义 scheme（小红书 / 抖音 / B站 / 微信 / QQ / 微博）。
    private static let customSchemes: Set<String> = [
        "xhsdiscover", "xhs",              // 小红书
        "snssdk1128", "snssdk", "douyin",  // 抖音
        "bilibili",                        // B站
        "weixin",                          // 微信
        "mqq",                             // QQ
        "sinaweibo"                        // 微博
    ]

    /// 判断 URL 是否属于「打开 App」类型的外部链接（仅自定义 scheme，不含 http/https）。
    static func shouldOpenExternally(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return customSchemes.contains(scheme)
    }
}
