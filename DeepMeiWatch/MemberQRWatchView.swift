//
//  MemberQRWatchView.swift
//  DeepMeiWatch
//
//  手表第三页：固定展示登录社员的「社员识别码」二维码（如 SM201809A00100201，无横线）。
//  二维码 PNG 由手机端用 CoreImage 生成后随登录态同步过来（watchOS 没有 CoreImage）。
//  本页不滚动，内容按屏幕尺寸等比缩放，保证一屏放下。
//

import SwiftUI
import UIKit

struct MemberQRWatchView: View {
    @ObservedObject private var session = WatchSessionManager.shared
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var qrCodeValue: String? {
        let code = session.loginInfo.memberCode
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return code.isEmpty ? nil : code
    }

    var body: some View {
        GeometryReader { proxy in
            compactContent(
                qrSize: min(proxy.size.width * 0.88, proxy.size.height * 0.82)
            )
        }
    }

    private func compactContent(qrSize: CGFloat) -> some View {
        VStack(spacing: 6) {
            if session.loginInfo.isLoggedIn {
                if isLuminanceReduced {
                    QRUnavailableCard(
                        title: "二维码已隐藏",
                        message: "轻触查看"
                    )
                } else if let qrCodeValue = qrCodeValue,
                   let qrData = session.loginInfo.qrCodeData,
                   !qrData.isEmpty {
                    QRCodeTile(qrData: qrData, size: qrSize)

                    Text(qrCodeValue)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else {
                    QRUnavailableCard(
                        title: "二维码未同步",
                        message: "请在手机 App 重新登录",
                        isPhoneReachable: session.isPhoneReachable,
                        isSyncing: session.syncInProgress,
                        onRetry: {
                            WatchSessionManager.shared.requestSync()
                        }
                    )
                }
            } else {
                QRUnavailableCard(
                    title: "未登录",
                    message: "请在手机 App 登录",
                    isPhoneReachable: session.isPhoneReachable,
                    isSyncing: session.syncInProgress,
                    onRetry: {
                        WatchSessionManager.shared.requestSync()
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 白底二维码块，尺寸由页面按屏幕大小计算。
private struct QRCodeTile: View {
    let qrData: Data?
    let size: CGFloat

    private var qrImage: UIImage? {
        qrData.flatMap(UIImage.init(data:))
    }

    private var cornerRadius: CGFloat {
        size * 0.08
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white)

            if let qrImage {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.05)
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: size * 0.3))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .accessibilityLabel("社员识别码二维码")
    }
}

/// 未登录 / 二维码未同步时的紧凑提示。
private struct QRUnavailableCard: View {
    let title: String
    let message: String
    var isPhoneReachable: Bool = true
    var isSyncing: Bool = false
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "qrcode")
                .font(.title2)
                .foregroundStyle(Color.accentColor)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !isPhoneReachable {
                Text(isSyncing ? "手机 App 未连接\n正在自动重试" : "手机 App 未连接")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            if let onRetry {
                Button(isSyncing ? "同步中…" : "重新同步", action: onRetry)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .disabled(isSyncing)
            }
        }
        .padding(10)
    }
}

#Preview("二维码示例") {
    QRCodeTile(qrData: nil, size: 120)
}

#Preview {
    MemberQRWatchView()
}
