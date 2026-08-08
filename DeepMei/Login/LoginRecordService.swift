//
//  LoginRecordService.swift
//  DeepMei
//
//  登录记录写入：登录成功后把「登录人 / 时间 / 定位（系统权限允许时）」写入飞书登录记录表。
//  与 Android LoginRecordService 对齐；写入失败静默跳过，不影响登录。
//

import Foundation

struct LoginRecordService {
    static let shared = LoginRecordService()

    // ★★★ 登录记录表（飞书端已建表，与 Android 共用） ★★★
    private let appToken = "DCLswycxhiwXTaklIAec3CUJnBS"
    private let tableId = "tblyFE3XCBPm5EAE"
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        session = URLSession(configuration: configuration)
    }

    func recordLogin(name: String, idCode: String, lat: Double?, lng: Double?) async {
        do {
            let token = try await MemberService.shared.getTenantAccessToken()
            let url = URL(
                string: "https://open.feishu.cn/open-apis/bitable/v1/apps/\(appToken)/tables/\(tableId)/records"
            )!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

            let location: String?
            if let lat, let lng {
                location = "\(lat), \(lng)"
            } else {
                location = nil
            }
            let payload = LoginRecordPayload(
                fields: LoginRecordFields(
                    loginName: name,
                    idCode: idCode,
                    loginTime: Int64(Date().timeIntervalSince1970 * 1000),
                    loginMethod: "App 登录",
                    result: "成功",
                    location: location
                )
            )
            request.httpBody = try JSONEncoder().encode(payload)
            _ = try await session.data(for: request)
        } catch {
            print("登录记录写入失败: \(error)")
        }
    }
}

private struct LoginRecordPayload: Encodable {
    let fields: LoginRecordFields
}

private struct LoginRecordFields: Encodable {
    let loginName: String
    let idCode: String
    let loginTime: Int64
    let loginMethod: String
    let result: String
    let location: String?

    enum CodingKeys: String, CodingKey {
        case loginName = "登录人"
        case idCode = "社员编号"
        case loginTime = "登录时间"
        case loginMethod = "登录方式"
        case result = "结果"
        case location = "定位"
    }
}
