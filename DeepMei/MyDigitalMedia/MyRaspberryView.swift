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
        func isValid(_ s: String) -> Bool {
            guard let url = URL(string: s), let scheme = url.scheme?.lowercased() else { return false }
            return scheme == "http" || scheme == "https"
        }
        return avatarURLs.first(where: isValid)
            ?? photoURLs.first(where: isValid)
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
    @State private var notFoundMessage = "请核对输入的社员姓名或编号（如 No.00001）后重新搜索"
    @State private var serviceError: String?
    @State private var isRefreshingSnapshot = false
    @State private var refreshMessage: String?
    @State private var isReadingNFC = false
    @FocusState private var isFocused: Bool
    @Namespace private var viewerNamespace
    @State private var viewerRoute: ImageViewerRoute?

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
                                MemberProfileCard(
                                    member: selectedMember,
                                    namespace: viewerNamespace,
                                    viewerRoute: $viewerRoute
                                )
                                
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
                            Text(notFoundMessage)
                        } actions: {
                            Button("重新搜索") {
                                searchText = ""
                                notFound = false
                                notFoundMessage = "请核对输入的社员姓名或编号（如 No.00001）后重新搜索"
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
                            Text("在上方搜索框输入社员姓名或认证识别码，或点右上角 NFC 图标贴卡识别")
                        }
                    }
                }
                .navigationTitle("社员查询")
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

                    // NFC 贴卡识别（与 Android「将社员卡贴近手机背面自动识别」对齐）
                    if NFCUIDReader.isReadingAvailable {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: startNFCRead) {
                                if isReadingNFC {
                                    ProgressView()
                                } else {
                                    Image(systemName: "wave.3.right")
                                }
                            }
                            .disabled(isReadingNFC)
                            .accessibilityLabel("贴卡识别")
                            .accessibilityHint("将社员卡靠近 iPhone 后自动查询")
                        }
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
                .navigationDestination(item: $viewerRoute) { route in
                    ImageViewer(
                        urls: route.urls,
                        initialIndex: route.initialIndex,
                        sourceID: route.sourceID,
                        namespace: viewerNamespace
                    )
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
            notFoundMessage = "请核对输入的社员姓名或编号（如 No.00001）后重新搜索"
        }
    }

    private func performSearch() {
        isFocused = false
        isSearching = true
        notFound = false
        notFoundMessage = "请核对输入的社员姓名或编号（如 No.00001）后重新搜索"
        serviceError = nil

        let query = searchText
        Task {
            do {
                // 三级查询链路（与 Android 2.8.5 对齐）：
                // 1. 本地快照命中 → 直接返回（秒开，日常路径）；
                // 2. 未命中且快照过期/缺失 → 刷新 KV 全量快照（Worker /api/members/full）后再查本地；
                // 3. 仍未命中 → 飞书实时兜底（覆盖刚登记、自动化刷新尚未生效的新社员），
                //    保证确实查无此人时才报"未找到"，不因快照短暂陈旧而误报。
                // 都返回全部精确匹配，重名时由界面给出候选列表。
                let cached = await MemberSnapshotCache.shared.findMembers(query: query)
                var results: [RaspberryMember] = cached
                var fromSnapshot = !cached.isEmpty
                if results.isEmpty {
                    if !(await MemberSnapshotCache.shared.isFresh()) {
                        _ = await MemberSnapshotCache.shared.refresh()
                        results = await MemberSnapshotCache.shared.findMembers(query: query)
                        fromSnapshot = !results.isEmpty
                    }
                    if results.isEmpty {
                        results = try await MemberService.shared.searchMembers(byNameOrCodeOrAlias: query)
                        fromSnapshot = false
                    }
                }
                // 结果来自飞书实时兜底（如刚登记的新社员）：后台补刷快照，下次即可秒开
                if !fromSnapshot && !results.isEmpty {
                    Task { _ = await MemberSnapshotCache.shared.refresh() }
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

    // MARK: - NFC 贴卡识别

    private func startNFCRead() {
        guard !isReadingNFC else { return }
        isReadingNFC = true
        Task {
            do {
                let cardId = try await NFCUIDReader.shared.readUID()
                isReadingNFC = false
                lookupByCardId(cardId)
            } catch NFCReadError.canceled {
                isReadingNFC = false
            } catch {
                isReadingNFC = false
                showToast("NFC 读取失败：\(error.localizedDescription)")
            }
        }
    }

    private func lookupByCardId(_ cardId: String) {
        isSearching = true
        notFound = false
        serviceError = nil
        Task {
            do {
                // 三级查询链路（与 Android 2.8.5 对齐）：本地快照 → KV 全量刷新 → 飞书实时兜底
                let cached = await MemberSnapshotCache.shared.findMemberByCard(cardId: cardId)
                var found: RaspberryMember? = cached
                var fromSnapshot = cached != nil
                if found == nil {
                    if !(await MemberSnapshotCache.shared.isFresh()) {
                        _ = await MemberSnapshotCache.shared.refresh()
                        found = await MemberSnapshotCache.shared.findMemberByCard(cardId: cardId)
                        fromSnapshot = found != nil
                    }
                    if found == nil {
                        found = try await MemberService.shared.searchByCardId(cardId: cardId)
                        fromSnapshot = false
                    }
                }
                await MainActor.run {
                    isSearching = false
                    if let found {
                        // 结果来自飞书实时兜底（如刚登记的新卡）：后台补刷快照，下次即可秒开
                        if !fromSnapshot {
                            Task { _ = await MemberSnapshotCache.shared.refresh() }
                        }
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            members = [found]
                            selectedIndex = 0
                        }
                    } else {
                        members = []
                        selectedIndex = -1
                        notFound = true
                        notFoundMessage = "未找到该卡号对应的社员，请确认卡片已登记"
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

    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            refreshMessage = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation(.easeIn(duration: 0.25)) {
                refreshMessage = nil
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
                                            .fill(Color(uiColor: .secondarySystemFill))
                                        Text(String(member.name.prefix(1)))
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundStyle(.secondary)
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
    let namespace: Namespace.ID
    @Binding var viewerRoute: ImageViewerRoute?
    @State private var copyFeedback: String?
    @State private var isPreparingShare = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // 1. 照片轮播
            if !member.photoURLs.isEmpty {
                PhotoCarouselView(
                    urls: member.photoURLs,
                    namespace: namespace,
                    viewerRoute: $viewerRoute
                )
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
                    
                    HStack(spacing: 8) {
                        Text(member.idCode)
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(Capsule())

                        Spacer(minLength: 0)

                        // 分享按钮放在识别码同一行，避免挤占姓名行的显示空间
                        Button {
                            presentShareSheet()
                        } label: {
                            Group {
                                if isPreparingShare {
                                    ProgressView()
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                        }
                        .disabled(isPreparingShare)
                        .accessibilityLabel("分享社员档案")
                        .accessibilityHint("分享查询结果卡片")
                    }
                }
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
                WorkGridSection(
                    works: member.works,
                    namespace: namespace,
                    viewerRoute: $viewerRoute
                )
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

    /// 点击分享时实时渲染整卡并调起系统分享面板。
    @MainActor
    private func presentShareSheet() {
        guard !isPreparingShare else { return }
        isPreparingShare = true
        Task {
            await preloadShareImages()
            let image = renderShareImage()
            isPreparingShare = false
            guard let image else { return }
            presentActivitySheet(with: image)
        }
    }

    /// 分享前把头像、封面照片预取进内存缓存，保证分享图里是真实图片。
    @MainActor
    private func preloadShareImages() async {
        var urls: [String] = []
        if let avatarURLString = member.avatarURL {
            urls.append(avatarURLString)
        }
        if let firstPhoto = member.photoURLs.first {
            urls.append(firstPhoto)
        }

        for url in urls {
            _ = await ImageCacheManager.shared.image(for: url)
        }
    }

    /// 渲染整张分享卡图片。
    @MainActor
    private func renderShareImage() -> UIImage? {
        let card = MemberShareCardView(
            member: member,
            querierIdCode: LoginManager.shared.loggedInIdCode
        )
        // 跟随 App 当前深浅色，保证分享卡配色与软件一致
        .environment(\.colorScheme, colorScheme)
        .frame(width: 360)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        return renderer.uiImage
    }

    private func presentActivitySheet(with image: UIImage) {
        let activityController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        // iPad 上以弹出层展示，需要 sourceView/sourceRect
        activityController.popoverPresentationController?.sourceView = root.view
        activityController.popoverPresentationController?.sourceRect = CGRect(
            x: root.view.bounds.midX,
            y: root.view.bounds.midY,
            width: 0,
            height: 0
        )
        activityController.popoverPresentationController?.permittedArrowDirections = []
        root.present(activityController, animated: true)
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
                .fill(Color(uiColor: .secondarySystemFill))
                .frame(width: 64, height: 64)
            
            Text(String(member.name.prefix(1)))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
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
            self.init(systemImage: "crown.fill", color: Color(red: 0.62, green: 0.50, blue: 0.12), accessibilityLabel: "社团领袖")
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

// MARK: - 查询结果分享卡（供 ImageRenderer 导出图片）

/// 完整还原查询结果卡片：封面照片、身份区、统计、履历、代表作品，并铺满多枚查询人水印。
private struct MemberShareCardView: View {
    let member: RaspberryMember
    let querierIdCode: String

    /// App 品牌强调色（与 AccentColor 资产一致；ImageRenderer 下显式指定，避免回退到系统蓝）。
    private static let brandAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 179 / 255.0, blue: 183 / 255.0, alpha: 1)
            : UIColor(red: 148 / 255.0, green: 43 / 255.0, blue: 56 / 255.0, alpha: 1)
    })

    private var badge: RatingBadge? {
        RatingBadge(rawValue: member.rating)
    }

    private var watermarkText: String {
        querierIdCode.isEmpty ? "树莓社社员" : querierIdCode
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 1. 照片封面（取第一张；已缓存用原图，未缓存用同款渐变占位）
                if !member.photoURLs.isEmpty {
                    coverPhoto
                        .padding([.top, .horizontal], 16)
                }

                // 2. 身份头部区
                identityHeader
                    .padding(16)

                Divider()
                    .padding(.horizontal, 16)

                // 3. 核心数据统计区
                statsRow
                    .padding(.vertical, 14)

                // 4. 详细履历区
                if hasDetailRows {
                    Divider()
                        .padding(.horizontal, 16)
                    detailRows
                        .padding(16)
                }

                // 5. 底部品牌标志（与查询结果页面底部一致）
                Image("DigitalMedia-Line")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 140)
                    .accessibilityHidden(true)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
            .frame(width: 360)

            // 多枚斜向水印铺满整卡
            WatermarkLayer(text: "由 \(watermarkText) 查询")
        }
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: 封面
    private var coverPhoto: some View {
        Group {
            if let first = member.photoURLs.first,
               let cached = ImageCacheManager.shared.cachedImage(for: first) {
                Image(uiImage: cached)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [.indigo, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text(String(member.name.prefix(1)))
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: 身份头部
    private var identityHeader: some View {
        HStack(spacing: 16) {
            avatar

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(member.name)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    if !member.alias.isEmpty {
                        Text("(\(member.alias))")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    if let badge {
                        Image(systemName: badge.systemImage)
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(.white)
                            .font(.caption)
                            .frame(width: 20, height: 20)
                            .background(badge.color, in: Circle())
                    }
                }

                Text("\(member.generation) \(member.clazz) · \(member.department)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(member.idCode)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Self.brandAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Self.brandAccent.opacity(0.12))
                    .clipShape(Capsule())
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: 统计
    private var statsRow: some View {
        HStack(spacing: 0) {
            StatView(title: "参与活动", value: "\(member.activityCount)", unit: "次")
            Divider().frame(height: 28)
            StatView(title: "志愿时长", value: String(format: "%.0f", member.totalHours), unit: "h")
            Divider().frame(height: 28)
            StatView(title: "入社年份", value: member.joinYearFormatted, unit: "年")
        }
    }

    // MARK: 履历
    private var hasDetailRows: Bool {
        !member.fullBirthdayFormatted.isEmpty
            || !member.contactQQ.isEmpty
            || !member.roles.isEmpty
            || !member.honors.isEmpty
            || !member.college.isEmpty
            || !member.description.isEmpty
    }

    private var detailRows: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !member.fullBirthdayFormatted.isEmpty {
                DetailRow(icon: "birthday.cake.fill", title: "生日", content: member.fullBirthdayFormatted, tint: .pink)
            }
            if !member.contactQQ.isEmpty {
                DetailRow(icon: "bubble.left.and.bubble.right.fill", title: "QQ", content: member.contactQQ, tint: .blue)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 头像
    private var avatar: some View {
        Group {
            if let avatarURLString = member.avatarURL,
               let cached = ImageCacheManager.shared.cachedImage(for: avatarURLString) {
                Image(uiImage: cached)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Color(uiColor: .secondarySystemFill))
                    Text(String(member.name.prefix(1)))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
    }
}

/// 铺满整卡的多枚斜向水印，低调但可溯源。
private struct WatermarkLayer: View {
    let text: String

    var body: some View {
        GeometryReader { proxy in
            let columns = max(2, Int(proxy.size.width / 150))
            let rows = max(3, Int(proxy.size.height / 180))

            VStack(spacing: 64) {
                ForEach(0..<rows, id: \.self) { _ in
                    HStack(spacing: 64) {
                        ForEach(0..<columns, id: \.self) { _ in
                            Text(text)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .opacity(0.30)
                                .rotationEffect(.degrees(-25))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct PhotoCarouselView: View {
    let urls: [String]
    let namespace: Namespace.ID
    @Binding var viewerRoute: ImageViewerRoute?
    @State private var selection = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selection) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    FeishuAsyncImage(urlString: url, placeholderName: "照片", contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())        // 保证整个区域可点击
                        .matchedTransitionSource(id: "carousel-\(url)", in: namespace)
                        .onTapGesture {
                            viewerRoute = ImageViewerRoute(
                                urls: urls,
                                initialIndex: selection,
                                sourceID: "carousel-\(urls[selection])"
                            )
                        }
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
    }
}

// MARK: - 全屏图片查看器（UIPageViewController 分页 + UIScrollView 原生缩放）

/// 查看器路由：把图片列表、起始页码和 zoom 来源 ID 一起显式传入。
struct ImageViewerRoute: Identifiable, Hashable {
    let urls: [String]
    let initialIndex: Int
    let sourceID: String
    var id: String { sourceID }
}

struct ImageViewer: View {
    let urls: [String]
    let sourceID: String
    let namespace: Namespace.ID
    @State private var selection: Int

    init(urls: [String], initialIndex: Int = 0, sourceID: String, namespace: Namespace.ID) {
        self.urls = urls
        self.sourceID = sourceID
        self.namespace = namespace
        _selection = State(initialValue: min(max(initialIndex, 0), max(urls.count - 1, 0)))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 系统级分页查看器：左右滑动切换、双指缩放、放大后拖拽
            SystemImageViewer(urls: urls, selection: $selection)

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
        }
        // 系统相册式放大进入：从点按的缩略图 zoom 到全屏查看器
        .navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        // 相册风格：保留系统 Back + 边缘右滑返回；导航栏半透明黑，隐藏底部 TabBar
        .toolbarBackground(.black.opacity(0.4), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}

/// SwiftUI 包装：UIPageViewController（横向翻页）+ 每页 UIScrollView（原生缩放）。
struct SystemImageViewer: UIViewControllerRepresentable {
    let urls: [String]
    @Binding var selection: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [.interPageSpacing: 20]
        )
        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator
        pageViewController.view.backgroundColor = .black

        let initialIndex = min(max(selection, 0), max(urls.count - 1, 0))
        pageViewController.setViewControllers(
            [context.coordinator.pageController(for: initialIndex)],
            direction: .forward,
            animated: false
        )
        return pageViewController
    }

    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        guard let current = pageViewController.viewControllers?.first as? ZoomableImagePageViewController,
              current.index != selection else { return }
        pageViewController.setViewControllers(
            [context.coordinator.pageController(for: selection)],
            direction: selection > current.index ? .forward : .reverse,
            animated: false
        )
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: SystemImageViewer
        private var pages: [Int: ZoomableImagePageViewController] = [:]

        init(_ parent: SystemImageViewer) {
            self.parent = parent
        }

        func pageController(for index: Int) -> UIViewController {
            if let page = pages[index] {
                return page
            }
            let page = ZoomableImagePageViewController(url: parent.urls[index], index: index)
            pages[index] = page
            return page
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let index = (viewController as? ZoomableImagePageViewController)?.index, index > 0 else {
                return nil
            }
            return pageController(for: index - 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let index = (viewController as? ZoomableImagePageViewController)?.index,
                  index < parent.urls.count - 1 else {
                return nil
            }
            return pageController(for: index + 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard completed,
                  let current = pageViewController.viewControllers?.first as? ZoomableImagePageViewController else {
                return
            }
            parent.selection = current.index
        }
    }
}

/// 单页图片：UIScrollView 原生缩放 / 拖拽 + 异步加载。
final class ZoomableImagePageViewController: UIViewController, UIScrollViewDelegate {
    let index: Int
    private let url: String

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let loadingView = UIActivityIndicatorView(style: .large)
    private var imageLoaded = false
    /// 最近一次布局尺寸：尺寸不变时不再重建布局，避免重置用户缩放状态。
    private var lastLayoutSize: CGSize = .zero
    /// 缩放为 1 时的图片原始展示尺寸（用于 zoom 后重新居中）。
    private var baseImageSize: CGSize = .zero

    init(url: String, index: Int) {
        self.url = url
        self.index = index
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        view.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        loadingView.color = .white
        loadingView.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        loadingView.autoresizingMask = [
            .flexibleLeftMargin, .flexibleRightMargin,
            .flexibleTopMargin, .flexibleBottomMargin
        ]
        loadingView.startAnimating()
        view.addSubview(loadingView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTap)

        loadImage()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = scrollView.bounds
        guard bounds.width > 0, bounds.height > 0, imageLoaded, bounds.size != lastLayoutSize else { return }
        lastLayoutSize = bounds.size
        layoutImage()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent(in: scrollView)
    }

    // MARK: - 图片加载

    private func loadImage() {
        Task { @MainActor in
            let image = await ImageCacheManager.shared.image(for: url)
            loadingView.stopAnimating()
            loadingView.removeFromSuperview()
            guard let image else {
                showFailurePlaceholder()
                return
            }
            imageView.image = image
            imageLoaded = true
            layoutImage()
            lastLayoutSize = scrollView.bounds.size
        }
    }

    private func showFailurePlaceholder() {
        let label = UILabel()
        label.text = "图片加载失败"
        label.textColor = .white.withAlphaComponent(0.7)
        label.font = .systemFont(ofSize: 15)
        label.sizeToFit()
        label.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        label.autoresizingMask = [
            .flexibleLeftMargin, .flexibleRightMargin,
            .flexibleTopMargin, .flexibleBottomMargin
        ]
        view.addSubview(label)
    }

    // MARK: - 布局

    /// 按原始图片比例缩放到一屏内（不超过 1:1），并居中。
    private func layoutImage() {
        guard let image = imageView.image, scrollView.bounds.width > 0 else { return }
        let bounds = scrollView.bounds
        let fitScale = min(bounds.width / image.size.width, bounds.height / image.size.height, 1)
        baseImageSize = CGSize(
            width: image.size.width * fitScale,
            height: image.size.height * fitScale
        )
        scrollView.zoomScale = 1
        imageView.frame = CGRect(origin: .zero, size: baseImageSize)
        scrollView.contentSize = baseImageSize
        centerContent(in: scrollView)
    }

    /// 图片小于可视区域时居中于 bounds；放大后 contentSize 由系统维护，居中于内容区。
    private func centerContent(in scrollView: UIScrollView) {
        let bounds = scrollView.bounds
        let contentSize = scrollView.contentSize
        imageView.center = CGPoint(
            x: contentSize.width < bounds.width ? bounds.width / 2 : contentSize.width / 2,
            y: contentSize.height < bounds.height ? bounds.height / 2 : contentSize.height / 2
        )
    }

    // MARK: - 手势

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1 {
            scrollView.setZoomScale(1, animated: true)
            return
        }
        let point = gesture.location(in: imageView)
        let targetScale: CGFloat = 2.5
        let zoomRect = CGRect(
            x: point.x - scrollView.bounds.width / (2 * targetScale),
            y: point.y - scrollView.bounds.height / (2 * targetScale),
            width: scrollView.bounds.width / targetScale,
            height: scrollView.bounds.height / targetScale
        )
        scrollView.zoom(to: zoomRect, animated: true)
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
    let namespace: Namespace.ID
    @Binding var viewerRoute: ImageViewerRoute?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var supportedWorks: [WorkItem] {
        works.filter { $0.type != .unsupported && !$0.url.isEmpty }
    }
    private var unsupportedCount: Int {
        works.count - supportedWorks.count
    }

    /// 两列等宽网格，与 Android ArtWorksGridSection 一致；宽度随容器自适应。
    private static let gridSpacing: CGFloat = 12
    /// 作品卡统一高度（与 Android 的 150dp 一致）。
    private let workCardHeight: CGFloat = 150

    /// 自适应列数：iPhone 两列；iPad 用更大的最小宽度，避免卡片过小。
    private var gridColumns: [GridItem] {
        let minimum: CGFloat = horizontalSizeClass == .regular ? 220 : 150
        return [GridItem(.adaptive(minimum: minimum), spacing: Self.gridSpacing)]
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

            // 作品网格：单张直接全宽；多张用自适应列数（iPhone 两列，iPad 自动增多）。
            if !supportedWorks.isEmpty {
                Group {
                    if supportedWorks.count == 1, let work = supportedWorks.first {
                        // 单张作品跨满整行，避免出现孤立的窄卡片
                        ImageWorkCard(work: work, height: workCardHeight) {
                            viewerRoute = ImageViewerRoute(
                                urls: supportedWorks.map(\.url),
                                initialIndex: 0,
                                sourceID: "work-\(work.id)"
                            )
                        }
                        .matchedTransitionSource(id: "work-\(work.id)", in: namespace)
                    } else {
                        LazyVGrid(
                            columns: gridColumns,
                            spacing: Self.gridSpacing
                        ) {
                            ForEach(Array(supportedWorks.enumerated()), id: \.element.id) { index, work in
                                ImageWorkCard(work: work, height: workCardHeight) {
                                    viewerRoute = ImageViewerRoute(
                                        urls: supportedWorks.map(\.url),
                                        initialIndex: index,
                                        sourceID: "work-\(work.id)"
                                    )
                                }
                                .matchedTransitionSource(id: "work-\(work.id)", in: namespace)
                            }
                        }
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
    }
}

struct ImageWorkCard: View {
    let work: WorkItem
    let height: CGFloat
    let onTap: () -> Void

    var body: some View {
        FeishuAsyncImage(urlString: work.url, placeholderName: "作品", contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: height)
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
