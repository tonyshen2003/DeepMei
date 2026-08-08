//
//  MemberQRCodeGenerator.swift
//  DeepMei
//
//  在手机端用 CoreImage 生成「社员识别码」二维码，再随登录态同步给 Apple Watch。
//  （watchOS 没有 CoreImage，所以由手机生成 PNG 后通过 WatchConnectivity 传输。）
//

import CoreImage
import UIKit

enum MemberQRCodeGenerator {
    /// 生成二维码 PNG 数据；识别码为空或生成失败时返回 nil。
    /// 识别码统一去掉横线、转大写（如 SM-201809-A001-002-01 → SM201809A00100201）。
    static func pngData(for rawCode: String, scale: CGFloat = 12) -> Data? {
        let code = rawCode
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !code.isEmpty else { return nil }

        let data = Data(code.utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }

        // 垫一层白色背景，避免透明区域在深色表盘 / 卡片上发黑。
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        // 必须用 1x 渲染，否则默认按屏幕 3x 输出，PNG 体积膨胀 9 倍撑爆 WatchConnectivity。
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))
        }
        return image.pngData()
    }
}
