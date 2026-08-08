//
//  LoginManager.swift
//  DeepMei
//
//  前端登录态管理（UserDefaults 持久化，与 Android LoginManager 对齐）。
//  使用 ObservableObject 发布状态，登录 / 退出后界面自动刷新。
//

import Combine
import Foundation

@MainActor
final class LoginManager: ObservableObject {
    static let shared = LoginManager()

    @Published private(set) var isLoggedIn: Bool
    @Published private(set) var loggedInName: String
    @Published private(set) var loggedInIdCode: String
    @Published private(set) var loggedInAt: Date?
    @Published private(set) var loggedInAvatarUrl: String

    private enum Keys {
        static let loggedIn = "login_logged_in"
        static let name = "login_name"
        static let idCode = "login_id_code"
        static let loginAt = "login_at"
        static let avatarUrl = "login_avatar_url"
    }

    private init() {
        let defaults = UserDefaults.standard
        isLoggedIn = defaults.bool(forKey: Keys.loggedIn)
        loggedInName = defaults.string(forKey: Keys.name) ?? ""
        loggedInIdCode = defaults.string(forKey: Keys.idCode) ?? ""
        loggedInAt = defaults.object(forKey: Keys.loginAt) as? Date
        loggedInAvatarUrl = defaults.string(forKey: Keys.avatarUrl) ?? ""
    }

    func login(name: String, idCode: String, avatarUrl: String = "") {
        isLoggedIn = true
        loggedInName = name
        loggedInIdCode = idCode
        loggedInAt = Date()
        loggedInAvatarUrl = avatarUrl

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Keys.loggedIn)
        defaults.set(name, forKey: Keys.name)
        defaults.set(idCode, forKey: Keys.idCode)
        defaults.set(loggedInAt, forKey: Keys.loginAt)
        defaults.set(avatarUrl, forKey: Keys.avatarUrl)

        // 把最新登录态同步给 Apple Watch（手表第二页展示用）
        WatchSessionManager.shared.syncLoginState()
    }

    func logout() {
        isLoggedIn = false
        loggedInName = ""
        loggedInIdCode = ""
        loggedInAt = nil
        loggedInAvatarUrl = ""

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.loggedIn)
        defaults.removeObject(forKey: Keys.name)
        defaults.removeObject(forKey: Keys.idCode)
        defaults.removeObject(forKey: Keys.loginAt)
        defaults.removeObject(forKey: Keys.avatarUrl)

        // 退出登录时同步清空手表上的个人信息
        WatchSessionManager.shared.syncLoginState()
    }
}
