//
//  ActivityView.swift
//  DeepMei
//
//  活动页面 —— 内容与布局分离，方便单独管理。
//  想增删 / 修改活动，只需编辑本文件顶部的「活动内容数据」数组即可，
//  无需改动下面的页面布局代码。
//

import SwiftUI

// MARK: - 品牌色（如要换成树莓红等主题色，改这里一处即可）
private let activityAccent = Color.red

// MARK: - 数据模型
/// 一条社团活动。字段含义见下方「活动内容数据」区的注释。
struct ClubActivity: Identifiable {
    let id = UUID()
    let title: String          // 活动名称
    let subtitle: String       // 一句话简介（列表副标题）
    let dateText: String       // 展示用时间，如 "2026.09.01 周六 15:00"
    let location: String       // 活动地点
    let symbol: String         // 列表前导图标（SF Symbol 名称）
    let summary: String        // 详情页正文（支持用空行 \n\n 分段）
    var articleFileName: String? = nil  // 可选：关联树莓文库中的 .md 文章文件名（不含扩展名）
    var linkURL: String? = nil          // 可选：外部链接，如报名表 / 直播地址
}

// MARK: - 活动内容数据（在此管理 ✏️）
///
/// 新增活动：复制下面任意一个 ClubActivity(...) 整体，改掉里面的文字即可。
/// 删除活动：把对应整段 ClubActivity(...) 删掉。
/// 顺序：数组从上到下的顺序，就是 App 里列表从上到下的顺序。
/// 字段速查：
///   title          活动标题
///   subtitle       列表里显示的灰色小字
///   dateText       时间（直接写给人看的字符串，不用管格式）
///   location       地点
///   symbol         列表左侧图标，常用："calendar"、"film"、"camera"、"ticket"、"person.3"、"paintpalette"
///   summary        详情正文，\n\n 表示换一段
///   articleFileName 想跳转到某篇文库文章就填文件名（如 "constitution"），不跳就删掉这行
///   linkURL        想放报名/直播外链就填网址，不需要就删掉这行
private let activities: [ClubActivity] = [
    ClubActivity(
        title: "第八届社员大会",
        subtitle: "年度盛会 · 换届与展望",
        dateText: "2026.09.01 周六 15:00",
        location: "苏州中学道山厅",
        symbol: "person.3.sequence.fill",
        summary: "树莓社一年一度的全体社员大会。\n\n将回顾过去一年的影像创作与社团建设，公布新一届组委会名单，并发布新学年重点项目规划。欢迎新老社员到场，一起为树莓社写下新的篇章。",
        articleFileName: "SMS-RC_C8_President_Report_2026"
    ),
    ClubActivity(
        title: "迎新影像工作坊",
        subtitle: "零基础也能拍出好片子",
        dateText: "2026.09.15 周六 16:30",
        location: "创客空间 影视机房",
        symbol: "camera.fill",
        summary: "面向新社员的入门工作坊。\n\n从构图、运镜到手机剪辑，资深社员手把手带你完成第一条短片。现场提供拍摄设备，无需自带。\n\n结束后可凭作品参与「新人最佳镜头」评选。",
        linkURL: "https://example.com/signup-workshop"
    ),
    ClubActivity(
        title: "《识茶记》首映观影会",
        subtitle: "社团原创短片展映",
        dateText: "2026.10.06 周日 19:00",
        location: "图书馆报告厅",
        symbol: "film.fill",
        summary: "树莓社年度原创短片《识茶记》线下首映。\n\n映后设有导演交流环节，主创团队将分享从脚本到成片的幕后故事。座位有限，先到先得。",
        linkURL: "https://shumeiartworks.coze.site"
    ),
    ClubActivity(
        title: "校园寻访 · 城市影像计划",
        subtitle: "用镜头记录苏州",
        dateText: "2026.10.20 周六 全天",
        location: "校内集合 · 校外采风",
        symbol: "map.fill",
        summary: "延续「用流动的影像传承历史」的理念，走出校园记录城市与人。\n\n以小组为单位完成主题拍摄任务，优秀作品将收录进树莓社年度影像档案，并在公众号展出。",
        articleFileName: "raspberry-club-speech"
    )
]

// MARK: - 活动列表页
struct ActivityView: View {
    var body: some View {
        NavigationStack {
            Group {
                if activities.isEmpty {
                    ContentUnavailableView(
                        "暂无活动",
                        systemImage: "calendar",
                        description: Text("活动正在筹备中，敬请期待")
                    )
                } else {
                    List {
                        ForEach(activities) { activity in
                            NavigationLink {
                                ActivityDetailView(activity: activity)
                            } label: {
                                Label {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(activity.title)
                                            .font(.headline)
                                        Text(activity.subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        HStack(spacing: 4) {
                                            Image(systemName: "clock")
                                                .imageScale(.small)
                                            Text(activity.dateText)
                                                .font(.caption)
                                        }
                                        .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 4)
                                } icon: {
                                    Image(systemName: activity.symbol)
                                        .symbolRenderingMode(.hierarchical)
                                        .foregroundStyle(activityAccent)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(activity.title)，\(activity.subtitle)")
                            .accessibilityHint("查看活动详情")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("活动")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - 活动详情页
struct ActivityDetailView: View {
    let activity: ClubActivity

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 标题区
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        Text(activity.dateText)
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .foregroundStyle(activityAccent)

                    Text(activity.title)
                        .font(.largeTitle.bold())

                    Label {
                        Text(activity.location)
                            .font(.subheadline)
                    } icon: {
                        Image(systemName: "mappin.and.ellipse")
                    }
                    .foregroundStyle(.secondary)
                }

                // 正文
                Text(activity.summary)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                // 关联文章入口
                if let articleFileName = activity.articleFileName {
                    NavigationLink {
                        MarkdownArticleView(fileName: articleFileName)
                    } label: {
                        Label("阅读相关文章", systemImage: "doc.text.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                // 外部链接入口
                if let linkURL = activity.linkURL, let url = URL(string: linkURL) {
                    Link(destination: url) {
                        Label("前往报名 / 查看", systemImage: "arrow.up.right.square.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(activityAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("活动详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ActivityView()
}
