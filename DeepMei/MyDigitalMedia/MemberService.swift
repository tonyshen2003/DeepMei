//
//  Untitled.swift
//  DeepMei
//
//  Created by 沈孙丰 on 2026/7/26.
//

import Foundation

// MARK: - 错误类型
enum MemberServiceError: Error, LocalizedError {
    case invalidURL
    case httpError(Int)
    case apiError(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL 无效"
        case .httpError(let code): return "网络错误 (\(code))"
        case .apiError(let code, let msg): return "飞书 API 错误 \(code): \(msg)"
        }
    }
}

// MARK: - 飞书 API 响应模型
private struct LarkTokenResponse: Decodable {
    let code: Int
    let msg: String
    let tenantAccessToken: String

    enum CodingKeys: String, CodingKey {
        case code, msg
        case tenantAccessToken = "tenant_access_token"
    }
}

private struct LarkRecordListResponse: Decodable {
    let code: Int
    let msg: String
    let data: DataPayload?

    struct DataPayload: Decodable {
        let items: [Item]?
        let pageToken: String?
        let hasMore: Bool?

        enum CodingKeys: String, CodingKey {
            case items
            case pageToken = "page_token"
            case hasMore = "has_more"
        }
    }

    struct Item: Decodable {
        let fields: [String: LarkValue]
    }
}

// MARK: - 飞书字段值通用解码
// 飞书多行文本返回 [{text:"...", type:"text"}]，单行文本返回 String，数字返回 Number
private enum LarkValue: Decodable {
    case string(String)
    case double(Double)
    case int(Int)
    case array([LarkValue])
    case object([String: LarkValue])
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Int.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else if let v = try? c.decode([LarkValue].self) { self = .array(v) }
        else if let v = try? c.decode([String: LarkValue].self) { self = .object(v) }
        else { self = .null }
    }

    var flattenedText: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return d == d.rounded() ? String(Int(d)) : String(d)
        case .array(let arr): return arr.map { $0.flattenedText }.joined()
        case .object(let dict):
            if case .string(let t) = dict["text"] ?? .null { return t }
            if case .string(let n) = dict["name"] ?? .null { return n }
            return ""
        case .null: return ""
        }
    }

    var intValue: Int? {
        switch self {
        case .int(let i): return i
        case .double(let d): return Int(d)
        case .string(let s): return Int(s)
        default: return nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case .double(let d): return d
        case .int(let i): return Double(i)
        case .string(let s): return Double(s)
        default: return nil
        }
    }
}

// MARK: - 飞书社员数据服务
// ⚠️ 测试期临时硬编码密钥，上架前务必迁移到后端中间件！
actor MemberService {
    static let shared = MemberService()

    // TODO: 替换为你飞书应用的真实凭据
    private let appId = "cli_xxxxxxxxxxxxxxxx"
    private let appSecret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    private let appToken = "xxxxxxxxxxxxxxxxxxxx"  // 多维表格 URL 中 /base/ 后的部分
    private let tableId = "tblxxxxxxxxxxxx"        // 多维表格 URL 中 ?table= 后的部分

    private let baseURL = URL(string: "https://open.feishu.cn")!
    private var cachedToken: String?
    private var tokenExpiry: Date?

    /// 按姓名或社员编号查询社员
    func searchMember(byNameOrCode query: String) async throws -> RaspberryMember? {
        let token = try await getTenantAccessToken()
        let all = try await fetchAllRecords(token: token)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return all.first {
            $0.name == trimmed || $0.idCode.caseInsensitiveCompare(trimmed) == .orderedSame
        }
    }

    // MARK: Token
    private func getTenantAccessToken() async throws -> String {
        if let cached = cachedToken, let exp = tokenExpiry, exp > Date().addingTimeInterval(60) {
            return cached
        }
        var req = URLRequest(url: baseURL.appendingPathComponent("/open-apis/auth/v3/tenant_access_token/internal"))
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode([
            "app_id": appId,
            "app_secret": appSecret
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw MemberServiceError.httpError((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded = try JSONDecoder().decode(LarkTokenResponse.self, from: data)
        guard decoded.code == 0 else {
            throw MemberServiceError.apiError(code: decoded.code, message: decoded.msg)
        }
        cachedToken = decoded.tenantAccessToken
        tokenExpiry = Date().addingTimeInterval(7200)
        return decoded.tenantAccessToken
    }

    // MARK: Records (分页拉取所有记录)
    private func fetchAllRecords(token: String) async throws -> [RaspberryMember] {
        var members: [RaspberryMember] = []
        var pageToken: String?
        repeat {
            var components = URLComponents(
                url: baseURL.appendingPathComponent("/open-apis/bitable/v1/apps/\(appToken)/tables/\(tableId)/records"),
                resolvingAgainstBaseURL: false
            )!
            var queryItems = [URLQueryItem(name: "page_size", value: "100")]
            if let pt = pageToken { queryItems.append(URLQueryItem(name: "page_token", value: pt)) }
            components.queryItems = queryItems
            var req = URLRequest(url: components.url!)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            let (data, _) = try await URLSession.shared.data(for: req)
            let decoded = try JSONDecoder().decode(LarkRecordListResponse.self, from: data)
            guard decoded.code == 0 else {
                throw MemberServiceError.apiError(code: decoded.code, message: decoded.msg)
            }
            for item in decoded.data?.items ?? [] {
                if let m = Self.mapRecord(fields: item.fields) {
                    members.append(m)
                }
            }
            pageToken = decoded.data?.pageToken
            if decoded.data?.hasMore != true { break }
        } while pageToken != nil
        return members
    }

    // MARK: 字段映射 (多维表格字段名 → RaspberryMember)
    // ⚠️ 字段名必须与多维表格实际字段名完全一致（含括号、空格）
    private static func mapRecord(fields: [String: LarkValue]) -> RaspberryMember? {
        func text(_ key: String) -> String {
            (fields[key]?.flattenedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let name = text("姓名")
        guard !name.isEmpty else { return nil }
        return RaspberryMember(
            name: name,
            idCode: text("社员编号"),
            generation: text("年级"),
            clazz: text("班级（分班后）"),
            department: text("社团部门"),
            roles: text("社团职务"),
            college: text("升学去向"),
            joinDate: text("入社日期"),
            activityCount: fields["参与活动次数"]?.intValue ?? 0,
            totalHours: fields["统计时长 (社团活动记录表)"]?.doubleValue ?? 0,
            description: text("详细介绍")
        )
    }
}
