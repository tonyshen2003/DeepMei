//
//  DirectorCameraView.swift
//  DeepMei
//
//  专业导演取景器 — 树莓相机 (Director's Viewfinder Pro)
//  已修复全部编译错误、线程隔离问题和 ViewBuilder 语法问题
//

import SwiftUI
import Combine
import AVFoundation
import Photos
import UIKit
import CoreLocation
import ImageIO
import UniformTypeIdentifiers

// MARK: - 电影画幅比例定义

enum FilmAspectRatio: String, CaseIterable, Identifiable, Sendable {
    case full = "全画幅"
    case cinescope = "2.39:1"
    case flat = "1.85:1"
    case standard = "16:9"
    case classic = "4:3"
    case square = "1:1"

    var id: String { rawValue }

    var ratioValue: CGFloat? {
        switch self {
        case .full: return nil
        case .cinescope: return 2.39
        case .flat: return 1.85
        case .standard: return 16.0 / 9.0
        case .classic: return 4.0 / 3.0
        case .square: return 1.0
        }
    }
}

// MARK: - 经典电影定焦镜头预设

struct CinemaLensPreset: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let focalLengthMM: Int
    let zoomFactor: CGFloat
}

// MARK: - 拍摄元数据

struct CaptureMetadata: Equatable, Sendable {
    var focalLength: Float
    var focalLength35mm: Float
    var aperture: Float
    var exposureTime: Double
    var iso: Float
    var lensModel: String
    var dateTime: String
    var aspectRatioText: String
    var directorName: String

    // 拍摄地理位置（取景器拍照时记录）
    var latitude: Double? = nil
    var longitude: Double? = nil
    var locationText: String? = nil

    var focalLengthDisplay: String {
        let mm = focalLength35mm > 0 ? Int(focalLength35mm) : (focalLength > 0 ? Int(focalLength) : 24)
        return "\(mm)mm"
    }

    var apertureDisplay: String {
        aperture > 0 ? String(format: "f/%.1f", aperture) : "f/1.8"
    }

    var shutterDisplay: String {
        guard exposureTime > 0 else { return "1/50s" }
        if exposureTime < 1 {
            let denom = max(1, Int((1.0 / exposureTime).rounded()))
            return "1/\(denom)s"
        }
        return String(format: "%.1fs", exposureTime)
    }

    var isoDisplay: String {
        iso > 0 ? "ISO \(Int(iso))" : "ISO 100"
    }
}

// MARK: - 保存结果

enum SaveResult: Equatable, Sendable {
    case success
    case failure(String)
}

// MARK: - 地理位置服务（取景器拍照时记录拍摄地点）

final class LocationService: NSObject {
    private let manager = CLLocationManager()
    private(set) var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
    }

    /// 请求“使用期间”定位权限并启动位置更新。
    func requestAndStart() {
        let status = manager.authorizationStatus
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let authorized = manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways
        if authorized {
            DispatchQueue.main.async { manager.startUpdatingLocation() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            DispatchQueue.main.async { [weak self] in
                self?.lastLocation = loc
            }
        }
    }
}

// MARK: - 相机管理器 (回归底层队列机制，告别线程阻塞异常)

final class CameraManager: NSObject, ObservableObject {

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var currentDevice: AVCaptureDevice?
    
    // 使用专用的串行队列管理硬件，完全解决 Swift 6 并发模型的卡顿与报错
    private let cameraQueue = DispatchQueue(label: "com.deepmei.camera.queue", qos: .userInitiated)
    private let locationService = LocationService()

    // Published UI 状态
    @Published var isAuthorized = false
    @Published var isConfigured = false
    @Published var isRunning = false
    @Published var capturedImage: UIImage?
    @Published var capturedMetadata: CaptureMetadata?
    @Published var showPreview = false
    @Published var errorText: String?
    @Published var isSaving = false
    @Published var saveResult: SaveResult?
    @Published var photoLibraryAuthorized = false

    // Live 参数
    @Published var zoomFactor: CGFloat = 1.0
    @Published var minZoom: CGFloat = 0.5
    @Published var maxZoom: CGFloat = 10.0
    @Published var liveISO: Float = 0
    @Published var liveShutter: Double = 0
    @Published var liveAperture: Float = 0
    @Published var lensName: String = ""
    @Published var isFront = false
    @Published var gridEnabled = true
    @Published var isMonochrome = false
    @Published var exposureTargetBias: Float = 0.0
    @Published var selectedAspectRatio: FilmAspectRatio = .cinescope
    @Published var directorName: String = "DIRECTOR"

    private var liveTimer: Timer?

    // MARK: - 权限检查
    func checkAuthorization() async {
        let videoGranted = await AVCaptureDevice.requestAccess(for: .video)
        
        let photoStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        let photoGranted = (photoStatus == .authorized || photoStatus == .limited)
        
        await MainActor.run {
            self.isAuthorized = videoGranted
            self.photoLibraryAuthorized = photoGranted
        }
    }

    // MARK: - 定位服务

    func startLocationServices() {
        locationService.requestAndStart()
    }

    // MARK: - 相机配置
    func configure() {
        let isFrontCamera = self.isFront
        let session = self.session
        let photoOutput = self.photoOutput
        // 在主线程（MainActor）先把设备解析好，避免后台队列跨 actor 访问 self 的属性
        let device = CameraManager.getBestCamera(position: isFrontCamera ? .front : .back)

        cameraQueue.async { [weak self] in
            guard let device else {
                DispatchQueue.main.async { self?.errorText = "无法访问相机硬件" }
                return
            }

            session.beginConfiguration()
            session.sessionPreset = .photo

            session.inputs.forEach { session.removeInput($0) }
            session.outputs.forEach { session.removeOutput($0) }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                }

                if session.canAddOutput(photoOutput) {
                    session.addOutput(photoOutput)
                    if #available(iOS 16.0, *), let maxDim = device.activeFormat.supportedMaxPhotoDimensions.last {
                        photoOutput.maxPhotoDimensions = maxDim
                    }
                }

                session.commitConfiguration()

                // currentDevice 是 MainActor 属性，跨回主线程赋值
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.currentDevice = device
                    self.updateDeviceProperties(device)
                    self.isConfigured = true
                    self.startLiveUpdates()
                }

                if !session.isRunning {
                    session.startRunning()
                    DispatchQueue.main.async { self?.isRunning = true }
                }
            } catch {
                session.commitConfiguration()
                DispatchQueue.main.async { self?.errorText = "初始化相机设备失败" }
            }
        }
    }

    private static func getBestCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if position == .front {
            return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        for type in types {
            if let d = AVCaptureDevice.default(type, for: .video, position: .back) {
                return d
            }
        }
        return nil
    }

    private func updateDeviceProperties(_ device: AVCaptureDevice) {
        let minZ = device.minAvailableVideoZoomFactor
        let maxZ = min(device.maxAvailableVideoZoomFactor, 15.0)

        self.lensName = device.localizedName
        self.minZoom = minZ
        self.maxZoom = maxZ
        
        self.setZoom(1.0)
    }

    // MARK: - 实时参数更新
    func startLiveUpdates() {
        stopLiveUpdates()
        liveTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, let device = self.currentDevice else { return }
            let iso = device.iso
            let exp = device.exposureDuration.seconds
            let apt = device.lensAperture
            DispatchQueue.main.async {
                self.liveISO = iso
                self.liveShutter = exp
                self.liveAperture = apt
            }
        }
    }

    func stopLiveUpdates() {
        liveTimer?.invalidate()
        liveTimer = nil
    }

    // MARK: - 控制功能
    func setZoom(_ factor: CGFloat) {
        let clamped = max(minZoom, min(factor, maxZoom))
        self.zoomFactor = clamped
        let device = self.currentDevice

        cameraQueue.async {
            guard let device else { return }
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch { }
        }
    }

    func setEV(_ bias: Float) {
        guard let device = currentDevice else { return }
        let clamped = max(device.minExposureTargetBias, min(bias, device.maxExposureTargetBias))
        self.exposureTargetBias = clamped
        
        cameraQueue.async {
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(clamped)
                device.unlockForConfiguration()
            } catch { }
        }
    }

    func focus(at point: CGPoint) {
        let device = self.currentDevice
        cameraQueue.async {
            guard let device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch { }
        }
    }

    func flipCamera() {
        isFront.toggle()
        stopLiveUpdates()
        let session = self.session
        cameraQueue.async { [weak self] in
            session.stopRunning()
            DispatchQueue.main.async {
                self?.configure()
            }
        }
    }

    // MARK: - 拍照逻辑
    func capture() {
        let photoOutput = self.photoOutput
        cameraQueue.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            if #available(iOS 16.0, *) {
                settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
            }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func start() {
        let session = self.session
        guard !session.isRunning else { return }
        cameraQueue.async { [weak self] in
            session.startRunning()
            DispatchQueue.main.async {
                self?.isRunning = true
                self?.startLiveUpdates()
            }
        }
    }

    func stop() {
        stopLiveUpdates()
        let session = self.session
        guard session.isRunning else { return }
        cameraQueue.async { [weak self] in
            session.stopRunning()
            DispatchQueue.main.async { self?.isRunning = false }
        }
    }

    // MARK: - 相册保存
    func saveToAlbum(_ image: UIImage) {
        isSaving = true
        saveResult = nil

        guard photoLibraryAuthorized else {
            isSaving = false
            saveResult = .failure("未授权相册权限，请在设置中开启")
            return
        }

        // 若本次拍摄带有 GPS 坐标，将经纬度写入照片 EXIF 的 GPS 目录
        let gpsData = CameraManager.embedGPSData(
            image: image,
            latitude: capturedMetadata?.latitude,
            longitude: capturedMetadata?.longitude
        )

        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            if let gpsData {
                request.addResource(with: .photo, data: gpsData, options: nil)
            } else if let jpeg = image.jpegData(compressionQuality: 0.95) {
                request.addResource(with: .photo, data: jpeg, options: nil)
            }
        } completionHandler: { [weak self] ok, err in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSaving = false
                if ok {
                    self.saveResult = .success
                } else {
                    self.saveResult = .failure(err?.localizedDescription ?? "保存失败")
                }
            }
        }
    }

    func resetCapture() {
        capturedImage = nil
        capturedMetadata = nil
        showPreview = false
        saveResult = nil
        start()
    }
}

// MARK: - Photo Capture Delegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            DispatchQueue.main.async { [weak self] in self?.errorText = "拍摄失败: \(error.localizedDescription)" }
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let originalImage = UIImage(data: data) else {
            DispatchQueue.main.async { [weak self] in self?.errorText = "无法处理图像数据" }
            return
        }

        let meta = Self.extractMetadata(from: photo)

        // 先在主线程安全读取当前 UI 设置与拍摄地点，再把手绘 + 滤镜渲染派发到后台，
        // 彻底避免大图在主线程同步渲染导致的卡死 / Watchdog 强杀。
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var fullMeta = meta
            fullMeta.aspectRatioText = self.selectedAspectRatio.rawValue
            fullMeta.directorName = self.directorName.isEmpty ? "DIRECTOR" : self.directorName

            let currentRatio = self.selectedAspectRatio
            let currentIsMono = self.isMonochrome

            func render(_ metaToRender: CaptureMetadata) {
                DispatchQueue.global(qos: .userInitiated).async {
                    let processedImage = DirectorWatermarkRenderer.renderCinemaSlate(
                        on: originalImage,
                        metadata: metaToRender,
                        aspectRatio: currentRatio,
                        isMonochrome: currentIsMono
                    )

                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.capturedImage = processedImage
                        self.capturedMetadata = metaToRender
                        self.showPreview = true
                        self.stop()
                        // 不再自动存入相册：由预览页“存入相册”按钮手动保存
                    }
                }
            }

            // 读取取景器记录的拍摄地点，反查为人类可读文字后印到场记卡片上
            guard let location = self.locationService.lastLocation else {
                render(fullMeta)
                return
            }
            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude
            fullMeta.latitude = lat
            fullMeta.longitude = lon

            let geocoder = CLGeocoder()
            geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                let place = CameraManager.placeName(from: placemarks?.first, latitude: lat, longitude: lon)
                var locatedMeta = fullMeta
                locatedMeta.locationText = "📍 " + place
                render(locatedMeta)
            }
        }
    }

    private nonisolated static func extractMetadata(from photo: AVCapturePhoto) -> CaptureMetadata {
        let raw = photo.metadata
        var fl: Float = 0, fl35: Float = 0, apt: Float = 0, exp: Double = 0, isoVal: Float = 0
        var lens = "", dt = ""

        if let exif = raw["{Exif}"] as? [String: Any] {
            fl = floatValue(exif["FocalLength"])
            fl35 = floatValue(exif["FocalLenIn35mmFilm"])
            apt = floatValue(exif["FNumber"])
            exp = doubleValue(exif["ExposureTime"])
            if let arr = exif["ISOSpeedRatings"] as? [Any], let first = arr.first {
                isoVal = floatValue(first)
            }
            if let s = exif["DateTimeOriginal"] as? String { dt = s }
        }

        if let tiff = raw["{TIFF}"] as? [String: Any] {
            if let s = tiff["LensModel"] as? String { lens = s }
            if dt.isEmpty, let s = tiff["DateTime"] as? String { dt = s }
        }
        if lens.isEmpty, let s = raw["LensModel"] as? String { lens = s }
        if dt.isEmpty {
            let f = DateFormatter()
            f.dateFormat = "yyyy:MM:dd HH:mm"
            dt = f.string(from: Date())
        }

        return CaptureMetadata(
            focalLength: fl, focalLength35mm: fl35, aperture: apt,
            exposureTime: exp, iso: isoVal, lensModel: lens,
            dateTime: dt, aspectRatioText: "2.39:1", directorName: "DIRECTOR"
        )
    }

    private nonisolated static func floatValue(_ v: Any?) -> Float {
        if let d = v as? Double { return Float(d) }
        if let f = v as? Float { return f }
        if let i = v as? Int { return Float(i) }
        return 0
    }

    private nonisolated static func doubleValue(_ v: Any?) -> Double {
        if let d = v as? Double { return d }
        if let f = v as? Float { return Double(f) }
        if let i = v as? Int { return Double(i) }
        return 0
    }
}

// MARK: - 地理位置格式化与 EXIF 写入

extension CameraManager {
    /// 将坐标反查为可读地点：中国返回“省/市 区”，海外返回“城市, 国家”，
    /// 反查失败则回退为 “纬度, 经度” 文本。
    private nonisolated static func placeName(from placemark: CLPlacemark?, latitude: Double, longitude: Double) -> String {
        guard let pm = placemark else { return coordsText(latitude, longitude) }
        let country = pm.country ?? ""
        if country == "中国" || country == "China" {
            let admin = pm.administrativeArea ?? ""
            let sub = pm.subLocality ?? ""
            let local = pm.locality ?? ""
            var parts: [String] = []
            if !admin.isEmpty { parts.append(admin) }
            let secondary = (!sub.isEmpty && sub != admin) ? sub
                : ((!local.isEmpty && local != admin) ? local : "")
            if !secondary.isEmpty { parts.append(secondary) }
            if !parts.isEmpty { return parts.joined(separator: " ") }
            return coordsText(latitude, longitude)
        } else {
            let local = pm.locality ?? pm.subAdministrativeArea ?? ""
            if !local.isEmpty, !country.isEmpty {
                return "\(local), \(country)"
            }
            if !local.isEmpty { return local }
            return coordsText(latitude, longitude)
        }
    }

    private nonisolated static func coordsText(_ lat: Double, _ lon: Double) -> String {
        let latRef = lat >= 0 ? "N" : "S"
        let lonRef = lon >= 0 ? "E" : "W"
        return String(format: "%.4f°%@, %.4f°%@", abs(lat), latRef, abs(lon), lonRef)
    }

    /// 将 GPS 经纬度写入 JPEG 的 EXIF（GPS IFD），返回带位置信息的图片数据。
    private nonisolated static func embedGPSData(image: UIImage, latitude: Double?, longitude: Double?) -> Data? {
        guard let lat = latitude, let lon = longitude, let cgImage = image.cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }

        var gps: [CFString: Any] = [:]
        gps[kCGImagePropertyGPSLatitude] = abs(lat)
        gps[kCGImagePropertyGPSLatitudeRef] = lat >= 0 ? "N" : "S"
        gps[kCGImagePropertyGPSLongitude] = abs(lon)
        gps[kCGImagePropertyGPSLongitudeRef] = lon >= 0 ? "E" : "W"
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        gps[kCGImagePropertyGPSDateStamp] = formatter.string(from: Date())

        CGImageDestinationAddImage(destination, cgImage, [kCGImagePropertyGPSDictionary: gps] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

// MARK: - 电影级水印卡片渲染器

enum DirectorWatermarkRenderer {
    static func renderCinemaSlate(
        on original: UIImage,
        metadata: CaptureMetadata,
        aspectRatio: FilmAspectRatio,
        isMonochrome: Bool
    ) -> UIImage {
        var baseImage = original
        if isMonochrome, let ciImage = CIImage(image: original) {
            let filter = CIFilter(name: "CIPhotoEffectNoir")
            filter?.setValue(ciImage, forKey: kCIInputImageKey)
            if let out = filter?.outputImage,
               let cgImg = CIContext().createCGImage(out, from: out.extent) {
                baseImage = UIImage(cgImage: cgImg, scale: original.scale, orientation: original.imageOrientation)
            }
        }

        let maxEdge: CGFloat = 2500
        let longEdge = max(baseImage.size.width, baseImage.size.height)
        let scaleFactor = longEdge > maxEdge ? maxEdge / longEdge : 1.0
        let renderSize = CGSize(
            width: floor(baseImage.size.width * scaleFactor),
            height: floor(baseImage.size.height * scaleFactor)
        )

        let sourceRect: CGRect
        if let targetRatio = aspectRatio.ratioValue {
            let imgRatio = renderSize.width / renderSize.height
            if imgRatio > targetRatio {
                let newW = renderSize.height * targetRatio
                sourceRect = CGRect(x: (renderSize.width - newW) / 2, y: 0, width: newW, height: renderSize.height)
            } else {
                let newH = renderSize.width / targetRatio
                sourceRect = CGRect(x: 0, y: (renderSize.height - newH) / 2, width: renderSize.width, height: newH)
            }
        } else {
            sourceRect = CGRect(origin: .zero, size: renderSize)
        }

        let slateHeight = renderSize.width * 0.18
        let finalCanvasSize = CGSize(width: sourceRect.width, height: sourceRect.height + slateHeight)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: finalCanvasSize, format: format)

        return renderer.image { ctx in
            let cgctx = ctx.cgContext
            
            baseImage.draw(in: CGRect(
                x: -sourceRect.minX,
                y: -sourceRect.minY,
                width: renderSize.width,
                height: renderSize.height
            ))

            let slateRect = CGRect(x: 0, y: sourceRect.height, width: sourceRect.width, height: slateHeight)
            cgctx.setFillColor(UIColor.black.cgColor)
            cgctx.fill(slateRect)

            cgctx.setFillColor(UIColor.systemYellow.withAlphaComponent(0.8).cgColor)
            cgctx.fill(CGRect(x: 0, y: sourceRect.height, width: sourceRect.width, height: 2))

            let w = sourceRect.width
            let titleFont = UIFont.systemFont(ofSize: w * 0.038, weight: .black)
            let metaFont = UIFont.monospacedDigitSystemFont(ofSize: w * 0.028, weight: .bold)
            let subFont = UIFont.systemFont(ofSize: w * 0.022, weight: .medium)
            let locFont = UIFont.systemFont(ofSize: w * 0.026, weight: .semibold)

            let padding = w * 0.04
            let startY = sourceRect.height + slateHeight * 0.18

            let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: UIColor.white]
            ("🎬 \(metadata.directorName.uppercased())" as NSString).draw(
                at: CGPoint(x: padding, y: startY),
                withAttributes: titleAttr
            )

            let subAttr: [NSAttributedString.Key: Any] = [.font: subFont, .foregroundColor: UIColor.lightGray]
            ("DIRECTOR’S VIEWFINDER  |  \(metadata.aspectRatioText)" as NSString).draw(
                at: CGPoint(x: padding, y: startY + titleFont.lineHeight + 4),
                withAttributes: subAttr
            )

            let exifString = "\(metadata.focalLengthDisplay)  \(metadata.apertureDisplay)  \(metadata.shutterDisplay)  \(metadata.isoDisplay)"
            let exifAttr: [NSAttributedString.Key: Any] = [.font: metaFont, .foregroundColor: UIColor.systemYellow]
            let exifSize = (exifString as NSString).size(withAttributes: exifAttr)

            (exifString as NSString).draw(
                at: CGPoint(x: w - exifSize.width - padding, y: startY),
                withAttributes: exifAttr
            )

            let dateAttr: [NSAttributedString.Key: Any] = [.font: subFont, .foregroundColor: UIColor.gray]
            let dateSize = (metadata.dateTime as NSString).size(withAttributes: dateAttr)
            (metadata.dateTime as NSString).draw(
                at: CGPoint(x: w - dateSize.width - padding, y: startY + metaFont.lineHeight + 4),
                withAttributes: dateAttr
            )

            // 拍摄地点（人类可读文字），以青色印在场记卡片左侧底部
            if let locationText = metadata.locationText, !locationText.isEmpty {
                let locAttr: [NSAttributedString.Key: Any] = [.font: locFont, .foregroundColor: UIColor.systemTeal]
                let locY = startY + titleFont.lineHeight + 4 + subFont.lineHeight + 12
                (locationText as NSString).draw(at: CGPoint(x: padding, y: locY), withAttributes: locAttr)
            }
        }
    }
}

// MARK: - 相机实时预览 UIViewRepresentable

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var onFocusTap: ((CGPoint) -> Void)?

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        v.addGestureRecognizer(tap)
        context.coordinator.previewView = v
        context.coordinator.onFocusTap = onFocusTap
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        context.coordinator.onFocusTap = onFocusTap
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    final class Coordinator: NSObject {
        weak var previewView: PreviewView?
        var onFocusTap: ((CGPoint) -> Void)?

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = previewView else { return }
            let point = gesture.location(in: view)
            let devicePoint = view.previewLayer.captureDevicePointConverted(fromLayerPoint: point)
            onFocusTap?(devicePoint)
        }
    }
}

// MARK: - 导演取景器主视图

struct DirectorCameraView: View {
    @StateObject private var camera = CameraManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var baseZoom: CGFloat = 1.0
    @State private var showEVControls = false

    private let cinemaLenses: [CinemaLensPreset] = [
        CinemaLensPreset(name: "13mm", focalLengthMM: 13, zoomFactor: 0.5),
        CinemaLensPreset(name: "24mm", focalLengthMM: 24, zoomFactor: 1.0),
        CinemaLensPreset(name: "35mm", focalLengthMM: 35, zoomFactor: 1.45),
        CinemaLensPreset(name: "50mm", focalLengthMM: 50, zoomFactor: 2.1),
        CinemaLensPreset(name: "85mm", focalLengthMM: 85, zoomFactor: 3.5),
        CinemaLensPreset(name: "135mm", focalLengthMM: 135, zoomFactor: 5.6)
    ]

    var body: some View {
        Group {
            if !camera.isAuthorized {
                permissionView
            } else if camera.showPreview, let image = camera.capturedImage, let meta = camera.capturedMetadata {
                CapturedPreview(image: image, metadata: meta, camera: camera)
            } else {
                cameraInterface
            }
        }
        .task {
            await camera.checkAuthorization()
            if camera.isAuthorized {
                camera.startLocationServices()
                if camera.isConfigured { camera.start() } else { camera.configure() }
            }
        }
        .onDisappear { camera.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                camera.stop()
            } else if phase == .active, camera.isAuthorized, camera.isConfigured, !camera.showPreview {
                camera.start()
            }
        }
    }

    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.aperture")
                .font(.system(size: 64))
                .foregroundStyle(.yellow)
            Text("需要相机与相册权限")
                .font(.title2.bold())
            Text("导演取景器需要使用相机进行专业构图取景，并将片场记录自动存入相册。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("去开启权限") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
            .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    private var cameraInterface: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: camera.session, onFocusTap: { point in
                camera.focus(at: point)
            })
            .ignoresSafeArea()
            .saturation(camera.isMonochrome ? 0.0 : 1.0)
            .gesture(
                MagnificationGesture()
                    .onChanged { val in
                        camera.setZoom(baseZoom * val)
                    }
                    .onEnded { _ in
                        baseZoom = camera.zoomFactor
                    }
            )

            AspectMaskOverlay(aspectRatio: camera.selectedAspectRatio)
                .ignoresSafeArea()

            if camera.gridEnabled {
                gridOverlay
            }

            VStack(spacing: 0) {
                topBar
                    .padding(.top, 8)

                liveInfoBar
                    .padding(.top, 10)

                if showEVControls {
                    evSlider
                        .padding(.top, 8)
                }

                Spacer()

                lensSelectorRow
                    .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            bottomControlBar
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.85))
        }
        .alert("提示", isPresented: Binding(
            get: { camera.errorText != nil },
            set: { if !$0 { camera.errorText = nil } }
        )) {
            Button("确定") { camera.errorText = nil }
        } message: {
            Text(camera.errorText ?? "")
        }
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) {
                Image(systemName: "film.stack.fill")
                    .foregroundStyle(.yellow)
                TextField("导演名称", text: $camera.directorName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(width: 90)
            }

            Spacer()

            Button {
                camera.isMonochrome.toggle()
            } label: {
                Image(systemName: camera.isMonochrome ? "circle.righthalf.filled" : "circle.dashed")
                    .font(.title3)
                    .foregroundStyle(camera.isMonochrome ? .yellow : .white)
            }

            Button {
                withAnimation { showEVControls.toggle() }
            } label: {
                Image(systemName: "plusminus")
                    .font(.title3)
                    .foregroundStyle(showEVControls ? .yellow : .white)
            }

            Button {
                camera.gridEnabled.toggle()
            } label: {
                Image(systemName: camera.gridEnabled ? "grid" : "grid.circle")
                    .font(.title3)
                    .foregroundStyle(camera.gridEnabled ? .yellow : .white)
            }

            Menu {
                Picker("画幅比例", selection: $camera.selectedAspectRatio) {
                    ForEach(FilmAspectRatio.allCases) { ratio in
                        Text(ratio.rawValue).tag(ratio)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(camera.selectedAspectRatio.rawValue)
                        .font(.caption.bold())
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.yellow, in: Capsule())
            }
        }
        .padding(.horizontal, 16)
    }

    private var evSlider: some View {
        HStack {
            Text("EV")
                .font(.caption2.bold())
                .foregroundStyle(.yellow)
            Slider(value: Binding(
                get: { camera.exposureTargetBias },
                set: { camera.setEV($0) }
            ), in: -2.0...2.0, step: 0.3)
            .tint(.yellow)
            Text(String(format: "%.1f", camera.exposureTargetBias))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6), in: Capsule())
        .padding(.horizontal, 20)
    }

    private var liveInfoBar: some View {
        HStack(spacing: 16) {
            Label(currentFocalLengthDisplay, systemImage: "camera.aperture")
            Label(liveShutterText, systemImage: "timer")
            Label("ISO \(Int(camera.liveISO))", systemImage: "sun.max")
        }
        .font(.caption.weight(.semibold).monospacedDigit())
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.5), in: Capsule())
    }

    private var currentFocalLengthDisplay: String {
        let baseMM: CGFloat = 24.0
        let currentMM = Int(baseMM * camera.zoomFactor)
        return "\(currentMM)mm"
    }

    private var liveShutterText: String {
        guard camera.liveShutter > 0 else { return "1/50s" }
        if camera.liveShutter < 1 {
            let denom = max(1, Int((1.0 / camera.liveShutter).rounded()))
            return "1/\(denom)s"
        }
        return String(format: "%.1fs", camera.liveShutter)
    }

    private var lensSelectorRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(cinemaLenses) { lens in
                    let isSelected = abs(camera.zoomFactor - lens.zoomFactor) < 0.15
                    Button {
                        baseZoom = lens.zoomFactor
                        camera.setZoom(lens.zoomFactor)
                    } label: {
                        VStack(spacing: 2) {
                            Text(lens.name)
                                .font(.subheadline.bold())
                            Text("\(lens.focalLengthMM)mm")
                                .font(.caption2)
                                .opacity(0.8)
                        }
                        .foregroundStyle(isSelected ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isSelected ? Color.yellow : Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var bottomControlBar: some View {
        HStack {
            Button {
                camera.flipCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
            }

            Spacer()

            Button {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                camera.capture()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.yellow, lineWidth: 3)
                        .frame(width: 72, height: 72)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                }
            }

            Spacer()

            Color.clear.frame(width: 50, height: 50)
        }
    }

    private var gridOverlay: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height
                path.move(to: CGPoint(x: w / 3, y: 0)); path.addLine(to: CGPoint(x: w / 3, y: h))
                path.move(to: CGPoint(x: w * 2 / 3, y: 0)); path.addLine(to: CGPoint(x: w * 2 / 3, y: h))
                path.move(to: CGPoint(x: 0, y: h / 3)); path.addLine(to: CGPoint(x: w, y: h / 3))
                path.move(to: CGPoint(x: 0, y: h * 2 / 3)); path.addLine(to: CGPoint(x: w, y: h * 2 / 3))
            }
            .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 电影画幅遮罩 View (修复 ViewBuilder 异常)

struct AspectMaskOverlay: View {
    let aspectRatio: FilmAspectRatio

    var body: some View {
        GeometryReader { geo in
            createMask(geo: geo)
        }
        .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private func createMask(geo: GeometryProxy) -> some View {
        if let targetRatio = aspectRatio.ratioValue {
            let screenW = geo.size.width
            let screenH = geo.size.height
            let screenRatio = screenW / screenH

            let maskW = screenRatio > targetRatio ? screenH * targetRatio : screenW
            let maskH = screenRatio > targetRatio ? screenH : screenW / targetRatio

            let horizontalGap = max(0, (screenW - maskW) / 2)
            let verticalGap = max(0, (screenH - maskH) / 2)

            ZStack {
                VStack(spacing: 0) {
                    Color.black.opacity(0.85).frame(height: verticalGap)
                    Spacer(minLength: 0)
                    Color.black.opacity(0.85).frame(height: verticalGap)
                }

                HStack(spacing: 0) {
                    Color.black.opacity(0.85).frame(width: horizontalGap)
                    Spacer(minLength: 0)
                    Color.black.opacity(0.85).frame(width: horizontalGap)
                }

                Rectangle()
                    .stroke(Color.yellow.opacity(0.6), lineWidth: 1)
                    .frame(width: maskW, height: maskH)
            }
        } else {
            // 提供明确占位，解决 Type '()' cannot conform to 'View' 报错
            Color.clear
        }
    }
}

// MARK: - 照片预览与导出视图

struct CapturedPreview: View {
    let image: UIImage
    let metadata: CaptureMetadata
    @ObservedObject var camera: CameraManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(4)
                    .shadow(color: .white.opacity(0.1), radius: 10)
                    .padding(.horizontal, 12)

                VStack(spacing: 6) {
                    Text("🎬 片场记录与拍摄参数已写入卡片")
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)

                    Text("\(metadata.focalLengthDisplay)  |  \(metadata.apertureDisplay)  |  \(metadata.shutterDisplay)  |  \(metadata.isoDisplay)")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(.white)

                    if let locationText = metadata.locationText, !locationText.isEmpty {
                        Text(locationText)
                            .font(.caption.bold())
                            .foregroundStyle(.teal)
                            .padding(.top, 2)
                    }
                }
                .padding(.top, 4)

                saveStatusView

                Spacer()

                HStack(spacing: 60) {
                    Button {
                        camera.resetCapture()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 44))
                            Text("重新取景")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.white)
                    }

                    Button {
                        camera.saveToAlbum(image)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: saveIcon)
                                .font(.system(size: 44))
                            Text(saveText)
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.yellow)
                    }
                    .disabled(camera.isSaving || camera.saveResult == .success)
                }
                .padding(.bottom, 32)
            }
        }
    }

    private var saveIcon: String {
        if camera.isSaving { return "hourglass.circle.fill" }
        if case .success = camera.saveResult { return "checkmark.circle.fill" }
        return "arrow.down.circle.fill"
    }

    private var saveText: String {
        if camera.isSaving { return "保存中..." }
        if case .success = camera.saveResult { return "已存入相册" }
        return "存入相册"
    }

    @ViewBuilder
    private var saveStatusView: some View {
        if case .failure(let msg) = camera.saveResult {
            Text("保存失败: \(msg)")
                .font(.caption)
                .foregroundStyle(.red)
        } else {
            // 空白占位确保布局不跳动
            Color.clear.frame(height: 16)
        }
    }
}
