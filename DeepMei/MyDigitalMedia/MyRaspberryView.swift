import SwiftUI
import Foundation
import UIKit

// MARK: - 1. 数据模型定义

/// 代表作品项（仅图片）
struct WorkItem: Identifiable, Equatable {
    var id: String { url }
    let url: String
    let type: WorkType
    let fileName: String

    enum WorkType: Equatable {
        case image
        case unsupported

        /// 常见图片格式
        private static let supportedImageExts: Set<String> = ["jpg", "jpeg", "png", "heic", "gif", "webp", "bmp", "tiff"]

        /// 通过文件名或 URL 扩展名判断类型
        static func detect(from fileNameOrURL: String) -> WorkType {
            let ext = (fileNameOrURL as NSString).pathExtension.lowercased()
            guard !ext.isEmpty else { return .unsupported }
            return supportedImageExts.contains(ext) ? .image : .unsupported
        }

        /// 综合 MIME 类型 + 文件名判断（MIME 优先，扩展名兜底）
        static func detect(mimeType: String, fileNameOrURL: String) -> WorkType {
            let lowerMime = mimeType.lowercased()
            if lowerMime.hasPrefix("image/") {
                return .image
            }
            return detect(from: fileNameOrURL)
        }
    }

    init(url: String, type: WorkType? = nil, fileName: String = "") {
        self.url = url
        self.type = type ?? .detect(from: fileName.isEmpty ? url : fileName)
        self.fileName = fileName.isEmpty ? (url as NSString).lastPathComponent : fileName
    }
}

struct RaspberryMember: Identifiable, Equatable, Decodable {
    var id: String { idCode }

    let name: String            // 姓名
    let alias: String
    let idCode: String          // 社员编号 (如 No.00001)
    let memberCode: String      // 社员识别码（无横线，如 SM201809A00100201）
    let generation: String      // 年级 (如 2018级)
    let clazz: String           // 班级
    let Birthday: Date
    let contactQQ: String
    let department: String      // 社团部门 (如 摄影部)
    let roles: String           // 社团职务 (如 树莓社社长)
    let rating: String          // 社员评级 (如 社团领袖)
    let honors: String          // 其他职务或荣誉
    let college: String         // 升学去向 (如 中国传媒大学)
    
    let joinDate: Date          // 入社日期 (解析 13 位时间戳)

    let activityCount: Int      // 参与活动次数
    let totalHours: Double      // 统计时长
    let description: String     // 详细介绍
    let photoURLs: [String]     // 个人照片 URL 列表
    let avatarURLs: [String]    // 头像 URL 列表（飞书「头像」字段，Android 同款）
    let works: [WorkItem]       // 代表作品列表（图片或视频）
    let loginPassword: String   // 登录密码（仅登录页比对使用）

    /// 头像：优先「头像」字段第一张，缺失时回退到个人照片第一张（与 Android 对齐）。
    var avatarURL: String? {
        avatarURLs.first(where: { !$0.isEmpty })
            ?? photoURLs.first(where: { !$0.isEmpty })
    }
    
    // 💡 格式化输出：提取入社年份 (如 "2018")
    var joinYearFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: joinDate)
    }
    
    // 💡 完整年月日输出 (如 "2018-09-12")
    var fullBirthdayFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Birthday)
    }

    // 💡 完整年月日输出 (如 "2018-09-12")
    var fullJoinDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: joinDate)
    }
}

// MARK: - 2. 针对飞书 JSON 格式的自定义解码器
extension RaspberryMember {
    enum CodingKeys: String, CodingKey {
        case name = "姓名"
        case alias = "别名"
        case idCode = "社员编号"
        case memberCode = "社员识别码"
        case generation = "年级"
        case clazz = "班级（分班后）"
        case Birthday = "生日"
        case contactQQ = "QQ"
        case department = "社团部门"
        case roles = "社团职务"
        case rating = "社员评级"
        case honors = "其他职务或荣誉"
        case college = "升学去向"
        case joinDate = "入社日期"
        case activityCount = "参与活动次数"
        case totalHours = "统计时长 (社团活动记录表)"
        case description = "详细介绍"
        case avatarList = "个人照片"
        case avatar = "头像"
        case ArtpicList = "代表作品"
        case loginPassword = "登录密码"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 基础字段解析
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        alias = try container.decodeIfPresent(String.self, forKey: .alias) ?? ""
        idCode = try container.decodeIfPresent(String.self, forKey: .idCode) ?? ""
        memberCode = try container.decodeIfPresent(String.self, forKey: .memberCode) ?? ""
        contactQQ = try container.decodeIfPresent(String.self, forKey: .contactQQ) ?? ""
        generation = try container.decodeIfPresent(String.self, forKey: .generation) ?? ""
        clazz = try container.decodeIfPresent(String.self, forKey: .clazz) ?? ""
        rating = try container.decodeIfPresent(String.self, forKey: .rating) ?? ""
        college = try container.decodeIfPresent(String.self, forKey: .college) ?? ""
        activityCount = try container.decodeIfPresent(Int.self, forKey: .activityCount) ?? 0
        totalHours = try container.decodeIfPresent(Double.self, forKey: .totalHours) ?? 0.0
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""

        // 1. 处理数组字段：社团部门 ( ["摄影部"] -> "摄影部" )
        if let deptArray = try? container.decode([String].self, forKey: .department) {
            department = deptArray.joined(separator: "、")
        } else {
            department = (try? container.decode(String.self, forKey: .department)) ?? "无"
        }

        // 2. 处理数组字段：社团职务 ( ["树莓社社长", "摄影部部长"] -> "树莓社社长" )
        if let rolesArray = try? container.decode([String].self, forKey: .roles) {
            roles = rolesArray.first ?? "社员"
        } else {
            roles = (try? container.decode(String.self, forKey: .roles)) ?? "社员"
        }

        // 3. 处理数组字段：其他职务或荣誉 ( ["荣誉A", "荣誉B"] -> "荣誉A, 荣誉B" )
        if let honorsArray = try? container.decode([String].self, forKey: .honors) {
            honors = honorsArray.joined(separator: " / ")
        } else {
            honors = (try? container.decode(String.self, forKey: .honors)) ?? "无"
        }

        // 4. 处理 13 位毫秒 Unix 时间戳：入社日期 ( 1536681600000 )
        if let timestamp = try? container.decode(Double.self, forKey: .joinDate) {
            let seconds = timestamp > 10000000000 ? timestamp / 1000.0 : timestamp
            joinDate = Date(timeIntervalSince1970: seconds)
        } else {
            joinDate = Date()
        }
        if let timestamp = try? container.decode(Double.self, forKey: .Birthday) {
            let seconds = timestamp > 10000000000 ? timestamp / 1000.0 : timestamp
            Birthday = Date(timeIntervalSince1970: seconds)
        } else {
            Birthday = Date()
        }
        // 5. 处理个人照片 (提取图片临时下载 URL 列表)
        if let photos = try? container.decode([[String: DynamicCodingProperty]].self, forKey: .avatarList) {
            let urls = photos.compactMap { $0["tmp_url"]?.stringValue ?? $0["url"]?.stringValue }
            photoURLs = urls
        } else {
            photoURLs = []
        }

        // 5b. 处理头像（飞书「头像」字段，独立于个人照片）
        if let avatars = try? container.decode([[String: DynamicCodingProperty]].self, forKey: .avatar) {
            avatarURLs = avatars.compactMap { $0["tmp_url"]?.stringValue ?? $0["url"]?.stringValue }
        } else if let avatarString = try? container.decode(String.self, forKey: .avatar),
                  !avatarString.isEmpty {
            avatarURLs = [avatarString]
        } else {
            avatarURLs = []
        }
        
        // 6. 处理作品（仅保留图片）
        if let items = try? container.decode([[String: DynamicCodingProperty]].self, forKey: .ArtpicList) {
            works = items.compactMap { dict in
                let urlString = dict["tmp_url"]?.stringValue ?? dict["url"]?.stringValue
                guard let urlString = urlString, !urlString.isEmpty else { return nil }
                let name = dict["name"]?.stringValue ?? ""
                let mimeType = dict["type"]?.stringValue ?? ""
                let type = WorkItem.WorkType.detect(mimeType: mimeType, fileNameOrURL: name.isEmpty ? urlString : name)
                return WorkItem(url: urlString, type: type, fileName: name)
            }
        } else {
            works = []
        }
        loginPassword = try container.decodeIfPresent(String.self, forKey: .loginPassword) ?? ""
    }
}

// 辅助结构：用于灵活解码照片对象中的 URL 字符串
private struct DynamicCodingProperty: Codable {
    var stringValue: String?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        stringValue = try? container.decode(String.self)
    }
}
// MARK: - 2. 主页面视图
struct MyRaspberryView: View {
    @ObservedObject private var loginManager = LoginManager.shared

    @State private var members: [RaspberryMember] = []
    @State private var selectedIndex: Int = -1

    // 查询状态管理
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var notFound: Bool = false
    @State private var serviceError: String?
    @State private var isRefreshingSnapshot = false
    @State private var refreshMessage: String?
    @FocusState private var isFocused: Bool

    private var selectedMember: RaspberryMember? {
        guard selectedIndex >= 0, selectedIndex < members.count else { return nil }
        return members[selectedIndex]
    }

    var body: some View {
        if loginManager.isLoggedIn {
            myRaspberryContent
        } else {
            NavigationStack {
                LoginPromptView()
            }
        }
    }

    private var myRaspberryContent: some View {
            NavigationStack {
                Group {
                    if isSearching {
                        ProgressView("正在查询社员档案...")
                            .controlSize(.large)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let selectedMember {
                        ScrollView {
                            VStack(spacing: 20) {
                                MemberProfileCard(member: selectedMember)
                                
                                // 底部品牌标识
                                Image("DigitalMedia-Line")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 140)
                                    .accessibilityHidden(true)
                                    .padding(.top, 12)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                        .background(Color(uiColor: .systemGroupedBackground))
                        .transition(.opacity)
                    } else if !members.isEmpty {
                        // 重名候选列表：多结果时停留在此，点选后进入详情
                        MemberCandidateList(members: members) { index in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                selectedIndex = index
                            }
                        }
                        .transition(.opacity)
                    } else if notFound {
                        // 符合 iOS 规范的整页空状态提示
                        ContentUnavailableView {
                            Label("未找到该社员", systemImage: "person.slash.fill")
                        } description: {
                            Text("请核对输入的社员姓名或编号（如 No.00001）后重新搜索")
                        } actions: {
                            Button("重新搜索") {
                                searchText = ""
                                notFound = false
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else if let serviceError {
                        ContentUnavailableView {
                            Label("服务异常", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text(serviceError)
                        } actions: {
                            Button("重试") {
                                performSearch()
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        // 默认初始引导状态
                        ContentUnavailableView {
                            Label("身份识别", systemImage: "person.crop.rectangle.badge.plus")
                        } description: {
                            Text("在上方搜索框输入社员姓名或认证识别码以检索履历")
                        }
                    }
                }
                .navigationTitle("我的树莓")
                .navigationBarTitleDisplayMode(.large)
                // 💡 改用苹果原生 searchable，适配系统搜索交互
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "例如: 树莓酱 或 No.00000"
                )
                .onSubmit(of: .search) {
                    performSearch()
                }
                .toolbar {
                    // 详情页返回候选列表（重名时）
                    if selectedMember != nil, members.count > 1 {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    selectedIndex = -1
                                }
                            } label: {
                                Label("候选列表", systemImage: "chevron.left")
                            }
                        }
                    }

                    // 退出登录（与 Android 工具栏一致）
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            LoginManager.shared.logout()
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                        .accessibilityLabel("退出登录")
                    }

                    // 手动刷新社员资料快照
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            refreshSnapshot()
                        } label: {
                            if isRefreshingSnapshot {
                                ProgressView()
                            } else {
                                Label("刷新社员资料", systemImage: "arrow.clockwise")
                            }
                        }
                        .disabled(isRefreshingSnapshot)
                    }

                    if selectedMember != nil {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                resetSearch()
                            } label: {
                                Label("重新查询", systemImage: "arrow.counterclockwise")
                            }
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    if let refreshMessage {
                        Text(refreshMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.75), in: Capsule())
                            .padding(.bottom, 24)
                            .transition(.opacity)
                    }
                }
            }
    }

    // MARK: 交互逻辑
    private func resetSearch() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            members = []
            selectedIndex = -1
            searchText = ""
            notFound = false
        }
    }

    private func performSearch() {
        isFocused = false
        isSearching = true
        notFound = false
        serviceError = nil

        let query = searchText
        Task {
            do {
                // 快照缓存优先（秒开、离线可用）；都返回全部精确匹配，重名时由界面给出候选列表
                let cached = await MemberSnapshotCache.shared.findMembers(query: query)
                let results: [RaspberryMember]
                if !cached.isEmpty {
                    results = cached
                    // 快照过期：先用旧数据展示，后台静默刷新
                    if !(await MemberSnapshotCache.shared.isFresh()) {
                        Task { _ = await MemberSnapshotCache.shared.refresh() }
                    }
                } else {
                    results = try await MemberService.shared.searchMembers(byNameOrCodeOrAlias: query)
                    // 本地快照未命中（如刚登记的新社员）：在线查到后立即后台刷新快照，下次即可秒开
                    if !results.isEmpty {
                        Task { _ = await MemberSnapshotCache.shared.refresh() }
                    }
                }
                await MainActor.run {
                    isSearching = false
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        if !results.isEmpty {
                            members = results
                            // 只有一条结果时直接进详情；多条时先停在候选列表
                            selectedIndex = results.count == 1 ? 0 : -1
                        } else {
                            members = []
                            selectedIndex = -1
                            notFound = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    serviceError = error.localizedDescription
                }
            }
        }
    }

    /// 手动刷新社员资料快照，并给出轻量反馈。
    private func refreshSnapshot() {
        guard !isRefreshingSnapshot else { return }
        isRefreshingSnapshot = true
        Task {
            let ok = await MemberSnapshotCache.shared.refresh()
            await MainActor.run {
                isRefreshingSnapshot = false
                withAnimation(.easeOut(duration: 0.2)) {
                    refreshMessage = ok ? "社员资料已更新" : "刷新失败，请检查网络"
                }
                Task {
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    withAnimation(.easeIn(duration: 0.25)) {
                        refreshMessage = nil
                    }
                }
            }
        }
    }
}

// MARK: - 2.5 重名候选列表

private struct MemberCandidateList: View {
    let members: [RaspberryMember]
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("找到 \(members.count) 位社员，请选择")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 4)

                ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                    Button {
                        onSelect(index)
                    } label: {
                        HStack(spacing: 12) {
                            Group {
                                if let avatarURL = member.avatarURL, URL(string: avatarURL) != nil {
                                    FeishuAsyncImage(
                                        urlString: avatarURL,
                                        placeholderName: member.name,
                                        contentMode: .fill
                                    )
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(Color.accentColor.gradient)
                                        Text(String(member.name.prefix(1)))
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(member.name)
                                        .font(.headline)
                                    if !member.alias.isEmpty {
                                        Text("(\(member.alias))")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text([member.generation, member.clazz, member.department]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " · "))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 8)

                            Text(member.idCode)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(12)
                        .background(
                            Color(uiColor: .secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: - 3. 社员档案卡片组件
struct MemberProfileCard: View {
    let member: RaspberryMember
    @State private var copyFeedback: String?

    var body: some View {
        VStack(spacing: 0) {
            // 1. 照片轮播
            if !member.photoURLs.isEmpty {
                PhotoCarouselView(urls: member.photoURLs)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding([.top, .horizontal], 16)
            }
            
            // 2. 身份头部区
            HStack(spacing: 16) {
                if let avatarURLString = member.avatarURL, URL(string: avatarURLString) != nil {
                    FeishuAsyncImage(urlString: member.avatarURL, placeholderName: member.name, contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
                } else {
                    placeholderAvatar
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text(member.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                        if !member.alias.isEmpty{
                            Text("(\(member.alias))")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        // 评级徽章：按「社员评级」展示对应图标与颜色（无评级或脏数据不显示）
                        if let badge = RatingBadge(rawValue: member.rating) {
                            Image(systemName: badge.systemImage)
                                .symbolRenderingMode(.monochrome)
                                .foregroundStyle(.white)
                                .font(.caption)
                                .frame(width: 20, height: 20)
                                .background(badge.color, in: Circle())
                                .accessibilityLabel(badge.accessibilityLabel)
                        }
                    }
                    
                    Text("\(member.generation) \(member.clazz) · \(member.department)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text(member.idCode)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
            .padding(16)
      
            Divider()
                .padding(.horizontal, 16)
            
            // 3. 核心数据统计区
            HStack(spacing: 0) {
                StatView(title: "参与活动", value: "\(member.activityCount)", unit: "次")
                Divider().frame(height: 28)
                StatView(title: "志愿时长", value: String(format: "%.0f", member.totalHours), unit: "h")
                Divider().frame(height: 28)
                StatView(title: "入社年份", value: member.joinYearFormatted, unit: "年")
            }
            .padding(.vertical, 14)
            
            Divider()
                .padding(.horizontal, 16)
            
            // 4. 详细履历区
            // 第三部分：履历详情区
            VStack(alignment: .leading, spacing: 16) { // 💡 指定 alignment: .leading
                if !member.fullBirthdayFormatted.isEmpty {
                    DetailRow(icon: "birthday.cake.fill", title: "生日", content: member.fullBirthdayFormatted, tint: .pink)
                }
                if !member.contactQQ.isEmpty {
                    DetailRow(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "QQ",
                        content: member.contactQQ,
                        tint: .blue,
                        onCopy: {
                            UIPasteboard.general.string = member.contactQQ
                            showCopyFeedback("QQ 已复制")
                        }
                    )
                }
                if !member.roles.isEmpty {
                    DetailRow(icon: "briefcase.fill", title: "社团职务", content: member.roles, tint: .orange)
                }
                if !member.honors.isEmpty {
                    DetailRow(icon: "star.fill", title: "荣誉/其他职务", content: member.honors, tint: .yellow)
                }

                if !member.college.isEmpty {
                    DetailRow(icon: "graduationcap.fill", title: "升学去向", content: member.college, tint: .green)
                }

                if !member.description.isEmpty {
                    DetailRow(icon: "text.quote", title: "社员简介", content: member.description, tint: .purple)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading) // 💡 确保整个列表区撑满卡片
            .padding(16)

            // 5. 代表作品集
            if !member.works.isEmpty {
                Divider()
                    .padding(.horizontal, 16)
                WorkGridSection(works: member.works)
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        .overlay(alignment: .bottom) {
            if let copyFeedback {
                Text(copyFeedback)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.75), in: Capsule())
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
    }

    private func showCopyFeedback(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            copyFeedback = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeIn(duration: 0.25)) {
                copyFeedback = nil
            }
        }
    }

    private var placeholderAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.gradient)
                .frame(width: 64, height: 64)
            
            Text(String(member.name.prefix(1)))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - 评级徽章

/// 把「社员评级」映射为徽章（对标 Android ratingBadge）；空值 / 脏数据不显示。
private struct RatingBadge {
    let systemImage: String
    let color: Color
    let accessibilityLabel: String

    init?(rawValue: String) {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "社团领袖":
            self.init(systemImage: "crown.fill", color: Color(red: 0.79, green: 0.64, blue: 0.15), accessibilityLabel: "社团领袖")
        case "核心社员":
            self.init(systemImage: "checkmark.seal.fill", color: Color(red: 0.58, green: 0.17, blue: 0.22), accessibilityLabel: "核心社员")
        case "活跃社员":
            self.init(systemImage: "sparkles", color: Color(red: 0.27, green: 0.37, blue: 0.55), accessibilityLabel: "活跃社员")
        case "普通社员":
            self.init(systemImage: "person.fill", color: Color(red: 0.42, green: 0.45, blue: 0.50), accessibilityLabel: "普通社员")
        default:
            return nil
        }
    }

    private init(systemImage: String, color: Color, accessibilityLabel: String) {
        self.systemImage = systemImage
        self.color = color
        self.accessibilityLabel = accessibilityLabel
    }
}

struct PhotoCarouselView: View {
    let urls: [String]
    @State private var selection = 0
    @State private var viewerPresented = false
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selection) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    FeishuAsyncImage(urlString: url, placeholderName: "照片", contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())        // 保证整个区域可点击
                        .onTapGesture { viewerPresented = true }
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: urls.count > 1 ? .always : .never))
            
            if urls.count > 1 {
                Text("\(selection + 1) / \(urls.count)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                .padding(10)
            }
        }
        .fullScreenCover(isPresented: $viewerPresented) {
            ImageViewer(urls: urls, initialIndex: selection)
        }
    }
}

// MARK: - 全屏图片查看器（支持多图左右滑动切换）

struct ImageViewer: View {
    let urls: [String]
    @State private var selection: Int
    @Environment(\.dismiss) var dismiss

    init(urls: [String], initialIndex: Int = 0) {
        self.urls = urls
        _selection = State(initialValue: min(max(initialIndex, 0), max(urls.count - 1, 0)))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    ZoomableImageView(url: url)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // 页码指示器（多图时显示）
            if urls.count > 1 {
                Text("\(selection + 1) / \(urls.count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundColor(.white)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(.black.opacity(0.5), in: Capsule())
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 28)
            }

            // 关闭按钮
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding()
                    }
                    .accessibilityLabel("关闭")
                }
                Spacer()
            }
        }
    }
}

/// 单张图片查看：黑底、双指缩放、放大后拖拽、双击放大/还原。
private struct ZoomableImageView: View {
    let url: String

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        FeishuAsyncImage(urlString: url, placeholderName: "加载中…", contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            // 双指缩放
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        let delta = value / lastScale
                        lastScale = value
                        scale = min(max(scale * delta, 0.5), 5.0)
                    }
                    .onEnded { _ in
                        lastScale = 1
                    }
            )
            // 单指拖拽（仅在放大时生效）
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard scale > 1 else { return }
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        lastOffset = offset
                    }
            )
            // 双击放大/还原
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3)) {
                    if scale > 1 {
                        scale = 1
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2.5
                    }
                }
            }
    }
}
    
    
// MARK: - 4. 辅助 UI 组件
struct StatView: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.bold())
                    .monospacedDigit()
                
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}




struct DetailRow: View {
    let icon: String
    let title: String
    let content: String
    let tint: Color
    var onCopy: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 标题行
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                    .frame(width: 20)
                
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                
                Spacer() // 💡 1. 加上 Spacer 撑开标题行宽度
            }

            // 内容文本（可复制时行尾显示复制按钮；按钮高度与文本行一致，避免撑高行距）
            HStack(alignment: .center, spacing: 8) {
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let onCopy {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("复制\(title)")
                }
            }
            .padding(.leading, 28)
        }
        // 💡 2. 核心修正：强制该组件占满父容器宽度，并统一靠左对齐
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}



// MARK: - 5. 代表作品集组件
struct WorkGridSection: View {
    let works: [WorkItem]
    @State private var viewerPresented = false
    @State private var selectedIndex = 0

    private var supportedWorks: [WorkItem] {
        works.filter { $0.type != .unsupported && !$0.url.isEmpty }
    }
    private var unsupportedCount: Int {
        works.count - supportedWorks.count
    }

    /// 与 Android ArtWorksGridSection 一致：两两一行，避免 Lazy 网格在滚动容器里的布局歧义。
    private var rows: [[WorkItem]] {
        stride(from: 0, to: supportedWorks.count, by: 2).map { start in
            Array(supportedWorks[start..<min(start + 2, supportedWorks.count)])
        }
    }

    /// 两列布局下作品卡的最大宽度（超过后不再拉宽）。
    private let maxCardWidth: CGFloat = 240
    private let gridSpacing: CGFloat = 20

    /// 作品卡宽度：两列各占可用宽度的一半，但不超过最大宽度。
    /// 布局常量：页面左右边距 16×2 + 本节内边距 16×2 + 列间距 [gridSpacing]。
    private var workCardWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let availableInner = screenWidth - 64
        let columnWidth = (availableInner - gridSpacing) / 2
        return min(columnWidth, maxCardWidth)
    }

    /// 4:3 照片比例。
    private var workCardHeight: CGFloat {
        workCardWidth * 3 / 4
    }

    /// 单张作品：与网格卡一致的最大宽度 + 4:3，保证任何场景宽度都被限制。
    private var singleWorkWidth: CGFloat {
        min(UIScreen.main.bounds.width - 64, maxCardWidth)
    }

    private var singleWorkHeight: CGFloat {
        singleWorkWidth * 3 / 4
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 标题行
            HStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.subheadline)
                    .foregroundStyle(.teal)
                Text("代表作品")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(supportedWorks.count) 件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            // 作品网格：单张全宽；多张两两一行
            if supportedWorks.count == 1 {
                ImageWorkCard(
                    work: supportedWorks[0],
                    width: singleWorkWidth,
                    height: singleWorkHeight
                ) {
                    selectedIndex = 0
                    viewerPresented = true
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                // 作品卡最大宽度 + 4:3 比例：避免宽屏下卡片被拉得过宽
                VStack(spacing: gridSpacing) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                        HStack(spacing: gridSpacing) {
                            ForEach(Array(row.enumerated()), id: \.element.id) { colIndex, work in
                                ImageWorkCard(
                                    work: work,
                                    width: workCardWidth,
                                    height: workCardHeight
                                ) {
                                    selectedIndex = rowIndex * 2 + colIndex
                                    viewerPresented = true
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.vertical, 8)
            }

            // 不支持格式提示
            if unsupportedCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                    Text("另有 \(unsupportedCount) 个文件格式不支持")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .fullScreenCover(isPresented: $viewerPresented) {
            ImageViewer(urls: supportedWorks.map(\.url), initialIndex: selectedIndex)
        }
    }
}

struct ImageWorkCard: View {
    let work: WorkItem
    let width: CGFloat
    let height: CGFloat
    let onTap: () -> Void

    var body: some View {
        FeishuAsyncImage(urlString: work.url, placeholderName: "作品", contentMode: .fill)
            .frame(width: width, height: height)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(uiColor: .separator), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
    }
}



#Preview {
    NavigationStack {
        MyRaspberryView()
    }
}
