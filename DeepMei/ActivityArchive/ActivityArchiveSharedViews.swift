//
//  ActivityArchiveSharedViews.swift
//  DeepMei
//
//  活动记录模块共用的小组件：类型配色/短名、类型胶囊、统计条、全屏照片查看器。
//  配色与短名口径与微信小程序 activityTypes.ts 保持一致。
//

import SwiftUI

// MARK: - 类型视觉

enum ActivityVisual {
    /// 各活动类型的主题色（小程序同款，深浅色模式下均保持可读对比度）。
    static func color(for type: String?) -> Color {
        switch type {
        case "影视制作":
            return Color(red: 0.48, green: 0.17, blue: 0.75) // #7b2cbf
        case "校园新闻采编制作":
            return Color(red: 0.08, green: 0.50, blue: 0.29) // #157f4a
        case "数字媒体学习实践":
            return Color(red: 0.12, green: 0.44, blue: 0.92) // #1f6feb
        case "树莓社发展建设":
            return Color(red: 0.59, green: 0.43, blue: 0.04) // #976e09
        case "树莓社宣传工作":
            return Color(red: 0.58, green: 0.17, blue: 0.22) // #942b38
        default:
            return Color(red: 0.23, green: 0.25, blue: 0.28) // 灰系兜底
        }
    }

    /// 深色模式下更亮的同色系文字色，保证在近黑背景上仍可读（浅色模式仍用 color）。
    static func brightColor(for type: String?) -> Color {
        switch type {
        case "影视制作":
            return Color(red: 0.79, green: 0.64, blue: 0.95)
        case "校园新闻采编制作":
            return Color(red: 0.50, green: 0.83, blue: 0.66)
        case "数字媒体学习实践":
            return Color(red: 0.54, green: 0.71, blue: 1.0)
        case "树莓社发展建设":
            return Color(red: 0.89, green: 0.71, blue: 0.27)
        case "树莓社宣传工作":
            return Color(red: 0.95, green: 0.64, blue: 0.68)
        default:
            return Color(red: 0.72, green: 0.74, blue: 0.77)
        }
    }

    /// 类型胶囊短名（统一 4 字；未知类型保留原名，信息不丢）。
    static func shortLabel(for type: String?) -> String {
        switch type {
        case "影视制作":
            return "影视制作"
        case "校园新闻采编制作":
            return "新闻传媒"
        case "数字媒体学习实践":
            return "数媒技术"
        case "树莓社发展建设":
            return "发展建设"
        case "树莓社宣传工作":
            return "树莓宣传"
        case let .some(other):
            return other
        default:
            return "活动"
        }
    }
}

/// 类型胶囊：短名 + 主题色浅底（近似 iOS 标签的轻量表达）。
struct ActivityTypeBadge: View {
    let type: String?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let base = ActivityVisual.color(for: type)
        let textColor = colorScheme == .dark ? ActivityVisual.brightColor(for: type) : base
        Text(ActivityVisual.shortLabel(for: type))
            .font(.caption.weight(.medium))
            .foregroundStyle(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(base.opacity(0.14), in: Capsule())
    }
}

/// “志愿时长”标记。
struct ActivityVolunteerBadge: View {
    var body: some View {
        Label("志愿时长", systemImage: "clock.badge.checkmark")
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
    }
}

/// 列表行封面：有图走图片缓存；无图时用类型色渐变 + 左上角竖排日期，
/// 对齐小程序版“无封面日期块”的设计，不用干巴巴的单个字符占位。
struct ActivityListCover: View {
    let urlString: String?
    let type: String?
    let name: String
    let date: String

    var body: some View {
        if let urlString, !urlString.isEmpty {
            FeishuAsyncImage(
                urlString: urlString,
                placeholderName: name,
                contentMode: .fill,
                placeholderSystemImage: "photo"
            )
        } else {
            datePlaceholder
        }
    }

    private var datePlaceholder: some View {
        let color = ActivityVisual.color(for: type)
        return ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [color, color.mix(with: .white, by: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let (month, day) = monthDayParts {
                VStack(alignment: .leading, spacing: 0) {
                    Text(month)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                    Text(day)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                }
                .padding(6)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// "2026-09-05" → ("9月", "5")；无法解析时返回 nil。
    private var monthDayParts: (String, String)? {
        let parts = date.split(separator: "-")
        guard parts.count == 3,
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }
        return ("\(month)月", "\(day)")
    }
}

// MARK: - 数值格式化

extension Double {
    /// 整数不带小数位、非整数保留一位小数（时长展示用）。
    var cleanHoursText: String {
        if self == rounded() {
            return String(Int(self))
        }
        return String(format: "%.1f", self)
    }
}

// MARK: - 详情统计条

/// 参与 / 总时长 / 志愿时长 / 人均 四项统计。
struct ActivityStatsBar: View {
    let stats: ActivityStats?
    let hoursPer: Double

    private struct StatItem {
        let value: String
        let title: String
    }

    private var items: [StatItem] {
        guard let stats else { return [] }
        return [
            StatItem(value: String(stats.people), title: "参与人数"),
            StatItem(value: stats.totalHours.cleanHoursText, title: "总时长(h)"),
            StatItem(value: stats.volunteerHours.cleanHoursText, title: "志愿时长(h)"),
            StatItem(value: hoursPer.cleanHoursText, title: "人均时长(h)"),
        ]
    }

    var body: some View {
        if !items.isEmpty {
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 4) {
                        Text(item.value)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(item.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)

                    if item.title != items.last?.title {
                        Divider()
                            .frame(height: 28)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
}

/// 照片格按压反馈：轻微缩放 + 变淡（替代无反馈的 .plain）。
struct SqueezeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - 正文分段

/// “活动介绍 / 成果回顾 / 活动记录”正文段落。
struct ActivityTextSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 全屏照片查看器

/// 全屏浏览活动照片：原生翻页 + 关闭按钮，深色底显示 w1200 大图。
struct ActivityPhotoViewer: View {
    let photos: [ActivityPhotoItem]
    @State private var currentIndex: Int
    @State private var isReadyToShow = false
    private let requestedStartIndex: Int
    @Environment(\.dismiss) private var dismiss

    init(photos: [ActivityPhotoItem], startIndex: Int) {
        self.photos = photos
        requestedStartIndex = min(max(startIndex, 0), max(photos.count - 1, 0))
        // 先落在 0，等 TabView 完成首次布局后再跳目标页。
        // 直接给非 0 初值会被 PageTabViewStyle 忽略（SwiftUI 已知问题），表现为第一次总是第一张。
        _currentIndex = State(initialValue: 0)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if photos.isEmpty {
                ContentUnavailableView {
                    Label("暂无照片", systemImage: "photo.on.rectangle.angled")
                }
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                        ZStack {
                            // 跳到目标页前不加载；只加载当前页附近 1 张，避免翻页视图把全部 w1200 大图同时解码。
                            if isReadyToShow, abs(index - currentIndex) <= 1 {
                                FeishuAsyncImage(
                                    urlString: photo.full.isEmpty ? nil : photo.full,
                                    placeholderName: photo.name,
                                    contentMode: .fit,
                                    placeholderSystemImage: "photo",
                                    autoRetry: true
                                )
                                .padding(.vertical, 4)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .tag(index)
                        .accessibilityLabel(photo.name)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
                .opacity(isReadyToShow ? 1 : 0)
                .onAppear {
                    alignToRequestedPage()
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.55), in: Circle())
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
            .accessibilityLabel("关闭")
        }
        .overlay(alignment: .bottom) {
            if photos.count > 1 {
                Text("\(currentIndex + 1) / \(photos.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func alignToRequestedPage() {
        let target = min(max(requestedStartIndex, 0), max(photos.count - 1, 0))
        // 等当前布局结束后再设置，TabView 才会真正翻到目标页。
        DispatchQueue.main.async {
            currentIndex = target
            isReadyToShow = true
        }
    }
}
