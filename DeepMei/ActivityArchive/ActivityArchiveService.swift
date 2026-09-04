//
//  ActivityArchiveService.swift
//  DeepMei
//
//  活动记录归档：直接对接 nfc.raspjam.com 的 Cloudflare Worker 活动接口
//  （与小程序活动页共用同一数据源，但原生端无需微信云函数/照片转存中转）。
//

import Foundation

/// 图片附件扩展名白名单（与 Worker attachmentsOf 的 IMG_EXT_RE 保持一致）。
private let activityImageExtensions: Set<String> = [
    "jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "heif", "avif", "jfif",
]

private func isActivityImageName(_ name: String) -> Bool {
    guard let ext = name.split(separator: ".").last?.lowercased(), !ext.isEmpty else {
        return false
    }
    return activityImageExtensions.contains(String(ext))
}

// MARK: - 数据模型（对齐 Worker /api/activities 响应）

/// 活动类型统计（facets.types）
struct ActivityTypeFacet: Decodable {
    let type: String
    let count: Int
}

/// 年份统计（facets.years，服务端已按年份倒序）
struct ActivityYearFacet: Decodable {
    let year: String
    let count: Int
}

struct ActivityFacets: Decodable {
    let types: [ActivityTypeFacet]?
    let years: [ActivityYearFacet]?
}

/// 列表页活动摘要
struct ActivityListItem: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    let date: String // YYYY-MM-DD
    let place: String
    let hoursPer: Double
    let isVolunteer: Bool
    let photoCount: Int
    let people: Int
    /// w400 封面 URL（无封面时为空字符串）
    let cover: String

    var displayDate: String { date.activityDisplayDate }

    enum CodingKeys: String, CodingKey {
        case id, name, type, date, place
        case hoursPer, isVolunteer, photoCount, people, cover
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        date = try container.decode(String.self, forKey: .date)
        place = try container.decodeIfPresent(String.self, forKey: .place) ?? ""
        hoursPer = try container.decodeIfPresent(Double.self, forKey: .hoursPer) ?? 0
        isVolunteer = try container.decodeIfPresent(Bool.self, forKey: .isVolunteer) ?? false
        photoCount = try container.decodeIfPresent(Int.self, forKey: .photoCount) ?? 0
        people = try container.decodeIfPresent(Int.self, forKey: .people) ?? 0
        cover = try container.decodeIfPresent(String.self, forKey: .cover) ?? ""
    }
}

struct ActivityListResponse: Decodable {
    let total: Int
    let offset: Int
    let limit: Int
    let items: [ActivityListItem]
    let facets: ActivityFacets?
}

/// 详情页单张照片（thumb=w400 墙图，full=w1200 全屏大图）
struct ActivityPhotoItem: Decodable, Identifiable, Hashable {
    let token: String
    let name: String
    let thumb: String
    let full: String

    var id: String {
        token.isEmpty ? "\(name)|\(thumb)|\(full)" : token
    }

    enum CodingKeys: String, CodingKey {
        case token, name, thumb, full
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = try container.decodeIfPresent(String.self, forKey: .token) ?? ""
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        thumb = try container.decodeIfPresent(String.self, forKey: .thumb) ?? ""
        full = try container.decodeIfPresent(String.self, forKey: .full) ?? ""
    }
}

struct ActivityStats: Decodable {
    let people: Int
    let totalHours: Double
    let volunteerHours: Double

    enum CodingKeys: String, CodingKey {
        case people, totalHours, volunteerHours
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        people = try container.decodeIfPresent(Int.self, forKey: .people) ?? 0
        totalHours = try container.decodeIfPresent(Double.self, forKey: .totalHours) ?? 0
        volunteerHours = try container.decodeIfPresent(Double.self, forKey: .volunteerHours) ?? 0
    }
}

struct ActivityDetailItem: Decodable, Identifiable {
    let id: String
    let name: String
    let type: String
    let date: String
    let place: String
    let intro: String
    let result: String
    let record: String
    let hoursPer: Double
    let isVolunteer: Bool
    let photos: [ActivityPhotoItem]
    let stats: ActivityStats?

    var displayDate: String { date.activityDisplayDate }

    enum CodingKeys: String, CodingKey {
        case id, name, type, date, place, intro, result, record
        case hoursPer, isVolunteer, photos, stats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? ""
        place = try container.decodeIfPresent(String.self, forKey: .place) ?? ""
        intro = try container.decodeIfPresent(String.self, forKey: .intro) ?? ""
        result = try container.decodeIfPresent(String.self, forKey: .result) ?? ""
        record = try container.decodeIfPresent(String.self, forKey: .record) ?? ""
        hoursPer = try container.decodeIfPresent(Double.self, forKey: .hoursPer) ?? 0
        isVolunteer = try container.decodeIfPresent(Bool.self, forKey: .isVolunteer) ?? false
        let decodedPhotos = try container.decodeIfPresent([ActivityPhotoItem].self, forKey: .photos) ?? []
        // 线上快照可能混入非图片附件（pdf/mp4/docx 等，接口请求必然 502）；
        // 这里按文件名后缀过滤，照片墙只展示真正的图片。
        photos = decodedPhotos.filter { isActivityImageName($0.name) }
        stats = try container.decodeIfPresent(ActivityStats.self, forKey: .stats)
    }
}

struct ActivityDetailResponse: Decodable {
    let found: Bool
    let activity: ActivityDetailItem?
}

// MARK: - 日期展示

extension String {
    /// "2026-09-01" → "2026年9月1日"；无法解析时原样返回。
    var activityDisplayDate: String {
        let parts = split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return self
        }
        return "\(year)年\(month)月\(day)日"
    }

    /// "2026-09-01" → "9月1日"；无法解析时返回空字符串。
    var activityMonthDay: String {
        let parts = split(separator: "-")
        guard parts.count == 3,
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return ""
        }
        return "\(month)月\(day)日"
    }
}

// MARK: - 服务

enum ActivityArchiveError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case decodeError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器返回了无法识别的内容"
        case .httpError(let code):
            return "请求失败（HTTP \(code)）"
        case .decodeError:
            return "数据解析失败"
        }
    }
}

private final class ActivityDetailCacheBox {
    let item: ActivityDetailItem

    init(_ item: ActivityDetailItem) {
        self.item = item
    }
}

final class ActivityArchiveService {
    static let shared = ActivityArchiveService()

    private let baseURL = URL(string: "https://nfc.raspjam.com")!
    private let detailCache = NSCache<NSString, ActivityDetailCacheBox>()
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    private init() {
        detailCache.countLimit = 120
    }

    /// 活动列表（分页 + 筛选）。
    /// year：4 位年份；type：完整类型名；传空表示不筛选。
    func fetchList(
        year: String? = nil,
        type: String? = nil,
        q: String? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> ActivityListResponse {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/activities"),
            resolvingAgainstBaseURL: false
        )!
        var query: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        if let year, !year.isEmpty {
            query.append(URLQueryItem(name: "year", value: year))
        }
        if let type, !type.isEmpty {
            query.append(URLQueryItem(name: "type", value: type))
        }
        if let q, !q.isEmpty {
            query.append(URLQueryItem(name: "q", value: q))
        }
        components.queryItems = query

        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response: response)
        do {
            return try JSONDecoder().decode(ActivityListResponse.self, from: data)
        } catch {
            throw ActivityArchiveError.decodeError
        }
    }

    /// 活动详情（含照片墙与大图地址）
    func fetchDetail(id: String) async throws -> ActivityDetailResponse {
        if let cached = detailCache.object(forKey: id as NSString)?.item {
            return ActivityDetailResponse(found: true, activity: cached)
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/activities/detail"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(name: "id", value: id),
        ]

        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response: response)
        do {
            let decoded = try JSONDecoder().decode(ActivityDetailResponse.self, from: data)
            if let activity = decoded.activity {
                detailCache.setObject(ActivityDetailCacheBox(activity), forKey: id as NSString)
            }
            return decoded
        } catch {
            throw ActivityArchiveError.decodeError
        }
    }

    private static func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ActivityArchiveError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ActivityArchiveError.httpError(http.statusCode)
        }
    }
}

/// 从 w400 封面 URL 提升为更高分辨率（详情头图用；非活动照片 URL 原样返回）。
func activityPhotoURL(_ urlString: String, width: Int) -> String? {
    guard var components = URLComponents(string: urlString),
          let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
          !token.isEmpty else {
        return urlString.isEmpty ? nil : urlString
    }
    var query = components.queryItems?.filter { $0.name != "w" } ?? []
    query.append(URLQueryItem(name: "w", value: String(width)))
    components.queryItems = query
    return components.url?.absoluteString
}
