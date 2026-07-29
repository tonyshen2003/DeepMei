//
//  WorkbenchService.swift
//  DeepMei
//
//  工作台数据获取层 —— 从飞书 Bitable 拉取工作台入口列表。
//
//  Swift 6 并发说明：
//  - 所有 DTO 类型收进 WorkbenchDTO 枚举命名空间，避免被 Swift 6 推断为 @MainActor；
//  - FieldMap 替代 Dictionary extension，消除跨隔离域方法调用；
//  - groupOrder 在 actor 内部自维护，不引用全局 serviceGroupOrder。
//
//  飞书多维表格字段约定（用户自行建表）：
//  | 字段名     | 类型     | 说明                                              |
//  |-----------|----------|---------------------------------------------------|
//  | 入口标题   | 文本     | 卡片标题                                           |
//  | 副标题     | 文本     | 一句话简介（可留空）                                 |
//  | 分组       | 单选     | 活动 / 资源 / 媒体                                  |
//  | 常用       | 复选框   | 勾选后置顶「常用」区                                 |
//  | 跳转类型   | 单选     | 网页 / 文章                                        |
//  | 链接URL    | 文本     | 跳转类型含「网页」时填                               |
//  | 文件名     | 文本     | 跳转类型含「文章」时填                               |
//  | 图标       | 单选     | event / home / cloud / book / play / apps          |
//  | 排序       | 数字     | 同组内升序排列（可留空，默认 0）                     |
//

import Foundation

// MARK: - 数据传输对象（非 actor 作用域，避免 @MainActor 推断）

private enum WorkbenchDTO {

    struct RecordListResponse: Decodable {
        let code: Int
        let msg: String
        let data: DataPayload?

        struct DataPayload: Decodable {
            let items: [Record]?
            let pageToken: String?
            let hasMore: Bool?

            enum CodingKeys: String, CodingKey {
                case items
                case pageToken = "page_token"
                case hasMore = "has_more"
            }
        }
    }

    struct Record: Decodable {
        let recordId: String
        let fields: FieldMap

        enum CodingKeys: String, CodingKey {
            case recordId = "record_id"
            case fields
        }
    }

    /// 字段映射容器 —— 替代 Dictionary extension，所有提取方法集中于此，
    /// 避免 Swift 6 将 Dictionary 扩展方法推断为 @MainActor。
    struct FieldMap: Decodable {
        private let raw: [String: FieldValue]

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            raw = try container.decode([String: FieldValue].self)
        }

        func text(_ key: String) -> String {
            raw[key]?.flattenedText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        func bool(_ key: String) -> Bool {
            guard let v = raw[key] else { return false }
            switch v {
            case .bool(let b): return b
            case .string(let s): return s == "true" || s == "1"
            case .number(let d): return d == 1.0
            default: return false
            }
        }

        func int(_ key: String) -> Int {
            guard let v = raw[key] else { return 0 }
            switch v {
            case .number(let d): return Int(d)
            case .string(let s): return Int(s) ?? 0
            default: return 0
            }
        }
    }

    /// 飞书字段值解码（工作台专用，轻量版）。
    enum FieldValue: Decodable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case array([FieldValue])
        case object([String: FieldValue])
        case null

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let v = try? container.decode(String.self) { self = .string(v) }
            else if let v = try? container.decode(Bool.self) { self = .bool(v) }
            else if let v = try? container.decode(Double.self) { self = .number(v) }
            else if let v = try? container.decode(Int.self) { self = .number(Double(v)) }
            else if let v = try? container.decode([FieldValue].self) { self = .array(v) }
            else if let v = try? container.decode([String: FieldValue].self) { self = .object(v) }
            else { self = .null }
        }

        var flattenedText: String {
            switch self {
            case .string(let s): return s
            case .number(let d): return d == d.rounded() ? String(Int(d)) : String(d)
            case .bool(let b): return b ? "true" : "false"
            case .array(let arr): return arr.map { $0.flattenedText }.joined(separator: ", ")
            case .object(let dict):
                if case .string(let t) = dict["text"] ?? .null { return t }
                if case .string(let n) = dict["name"] ?? .null { return n }
                return ""
            case .null: return ""
            }
        }
    }
}

// MARK: - 工作台数据服务

actor WorkbenchService {
    static let shared = WorkbenchService()

    // ★★★ 飞书 Bitable 配置 —— 与 Android 版共用同一张表 ★★★
    private let appToken = "Ewq5btu9LaIUdLsZe2ecRWqWntc"
    private let tableId = "tblJT0oKin9rxdJQ"

    private let baseURL = URL(string: "https://open.feishu.cn")!

    /// 分组展示顺序 —— actor 内部自维护，不引用全局 serviceGroupOrder
    private let groupOrder: [ServiceGroup] = [.activity, .resource, .media]

    /// 内存缓存：本次启动内只请求一次飞书
    private var cachedActivities: [ActivityItem]?

    // MARK: - 公开接口

    /// 拉取工作台入口列表。
    func fetchActivities() async -> [ActivityItem]? {
        if let cached = cachedActivities { return cached }

        guard !appToken.isEmpty, !tableId.isEmpty else { return nil }

        do {
            let token = try await MemberService.shared.getTenantAccessToken()

            var allRecords: [WorkbenchDTO.Record] = []
            var pageToken: String? = nil

            repeat {
                var components = URLComponents(
                    url: baseURL.appendingPathComponent(
                        "/open-apis/bitable/v1/apps/\(appToken)/tables/\(tableId)/records"
                    ),
                    resolvingAgainstBaseURL: false
                )!
                components.queryItems = [URLQueryItem(name: "page_size", value: "100")]
                if let pt = pageToken, !pt.isEmpty {
                    components.queryItems?.append(URLQueryItem(name: "page_token", value: pt))
                }

                guard let url = components.url else { return nil }

                var req = URLRequest(url: url)
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }

                let decoded = try JSONDecoder().decode(WorkbenchDTO.RecordListResponse.self, from: data)
                guard decoded.code == 0 else { return nil }

                if let items = decoded.data?.items { allRecords.append(contentsOf: items) }
                pageToken = (decoded.data?.hasMore == true) ? decoded.data?.pageToken : nil
            } while pageToken != nil

            guard !allRecords.isEmpty else { return nil }

            let items = mapRecords(allRecords)
            guard !items.isEmpty else { return nil }

            cachedActivities = items
            return items
        } catch {
            return nil
        }
    }

    func clearCache() {
        cachedActivities = nil
    }

    // MARK: - 记录映射

    private func mapRecords(_ records: [WorkbenchDTO.Record]) -> [ActivityItem] {
        let order = groupOrder  // 本地捕获，避免闭包内跨域引用
        return records
            .compactMap { mapSingle($0) }
            .sorted { a, b in
                let idxA = order.firstIndex(of: a.item.group) ?? 0
                let idxB = order.firstIndex(of: b.item.group) ?? 0
                if idxA != idxB { return idxA < idxB }
                return a.sortValue < b.sortValue
            }
            .map { $0.item }
    }

    private func mapSingle(_ record: WorkbenchDTO.Record) -> SortableItem? {
        let fields = record.fields

        let title = fields.text("入口标题")
        guard !title.isEmpty else { return nil }

        let subtitle = fields.text("副标题")
        let group: ServiceGroup = {
            switch fields.text("分组") {
            case "资源": return .resource
            case "媒体": return .media
            default:     return .activity
            }
        }()
        let common = fields.bool("常用")
        let iconKey = fields.text("图标").isEmpty ? "apps" : fields.text("图标")
        let sortValue = fields.int("排序")

        let url = fields.text("链接URL")
        let fileName = fields.text("文件名")
        let jumpType = fields.text("跳转类型")

        let target: ActivityTarget
        if jumpType.contains("文章") {
            guard !fileName.isEmpty else { return nil }
            target = .markdown(fileName: fileName, title: title)
        } else if jumpType.contains("网页") {
            guard !url.isEmpty else { return nil }
            target = .webView(url: url, title: title)
        } else {
            if !url.isEmpty {
                target = .webView(url: url, title: title)
            } else if !fileName.isEmpty {
                target = .markdown(fileName: fileName, title: title)
            } else {
                return nil
            }
        }

        return SortableItem(
            item: ActivityItem(
                id: record.recordId.isEmpty ? title : record.recordId,
                title: title,
                subtitle: subtitle,
                group: group,
                common: common,
                iconKey: iconKey,
                target: target
            ),
            sortValue: sortValue
        )
    }

    private struct SortableItem {
        let item: ActivityItem
        let sortValue: Int
    }
}
