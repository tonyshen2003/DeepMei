//
//  LoginView.swift
//  DeepMei
//
//  登录页：输入 姓名/别名/社员编号 + 密码，复用社员查询拿到记录，
//  比对「登录密码」字段（空密码不允许登录）。登录成功写入飞书登录记录表（默认附带定位）。
//

import SwiftUI

/// 未登录时展示的提示页（可被 NavigationLink 推入登录页）。
struct LoginPromptView: View {
    var body: some View {
        ContentUnavailableView {
            Label("需要登录", systemImage: "lock.fill")
        } description: {
            Text("登录后可使用社员查询与活动签到功能\n账号由社团管理员开通")
        } actions: {
            NavigationLink {
                LoginView()
            } label: {
                Text("去登录")
                    .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

/// 登录表单：与 Android LoginScreen 对齐（5 次失败锁定 30 秒）。
struct LoginView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var account = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var failCount = 0
    @State private var lockedUntil: Date?

    private var isLocked: Bool {
        guard let lockedUntil else { return false }
        return Date() < lockedUntil
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image("ClubLogo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 88, height: 88)
                            .clipShape(Circle())
                        Text("欢迎回来")
                            .font(.title3.weight(.semibold))
                        Text("登录后可使用社员查询与活动签到功能")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("姓名 / 别名 / 社员编号", text: $account)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("密码", text: $password)
                    .textContentType(.password)
            } footer: {
                Text("账号由社团管理员开通，密码请联系管理员")
            }

            if let error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button(action: login) {
                    Group {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(isLocked ? "请稍后再试" : "登录")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(
                    account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        password.isEmpty || isLoading || isLocked
                )
            }
        }
        .navigationTitle("登录")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: lockedUntil) {
            guard let lockedUntil else { return }
            let seconds = lockedUntil.timeIntervalSinceNow
            if seconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
            failCount = 0
            self.lockedUntil = nil
        }
    }

    private func login() {
        guard !isLoading, !isLocked else { return }
        let query = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, !password.isEmpty else { return }

        isLoading = true
        error = nil

        Task {
            do {
                let member = try await MemberService.shared.searchMember(byNameOrCodeOrAlias: query)
                if let member {
                    if member.loginPassword.isEmpty {
                        error = "该账号未开通登录，请联系管理员"
                    } else if member.loginPassword != password {
                        error = "密码错误"
                        onLoginFailed()
                    } else {
                        LoginManager.shared.login(
                            name: member.name,
                            idCode: member.idCode,
                            avatarUrl: member.avatarURL ?? ""
                        )
                        await recordLoginWithLocation(member)
                        dismiss()
                    }
                } else {
                    error = "未找到该社员"
                    onLoginFailed()
                }
            } catch let caughtError {
                error = "登录失败：\(caughtError.localizedDescription)"
            }
            isLoading = false
        }
    }

    /// 登录默认附带定位：已授权直接用；未决定先请求，拒绝权限仍可登录（只是不写定位）。
    private func recordLoginWithLocation(_ member: RaspberryMember) async {
        if AppLocationService.shared.isAuthorized {
            let coordinate = await AppLocationService.shared.getLocationOnce()
            await LoginRecordService.shared.recordLogin(
                name: member.name,
                idCode: member.idCode,
                lat: coordinate?.latitude,
                lng: coordinate?.longitude
            )
        } else if AppLocationService.shared.isDenied {
            await LoginRecordService.shared.recordLogin(
                name: member.name,
                idCode: member.idCode,
                lat: nil,
                lng: nil
            )
        } else {
            let granted = await AppLocationService.shared.requestPermissionAndWait()
            if granted {
                let coordinate = await AppLocationService.shared.getLocationOnce()
                await LoginRecordService.shared.recordLogin(
                    name: member.name,
                    idCode: member.idCode,
                    lat: coordinate?.latitude,
                    lng: coordinate?.longitude
                )
            } else {
                await LoginRecordService.shared.recordLogin(
                    name: member.name,
                    idCode: member.idCode,
                    lat: nil,
                    lng: nil
                )
            }
        }
    }

    private func onLoginFailed() {
        failCount += 1
        if failCount >= 5 {
            lockedUntil = Date().addingTimeInterval(30)
        }
    }
}
