//
//  WatchSessionManager.swift
//  DeepMei
//
//  通过 WatchConnectivity 把手机端最新登录态同步给 Apple Watch。
//  使用 applicationContext：系统只保留最新一份，手表端启动/激活时会自动收到。
//

import Foundation
import WatchConnectivity

/// 同步给手表端的登录信息（字段与 DeepMeiWatch.WatchLoginInfo 保持一致）。
struct WatchLoginInfo: Codable {
    var isLoggedIn: Bool
    var name: String
    var idCode: String
    var avatarUrl: String
    var loginAt: Date?
}

@MainActor
final class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    private var retryTask: Task<Void, Never>?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    /// 把 LoginManager 当前登录态推送一份到手表（登录、退出、App 启动时调用）。
    func syncLoginState() {
        let session = WCSession.default
        guard WCSession.isSupported() else { return }
        guard session.activationState == .activated else { return }

        let info = WatchLoginInfo(
            isLoggedIn: LoginManager.shared.isLoggedIn,
            name: LoginManager.shared.loggedInName,
            idCode: LoginManager.shared.loggedInIdCode,
            avatarUrl: LoginManager.shared.loggedInAvatarUrl,
            loginAt: LoginManager.shared.loggedInAt
        )
        push(info)
    }

    /// 当前登录态字典（供手表端 sendMessage 主动请求时回复）。
    func currentLoginStateDict() -> [String: Any] {
        let info = WatchLoginInfo(
            isLoggedIn: LoginManager.shared.isLoggedIn,
            name: LoginManager.shared.loggedInName,
            idCode: LoginManager.shared.loggedInIdCode,
            avatarUrl: LoginManager.shared.loggedInAvatarUrl,
            loginAt: LoginManager.shared.loggedInAt
        )
        do {
            let data = try JSONEncoder().encode(info)
            return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        } catch {
            return [:]
        }
    }

    private func push(_ info: WatchLoginInfo) {
        do {
            let data = try JSONEncoder().encode(info)
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            let session = WCSession.default

            // 通道 1：applicationContext（持久化，最可靠；模拟器上可能误报 7006）
            do {
                try session.updateApplicationContext(dict)
                print("⌚️ 已推送登录态到手表(applicationContext): \(info.isLoggedIn ? info.name : "未登录")")
                stopRetry()
            } catch {
                let nsError = error as NSError
                if nsError.domain == WCErrorDomain, nsError.code == WCError.Code.watchAppNotInstalled.rawValue {
                    print(
                        "⌚️ applicationContext 推送被拒(7006)，改用其他通道 "
                        + "(paired=\(session.isPaired), watchAppInstalled=\(session.isWatchAppInstalled))"
                    )
                    scheduleRetryIfNotInstalled()
                } else {
                    print("⌚️ applicationContext 推送失败: \(error)")
                }
            }

            // 通道 2：userInfo（系统排队投递，App 未运行时也能补投）
            session.transferUserInfo(["loginInfo": dict])

            // 通道 3：实时消息（手表正在运行且可达时立即收到，绕开模拟器坏掉的回包通道）
            if session.isReachable {
                session.sendMessage(
                    ["loginInfo": dict],
                    replyHandler: nil,
                    errorHandler: { error in
                        print("⌚️ 实时消息发送失败: \(error)")
                    }
                )
            }
        } catch {
            print("⌚️ 登录态编码失败: \(error)")
        }
    }

    /// 手表 App 装好后 WatchConnectivity 状态可能不会立刻刷新，
    /// 这里每 3 秒重试一次（最多 1 分钟），期间装好就能补发。
    private func scheduleRetryIfNotInstalled() {
        guard retryTask == nil else { return }
        retryTask = Task { @MainActor [weak self] in
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled, let self else { return }
                self.syncLoginState()
            }
            self?.retryTask = nil
        }
    }

    private func stopRetry() {
        retryTask?.cancel()
        retryTask = nil
    }

    // MARK: WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            WatchSessionManager.shared.syncLoginState()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    /// 手表 App 安装状态变化（例如刚装好）时，立刻补推一次最新登录态。
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            WatchSessionManager.shared.syncLoginState()
        }
    }

    /// 手机与手表的连接状态变化（手表 App 安装好/手机 App 回到前台时）也补推一次。
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            WatchSessionManager.shared.syncLoginState()
        }
    }

    /// 手表端主动请求最新登录态时回复（对应手表启动/手机变为可达）。
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        print("⌚️ 收到手表请求: \(message)")
        guard message["request"] as? String == "loginState" else {
            replyHandler([:])
            return
        }
        Task { @MainActor in
            replyHandler(WatchSessionManager.shared.currentLoginStateDict())
            print("⌚️ 已回复手表最新登录态")
        }
    }

    /// 手表端不带回包地请求登录态时，用普通消息把数据发回去（模拟器回包通道不可靠）。
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message["request"] as? String == "loginState" else { return }
        Task { @MainActor in
            let dict = WatchSessionManager.shared.currentLoginStateDict()
            session.sendMessage(
                ["loginInfo": dict],
                replyHandler: nil,
                errorHandler: { error in
                    print("⌚️ 实时消息发送失败: \(error)")
                }
            )
            print("⌚️ 已把手表登录态以消息形式发回")
        }
    }
}
