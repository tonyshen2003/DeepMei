//
//  QRScanner.swift
//  DeepMei
//
//  Created by 沈孙丰 on 2026/7/26.
//

import Foundation
import AVFoundation

class QRScanner: NSObject, ObservableObject {
    @Published var scannedCode: String?
    @Published var isScanning = false

    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?

    func startScanning() {
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("无法访问相机")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession = AVCaptureSession()
            captureSession?.addInput(input)

            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession?.addOutput(captureMetadataOutput)

            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = [.qr]

            isScanning = true
            captureSession?.startRunning()
        } catch {
            print("相机初始化失败: \(error)")
            isScanning = false
        }
    }

    func stopScanning() {
        captureSession?.stopRunning()
        isScanning = false
        scannedCode = nil
    }

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else { return nil }
        if videoPreviewLayer == nil {
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
            videoPreviewLayer?.videoGravity = .resizeAspectFill
        }
        return videoPreviewLayer
    }
}

extension QRScanner: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let code = metadataObj.stringValue {
            scannedCode = code
            stopScanning()
        }
    }
}
