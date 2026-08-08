//
//  QRScannerView.swift
//  DeepMei
//
//  原生二维码扫码层：AVFoundation 预览 + 元数据识别。
//  识别成功后回调一次并自动关闭；无相机权限时给出明确提示。
//

import AVFoundation
import SwiftUI
import UIKit

struct QRScannerView: UIViewControllerRepresentable {
    var onCodeDetected: (String) -> Void
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onCodeDetected = onCodeDetected
        controller.onDismiss = onDismiss
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeDetected: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isConfigured = false
    private var didDetect = false

    private let messageLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupMessageLabel()
        setupCloseButton()
        checkPermission()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        messageLabel.frame = CGRect(
            x: 24,
            y: view.bounds.height - 96,
            width: view.bounds.width - 48,
            height: 48
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    // MARK: - 权限与配置

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    if granted {
                        self?.configureAndStart()
                    } else {
                        self?.showPermissionDenied()
                    }
                }
            }
        default:
            showPermissionDenied()
        }
    }

    private func configureAndStart() {
        guard !isConfigured else { return }
        isConfigured = true

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video)
        else {
            showUnavailable()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard captureSession.canAddInput(input) else {
                showUnavailable()
                return
            }
            captureSession.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard captureSession.canAddOutput(output) else {
                showUnavailable()
                return
            }
            captureSession.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let layer = AVCaptureVideoPreviewLayer(session: captureSession)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.insertSublayer(layer, at: 0)
            previewLayer = layer

            messageLabel.text = "将社员识别码对准扫描区域"
            messageLabel.isHidden = false

            captureSession.startRunning()
        } catch {
            showUnavailable()
        }
    }

    private func stopSession() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    private func showPermissionDenied() {
        messageLabel.text = "需要相机权限才能扫码签到\n请在系统设置中允许 DeepMei 使用相机"
        messageLabel.isHidden = false
    }

    private func showUnavailable() {
        messageLabel.text = "相机不可用，请使用手动输入"
        messageLabel.isHidden = false
    }

    // MARK: - 识别回调

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let code = object.stringValue,
            !code.isEmpty
        else { return }

        Task { @MainActor [weak self] in
            guard let self, !self.didDetect else { return }
            self.didDetect = true
            self.stopSession()
            self.onCodeDetected?(code)
        }
    }

    // MARK: - UI

    private func setupCloseButton() {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 22
        button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(button)

        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            button.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupMessageLabel() {
        messageLabel.textColor = .white
        messageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.text = "正在请求相机权限…"
        view.addSubview(messageLabel)
    }

    @objc private func closeTapped() {
        stopSession()
        onDismiss?()
    }
}
