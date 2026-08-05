//
//  MemberService.swift
//  DeepMei
//

import Foundation
import UIKit

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
private struct LarkTokenResponse: Decodable, Sendable {
    let code: Int
    let msg: String
    let tenantAccessToken: String

    enum CodingKeys: String, CodingKey {
        case code, msg
        case tenantAccessToken = "tenant_access_token"
    }
}

private struct LarkRecordListResponse: Decodable, Sendable {
    let code: Int
    let msg: String
    let data: DataPayload?

    struct DataPayload: Decodable, Sendable {
        let items: [Item]?
        let pageToken: String?
        let hasMore: Bool?

        enum CodingKeys: String, CodingKey {
            case items
            case pageToken = "page_token"
            case hasMore = "has_more"
        }
    }

    struct Item: Decodable, Sendable {
        let fields: [String: LarkValue]
    }
}

private struct DriveTmpDownloadResponse: Decodable, Sendable {
    let code: Int
    let msg: String
    let data: DataPayload?

    struct DataPayload: Decodable, Sendable {
        let tmpDownloadURLs: [TmpDownloadURL]?

        enum CodingKeys: String, CodingKey {
            case tmpDownloadURLs = "tmp_download_urls"
        }
    }

    struct TmpDownloadURL: Decodable, Sendable {
        let fileToken: String?
        let tmpDownloadURL: String?

        enum CodingKeys: String, CodingKey {
            case fileToken = "file_token"
            case tmpDownloadURL = "tmp_download_url"
        }
    }
}

// MARK: - 飞书字段值通用解码
enum LarkValue: Decodable, Encodable, Sendable {
    case string(String)
    case double(Double)
    case int(Int)
    case array([LarkValue])
    case object([String: LarkValue])
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .array(let arr): try container.encode(arr)
        case .object(let dict): try container.encode(dict)
        case .null: try container.encodeNil()
        }
    }

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
        case .array(let arr): return arr.map { $0.flattenedText }.joined(separator: ", ")
        case .object(let dict):
            if case .string(let t) = dict["text"] ?? .null { return t }
            if case .string(let n) = dict["name"] ?? .null { return n }
            if case .string(let a) = dict["alias"] ?? .null { return a }
            return ""
        case .null: return ""
        }
    }

    /// 📸 优先解析飞书【个人照片】的 tmp_url（能有效规避 403）
        var imageURL: String? {
            switch self {
            case .array(let arr):
                for item in arr {
                    if let url = item.imageURL { return url }
                }
                return nil
            case .object(let dict):
                // 💡 核心修改：优先匹配 tmp_url，其次才是普通 url
                if case .string(let tmpUrl) = dict["tmp_url"] ?? .null { return tmpUrl }
                if case .string(let url) = dict["url"] ?? .null { return url }
                return nil
            case .string(let s):
                return s.hasPrefix("http") ? s : nil
            default:
                return nil
            }
        }

        var imageURLs: [String] {
            switch self {
            case .array(let arr):
                return arr.flatMap { $0.imageURLs }
            case .object(let dict):
                // 💡 核心修改：优先匹配 tmp_url
                if case .string(let tmpUrl) = dict["tmp_url"] ?? .null { return [tmpUrl] }
                if case .string(let url) = dict["url"] ?? .null { return [url] }
                return []
            case .string(let s):
                return s.hasPrefix("http") ? [s] : []
            default:
                return []
            }
        }

    /// 🎨 解析代表作品（仅提取图片 URL + 文件名 + MIME 类型）
    var workItems: [WorkItem] {
        switch self {
        case .array(let arr):
            return arr.flatMap { $0.workItems }
        case .object(let dict):
            let urlString = dict["tmp_url"]?.flattenedText ?? dict["url"]?.flattenedText
            guard let url = urlString, !url.isEmpty else { return [] }

            var name = ""
            if case .string(let n) = dict["name"] ?? .null { name = n }

            var mimeType = ""
            if case .string(let t) = dict["type"] ?? .null { mimeType = t }

            let type = WorkItem.WorkType.detect(mimeType: mimeType, fileNameOrURL: name.isEmpty ? url : name)
            return [WorkItem(url: url, type: type, fileName: name)]
        case .string(let s):
            return s.hasPrefix("http") ? [WorkItem(url: s)] : []
        default:
            return []
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
actor MemberService {
    static let shared = MemberService()

    private let appId = "cli_aaefa41a0c389bd9"
    private let appSecret = "LxJl21fuVl1GHQitcBwcXeJe2Y6SObJ6"
    private let appToken = "YUZ4wB3YJiLTq2kUobZccYOKnBb"
    private let tableId = "tblepAz1PHnzwxA2"

    private let baseURL = URL(string: "https://open.feishu.cn")!
    private var cachedToken: String?
    private var tokenExpiry: Date?

    /// 全能查询（支持：姓名 / 社员编号 / 社员识别码 / 认读码 / 社员序号）
    func searchMember(byNameOrCodeOrAlias query: String) async throws -> RaspberryMember? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let token = try await getTenantAccessToken()
        
        // ⚡️ 多维度服务端精准 Filter
        let filterFormula = """
        OR(
            CurrentValue.[姓名] = "\(trimmed)",
            CurrentValue.[别名] = "\(trimmed)",
            CurrentValue.[社员编号] = "\(trimmed)",
            CurrentValue.[社员识别码] = "\(trimmed)",
            CurrentValue.[社员身份编码（认读码）] = "\(trimmed)",
            CurrentValue.[社员序号] = "\(trimmed)"
        )
        """
        
        var components = URLComponents(
            url: baseURL.appendingPathComponent("/open-apis/bitable/v1/apps/\(appToken)/tables/\(tableId)/records"),
            resolvingAgainstBaseURL: false
        )!
        
        components.queryItems = [
            URLQueryItem(name: "filter", value: filterFormula),
            URLQueryItem(name: "page_size", value: "1")
        ]
        
        guard let requestURL = components.url else {
            throw MemberServiceError.invalidURL
        }
        
        var req = URLRequest(url: requestURL)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw MemberServiceError.httpError((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        
        let decoded = try JSONDecoder().decode(LarkRecordListResponse.self, from: data)
        guard decoded.code == 0 else {
            throw MemberServiceError.apiError(code: decoded.code, message: decoded.msg)
        }
        
        if let firstItem = decoded.data?.items?.first {
            return await Self.mapRecord(fields: firstItem.fields)
        }
        
        return nil
    }

    // MARK: Token 鉴权
    func getTenantAccessToken() async throws -> String {
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

    // MARK: - 专门下载带签名的 tmp_url（不需要携带 Authorization 头）
    func downloadTempMedia(from urlString: String) async throws -> UIImage? {
        guard let url = URL(string: urlString) else { return nil }

        print("开始下载 tmp_url：\(urlString)")

        if url.path.contains("/drive/v1/medias/batch_get_tmp_download_url") {
            let token = try await getTenantAccessToken()
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

            let (data, response) = try await URLSession.shared.data(for: req)
            guard let httpResponse = response as? HTTPURLResponse else { return nil }
            if httpResponse.statusCode != 200 {
                print("批量临时下载链接请求失败，状态码: \(httpResponse.statusCode)")
                if let body = String(data: data, encoding: .utf8) {
                    print("批量临时下载链接响应体：\(body)")
                }
                return nil
            }

            let decoded = try JSONDecoder().decode(DriveTmpDownloadResponse.self, from: data)
            guard decoded.code == 0,
                  let tmpURLString = decoded.data?.tmpDownloadURLs?.first?.tmpDownloadURL,
                  let tmpURL = URL(string: tmpURLString) else {
                print("解析批量临时下载链接失败，返回码: \(decoded.code), msg: \(decoded.msg)")
                return nil
            }
            return try await downloadImageDirectly(from: tmpURL)
        }

        return try await downloadImageDirectly(from: url)
    }

    private func downloadImageDirectly(from url: URL) async throws -> UIImage? {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("临时媒体下载失败，状态码: \(statusCode)")
            if let body = String(data: data, encoding: .utf8) {
                print("临时媒体下载失败响应体：\(body)")
            }
            return nil
        }

        if let image = UIImage(data: data) {
            print("🎉 成功从 tmp_url 解析出图片，尺寸: \(image.size)")
            return image
        } else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ 警告: 状态码200但返回的不是图片，内容是: \(errorString)")
            } else {
                print("❌ 警告: 数据无法识别为图片，长度: \(data.count) 字节")
            }
            return nil
        }
    }

    // MARK: 字段映射（完全匹配实测数据表头）
    @MainActor static func mapRecord(fields: [String: LarkValue]) -> RaspberryMember? {
        
        func text(_ key: String) -> String {
            (fields[key]?.flattenedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
            
            let name = text("姓名")
            let alias = text("别名")
    
            guard !name.isEmpty else { return nil }
            
            // 💡 修复核心：安全解析入社日期，将飞书的时间戳转换为 Date 对象
            let finalJoinDate: Date
            if let timestamp = fields["入社日期"]?.doubleValue {
                // 如果能直接拿到数字，判断是否是 13 位毫秒级时间戳
                let seconds = timestamp > 10000000000 ? timestamp / 1000.0 : timestamp
                finalJoinDate = Date(timeIntervalSince1970: seconds)
            } else if let dateString = fields["入社日期"]?.flattenedText, let timestamp = Double(dateString) {
                // 如果被解析成了字符串型的数字，再次尝试转换
                let seconds = timestamp > 10000000000 ? timestamp / 1000.0 : timestamp
                finalJoinDate = Date(timeIntervalSince1970: seconds)
            } else {
                // 解析失败的兜底情况
                finalJoinDate = Date()
            }
        
        let finalBirthday: Date
        if let timestamp = fields["生日"]?.doubleValue {
            // 如果能直接拿到数字，判断是否是 13 位毫秒级时间戳
            let seconds = timestamp > 10000000000 ? timestamp / 1000.0 : timestamp
            finalBirthday = Date(timeIntervalSince1970: seconds)
        } else if let dateString = fields["生日"]?.flattenedText, let timestamp = Double(dateString) {
            // 如果被解析成了字符串型的数字，再次尝试转换
            let seconds = timestamp > 10000000000 ? timestamp / 1000.0 : timestamp
            finalBirthday = Date(timeIntervalSince1970: seconds)
        } else {
            // 解析失败的兜底情况
            finalBirthday = Date()
        }
        
            
            return RaspberryMember(
                name: name,
                alias: alias,
                idCode: text("社员编号"),
                generation: text("年级"),
                clazz: text("班级（分班后）"),
                Birthday:finalBirthday,
                contactQQ: text("QQ"),
                department: text("社团部门"),
                roles: text("社团职务"),
                rating: text("社员评级"),
                honors: text("其他职务或荣誉"),
                college: text("升学去向"),
                joinDate: finalJoinDate, // ✅ 完美：现在传入的是真正的 Date 对象
                activityCount: fields["参与活动次数"]?.intValue ?? 0,
                totalHours: fields["统计时长 (社团活动记录表)"]?.doubleValue ?? 0,
                description: text("详细介绍"),
                photoURLs: fields["个人照片"]?.imageURLs ?? [],
                works: fields["代表作品"]?.workItems ?? []
            )
        }
}

// MARK: - 社员全量快照（Worker /api/members/full）

/// 与 Android 版 MemberFullSnapshot 对应的全量快照响应。
private struct MemberFullSnapshot: Codable, Sendable {
    let updatedAt: Int64
    let items: [MemberSnapshotItem]
}

private struct MemberSnapshotItem: Codable, Sendable {
    let recordId: String
    let fields: [String: LarkValue]

    enum CodingKeys: String, CodingKey {
        case recordId
        case fields
    }
}

/// 本地持久化的快照封装（保存拉取时间，用于判断 24h 新鲜度）。
private struct StoredMemberSnapshot: Codable, Sendable {
    let savedAt: Date
    let snapshot: MemberFullSnapshot
}

/// 社员资料本地快照缓存（与 Android MemberSnapshotCache 对齐）：
/// - 查询优先命中本地快照，秒开、离线可用；
/// - 快照超过 24h 视为过期，查询时后台静默刷新；
/// - 也提供手动刷新（我的树莓右上角按钮）。
actor MemberSnapshotCache {
    static let shared = MemberSnapshotCache()

    private let fileName = "member_snapshot.json"
    private let ttl: TimeInterval = 24 * 60 * 60
    private var memory: StoredMemberSnapshot?

    private var fileURL: URL {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return directory.appendingPathComponent(fileName)
    }

    /// 拉取最新快照并写盘；成功返回 true。
    func refresh() async -> Bool {
        guard let snapshot = await MemberSnapshotService.shared.fetchFullSnapshot() else {
            return false
        }
        let stored = StoredMemberSnapshot(savedAt: Date(), snapshot: snapshot)
        memory = stored
        do {
            let data = try JSONEncoder().encode(stored)
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// 读取快照（内存优先，进程重启后读文件）。
    fileprivate func load() async -> StoredMemberSnapshot? {
        if let memory { return memory }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let stored = try? JSONDecoder().decode(StoredMemberSnapshot.self, from: data) else {
            return nil
        }
        memory = stored
        return stored
    }

    /// 快照是否在新鲜期内（24h）。
    func isFresh() async -> Bool {
        guard let stored = await load() else { return false }
        return Date().timeIntervalSince(stored.savedAt) <= ttl
    }

    /// 按姓名/别名/编号/识别码/认读码/序号在快照中查找社员。
    func findMember(query: String) async -> RaspberryMember? {
        guard let stored = await load() else { return nil }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }

        let keys = [
            "姓名", "别名", "社员编号", "社员识别码",
            "社员身份编码（认读码）", "社员序号"
        ]
        guard let item = stored.snapshot.items.first(where: { item in
            keys.contains { key in
                item.fields[key]?.flattenedText.localizedCaseInsensitiveContains(q) ?? false
            }
        }) else { return nil }

        return await MainActor.run {
            MemberService.mapRecord(fields: item.fields)
        }
    }
}

/// 全量社员快照数据层：对接 Worker GET /api/members/full（与 Android 共用同一接口）。
private struct MemberSnapshotService {
    static let shared = MemberSnapshotService()

    private let baseURL = URL(string: "https://nfc.raspjam.com")!

    func fetchFullSnapshot() async -> MemberFullSnapshot? {
        let url = baseURL.appendingPathComponent("/api/members/full")
        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return try? JSONDecoder().decode(MemberFullSnapshot.self, from: data)
        } catch {
            return nil
        }
    }
}
