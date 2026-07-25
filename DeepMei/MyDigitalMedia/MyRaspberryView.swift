//
//  MyRaspberryView.swift
//  DeepMei
//
//  依据 iOS 27 Liquid Glass 设计规范优化
//

import SwiftUI


struct MyRaspberryView: View {


    @State private var member: Member?


    @State private var memberId: String = ""


    @State private var notFound: Bool = false


    @FocusState private var isFocused: Bool


    var body: some View {


        NavigationStack {


            ScrollView {


                VStack(spacing: 28) {


                    // 顶部品牌标识
                    Image(systemName: "apple.logo")
                        .font(.system(size: 56))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                        .padding(.top, 4)


                    if let member {


                        MemberInfoCard(member: member)


                    } else {


                        IdentityInputSection(
                            memberId: $memberId,
                            notFound: notFound,
                            isFocused: $isFocused,
                            onLookup: performLookup
                        )


                    }


                }
                .padding(.horizontal)
                .padding(.bottom, 40)


            }
            .navigationTitle("我的树莓")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if member != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation(.snappy) {
                                member = nil
                                memberId = ""
                                notFound = false
                            }
                        } label: {
                            Image(systemName: "arrow.counterclockwise.circle")
                                .symbolRenderingMode(.hierarchical)
                        }
                        .accessibilityLabel("重新识别")
                    }
                }
            }


        }


    }


    private func performLookup() {
        let found =
        MemberStore.shared.find(id: memberId) ?? MemberStore.shared.find(name: memberId)

        withAnimation(.snappy) {
            member = found
            notFound = (found == nil && !memberId.isEmpty)
        }
    }


}


// MARK: - 社员信息卡片
private struct MemberInfoCard: View {
    let member: Member


    var body: some View {
        VStack(spacing: 16) {


            // 头部：头像 + 姓名 + 头衔
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.tint.opacity(0.12))
                    Text(member.name.prefix(1))
                        .font(.title.bold())
                        .foregroundStyle(.tint)
                }
                .frame(width: 60, height: 60)


                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(.title2.bold())
                    Text(member.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }


                Spacer()


                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.green)
            }


            Divider()


            // 详细信息
            VStack(spacing: 12) {
                InfoRow(icon: "rectangle.stack.fill",
                        title: "届别",
                        value: member.generation)


                if !member.joinDate.isEmpty {
                    InfoRow(icon: "calendar",
                            title: "入社时间",
                            value: member.joinDate)
                }


                if !member.description.isEmpty {
                    InfoRow(icon: "text.alignleft",
                            title: "简介",
                            value: member.description)
                }
            }


        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "社员信息：\(member.name)，\(member.title)，\(member.generation)"
        )
    }
}


// MARK: - 信息行
private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String


    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .frame(width: 24)
                .accessibilityHidden(true)


            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }


            Spacer()
        }
    }
}


// MARK: - 身份输入区
private struct IdentityInputSection: View {
    @Binding var memberId: String
    let notFound: Bool
    var isFocused: FocusState<Bool>.Binding
    let onLookup: () -> Void


    var body: some View {
        VStack(spacing: 16) {


            ContentUnavailableView(
                "未识别身份",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text("请输入社员号或姓名进行身份识别")
            )
            .symbolRenderingMode(.hierarchical)
            .padding(.vertical, 8)


            VStack(spacing: 12) {
                TextField(
                    "请输入社员号或姓名",
                    text: $memberId
                )
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .focused(isFocused)
                .submitLabel(.search)
                .onSubmit(onLookup)
                .accessibilityLabel("社员号或姓名输入框")
                .accessibilityHint("请输入您的社员号或姓名进行身份识别")


                Button(action: onLookup) {
                    Label(
                        "确认识别",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(memberId.isEmpty)
                .accessibilityLabel("确认识别按钮")
                .accessibilityHint("双击根据输入内容查找社员信息")


                if notFound {
                    Label(
                        "未找到该社员，请检查输入",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.red)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityLabel("未找到社员提示")
                    .transition(.opacity)
                }
            }


        }
    }
}
