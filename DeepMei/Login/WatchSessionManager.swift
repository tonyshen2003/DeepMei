//
//  WatchSessionManager.swift
//  DeepMei
//
//  通过 WatchConnectivity 把手机端最新登录态同步给 Apple Watch。
//  使用 applicationContext：系统只保留最新一份，手表端启动/激活时会自动收到。
//

import Foundation
import UIKit
import WatchConnectivity

/// 同步给手表端的登录信息（字段与 DeepMeiWatch.WatchLoginInfo 保持一致）。
struct WatchLoginInfo: Codable {
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
final class WatchSessionManager: NSObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    private var retryTask: Task<Void, Never>?
    private var lastNotInstalledLogAt = Date.distantPast
    private var cachedAvatarData: Data?

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

        guard session.isWatchAppInstalled else {
            logWatchAppNotInstalled(session: session)
            scheduleInstallRetry()
            return
        }
        push(makeInfo(avatarData: cachedAvatarData))
        refreshAvatarForWatch()
    }

    /// 当前登录态字典（供手表端 sendMessage 主动请求时回复）。
    func currentLoginStateDict() -> [String: Any] {
        do {
            let data = try JSONEncoder().encode(makeInfo(avatarData: cachedAvatarData))
            return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        } catch {
            return [:]
        }
    }

    /// 响应手表的登录态请求：体积已压到几 KB，实时消息直接带完整数据（含头像/二维码），
    /// 同时用 applicationContext + transferUserInfo + transferFile 补推兜底。
    func respondToLoginStateRequest(session: WCSession) {
        let fullDict = currentLoginStateDict()
        do {
            try session.updateApplicationContext(fullDict)
        } catch {
            print("⌚️ 补推 applicationContext 失败: \(error)")
        }
        session.transferUserInfo(["loginInfo": fullDict])
        transferMediaFiles(for: makeInfo(avatarData: cachedAvatarData))
        if session.isReachable {
            session.sendMessage(
                ["loginInfo": fullDict],
                replyHandler: nil,
                errorHandler: { error in
                    print("⌚️ 实时消息发送失败: \(error)")
                }
            )
        }
        print("⌚️ 已响应手表的重新同步请求")
    }

    /// 头像/二维码单独走 transferFile：文件通道没有小 payload 限制，
    /// 且系统会排队投递，手表下次启动时也能收到。
    private func transferMediaFiles(for info: WatchLoginInfo) {
        let session = WCSession.default
        let fm = FileManager.default
        let dir = fm.temporaryDirectory

        if let avatar = info.avatarData {
            let url = dir.appendingPathComponent("avatar-\(UUID().uuidString).jpg")
            do {
                try avatar.write(to: url)
                session.transferFile(
                    url,
                    metadata: ["kind": "avatar", "memberCode": info.memberCode]
                )
            } catch {
                print("⌚️ 头像文件写入失败: \(error)")
            }
        }

        if let qr = info.qrCodeData {
            let url = dir.appendingPathComponent("qr-\(UUID().uuidString).png")
            do {
                try qr.write(to: url)
                session.transferFile(
                    url,
                    metadata: ["kind": "qr", "memberCode": info.memberCode]
                )
            } catch {
                print("⌚️ 二维码文件写入失败: \(error)")
            }
        }
    }

    /// 组装当前登录态；未登录时不会携带头像数据。
    private func makeInfo(avatarData: Data?) -> WatchLoginInfo {
        WatchLoginInfo(
            isLoggedIn: LoginManager.shared.isLoggedIn,
            name: LoginManager.shared.loggedInName,
            idCode: LoginManager.shared.loggedInIdCode,
            memberCode: LoginManager.shared.loggedInMemberCode,
            avatarUrl: LoginManager.shared.loggedInAvatarUrl,
            avatarData: LoginManager.shared.isLoggedIn ? avatarData : nil,
            loginAt: LoginManager.shared.loggedInAt,
            qrCodeData: MemberQRCodeGenerator.pngData(for: LoginManager.shared.loggedInMemberCode),
            alias: LoginManager.shared.loggedInAlias,
            generation: LoginManager.shared.loggedInGeneration,
            className: LoginManager.shared.loggedInClassName,
            department: LoginManager.shared.loggedInDepartment,
            position: LoginManager.shared.loggedInPosition,
            rating: LoginManager.shared.loggedInRating
        )
    }

    /// 头像 URL 在手机端已经能通过 ImageCacheManager 正确下载（处理飞书鉴权），
    /// 这里把头像压缩成小图随登录态补推一次，手表就不需要自己请求飞书 URL。
    private func refreshAvatarForWatch() {
        guard LoginManager.shared.isLoggedIn,
              !LoginManager.shared.loggedInAvatarUrl.isEmpty else {
            cachedAvatarData = nil
            return
        }

        let url = LoginManager.shared.loggedInAvatarUrl
        Task { @MainActor [weak self] in
            guard let self else { return }
            let image = await ImageCacheManager.shared.image(for: url)
            guard let data = image.flatMap({ Self.makeAvatarData(from: $0) }) else { return }
            if data != self.cachedAvatarData {
                self.cachedAvatarData = data
                self.push(self.makeInfo(avatarData: data))
            }
        }
    }

    /// 头像缩略图：手表头像显示只有 56pt，压到最长边 128pt 足够清晰，
    /// 同时减小体积，避免 applicationContext / transferUserInfo 超限。
    private static func makeAvatarData(from image: UIImage, maxDimension: CGFloat = 128) -> Data? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        // 必须用 1x 渲染，否则默认按屏幕 3x 输出，体积膨胀 9 倍撑爆 WatchConnectivity。
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }

    private func push(_ info: WatchLoginInfo) {
        do {
            let data = try JSONEncoder().encode(info)
            guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            let session = WCSession.default

            // 通道 1：applicationContext（持久化，最可靠）。
            // 手表 App 未安装时系统必然报 7006，而且还会额外打印
            // "WCSession counterpart app not installed"，所以这里直接跳过，
            // 等 sessionWatchStateDidChange / 回到前台时再补推。
            guard session.isWatchAppInstalled else {
                logWatchAppNotInstalled(session: session)
                return
            }
            do {
                try session.updateApplicationContext(dict)
                print("⌚️ 已推送登录态到手表(applicationContext): \(info.isLoggedIn ? info.name : "未登录")")
                stopRetry()
            } catch {
                let nsError = error as NSError
                if nsError.domain == WCErrorDomain,
                   nsError.code == WCError.Code.watchAppNotInstalled.rawValue {
                    // isWatchAppInstalled 为 true 却仍报 7006：通常是状态缓存未刷新
                    // （模拟器上常见），短时间内补推几次即可。
                    print("⌚️ applicationContext 报 7006（watchAppInstalled=true），稍后自动重试")
                    scheduleRetry()
                } else {
                    print("⌚️ applicationContext 推送失败: \(error)")
                }
            }

            // 通道 2：userInfo（系统排队投递，App 未运行时也能补投）
            session.transferUserInfo(["loginInfo": dict])

            // 通道 4：头像/二维码走文件传输，无小 payload 限制且会排队投递
            transferMediaFiles(for: info)

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

    /// 手表 App 未安装时只提示一次（避免每次同步都刷屏），并停止所有通道。
    private func logWatchAppNotInstalled(session: WCSession) {
        let now = Date()
        guard now.timeIntervalSince(lastNotInstalledLogAt) > 10 else { return }
        lastNotInstalledLogAt = now
        print(
            "⌚️ 手表 App 未安装(paired=\(session.isPaired), watchAppInstalled=false)，"
            + "跳过推送；安装完成后会自动补推最新登录态"
        )
    }

    /// 已安装却仍报 7006（例如模拟器状态缓存未刷新）时，短时间补推几次；
    /// 若期间手表 App 变为未安装则立即停止，避免空转刷屏。
    private func scheduleRetry() {
        guard retryTask == nil else { return }
        retryTask = Task { @MainActor [weak self] in
            for _ in 0..<5 {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled, let self else { return }
                guard WCSession.default.isWatchAppInstalled else {
                    self.logWatchAppNotInstalled(session: WCSession.default)
                    self.retryTask = nil
                    return
                }
                self.syncLoginState()
            }
            self?.retryTask = nil
        }
    }

    /// 手表 App 刚装好但系统状态还没刷新时，低频率等待一段时间；
    /// 一旦检测到已安装就立即补推，避免一直空等或反复打系统日志。
    private func scheduleInstallRetry() {
        guard retryTask == nil else { return }
        retryTask = Task { @MainActor [weak self] in
            for _ in 0..<12 {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled, let self else { return }
                guard WCSession.default.isWatchAppInstalled else {
                    self.logWatchAppNotInstalled(session: WCSession.default)
                    continue
                }
                self.retryTask = nil
                self.syncLoginState()
                return
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
            let manager = WatchSessionManager.shared
            replyHandler(manager.currentLoginStateDict())
            manager.respondToLoginStateRequest(session: session)
        }
    }

    /// 手表端不带回包地请求登录态时，用普通消息把数据发回去（模拟器回包通道不可靠）。
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message["request"] as? String == "loginState" else { return }
        Task { @MainActor in
            WatchSessionManager.shared.respondToLoginStateRequest(session: session)
        }
    }

    /// 手表端“重新同步”投递的排队请求：即使手机 App 刚才没在运行，
    /// 下次打开时会收到这里，把最新登录态补推回去。
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard userInfo["request"] as? String == "loginState" else { return }
        Task { @MainActor in
            WatchSessionManager.shared.respondToLoginStateRequest(session: session)
        }
    }

    /// 媒体文件发送完成（或失败）后清理临时文件。
    nonisolated func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        if let error {
            print("⌚️ 媒体文件传输失败: \(error)")
        }
        try? FileManager.default.removeItem(at: fileTransfer.file.fileURL)
    }
}
