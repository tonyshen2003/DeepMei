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
    @Published private(set) var loggedInMemberCode: String
    @Published private(set) var loggedInAt: Date?
    @Published private(set) var loggedInAvatarUrl: String
    @Published private(set) var loggedInAlias: String
    @Published private(set) var loggedInGeneration: String
    @Published private(set) var loggedInClassName: String
    @Published private(set) var loggedInDepartment: String
    @Published private(set) var loggedInPosition: String
    @Published private(set) var loggedInRating: String

    private enum Keys {
        static let loggedIn = "login_logged_in"
        static let name = "login_name"
        static let idCode = "login_id_code"
        static let memberCode = "login_member_code"
        static let loginAt = "login_at"
        static let avatarUrl = "login_avatar_url"
        static let alias = "login_alias"
        static let generation = "login_generation"
        static let className = "login_class_name"
        static let department = "login_department"
        static let position = "login_position"
        static let rating = "login_rating"
    }

    private init() {
        let defaults = UserDefaults.standard
        isLoggedIn = defaults.bool(forKey: Keys.loggedIn)
        loggedInName = defaults.string(forKey: Keys.name) ?? ""
        loggedInIdCode = defaults.string(forKey: Keys.idCode) ?? ""
        loggedInMemberCode = defaults.string(forKey: Keys.memberCode) ?? ""
        loggedInAt = defaults.object(forKey: Keys.loginAt) as? Date
        loggedInAvatarUrl = defaults.string(forKey: Keys.avatarUrl) ?? ""
        loggedInAlias = defaults.string(forKey: Keys.alias) ?? ""
        loggedInGeneration = defaults.string(forKey: Keys.generation) ?? ""
        loggedInClassName = defaults.string(forKey: Keys.className) ?? ""
        loggedInDepartment = defaults.string(forKey: Keys.department) ?? ""
        loggedInPosition = defaults.string(forKey: Keys.position) ?? ""
        loggedInRating = defaults.string(forKey: Keys.rating) ?? ""
    }

    func login(
        name: String,
        idCode: String,
        memberCode: String = "",
        avatarUrl: String = "",
        alias: String = "",
        generation: String = "",
        className: String = "",
        department: String = "",
        position: String = "",
        rating: String = ""
    ) {
        isLoggedIn = true
        loggedInName = name
        loggedInIdCode = idCode
        loggedInMemberCode = memberCode
        loggedInAt = Date()
        loggedInAvatarUrl = avatarUrl
        loggedInAlias = alias
        loggedInGeneration = generation
        loggedInClassName = className
        loggedInDepartment = department
        loggedInPosition = position
        loggedInRating = rating

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Keys.loggedIn)
        defaults.set(name, forKey: Keys.name)
        defaults.set(idCode, forKey: Keys.idCode)
        defaults.set(memberCode, forKey: Keys.memberCode)
        defaults.set(loggedInAt, forKey: Keys.loginAt)
        defaults.set(avatarUrl, forKey: Keys.avatarUrl)
        defaults.set(alias, forKey: Keys.alias)
        defaults.set(generation, forKey: Keys.generation)
        defaults.set(className, forKey: Keys.className)
        defaults.set(department, forKey: Keys.department)
        defaults.set(position, forKey: Keys.position)
        defaults.set(rating, forKey: Keys.rating)

        // 把最新登录态同步给 Apple Watch（手表第二页展示用）
        WatchSessionManager.shared.syncLoginState()
    }

    func logout() {
        isLoggedIn = false
        loggedInName = ""
        loggedInIdCode = ""
        loggedInMemberCode = ""
        loggedInAt = nil
        loggedInAvatarUrl = ""
        loggedInAlias = ""
        loggedInGeneration = ""
        loggedInClassName = ""
        loggedInDepartment = ""
        loggedInPosition = ""
        loggedInRating = ""

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.loggedIn)
        defaults.removeObject(forKey: Keys.name)
        defaults.removeObject(forKey: Keys.idCode)
        defaults.removeObject(forKey: Keys.memberCode)
        defaults.removeObject(forKey: Keys.loginAt)
        defaults.removeObject(forKey: Keys.avatarUrl)
        defaults.removeObject(forKey: Keys.alias)
        defaults.removeObject(forKey: Keys.generation)
        defaults.removeObject(forKey: Keys.className)
        defaults.removeObject(forKey: Keys.department)
        defaults.removeObject(forKey: Keys.position)
        defaults.removeObject(forKey: Keys.rating)

        // 退出登录时同步清空手表上的个人信息
        WatchSessionManager.shared.syncLoginState()
    }
}
