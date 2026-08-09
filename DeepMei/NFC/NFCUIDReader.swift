//
//  NFCUIDReader.swift
//  DeepMei
//
//  原生 NFC 读卡：只读取卡片 UID（与 Android tag.id 对齐），
//  输出大写十六进制（如 A1B2C3D4），后续查人/签到流程与扫码、手动完全一致。
//
//  注意：
//  - Core NFC 由系统呈现扫描界面，App 只能设置 alertMessage，不能自定义取景框；
//  - 仅 iPhone 真机支持（NFCTagReaderSession.readingAvailable 为 false 时隐藏入口）；
//  - MIFARE Classic 不被 Core NFC 支持，读不到的卡会走系统错误提示。
//

import CoreNFC
import Foundation

/// NFC 读取过程的错误类型。
enum NFCReadError: LocalizedError {
    case unavailable
    case canceled
    case sessionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "当前设备不支持 NFC"
        case .canceled:
            return "已取消"
        case .sessionFailed(let message):
            return message
        }
    }
}

/// NFC 读卡器（只读 UID）。
///
/// 工程默认 MainActor 隔离；Core NFC 的回调通过 `Task { @MainActor }` 跳回主线程，
/// 与 `AppLocationService` 的续体模式一致。
final class NFCUIDReader: NSObject, NFCTagReaderSessionDelegate {
    static let shared = NFCUIDReader()

    /// 当前设备是否支持 NFC 读卡（模拟器 / 不支持机型为 false）。
    static var isReadingAvailable: Bool {
        NFCTagReaderSession.readingAvailable
    }

    private var session: NFCTagReaderSession?
    private var continuation: CheckedContinuation<String, Error>?

    private override init() {
        super.init()
    }

    /// 启动一次系统扫描，返回卡片 UID（大写十六进制，如 A1B2C3D4）。
    func readUID() async throws -> String {
        guard Self.isReadingAvailable else {
            throw NFCReadError.unavailable
        }
        guard continuation == nil else {
            throw NFCReadError.sessionFailed("已有 NFC 扫描正在进行")
        }

        return try await withCheckedThrowingContinuation { continuation in
            guard let session = NFCTagReaderSession(
                pollingOption: [.iso14443],
                delegate: self,
                queue: .main
            ) else {
                continuation.resume(throwing: NFCReadError.sessionFailed("无法启动 NFC 会话"))
                return
            }
            self.continuation = continuation
            session.alertMessage = "将社员卡靠近 iPhone 顶部"
            session.begin()
            self.session = session
        }
    }

    // MARK: - NFCTagReaderSessionDelegate

    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        // 会话已激活，无需额外处理
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            self.handleInvalidation(error: error)
        }
    }

    nonisolated func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        // 这里只提取 Sendable 的 UID 数据，避免把非 Sendable 的 [NFCTag] 传进 Task。
        guard let tag = tags.first else {
            Task { @MainActor in
                self.invalidateWithMessage("未检测到卡片，请重试")
            }
            return
        }

        let uid: Data?
        switch tag {
        case .miFare(let miFareTag):
            uid = miFareTag.identifier
        case .iso7816(let iso7816Tag):
            uid = iso7816Tag.identifier
        default:
            uid = nil
        }

        guard let uid, !uid.isEmpty else {
            Task { @MainActor in
                self.invalidateWithMessage("暂不支持这张卡片，请使用扫码或手动输入")
            }
            return
        }

        let uidHex = uid.map { String(format: "%02X", $0) }.joined()
        Task { @MainActor in
            self.finish(uidHex)
        }
    }

    // MARK: - 内部处理

    private func finish(_ uid: String) {
        session?.alertMessage = "读取成功"
        session?.invalidate()
        continuation?.resume(returning: uid)
        continuation = nil
        session = nil
    }

    private func invalidateWithMessage(_ message: String) {
        session?.invalidate(errorMessage: message)
    }

    private func handleInvalidation(error: Error) {
        // 成功读取后 invalidate() 也会触发本回调；continuation 已清空则直接忽略。
        guard let continuation else {
            session = nil
            return
        }
        session = nil
        self.continuation = nil

        if (error as NSError).code == NFCReaderError.readerSessionInvalidationErrorUserCanceled.rawValue {
            continuation.resume(throwing: NFCReadError.canceled)
        } else {
            continuation.resume(throwing: NFCReadError.sessionFailed(error.localizedDescription))
        }
    }
}
