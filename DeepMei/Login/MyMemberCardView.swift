//
//  MyMemberCardView.swift
//  DeepMei
//
//  我的社员卡：登录后向管理员出示社员卡与识别码二维码。
//
//  设计遵循 HIG：
//  - 全屏页面容器 + 系统分组背景，内容按「卡面 → 二维码 → 操作」分层；
//  - 出示场景保持屏幕常亮，离开页面自动恢复；
//  - 深色模式下二维码保持白底黑码，保证扫码对比度；
//  - 提供 VoiceOver 标签与「复制识别码」主操作。
//

import SwiftUI
import UIKit

struct MyMemberCardView: View {
    @ObservedObject private var loginManager = LoginManager.shared
    @State private var toast: String?
    @State private var wasIdleTimerDisabled = false

    /// 把登录态映射成标准社员卡数据（卡面组件只依赖 CheckInMember）。
    private var member: CheckInMember {
        CheckInMember(
            name: loginManager.loggedInName,
            alias: loginManager.loggedInAlias,
            idCode: loginManager.loggedInIdCode,
            generation: loginManager.loggedInGeneration,
            className: loginManager.loggedInClassName,
            department: loginManager.loggedInDepartment,
            readableCode: loginManager.loggedInMemberCode,
            position: loginManager.loggedInPosition
        )
    }

    private var memberCode: String {
        loginManager.loggedInMemberCode
    }

    private var qrImage: UIImage? {
        MemberQRCodeGenerator.pngData(for: memberCode).flatMap(UIImage.init(data:))
    }

    var body: some View {
        Group {
            if loginManager.isLoggedIn {
                content
            } else {
                LoginPromptView()
            }
        }
        .navigationTitle("我的社员卡")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var content: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // 1. 社员卡（标准 ID-1 卡面，与签到页同一组件）
                    MemberCardFace(member: member)
                        .frame(maxWidth: 560)
                        .padding(.top, 16)

                    // 2. 识别码二维码（白底保证深浅色模式下对比度一致）
                    if !memberCode.isEmpty {
                        qrSection
                            .frame(maxWidth: 360)
                    }

                    // 3. 主操作与说明（保持单一主操作，克制不堆叠）
                    VStack(spacing: 12) {
                        Button(action: copyCode) {
                            Label("复制识别码", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(memberCode.isEmpty)
                        .frame(maxWidth: 560)

                        Text("向管理员出示此页面即可完成身份核验")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.75), in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
        .onAppear {
            // 出示场景保持屏幕常亮，避免扫码/核验时熄屏
            wasIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = wasIdleTimerDisabled
        }
    }

    private var qrSection: some View {
        VStack(spacing: 14) {
            Text("识别码二维码")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            QRCodeTile(code: memberCode, qrImage: qrImage)

            Text(memberCode)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(20)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }

    private func copyCode() {
        guard !memberCode.isEmpty else { return }
        UIPasteboard.general.string = memberCode
        showToast("识别码已复制")
    }

    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            toast = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation(.easeIn(duration: 0.25)) {
                toast = nil
            }
        }
    }
}

/// 白底二维码块：任何深浅色模式下都保持白底黑码，扫码对比度稳定。
private struct QRCodeTile: View {
    let code: String
    let qrImage: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)

            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 180, height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("社员识别码二维码")
        .accessibilityValue(code)
    }
}
