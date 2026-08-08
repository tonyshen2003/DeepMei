//
//  ProfileWatchView.swift
//  DeepMeiWatch
//
//  手表第二页：展示手机 App 上登录的社员信息（由 WatchConnectivity 自动同步）。
//

import Foundation
import SwiftUI

struct ProfileWatchView: View {
    @ObservedObject private var session = WatchSessionManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                avatar

                if session.loginInfo.isLoggedIn {
                    Text(session.loginInfo.name)
                        .font(.headline)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    if !session.loginInfo.idCode.isEmpty {
                        Text(session.loginInfo.idCode)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let loginAt = session.loginInfo.loginAt {
                        Text("登录于 \(loginAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("未登录")
                        .font(.headline)

                    Text("请在手机 App 登录\n个人信息会自动同步到这里")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if !session.isPhoneReachable {
                        Text("手机 App 未连接")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }

                    Button("重新同步") {
                        WatchSessionManager.shared.refresh()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .accessibilityLabel("个人信息")
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(session.loginInfo.isLoggedIn ? String(session.loginInfo.name.prefix(1)) : "?")
                .font(.title2.bold())
                .foregroundStyle(.white)
        }
        .frame(width: 56, height: 56)
        .overlay {
            if session.loginInfo.isLoggedIn, !session.loginInfo.avatarUrl.isEmpty {
                AsyncImage(url: URL(string: session.loginInfo.avatarUrl)) { phase in
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
    }
}

#Preview {
    ProfileWatchView()
}
