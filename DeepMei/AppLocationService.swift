//
//  AppLocationService.swift
//  DeepMei
//
//  登录 / 签到定位工具：优先使用系统定位，8 秒内拿不到就返回 nil。
//  坐标统一做 WGS-84 → GCJ-02（火星坐标）转换，与 Android LocationUtils 对齐。
//

import CoreLocation
import Foundation

@MainActor
final class AppLocationService: NSObject, CLLocationManagerDelegate {
    static let shared = AppLocationService()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var authContinuation: CheckedContinuation<Bool, Never>?
    private var authTimeoutTask: Task<Void, Never>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorized: Bool {
        let status = manager.authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    var isDenied: Bool {
        let status = manager.authorizationStatus
        return status == .denied || status == .restricted
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// 请求定位权限并等待用户决定（30 秒超时兜底）；已授权返回 true，拒绝/受限返回 false。
    func requestPermissionAndWait() async -> Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .denied, .restricted:
            return false
        default:
            break
        }

        return await withCheckedContinuation { continuation in
            authContinuation = continuation
            authTimeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                self?.resumeAuth(self?.manager.authorizationStatus ?? .denied)
            }
            manager.requestWhenInUseAuthorization()
        }
    }

    /// 尽力获取一次定位（已转换 GCJ-02）；无权限 / 超时 / 失败返回 nil。
    func getLocationOnce() async -> CLLocationCoordinate2D? {
        if let location = manager.location {
            return wgs84ToGcj02(location.coordinate)
        }
        guard isAuthorized else { return nil }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                self?.resume(nil)
            }
            manager.requestLocation()
        }
    }

    private func resume(_ coordinate: CLLocationCoordinate2D?) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation.resume(returning: coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        resume(locations.last?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resume(nil)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        resumeAuth(manager.authorizationStatus)
    }

    private func resumeAuth(_ status: CLAuthorizationStatus) {
        guard let continuation = authContinuation else { return }
        authContinuation = nil
        authTimeoutTask?.cancel()
        authTimeoutTask = nil
        let granted = status == .authorizedWhenInUse || status == .authorizedAlways
        continuation.resume(returning: granted)
    }

    // MARK: - WGS-84 → GCJ-02（火星坐标）

    private func wgs84ToGcj02(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        if outOfChina(latitude: coordinate.latitude, longitude: coordinate.longitude) {
            return coordinate
        }
        var dLat = transformLat(x: coordinate.longitude - 105.0, y: coordinate.latitude - 35.0)
        var dLng = transformLng(x: coordinate.longitude - 105.0, y: coordinate.latitude - 35.0)
        let radLat = coordinate.latitude / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - Self.ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = dLat * 180.0 / ((Self.a * (1 - Self.ee)) / (magic * sqrtMagic) * .pi)
        dLng = dLng * 180.0 / (Self.a / sqrtMagic * cos(radLat) * .pi)
        return CLLocationCoordinate2D(
            latitude: coordinate.latitude + dLat,
            longitude: coordinate.longitude + dLng
        )
    }

    private func outOfChina(latitude: Double, longitude: Double) -> Bool {
        longitude < 72.004 || longitude > 137.8347 ||
            latitude < 0.8293 || latitude > 55.8271
    }

    private func transformLat(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * .pi) + 320.0 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    private func transformLng(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return ret
    }

    private static let a = 6378245.0
    private static let ee = 0.00669342162296594323
}
