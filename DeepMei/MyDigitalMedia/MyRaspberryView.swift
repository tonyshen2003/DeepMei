import SwiftUI

// MARK: - 1. 数据模型定义
struct RaspberryMember: Identifiable, Equatable {
    var id: String { idCode }
    
    // 核心身份
    let name: String
    let idCode: String       // 社员编号 (如 No.00001)
    let generation: String   // 年级 (如 2018级)
    let clazz: String        // 班级 (如 9班 或 AP)
    let department: String   // 社团部门
    
    // 职务与成就
    let roles: String        // 社团职务
    let college: String      // 升学去向
    
    // 数据统计
    let joinDate: String     // 入社日期
    let activityCount: Int   // 参与活动次数
    let totalHours: Double   // 统计时长
    
    // 详情
    let description: String  // 详细介绍
}

// MARK: - 2. 主页面视图
struct MyRaspberryView: View {
    @State private var member: RaspberryMember?
    
    // 查询状态管理
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false
    @State private var notFound: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景层
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 顶部品牌标识 (动态隐藏)
                        Image(systemName: "apple.logo")
                            .font(.system(size: 42, weight: .light))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                            .padding(.top, 16)
                            .opacity(member == nil ? 1 : 0)
                            .frame(height: member == nil ? 50 : 0)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: member)
                        
                        // 内容路由
                        if let member {
                            MemberProfileCard(member: member)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .scale(scale: 0.95).combined(with: .opacity)
                                ))
                        } else {
                            IdentitySearchSection(
                                searchText: $searchText,
                                isSearching: $isSearching,
                                notFound: notFound,
                                isFocused: $isFocused,
                                onSearch: performMockSearch
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("我的树莓")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if member != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            resetSearch()
                        } label: {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title3)
                        }
                        .accessibilityLabel("重新查询")
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
    
    private func performMockSearch() {
        isFocused = false
        isSearching = true
        notFound = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isSearching = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                if searchText == "马雨璋" || searchText == "No.00001" {
                    member = RaspberryMember(
                        name: "马雨璋", idCode: "No.00001", generation: "2018级", clazz: "AP", department: "后期部",
                        roles: "树莓社社长, 后期部部长", college: "纽约大学",
                        joinDate: "2018-09-12", activityCount: 14, totalHours: 107,
                        description: "确立树莓社以影视创作为核心的社团定位。带领社员参加电影马拉松比赛..."
                    )
                } else if searchText == "沈孙丰" || searchText == "No.00002" {
                    member = RaspberryMember(
                        name: "沈孙丰", idCode: "No.00002", generation: "2018级", clazz: "9班", department: "摄影部",
                        roles: "树莓社社长, 传媒中心负责人", college: "中国传媒大学",
                        joinDate: "2018-09-12", activityCount: 46, totalHours: 283,
                        description: "起草《苏州中学树莓社章程》，确定了以影视创作、数字媒体、新闻传播为核心的三大社团核心业务..."
                    )
                } else {
                    notFound = true
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
            // 第一部分：身份头部
            VStack(spacing: 16) {
                HStack(alignment: .top) {
                    // 渐变头像
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.accentColor.opacity(0.8), Color.accentColor.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 68, height: 68)
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Text(String(member.name.prefix(1)))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center) {
                            Text(member.name)
                                .font(.title2.bold())
                            
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.blue)
                                .font(.subheadline)
                        }
                        
                        Text("\(member.generation) \(member.clazz) · \(member.department)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(member.idCode)
                            .font(.caption.weight(.medium))
                            .monospacedDigit()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .padding(.leading, 12)
                    
                    Spacer()
                }
            }
            .padding(24)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            
            Divider().padding(.horizontal, 24)
            
            // 第二部分：核心数据网格
            HStack(spacing: 0) {
                StatView(title: "参与活动", value: "\(member.activityCount)", unit: "次")
                Divider().frame(height: 30)
                StatView(title: "志愿时长", value: String(format: "%.0f", member.totalHours), unit: "h")
                Divider().frame(height: 30)
                StatView(title: "入社年份", value: String(member.joinDate.prefix(4)), unit: "年")
            }
            .padding(.vertical, 20)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            
            // 第三部分：履历详情
            VStack(spacing: 20) {
                DetailRow(icon: "briefcase.fill", title: "社团职务", content: member.roles, tint: .orange)
                
                if !member.college.isEmpty {
                    DetailRow(icon: "graduationcap.fill", title: "升学去向", content: member.college, tint: .green)
                }
                
                DetailRow(icon: "text.quote", title: "社员简介", content: member.description, tint: .purple)
            }
            .padding(24)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 8)
    }
}

// MARK: - 4. 辅助 UI 组件
struct StatView: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption2.weight(.medium))
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(tint)
                    .frame(width: 20)
                
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Spacer()
            }
            
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(5)
                .padding(.leading, 28)
        }
    }
}

// MARK: - 5. 搜索交互区组件
struct IdentitySearchSection: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    let notFound: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSearch: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ContentUnavailableView {
                Label("身份识别", systemImage: "person.crop.rectangle.badge.plus")
                    .font(.largeTitle)
            } description: {
                Text("输入社员姓名或认证识别码以查询履历")
                    .font(.subheadline)
            }
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.tint)
            .padding(.top, 10)
            
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    
                    TextField("例如: 马雨璋 / No.00001", text: $searchText)
                        .focused(isFocused)
                        .submitLabel(.search)
                        .onSubmit(onSearch)
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isFocused.wrappedValue ? AnyShapeStyle(Color.accentColor.opacity(0.6)) : AnyShapeStyle(Color.clear), lineWidth: 2)
                )
                
                Button(action: onSearch) {
                    HStack {
                        if isSearching {
                            ProgressView().tint(.white).padding(.trailing, 4)
                        }
                        Text("检索数据库")
                            .font(.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .disabled(searchText.isEmpty || isSearching)
                
                if notFound {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("未找到该社员，请核对后重试")
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.red)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 32)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 10)
    }
}
