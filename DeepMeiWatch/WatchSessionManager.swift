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
    var memberCode: String
    var avatarUrl: String
    var avatarData: Data?
    var loginAt: Date?
    var qrCodeData: Data?
    var alias: String
    var generation: String
    var className: String
    var department: String
    var position: String
    var rating: String

    init(
        isLoggedIn: Bool,
        name: String,
        idCode: String,
        memberCode: String = "",
        avatarUrl: String,
        avatarData: Data? = nil,
        loginAt: Date?,
        qrCodeData: Data? = nil,
        alias: String = "",
        generation: String = "",
        className: String = "",
        department: String = "",
        position: String = "",
        rating: String = ""
    ) {
        self.isLoggedIn = isLoggedIn
        self.name = name
        self.idCode = idCode
        self.memberCode = memberCode
        self.avatarUrl = avatarUrl
        self.avatarData = avatarData
        self.loginAt = loginAt
        self.qrCodeData = qrCodeData
        self.alias = alias
        self.generation = generation
        self.className = className
        self.department = department
        self.position = position
        self.rating = rating
    }

    private enum CodingKeys: String, CodingKey {
        case isLoggedIn, name, idCode, memberCode, avatarUrl, avatarData, loginAt, qrCodeData
        case alias, generation, className, department, position, rating
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isLoggedIn = try container.decodeIfPresent(Bool.self, forKey: .isLoggedIn) ?? false
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        idCode = try container.decodeIfPresent(String.self, forKey: .idCode) ?? ""
        memberCode = try container.decodeIfPresent(String.self, forKey: .memberCode) ?? ""
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl) ?? ""
        avatarData = try container.decodeIfPresent(Data.self, forKey: .avatarData)
        loginAt = try container.decodeIfPresent(Date.self, forKey: .loginAt)
        qrCodeData = try container.decodeIfPresent(Data.self, forKey: .qrCodeData)
        alias = try container.decodeIfPresent(String.self, forKey: .alias) ?? ""
        generation = try container.decodeIfPresent(String.self, forKey: .generation) ?? ""
        className = try container.decodeIfPresent(String.self, forKey: .className) ?? ""
        department = try container.decodeIfPresent(String.self, forKey: .department) ?? ""
        position = try container.decodeIfPresent(String.self, forKey: .position) ?? ""
        rating = try container.decodeIfPresent(String.self, forKey: .rating) ?? ""
    }
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
    @Published private(set) var syncInProgress = false

    private var lastRequestAt = Date.distantPast
    private var retryTask: Task<Void, Never>?
    /// 文件先于文字信息到达时，先按 memberCode 暂存，等文字信息到了再合并。
    private var pendingMedia: [String: [String: Data]] = [:]

    private static let cacheKey = "cachedWatchLoginInfo"

    private override init() {
        super.init()
        if let cached = Self.loadCached() {
            loginInfo = cached
        }
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    /// 把最新登录态写入本地，下次开 App 先恢复，不再依赖手机实时可达。
    private func persist(_ info: WatchLoginInfo) {
        guard let data = try? JSONEncoder().encode(info) else { return }
        UserDefaults.standard.set(data, forKey: Self.cacheKey)
    }

    private static func loadCached() -> WatchLoginInfo? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(WatchLoginInfo.self, from: data)
    }

    private func updateLoginInfo(_ info: WatchLoginInfo) {
        var merged = info
        if let media = pendingMedia[info.memberCode] {
            if merged.avatarData == nil, let data = media["avatar"] {
                merged.avatarData = data
            }
            if merged.qrCodeData == nil, let data = media["qr"] {
                merged.qrCodeData = data
            }
            pendingMedia.removeValue(forKey: info.memberCode)
        }
        loginInfo = merged
        persist(merged)
    }

    /// 合并图片数据：文字更新/旧上下文可能不带图，保留本地已有的头像和二维码；
    /// 只有换了一个社员时才清空旧图片，避免串人。
    private func mergingMedia(from info: WatchLoginInfo) -> WatchLoginInfo {
        var merged = info
        guard info.memberCode == loginInfo.memberCode,
              info.idCode == loginInfo.idCode else {
            return info
        }
        if merged.avatarData == nil {
            merged.avatarData = loginInfo.avatarData
        }
        if merged.qrCodeData == nil {
            merged.qrCodeData = loginInfo.qrCodeData
        }
        return merged
    }

    private static func decode(_ dict: [String: Any]) -> WatchLoginInfo? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return try? JSONDecoder().decode(WatchLoginInfo.self, from: data)
    }

    /// 重新读取系统保留的最新应用上下文，并在手机可达时主动请求一次（App 回到前台时调用）。
    func refresh() {
        let session = WCSession.default
        if WCSession.isSupported() {
            isPhoneReachable = session.isReachable
            if session.activationState == .activated,
               let info = Self.decode(session.applicationContext) {
                updateLoginInfo(mergingMedia(from: info))
            }
        }
        requestCurrentLoginStateIfPossible()
    }

    /// 用户点“重新同步”：立即尝试；手机不可达或会话未激活时自动重试，
    /// 同时投递一条排队请求，手机 App 下次打开时也能收到。
    func requestSync() {
        syncInProgress = true
        let session = WCSession.default
        if WCSession.isSupported(), session.activationState == .activated {
            session.transferUserInfo(["request": "loginState"])
        }
        refresh()
        scheduleRetryIfNeeded()
    }

    /// 手机不可达时每 3 秒重试一次，最多约 1 分钟；收到手机回包后停止。
    private func scheduleRetryIfNeeded() {
        guard retryTask == nil else { return }
        retryTask = Task { @MainActor [weak self] in
            for _ in 0..<20 {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled, let self else { return }
                self.refresh()
                if self.loginInfo.isLoggedIn {
                    break
                }
            }
            self?.retryTask = nil
            self?.syncInProgress = false
        }
    }

    /// 收到手机最新登录态后，结束“同步中”状态并取消自动重试。
    private func finishSync() {
        retryTask?.cancel()
        retryTask = nil
        syncInProgress = false
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
              var info = Self.decode(payload) else { return }
        info = mergingMedia(from: info)
        updateLoginInfo(info)
        finishSync()
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
                self.updateLoginInfo(self.mergingMedia(from: info))
                self.finishSync()
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

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let kind = file.metadata?["kind"] as? String,
              let data = try? Data(contentsOf: file.fileURL) else { return }
        let memberCode = file.metadata?["memberCode"] as? String ?? ""
        Task { @MainActor in
            self.handleReceivedMedia(kind: kind, data: data, memberCode: memberCode)
        }
    }

    /// 收到头像/二维码文件：当前社员直接合并，否则先暂存等文字信息。
    private func handleReceivedMedia(kind: String, data: Data, memberCode: String) {
        guard !memberCode.isEmpty else { return }
        if loginInfo.memberCode == memberCode {
            var updated = loginInfo
            switch kind {
            case "avatar":
                updated.avatarData = data
            case "qr":
                updated.qrCodeData = data
            default:
                return
            }
            updateLoginInfo(updated)
            finishSync()
        } else {
            pendingMedia[memberCode, default: [:]][kind] = data
        }
        print("⌚️ 收到媒体文件: \(kind) \(data.count) bytes")
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
            self.requestCurrentLoginStateIfPossible()
        }
    }
}
