//
//  MyRaspberryView.swift
//  DeepMei
//

import SwiftUI
import AVFoundation

struct MyRaspberryView: View {
    @State private var member: Member?
    @State private var inputId = ""
    @State private var showQRScanner = false
    @StateObject private var qrScanner = QRScanner()

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 60))
                Text("我的树莓")
                    .font(.largeTitle)

                if let member {
                    VStack(spacing: 10) {
                        Text(member.name)
                            .font(.title)
                        Text(member.title)
                        Text(member.generation)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Button("重新识别") {
                        member = nil
                        inputId = ""
                    }
                    .buttonStyle(.bordered)
                } else {
                    Text("请识别身份")
                        .foregroundStyle(.secondary)

                    // 手动输入
                    VStack(spacing: 12) {
                        TextField("输入社员号", text: $inputId)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 32)
                            .keyboardType(.asciiCapable)

                        Button("查询") {
                            guard !inputId.trimmingCharacters(in: .whitespaces).isEmpty else {
                                return
                            }
                            member = MemberStore.shared.find(id: inputId)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Divider()
                        .padding(.horizontal, 32)

                    // 扫码
                    Button {
                        showQRScanner = true
                    } label: {
                        Label(
                            "扫码识别",
                            systemImage: "qrcode.viewfinder"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("我的树莓")
        }
        .fullScreenCover(isPresented: $showQRScanner) {
            QRScannerView(scanner: qrScanner)
        }
        .onChange(of: qrScanner.scannedCode) { _, code in
            guard let code = code else { return }
            member = MemberStore.shared.find(id: code)
            showQRScanner = false
        }
    }
}

struct QRScannerView: View {
    @ObservedObject var scanner: QRScanner
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CameraPreview(scanner: scanner)
                .ignoresSafeArea()

            VStack {
                Spacer()
                VStack(spacing: 16) {
                    Text("请扫描社员二维码")
                        .foregroundColor(.white)
                        .font(.headline)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button("取消") {
                        scanner.stopScanning()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundColor(.black)
                }
                .padding()
            }
        }
        .onAppear {
            scanner.startScanning()
        }
        .onDisappear {
            scanner.stopScanning()
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var scanner: QRScanner

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        if let layer = scanner.getPreviewLayer() {
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = scanner.getPreviewLayer() {
            layer.frame = uiView.bounds
        }
    }
}
