//
//  ProfileWatchView.swift
//  DeepMeiWatch
//
//  手表第二页：社员卡式登录信息页。
//  版式参考手机端 MemberCardFace：社徽 + 姓名 + 编号 + 年级班级部门。
//  数据由 WatchConnectivity 从手机端同步（含头像数据）。
//

import SwiftUI
import UIKit

struct ProfileWatchView: View {
    @ObservedObject private var session = WatchSessionManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if session.loginInfo.isLoggedIn {
                    MemberWatchCard(info: session.loginInfo)
                } else {
                    NotLoggedInWatchCard(
                        isPhoneReachable: session.isPhoneReachable,
                        isSyncing: session.syncInProgress,
                        onRetry: {
                            WatchSessionManager.shared.requestSync()
                        }
                    )
                }
            }
            .padding(.bottom, 4)
        }
    }
}

/// 已登录时展示的社员卡（手机端 MemberCardFace 的手表简化版）。
struct MemberWatchCard: View {
    let info: WatchLoginInfo
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var showPosition = false

    private var memberID: String {
        let cleaned = info.idCode
            .replacingOccurrences(of: "No.", with: "")
            .replacingOccurrences(of: "NO.", with: "")
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "" : "ID: \(cleaned.suffix(6))"
    }

    private var classLine: String {
        let generation = cleaned(info.generation)
        let className = cleaned(info.className)
        if !generation.isEmpty, !className.isEmpty {
            return generation + className
        }
        return generation.isEmpty ? className : generation
    }

    private var departmentLine: String {
        cleaned(info.department)
    }

    private func cleaned(_ text: String) -> String {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty || value == "无" ? "" : value
    }

    private var positionLine: String {
        let position = info.position.trimmingCharacters(in: .whitespacesAndNewlines)
        return position.isEmpty || position == "社员" ? "正式社员" : position
    }

    private var hasMetaInfo: Bool {
        !classLine.isEmpty || !departmentLine.isEmpty
    }

    var body: some View {
        VStack(spacing: 6) {
            header
            MemberAvatarView(
                name: info.name,
                avatarData: info.avatarData,
                avatarUrl: info.avatarUrl
            )
                .padding(.top, 4)
            nameBlock

            if !isLuminanceReduced, hasMetaInfo {
                Button {
                    showPosition.toggle()
                } label: {
                    // 默认：班级一行 + 部门一行；职务：固定两行，长文本自动换行。
                    Text(showPosition ? positionLine + "\n" : classLine + "\n" + departmentLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.15), value: showPosition)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    showPosition
                        ? "职务 \(positionLine)"
                        : "班级 \(classLine)，部门 \(departmentLine)"
                )
                .accessibilityHint("点击切换显示职务")
            } else if !isLuminanceReduced {
                // 没有班级/部门信息时，直接展示职务（默认“正式社员”），固定两行。
                Text(positionLine + "\n")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
            }

            footer
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image("ClubLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 15, height: 15)
                .clipShape(Circle())

            Text("树莓社员卡")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.accentColor)
                .kerning(0.4)

            Spacer(minLength: 4)

            if !memberID.isEmpty, !isLuminanceReduced {
                Text(memberID)
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .kerning(0.6)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var nameBlock: some View {
        Group {
            if isLuminanceReduced {
                Text("轻触查看")
                    .foregroundStyle(.secondary)
            } else {
                Text(info.name)
            }
        }
        .font(.headline)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(.green)
                .frame(width: 6, height: 6)
            Text("ACTIVE MEMBER")
                .font(.footnote.weight(.semibold))
                .kerning(0.8)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("活跃会员")
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.18),
                            Color.accentColor.opacity(0.05),
                            Color(red: 0.94, green: 0.17, blue: 0.22).opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .stroke(Color.accentColor.opacity(0.08), lineWidth: 20)
                .frame(width: 150, height: 150)
                .offset(x: 95, y: -80)
        }
    }
}

/// 头像独立子视图：图片只解码/加载一次，父卡片刷新时不会重新闪一下。
private struct MemberAvatarView: View {
    let name: String
    let avatarData: Data?
    let avatarUrl: String

    @State private var decodedImage: UIImage?

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(name.isEmpty ? "?" : String(name.prefix(1)))
                .font(.title2.bold())
                .foregroundStyle(.white)

            if let decodedImage {
                Image(uiImage: decodedImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else if let url = URL(string: avatarUrl), !avatarUrl.isEmpty {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.clear
                    }
                }
                .clipShape(Circle())
            }
        }
        .frame(width: 56, height: 56)
        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
        .task(id: avatarData) {
            decodedImage = avatarData.flatMap(UIImage.init(data:))
        }
    }
}

/// 未登录时的手表提示卡。
private struct NotLoggedInWatchCard: View {
    let isPhoneReachable: Bool
    let isSyncing: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.8), .purple.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("?")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .frame(width: 60, height: 60)

            Text("未登录")
                .font(.headline)

            Text("请在手机 App 登录\n个人信息会自动同步到这里")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !isPhoneReachable {
                Text(isSyncing ? "手机 App 未连接\n正在自动重试，请打开手机 App" : "手机 App 未连接")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            Button(isSyncing ? "同步中…" : "重新同步", action: onRetry)
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(isSyncing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.accentColor.opacity(0.06))
        )
    }
}

#Preview {
    ProfileWatchView()
}

#Preview("社员卡示例") {
    ScrollView {
        MemberWatchCard(
            info: WatchLoginInfo(
                isLoggedIn: true,
                name: "沈孙丰",
                idCode: "No.00001",
                avatarUrl: "",
                loginAt: Date(),
                alias: "树莓",
                generation: "2026级",
                className: "高一(1)班",
                department: "摄影部",
                position: "摄影部部长",
                rating: "核心社员"
            )
        )
        .padding(.vertical, 8)
    }
}
