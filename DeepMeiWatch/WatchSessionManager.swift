//
//  WatchSessionManager.swift
//  DeepMeiWatch
//
//  接收手机 App 通过 WatchConnectivity 同步过来的登录信息，供手表第二页展示。
//

import Combine
import Foundation
import WatchConnectivity

/// 手机 App 同步过来的登录信息（字段与 DeepMei.WatchLoginInfo 保持一致）。
struct WatchLoginInfo: Codable, Equatable {
    var isLoggedIn: Bool
    var name: String
    var idCode: String
    var avatarUrl: String
    var loginAt: Date?
}

@MainActor
final class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published private(set) var loginInfo = WatchLoginInfo(
        isLoggedIn: false,
        name: "",
        idCode: "",
        avatarUrl: "",
        loginAt: nil
    )
    @Published private(set) var isPhoneReachable = false

    private var lastRequestAt = Date.distantPast

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    private static func decode(_ dict: [String: Any]) -> WatchLoginInfo? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return try? JSONDecoder().decode(WatchLoginInfo.self, from: data)
    }

    /// 重新读取系统保留的最新应用上下文，并在手机可达时主动请求一次（App 回到前台时调用）。
    func refresh() {
        let session = WCSession.default
        if WCSession.isSupported(), session.activationState == .activated {
            if let info = Self.decode(session.applicationContext) {
                loginInfo = info
            }
            isPhoneReachable = session.isReachable
        }
        requestCurrentLoginStateIfPossible()
    }

    /// 手机端可达时，主动要一次最新登录态（兜底：应用上下文可能因手表 App
    /// 未安装而从未成功推送过）。
    private func requestCurrentLoginStateIfPossible() {
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        isPhoneReachable = session.isReachable
        guard session.isReachable else {
            print("⌚️ 手机 App 当前不可达，稍后会自动重试")
            return
        }
        // 模拟器上可达状态会频繁抖动，节流避免刷屏
        guard Date().timeIntervalSince(lastRequestAt) > 2 else { return }
        lastRequestAt = Date()

        print("⌚️ 正在向手机请求最新登录态…")
        session.sendMessage(
            ["request": "loginState"],
            replyHandler: nil,
            errorHandler: { error in
                print("⌚️ 向手机请求登录态失败: \(error)")
            }
        )
    }

    /// 手机端用普通消息回传登录态时（模拟器上比回包通道可靠）。
    private func apply(message: [String: Any]) {
        guard let payload = message["loginInfo"] as? [String: Any],
              let info = Self.decode(payload) else { return }
        loginInfo = info
        print("⌚️ 收到手机实时登录态: \(info.isLoggedIn ? info.name : "未登录")")
    }

    // MARK: WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            self.refresh()
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            if let info = Self.decode(applicationContext) {
                self.loginInfo = info
                print("⌚️ 收到手机推送的登录态: \(info.isLoggedIn ? info.name : "未登录")")
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.apply(message: message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            self.apply(message: userInfo)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
            self.requestCurrentLoginStateIfPossible()
        }
    }
}
