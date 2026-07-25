//
//  HallOfFameView.swift
//  DeepMei
//
//  遵循 Apple HIG 规范重构的社团名人堂页面
//

import SwiftUI

// MARK: - 数据模型
struct HallOfFameMember: Identifiable, Hashable {
    let id: String
    let name: String
    let term: Int
    let role: String
    let tags: [String]
    let contribution: String
    let quote: String
    let grades: [String] // 6维能力：[组织, 创作, 文化, 影响, 责任, 创新]
    let archive: String
    let photo: String
    
    // 届别主题色 (符合 iOS HIG 语义调色)
    var termColor: Color {
        switch term {
        case 1: return Color(red: 0.58, green: 0.17, blue: 0.22)
        case 2: return Color(red: 0.67, green: 0.37, blue: 0.19)
        case 3: return Color(red: 0.61, green: 0.51, blue: 0.28)
        case 4: return Color(red: 0.26, green: 0.47, blue: 0.36)
        case 5: return Color(red: 0.27, green: 0.37, blue: 0.55)
        case 6: return Color(red: 0.40, green: 0.30, blue: 0.52)
        case 7: return Color(red: 0.54, green: 0.30, blue: 0.44)
        case 8: return Color(red: 0.22, green: 0.51, blue: 0.47)
        default: return .accentColor
        }
    }
}

// MARK: - 名人堂主视图
struct HallOfFameView: View {
    @State private var selectedTerm: Int = 0 // 0 表示全部
    @State private var selectedMember: HallOfFameMember? = nil
    @State private var searchText: String = ""
    
    let terms = [0, 1, 2, 3, 4, 5, 6, 7, 8]
    
    var filteredMembers: [HallOfFameMember] {
        allMembers.filter { member in
            let matchesTerm = (selectedTerm == 0 || member.term == selectedTerm)
            let matchesSearch = searchText.isEmpty ||
                                member.name.contains(searchText) ||
                                member.role.contains(searchText) ||
                                member.tags.contains(where: { $0.contains(searchText) })
            return matchesTerm && matchesSearch
        }
    }
    
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. 扁平滑动筛选胶囊 (HIG 推荐横向滚动)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(terms, id: \.self) { term in
                            FilterChip(
                                title: term == 0 ? "全部成员" : "第\(chineseTerm(term))届",
                                isSelected: selectedTerm == term
                            ) {
                                withAnimation(.snappy) {
                                    selectedTerm = term
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // 2. 成员卡片网格
                if filteredMembers.isEmpty {
                    ContentUnavailableView(
                        "无匹配成员",
                        systemImage: "person.slash",
                        description: Text("尝试切换届别或搜索关键词")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(filteredMembers) { member in
                            Button {
                                selectedMember = member
                            } label: {
                                MemberCard(member: member)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("历届名人堂")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "搜索姓名、职位或标签")
        .sheet(item: $selectedMember) { member in
            MemberDetailSheet(member: member).presentationDragIndicator(.visible)
        }
    }
    
    private func chineseTerm(_ term: Int) -> String {
        let names = ["一","二","三","四","五","六","七","八"]
        return term > 0 && term <= names.count ? names[term - 1] : "\(term)"
    }
}

// MARK: - 成员卡片组件 (HIG 风格)
struct MemberCard: View {
    let member: HallOfFameMember
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                // 头像/照片：使用 16:9 的固定比例容器 + overlay 裁切，彻底解决拉伸问题
                Color.clear
                    .frame(maxWidth:.infinity)
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay {
                        AsyncImage(url: URL(string: member.photo)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill() // 等比例填充并裁切
                            default:
                                ZStack {
                                    Rectangle()
                                        .fill(member.termColor.gradient)
                                    Text(member.name.prefix(2))
                                        .font(.title2.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                        }
                    }
                    .clipped() // 剪裁超出的部分
                
                // 届别 Badge
                Text("\(member.term) 届")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(member.termColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // 文本信息
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(member.role)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .padding(8)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        .contentShape(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
        )
        .accessibilityLabel(
            "\(member.name)，\(member.role)"
        )
        .accessibilityHint(
            "双击查看详细信息"
        )
    }
}

// MARK: - 筛选胶囊按钮
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .bold : .medium))
                .padding(.horizontal,16)
                .frame(minHeight:44)
                .background(isSelected ? Color.primary : Color(uiColor: .secondarySystemFill))
                .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : Color.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 成员详情 Drawer/Sheet (原生 iOS 弹出面板)
// MARK: - 成员详情 Drawer/Sheet (重构：符合 HIG 沉浸式 Modal 规范)
struct MemberDetailSheet: View {
    let member: HallOfFameMember
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 1. 主内容滚动区域
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 大图封面
                    Color.clear
                        .frame(height: 260)
                        .overlay {
                            AsyncImage(url: URL(string: member.photo)) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } else {
                                    ZStack {
                                        Rectangle()
                                            .fill(member.termColor.gradient)
                                        Text(member.name)
                                            .font(.largeTitle.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                        }
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    
                    // 详情文本及图表
                    VStack(alignment: .leading, spacing: 16) {
                        // 头衔
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name)
                                .font(.title.bold())
                            Text(member.role)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        // 标签列表
                        FlowLayout(spacing: 8) {
                            ForEach(member.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(uiColor: .tertiarySystemFill))
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Divider()
                        
                        // 背景故事/贡献
                        VStack(alignment: .leading, spacing: 8) {
                            Text("角色背景故事")
                                .font(.headline)
                            Text(member.contribution)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineSpacing(4)
                        }
                        
                        // 名言 Quotes
                        if !member.quote.isEmpty {
                            HStack(spacing: 12) {
                                Rectangle()
                                    .fill(member.termColor)
                                    .frame(width: 4)
                                Text(member.quote.replacingOccurrences(of: "<br>", with: "\n"))
                                    .font(.callout)
                                    .italic()
                                    .foregroundStyle(.primary)
                            }
                            .padding()
                            .background(Color(uiColor: .secondarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        
                        // 雷达图
                        if !member.grades.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("能力维度雷达")
                                    .font(.headline)
                                
                                SwiftUIXRadarChart(grades: member.grades, accentColor: member.termColor)
                                    .frame(height: 220)
                                    .padding(.vertical, 10)
                            }
                        }
                        
                        // 相关文献
                        if !member.archive.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("相关文献")
                                    .font(.headline)
                                Label(member.archive, systemImage: "doc.text.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(member.termColor)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 16) // 稍微拉开一点顶部边距
                .padding(.bottom, 30)
            }
            
            // 2. 右上角悬浮关闭按钮（iOS HIG 质感）
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .frame(
                        width:44,
                        height:44
                    )
                    .foregroundStyle(.secondary)
                    .background(.ultraThinMaterial, in: Circle()) // 毛玻璃悬浮圆圈
            }
            .padding(.trailing, 24)
            .padding(.top, 24)
        }
    }
}

// MARK: - 纯 SwiftUI 原生六维雷达图组件
struct SwiftUIXRadarChart: View {
    let grades: [String]
    let accentColor: Color
    
    private let categories = ["组织", "创作", "文化", "影响", "责任", "创新"]
    private let gradeScores: [String: Double] = [
        "A+": 5.0, "A": 5.0, "B": 4.0, "C": 3.0, "D": 2.0, "E": 1.0, "∞": 6.0, "F": 1.0, "?": 2.5, "无": 0.0
    ]
    
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 32
            
            ZStack {
                // 1. 背景网格
                ForEach(1...5, id: \.self) { level in
                    RadarPolygonShape(sides: 6, scale: CGFloat(level) / 5.0)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                }
                
                // 2. 轴线 & 标签
                ForEach(0..<6, id: \.self) { i in
                    let angle = (Double(i) * 60.0 - 90.0) * .pi / 180.0
                    
                    Path { p in
                        p.move(to: center)
                        p.addLine(to: CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle)))
                    }
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    
                    // 标注文字
                    let labelPos = CGPoint(x: center.x + (radius + 20) * cos(angle), y: center.y + (radius + 18) * sin(angle))
                    VStack(spacing: 2) {
                        Text(categories[i])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if i < grades.count {
                            Text(grades[i])
                                .font(.caption.bold())
                                .foregroundStyle(accentColor)
                        }
                    }
                    .position(labelPos)
                }
                
                // 3. 数据填充面
                RadarDataShape(scores: grades.map { gradeScores[$0] ?? 2.5 }, maxScore: 6.0)
                    .fill(accentColor.opacity(0.25))
                
                RadarDataShape(scores: grades.map { gradeScores[$0] ?? 2.5 }, maxScore: 6.0)
                    .stroke(accentColor, lineWidth: 2)
            }
        }
    }
}

// 雷达图多边形 Shape
struct RadarPolygonShape: Shape {
    let sides: Int
    let scale: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let radius = (min(rect.width, rect.height) / 2 - 32) * scale
        
        for i in 0..<sides {
            let angle = (Double(i) * (360.0 / Double(sides)) - 90.0) * .pi / 180.0
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

// 雷达数据 Shape
struct RadarDataShape: Shape {
    let scores: [Double]
    let maxScore: Double
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let maxRadius = min(rect.width, rect.height) / 2 - 32
        
        for i in 0..<scores.count {
            let score = min(scores[i], maxScore)
            let radius = maxRadius * CGFloat(score / maxScore)
            let angle = (Double(i) * (360.0 / Double(scores.count)) - 90.0) * .pi / 180.0
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

// 流式标签布局 (用于 Tags 排版)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            let point = result.points[index]
            subview.place(at: CGPoint(x: point.x + bounds.minX, y: point.y + bounds.minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var points: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var height: CGFloat = 0
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxLineWidth: CGFloat = 0
            
            for subview in subviews {
                let itemSize = subview.sizeThatFits(.unspecified)
                
                if x + itemSize.width > maxWidth, x > 0 {
                    maxLineWidth = max(maxLineWidth, x)
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                points.append(CGPoint(x: x, y: y))
                
                lineHeight = max(lineHeight, itemSize.height)
                x += itemSize.width + spacing
            }
            
            maxLineWidth = max(maxLineWidth, x)
            height = y + lineHeight
            
            self.size = CGSize(
                width: min(maxLineWidth, maxWidth),
                height: height
            )
        }
    }
}

// MARK: - 成员完整数据 (移植自 HTML)
let allMembers: [HallOfFameMember] = [
    // 第一届
    HallOfFameMember(id: "mayuzhang", name: "马雨璋", term: 1, role: "联合创始人 / 社长", tags: ["创社核心","影视创作","传媒中心","《苏迷》"], contribution: "确立树莓社以影视创作为核心的社团定位，创立传媒中心。领导制作纪录片《苏迷》，带领社员参加48小时电影马拉松比赛。", quote: "相信影像的力量！\n技术会迭代，但影像传达的热情不会。只要电影梦还在，我们就有存在的价值。", grades: ["A","∞","B","A","A","C"], archive: "《数媒社创社策划案》", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/mayuzhang.webp"),
    HallOfFameMember(id: "shensunfeng", name: "沈孙丰", term: 1, role: "联合创始人 / 社长 / 组委会主席", tags: ["组委会","民主改革","三项业务划分","树莓文化"], contribution: "提出用\"树莓\"代替\"数字媒体\"，主导社团管理体制民主改革，起草《社团章程》。联合发起树莓派援助武汉抗疫募捐活动。", quote: "既然\"数字媒体\"听起来太专业、太遥远，那我们就用\"树莓\"来拉近影像与每个人的距离。\n制度的存在不是为了约束，而是为了让每一个创意都能在科学的轨道上精准落地。", grades: ["A","B","∞","A","A","A"], archive: "《苏州中学树莓社章程》", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/shensunfeng.webp"),
    HallOfFameMember(id: "zhangshihan", name: "张诗菡", term: 1, role: "联合创始人 / 副社长", tags: ["视觉设计","树莓酱","树莓文化"], contribution: "创造了树莓社看板娘形象并主导早期视觉体系，为树莓社社团文化的发展奠定基础。", quote: "虽然我们只是学生组织，我们的影响力绝不应被预设边界。树莓社将用行动证明，影像的力量可以深入到社会的各个领域之中。", grades: ["B","B","A","C","A","C"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/zhangshihan.webp"),
    
    // 第二届
    HallOfFameMember(id: "shiyunhan", name: "石允涵", term: 2, role: "第二任社长（双社长）", tags: ["双社长制","照片直播"], contribution: "引入照片直播工作模式，开创摄影志愿服务品牌，大幅提高宣传时效性。荣获苏州市优秀社长称号。", quote: "“面对挑战，我能行；遇到困难，我不怕；突发状况，我担当。”\n“来树莓，种树莓，吃树莓，学数媒！”", grades: ["A","A","A","A","A","A"], archive: "《树莓社摄影志愿服务团队开展情况报告》", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/shiyunhan.webp"),
    HallOfFameMember(id: "liuenqi", name: "刘恩岐", term: 2, role: "第二任社长（双社长）", tags: ["经费保障","后期部"], contribution: "树莓社历史双社长制代表。设计第二代工作证，为社团运营提供重要经费保障，起草《2019 年社长工作报告》。", quote: "", grades: ["C","C","B","B","A","C"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/liuenqi.webp"),
    HallOfFameMember(id: "xingxiaohan", name: "邢笑菡", term: 2, role: "副社长 / 社盟副主席 / 代理社长", tags: ["代理社长","部门优化"], contribution: "担任代理社长期间主持社团换届，提出部门结构优化方案。担任苏州中学社团联盟理事会副主席，促进跨社团交流。", quote: "", grades: ["B","C","B","B","A","B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/xingxiaohan.webp"),
    HallOfFameMember(id: "yezhuo", name: "叶卓", term: 2, role: "代理社长 / 社盟主席", tags: ["B 站开创","社联主席"], contribution: "开创树莓社 B 站官方账号，探索社团传播新矩阵。当选社团联盟理事会主席，将\"校级赋能\"升级为常态发展引擎。", quote: "", grades: ["B","A","B","B","C","B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/yezhuo.webp"),
    
    // 第三届
    HallOfFameMember(id: "zhuyi", name: "朱奕", term: 3, role: "第三任社长", tags: ["走出困境","《识茶记》"], contribution: "在面临内外挑战时带领社团走出困境，明确社团发展方向。推动《识茶记》等核心作品创作，举办\"破界\"创意摄影大赛。", quote: "", grades: ["B","A","A","B","B","B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/zhuyi.webp"),
    HallOfFameMember(id: "luweiyi", name: "陆未一", term: 3, role: "策划与宣传部部长 / 第四届副社长", tags: ["公众号创始人","视觉设计"], contribution: "创立\"苏中树莓社\"微信公众号并建立文案排版分工体系，设计 2021 版看板娘，开启了社团的全媒体传播时代。", quote: "", grades: ["B","C","B","B","C","A"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/luweiyi.webp"),
    HallOfFameMember(id: "guhengting", name: "顾衡庭", term: 3, role: "后期部部长 / 第四届副社长", tags: ["数字媒体技术"], contribution: "成功引入高画质实时视频直播工作流，并在 B 站运营及色彩管理技术规范中起到了决定性作用，确立了社团的技术壁垒。", quote: "", grades: ["B","B","B","B","B","A"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/guhengting.webp"),
    
    // 第四届
    HallOfFameMember(id: "wangyiyang", name: "汪翊扬", term: 4, role: "第四任社长 / 后期部部长", tags: ["创纪录招新"], contribution: "在\"网课学期\"克服疫情障碍坚持线上活动，带领第五届招新创下 79 人历史最高纪录。推动树莓社与多校社团结成树莓派联盟。", quote: "我们呈现生活，我们记录感动，用一帧帧画面还原真实。", grades: ["A","B","A","A+","B","B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/wangyiyang.webp"),
    HallOfFameMember(id: "luziyi", name: "陆子易", term: 4, role: "副社长 / 后勤部部长 / 社盟主席", tags: ["社团外联","公共关系"], contribution: "第四届、第五届组委会核心成员。以社团联盟主席身份出席“树莓派·苏州数字媒体学生社团联盟”签约成立大会并见证签约。", quote: "", grades: ["A","C","A","B","A","B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/luziyi.webp"),
    
    // 第五届
    HallOfFameMember(id: "liqian", name: "李谦", term: 5, role: "第五任社长 / 传媒中心负责人", tags: ["线下回归","拍摄担当"], contribution: "以\"蒙故业，因遗策\"为治社纲领，采取过渡性战略，将受疫情影响的社团发展重心转移回线下，在各类大型活动中承担拍摄重任。", quote: "", grades: ["B","C","B","B","A","B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/liqian.webp"),
    
    // 第六届
    HallOfFameMember(id: "zhouyijia", name: "周熠嘉", term: 6, role: "第六任社长 / 社盟成员", tags: ["数字化转型","树莓派联盟"], contribution: "树莓派社团联盟主要创始人。推动社团治理数字化转型，提出\"回归社团本质、重视兴趣导向\"。创立《树莓日签》，推进 AIGC 研究。", quote: "现阶段的活动理念与社员实际期望的冲突，需要通过回归兴趣结社的社团本质来解决。", grades: ["A","C","A","A","A","B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/zhouyijia.webp"),
    HallOfFameMember(id: "zhangyujiang", name: "张宇江", term: 6, role: "副社长 / 后期部部长", tags: ["后期部","AIGC 探索"], contribution: "担任后期部负责人。在第六届社团管理中曾代行社长职权，为社团过渡期的稳定运作提供技术与管理保障。", quote: "", grades: ["B","B","C","B","A","A"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/zhangyujiang.webp"),
    HallOfFameMember(id: "wangyanran", name: "王嫣然", term: 6, role: "副社长 / 代理社长", tags: ["画纸共创","创作者权益"], contribution: "开创树莓社 QQ 宣发阵地，主导\"共享相册\"活动。在社团联盟成立仪式上发表《保障创作者权益倡议》。执笔第六届年度工作报告。", quote: "当我们的感受跃然纸上，记忆便成为了作品。", grades: ["B","A","A","B","A","∞"], archive: "树莓社 2024 年国旗下讲话", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/wangyanran.webp"),
    
    // 第七届
    HallOfFameMember(id: "yangziyan", name: "杨梓言", term: 7, role: "第七任社长", tags: ["全媒体矩阵","伟大完成论"], contribution: "建成全媒体传播矩阵（累计传播超 20 万次）。面对 AI 冲击提出\"伟大完成论\"，强调\"从单纯技术传授升华为创意火种的传递\"。", quote: "让那些转瞬即逝的声音可以被听见，让每一个创意都拥有落地生长的土壤。", grades: ["A","B","B","A","A","A"], archive: "《守温度、传火种、向未来》", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/yangziyan.webp"),
    HallOfFameMember(id: "luoanqi", name: "雒安琪", term: 7, role: "传媒中心负责人", tags: ["问道山下广播","抖音平台","传媒中心"], contribution: "运营《问道山下》广播节目。发起创建小红书账号，创立抖音账号，推动校园传媒业务创新与时代化改革。", quote: "", grades: ["B","B","A","B","C","A"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/luoanqi.webp"),
    HallOfFameMember(id: "zhujingxuan", name: "朱璟煊", term: 7, role: "策划与宣传部 / 第八届副社长", tags: ["树莓酱 IP","品牌运营"], contribution: "主导\"树莓酱\"形象系统性迭代与 Q 版化开发，通过深耕周边文创，将社团文化成功转化为具象的视觉资产与文化符号。", quote: "", grades: ["C","B","A","B","C","B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/zhujingxuan.webp"),
    
    // 第八届
    HallOfFameMember(id: "chenyuxin", name: "陈雨馨", term: 8, role: "第八任社长", tags: ["《寻找》主演","第八代核心"], contribution: "原创微电影《寻找》主演。面对\"技术过剩而产出不足\"的问题提出尖锐反思，推动社团回归影像记录本质。", quote:"为什么我们树莓的技术已经足够成熟，产出却没能跟上呢？ 当我们面对规则、面对既定，甚至于面对自己——你是否还有勇气转身，做出改变？你不需要立刻做出回答，而树莓也只愿你始终对世界保有好奇心——去记录，去创作，去热爱，去质疑，去思考。", grades: ["B","A","B","B","B","B"], archive: "", photo: "https://szzxshumei.oss-cn-hangzhou.aliyuncs.com/photo/leader/chenyuxin.webp")
]
