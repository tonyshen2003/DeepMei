import SwiftUI

import Foundation

// MARK: - 1. 数据模型定义
struct RaspberryMember: Identifiable, Equatable, Decodable {
    var id: String { idCode }

    let name: String            // 姓名
    let alias: String
    let idCode: String          // 社员编号 (如 No.00001)
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
    var avatarURL: String? { photoURLs.first }
    let ArtURLs: [String]       // 作品图片 URL 列表
    var ArtpicURL: String? { ArtURLs.first }
    
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
        case ArtpicList = "作品图片"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 基础字段解析
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        alias = try container.decodeIfPresent(String.self, forKey: .alias) ?? ""
        idCode = try container.decodeIfPresent(String.self, forKey: .idCode) ?? ""
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
        
        // 6. 处理作品 (提取图片临时下载 URL 列表)
        if let photos = try? container.decode([[String: DynamicCodingProperty]].self, forKey: .ArtpicList) {
            let urls = photos.compactMap { $0["tmp_url"]?.stringValue ?? $0["url"]?.stringValue }
            ArtURLs = urls
        } else {
            ArtURLs = []
        }
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
    @State private var member: RaspberryMember?
    @State private var members: [RaspberryMember] = []

    // 查询状态管理
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var notFound: Bool = false
    @State private var serviceError: String?
    @FocusState private var isFocused: Bool

    var body: some View {
            NavigationStack {
                Group {
                    if isSearching {
                        ProgressView("正在查询社员档案...")
                            .controlSize(.large)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let member {
                        ScrollView {
                            VStack(spacing: 20) {
                                MemberProfileCard(member: member)
                                
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
                    if member != nil {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                resetSearch()
                            } label: {
                                Label("重新查询", systemImage: "arrow.counterclockwise")
                            }
                        }
                    }
                }
            }
    }

    // MARK: 交互逻辑
    private func resetSearch() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            member = nil
            searchText = ""
            notFound = false
        }
    }

    private func loadMembers() {
        guard let url = Bundle.main.url(forResource: "Member", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return
        }
        
        let decoder = JSONDecoder()
        // 💡 优化点 2：设置全局时间戳解码策略（作为兜底）
        decoder.dateDecodingStrategy = .millisecondsSince1970
        
        members = (try? decoder.decode([RaspberryMember].self, from: data)) ?? []
    }

    private func performSearch() {
        isFocused = false
        isSearching = true
        notFound = false
        serviceError = nil

        let query = searchText
        Task {
            do {
                let result = try await MemberService.shared.searchMember(byNameOrCodeOrAlias: query)
                await MainActor.run {
                    isSearching = false
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        if let m = result {
                            member = m
                        } else {
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
}

// MARK: - 3. 社员档案卡片组件
struct MemberProfileCard: View {
    let member: RaspberryMember

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
                    FeishuAsyncImage(urlString: member.avatarURL, placeholderName: member.name)
                        .scaledToFill()
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
                        Image(systemName: "checkmark.seal.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .font(.subheadline)
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
            .frame(maxWidth: .infinity, alignment: .leading) // 💡 确保整个列表区撑满卡片
            .padding(16)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
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

struct PhotoCarouselView: View {
    let urls: [String]
    @State private var selection = 0
    @State private var selectedImage: IdentifiableImage?
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selection) {
                ForEach(Array(urls.enumerated()), id: \.offset) { index, url in
                    FeishuAsyncImage(urlString: url, placeholderName: "照片")
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .contentShape(Rectangle())        // 保证整个区域可点击
                        .onTapGesture {selectedImage = IdentifiableImage(url: url)}
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
        .fullScreenCover(item: $selectedImage) { image in
            ImageViewer(url: image.url)
        }
    }
}
    private struct IdentifiableImage: Identifiable {
        let id = UUID()
        let url: String
    }

    struct ImageViewer: View {
        let url: String
        @Environment(\.dismiss) var dismiss

        @State private var scale: CGFloat = 1
        @State private var lastScale: CGFloat = 1
        @State private var offset: CGSize = .zero
        @State private var lastOffset: CGSize = .zero

        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()

                FeishuAsyncImage(urlString: url, placeholderName: "加载中…")
                    .scaledToFit()
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
                    }
                    Spacer()
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

            // 内容文本
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .padding(.leading, 28)
        }
        // 💡 2. 核心修正：强制该组件占满父容器宽度，并统一靠左对齐
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}



#Preview {
    NavigationStack {
        MyRaspberryView()
    }
}
