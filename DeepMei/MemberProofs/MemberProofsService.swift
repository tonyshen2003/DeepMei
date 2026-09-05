//
//  MemberProofsService.swift
//  DeepMei
//
//  社员证明数据层：对接 Worker /api/proof-files 与 /api/file。
//  资格（发布时间 >= 入社日期）在客户端本地比较；joinDate 随 /api/members/detail 下发。
//

import Foundation

// MARK: - 模型

/// 目录接口返回的一条证明（单附件扁平行；当前文件表一份证明一个 PDF）。
struct MemberProofItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let owner: String
    let publishedAt: String
    let fileName: String
    let fileSize: Int64
    let fileToken: String

    var fileSizeText: String {
        if fileSize <= 0 { return "" }
        if fileSize < 1024 * 1024 {
            return "\(max(1, Int((Double(fileSize) / 1024).rounded()))) KB"
        }
        return String(format: "%.1f MB", Double(fileSize) / 1024 / 1024)
    }
}

struct MemberProofProfile: Hashable, Sendable {
    let code: String
    let name: String
    let joinDate: String
}

// MARK: - 服务

final class MemberProofsService {
    static let shared = MemberProofsService()

    private let baseURL = URL(string: "https://nfc.raspjam.com")!
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 90
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: 档案（joinDate 资格来源）

    func fetchProfile(code rawCode: String) async throws -> MemberProofProfile? {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return nil }

        let url = baseURL
            .appendingPathComponent("api/members/detail")
            .appending(queryItems: [URLQueryItem(name: "code", value: code)])
        let (data, response) = try await session.data(from: url)
        try validate(response, fallbackMessage: "社员档案请求失败")

        struct Response: Decodable {
            let found: Bool
            let member: MemberDTO?
        }
        struct MemberDTO: Decodable {
            let id: String?
            let name: String?
            let joinDate: String?
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard decoded.found, let member = decoded.member else { return nil }
        return MemberProofProfile(
            code: member.id ?? code,
            name: member.name ?? "",
            joinDate: member.joinDate ?? ""
        )
    }

    // MARK: 证明目录

    func fetchProofs() async throws -> [MemberProofItem] {
        let url = baseURL.appendingPathComponent("api/proof-files")
        let (data, response) = try await session.data(from: url)
        try validate(response, fallbackMessage: "证明目录请求失败")

        struct Response: Decodable {
            let found: Bool
            let files: [FileDTO]?
        }
        struct FileDTO: Decodable {
            let title: String?
            let owner: String?
            let publishedAt: String?
            let files: [AttachmentDTO]?
        }
        struct AttachmentDTO: Decodable {
            let name: String?
            let size: Int64?
            let fileToken: String?
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        guard decoded.found else {
            throw ProofServiceError.catalogUnavailable
        }

        var rows: [MemberProofItem] = []
        for file in decoded.files ?? [] {
            let title = file.title ?? ""
            let owner = file.owner ?? ""
            let publishedAt = file.publishedAt ?? ""
            for attachment in file.files ?? [] {
                guard let token = attachment.fileToken, !token.isEmpty else { continue }
                let fileName = attachment.name ?? (title.isEmpty ? "证明.pdf" : "\(title).pdf")
                rows.append(
                    MemberProofItem(
                        id: token,
                        title: title,
                        owner: owner,
                        publishedAt: publishedAt,
                        fileName: fileName,
                        fileSize: attachment.size ?? 0,
                        fileToken: token
                    )
                )
            }
        }
        return rows
    }

    // MARK: 下载 + 本地缓存

    func fileURL(for item: MemberProofItem) async throws -> URL {
        let fileURL = cachedURL(for: item)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("api/file"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "token", value: item.fileToken)]
        guard let url = components.url else {
            throw ProofServiceError.invalidRequest
        }

        let (data, response) = try await session.data(from: url)
        try validate(response, fallbackMessage: "证明文件下载失败")

        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func cachedURL(for item: MemberProofItem) -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = caches.appendingPathComponent("MemberProofs", isDirectory: true)

        let ext = (item.fileName as NSString).pathExtension.lowercased().isEmpty
            ? "pdf"
            : (item.fileName as NSString).pathExtension.lowercased()
        // token + size 参与文件名：上游同名更新时会自然失效旧缓存
        let baseName = "\(item.fileToken)_\(item.fileSize).\(ext)"
        return directory.appendingPathComponent(baseName)
    }

    private func validate(_ response: URLResponse, fallbackMessage: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ProofServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ProofServiceError.httpError(http.statusCode)
        }
    }
}

enum ProofServiceError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case catalogUnavailable
    case invalidRequest

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "网络响应无效"
        case .httpError(let code):
            return "请求失败（HTTP \(code)）"
        case .catalogUnavailable:
            return "证明目录暂不可用"
        case .invalidRequest:
            return "请求地址无效"
        }
    }
}
