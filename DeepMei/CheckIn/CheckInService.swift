//
//  CheckInService.swift
//  DeepMei
//
//  原生签到数据层：对接 Cloudflare Worker（nfc.raspjam.com），与 Android CheckInService 对齐。
//
//  - GET  /api/member?uid=xxx  按卡号/识别码查人
//  - POST /api/checkin         提交签到（写 WPS + 发飞书通知）
//

import Foundation

/// 查询 / 提交过程的错误类型。
enum CheckInServiceError: Error, LocalizedError {
    case invalidURL
    case timeout
    case network
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL 无效"
        case .timeout:
            return "查询超时，请重试"
        case .network:
            return "请检查网络"
        case .server(let code):
            return "服务异常（\(code)）"
        }
    }
}

/// Worker /api/member 返回的社员信息（字段与 Android CheckInMember 一致）。
struct CheckInMember: Identifiable, Equatable, Sendable {
    var id: String { cardId.isEmpty ? readableCode : cardId }

    let name: String
    let alias: String
    let idCode: String
    let generation: String
    let className: String
    let department: String
    let cardId: String
    let readableCode: String
    let memberSeq: String
    let position: String
    let joinYear: String

    nonisolated init(
        name: String = "",
        alias: String = "",
        idCode: String = "",
        generation: String = "",
        className: String = "",
        department: String = "",
        cardId: String = "",
        readableCode: String = "",
        memberSeq: String = "",
        position: String = "",
        joinYear: String = ""
    ) {
        self.name = name
        self.alias = alias
        self.idCode = idCode
        self.generation = generation
        self.className = className
        self.department = department
        self.cardId = cardId
        self.readableCode = readableCode
        self.memberSeq = memberSeq
        self.position = position
        self.joinYear = joinYear
    }

    enum CodingKeys: String, CodingKey {
        case name
        case alias
        case idCode
        case generation
        case className
        case department
        case cardId
        case readableCode
        case memberSeq
        case position
        case joinYear
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        alias = try container.decodeIfPresent(String.self, forKey: .alias) ?? ""
        idCode = try container.decodeIfPresent(String.self, forKey: .idCode) ?? ""
        generation = try container.decodeIfPresent(String.self, forKey: .generation) ?? ""
        className = try container.decodeIfPresent(String.self, forKey: .className) ?? ""
        department = try container.decodeIfPresent(String.self, forKey: .department) ?? ""
        cardId = try container.decodeIfPresent(String.self, forKey: .cardId) ?? ""
        readableCode = try container.decodeIfPresent(String.self, forKey: .readableCode) ?? ""
        memberSeq = try container.decodeIfPresent(String.self, forKey: .memberSeq) ?? ""
        position = try container.decodeIfPresent(String.self, forKey: .position) ?? ""
        joinYear = try container.decodeIfPresent(String.self, forKey: .joinYear) ?? ""
    }

}
nonisolated extension CheckInMember: Decodable {}

private struct CheckInLookupResponse: Sendable {
    let found: Bool
    let member: CheckInMember?
}
nonisolated extension CheckInLookupResponse: Decodable {}

private struct CheckInSubmitRequest: Sendable {
    let uid: String
    let mode: String
    let name: String
    let activity: String
    let duration: String
    let lat: Double?
    let lng: Double?
}
nonisolated extension CheckInSubmitRequest: Encodable {}

private struct CheckInSubmitResponse: Sendable {
    let ok: Bool
}
nonisolated extension CheckInSubmitResponse: Decodable {}

/// 签到数据服务（单例），超时 10 秒与 Android callTimeout 对齐。
actor CheckInService {
    static let shared = CheckInService()

    private let lookupURL = URL(string: "https://nfc.raspjam.com/api/member")!
    private let submitURL = URL(string: "https://nfc.raspjam.com/api/checkin")!
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 15
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    /// 按卡号或识别码查询社员；HTTP 非 200 返回 nil（与 Android 一致），网络异常抛错。
    func lookupMember(rawCode: String) async throws -> CheckInMember? {
        let code = normalize(rawCode)
        guard !code.isEmpty else { return nil }

        var components = URLComponents(url: lookupURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "uid", value: code)]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw CheckInServiceError.timeout
        } catch {
            throw CheckInServiceError.network
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }
        guard let decoded = try? JSONDecoder().decode(CheckInLookupResponse.self, from: data) else {
            return nil
        }
        return decoded.found ? decoded.member : nil
    }

    /// 提交签到；成功返回 true。
    func submitCheckIn(
        uid: String,
        name: String,
        activity: String,
        duration: String,
        lat: Double? = nil,
        lng: Double? = nil
    ) async throws -> Bool {
        let payload = CheckInSubmitRequest(
            uid: normalize(uid),
            mode: "nfc",
            name: name,
            activity: activity,
            duration: duration,
            lat: lat,
            lng: lng
        )
        var request = URLRequest(url: submitURL)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw CheckInServiceError.timeout
        } catch {
            throw CheckInServiceError.network
        }

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return false
        }
        guard let decoded = try? JSONDecoder().decode(CheckInSubmitResponse.self, from: data) else {
            return false
        }
        return decoded.ok
    }

    private func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: ":", with: "")
    }
}
