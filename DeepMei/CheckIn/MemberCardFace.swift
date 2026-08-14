//
//  MemberCardFace.swift
//  DeepMei
//
//  高质感树莓社员卡：斜切渐变 + 反光贴膜 + 防伪底纹 + 实体卡片版式。
//  与 Android MemberCardFace 对齐：ISO/IEC 7810 ID-1 比例（85.6:53.98）、约 20pt 圆角。
//

import SwiftUI

struct MemberCardFace: View {
    let member: CheckInMember
    var showStamp: Bool = false

    /// 内容区真实（最小）高度，用于在超出卡面时等比缩放，避免上下内容被裁切。
    @State private var contentHeight: CGFloat = 0

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(uiColor: .secondarySystemGroupedBackground),
                Color(uiColor: .systemGroupedBackground),
                Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var memberID: String {
        let raw = [member.idCode, member.readableCode, member.memberSeq]
            .first(where: { !$0.isEmpty }) ?? ""
        let cleaned = raw
            .replacingOccurrences(of: "No.", with: "")
            .replacingOccurrences(of: "NO.", with: "")
        return "ID: \(cleaned.suffix(6))"
    }

    private var formattedPosition: String {
        member.position
            .replacingOccurrences(of: "部/部长", with: "部部长")
            .replacingOccurrences(of: " / ", with: " · ")
            .replacingOccurrences(of: "/", with: " · ")
    }

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = proxy.size.width
            let cardHeight = cardWidth * (53.98 / 85.6)
            // 内容高于卡面时等比缩小；正常情况为 1，不影响设计
            let contentScale = min(1, cardHeight / max(contentHeight, 1))

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(cardGradient)

                // 右上角反光叠加光晕（模拟实体卡面的贴膜层）
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [Color.accentColor.opacity(0.14), .clear],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 340
                        )
                    )

                // 防伪底纹：低透明度几何线圈
                Circle()
                    .stroke(Color.primary.opacity(0.04), lineWidth: 40)
                    .frame(width: 320, height: 320)
                    .offset(x: 130, y: 120)
                Circle()
                    .stroke(Color.accentColor.opacity(0.06), lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .offset(x: -140, y: -120)

                // 内容层：超出卡面高度时等比缩放，保证上下内容完整可见
                cardContent
                    .scaleEffect(contentScale, anchor: .center)
                    .frame(width: cardWidth, height: cardHeight, alignment: .center)

                // 隐形测量副本：用 0 高度提案压出内容的最小高度，作为缩放依据
                cardContent
                    .background(
                        GeometryReader { inner in
                            Color.clear.preference(
                                key: CardContentHeightKey.self,
                                value: inner.size.height
                            )
                        }
                    )
                    .frame(width: cardWidth, height: 0, alignment: .top)
                    .hidden()

                if showStamp {
                    StampBadge()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 8)
                        .padding(.bottom, 12)
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .onPreferenceChange(CardContentHeightKey.self) { contentHeight = $0 }
        }
        .aspectRatio(85.6 / 53.98, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(
            color: .black.opacity(showStamp ? 0.08 : 0.16),
            radius: showStamp ? 4 : 12,
            y: showStamp ? 2 : 6
        )
    }

    /// 卡面文字内容（与背景、印章分离，便于测量与缩放）。
    private var cardContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image("ClubLogo")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                    Text("苏州中学树莓社社员")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                        .kerning(0.5)
                }
                Spacer(minLength: 8)
                if !memberID.isEmpty {
                    Text(memberID)
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .kerning(1.4)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .leading, spacing: 4) {
                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(member.name)
                        .font(.system(size: 26, weight: .black))
                        .kerning(0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !member.alias.isEmpty {
                        Text(member.alias)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }

                let meta = [member.generation, member.department]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                Text(meta.isEmpty ? "苏州中学树莓社 · 注册社员" : meta)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(formattedPosition.isEmpty ? "正式社员" : formattedPosition)
                    .font(.footnote.weight(.semibold))
                    .italic()
                    .kerning(0.4)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 7, height: 7)
                Text("ACTIVE MEMBER")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .kerning(1.4)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

/// 内容区最小高度偏好（用于把测量值传回视图）。
private struct CardContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 物理印章：放大 → 快速压落 → 弹性回弹，模拟真实盖章“咚”的一下。
private struct StampBadge: View {
    @State private var scale: CGFloat = 2.4
    @State private var opacity: Double = 0

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    private var sealColor: Color {
        // 印泥绯红：浅色沿用 Android 同款 #C62828，深色自动提亮，保证文字 4.5:1
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.84, green: 0.39, blue: 0.40, alpha: 1)
                : UIColor(red: 198 / 255.0, green: 40 / 255.0, blue: 40 / 255.0, alpha: 1)
        })
    }

    var body: some View {
        VStack(spacing: 2) {
            Text("VERIFIED\n已签到")
                .font(.footnote.weight(.black))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Text(timeText)
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .kerning(1)
                .opacity(0.8)
        }
        .foregroundStyle(sealColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(sealColor, lineWidth: 3.5)
        )
        .rotationEffect(.degrees(-14))
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.15)) {
                opacity = 1
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.52)) {
                scale = 1
            }
        }
    }
}
