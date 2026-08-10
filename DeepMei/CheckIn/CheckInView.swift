//
//  CheckInView.swift
//  DeepMei
//
//  原生签到页（卡片化设计）：
//
//  「待机 → 读取 → 亮卡 → 盖章」四幕式，与 Android 签到页交互对齐：
//  - 待机：扫码 / 手动输入作为入口，保留最近识别；
//  - 亮卡：实体社员卡 + 紧凑的盖章栏（活动 / 时长 / 定位 / 提交）；
//  - 未知卡：未登记卡片的友好兜底，支持复制卡号；
//  - 签到成功后卡片盖下印章，一键「下一位」回到待机。
//

import SwiftUI
import UIKit

// MARK: - 状态定义

private enum CheckInStage: Equatable {
    case idle
    case reading
    case cardRevealed(member: CheckInMember, cardId: String, submitting: Bool, submitted: Bool)
    case unknownCard(cardId: String)
}

private struct RecentCheckIn: Identifiable, Equatable {
    var id: String { cardId }
    let member: CheckInMember
    let cardId: String
    let submitted: Bool
}

// MARK: - 签到偏好记忆

private enum CheckInPrefs {
    private static let lastActivityKey = "checkin_last_activity"
    private static let lastDurationKey = "checkin_last_duration"
    private static let recentActivitiesKey = "checkin_recent_activities"
    private static let separator = "\u{0001}"

    static var savedActivity: String {
        UserDefaults.standard.string(forKey: lastActivityKey) ?? ""
    }

    static var savedDuration: String {
        let value = UserDefaults.standard.string(forKey: lastDurationKey) ?? ""
        return value.isEmpty ? "2" : value
    }

    static var activityOptions: [String] {
        (UserDefaults.standard.string(forKey: recentActivitiesKey) ?? "")
            .split(separator: separator)
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// 保存本次签到选择（活动 / 时长），并把最近活动写进记忆列表，返回更新后的列表。
    static func save(activity: String, duration: String) -> [String] {
        let options = activityOptions
        let updated = ([activity] + options)
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { result, item in
                if !result.contains(item) { result.append(item) }
            }
        let list = Array(updated.prefix(4))

        UserDefaults.standard.set(list.joined(separator: separator), forKey: recentActivitiesKey)
        if !activity.isEmpty {
            UserDefaults.standard.set(activity, forKey: lastActivityKey)
        }
        if !duration.isEmpty {
            UserDefaults.standard.set(duration, forKey: lastDurationKey)
        }
        return list
    }

    /// 删除一条记忆的活动名称；若它正是当前选中的活动，一并清空选中项。
    static func remove(activity: String) -> [String] {
        let updated = activityOptions.filter { $0 != activity }
        UserDefaults.standard.set(updated.joined(separator: separator), forKey: recentActivitiesKey)
        if UserDefaults.standard.string(forKey: lastActivityKey) == activity {
            UserDefaults.standard.removeObject(forKey: lastActivityKey)
        }
        return updated
    }
}

// MARK: - 主页面

struct CheckInView: View {
    @ObservedObject private var loginManager = LoginManager.shared

    @State private var stage: CheckInStage = .idle
    @State private var manualCode = ""
    @State private var activityName = CheckInPrefs.savedActivity
    @State private var duration = CheckInPrefs.savedDuration
    @State private var activityOptions = CheckInPrefs.activityOptions
    @State private var includeLocation = true
    @State private var locationDenied = AppLocationService.shared.isDenied
    @State private var scanning = false
    @State private var isReadingNFC = false
    @State private var showManualSheet = false
    @State private var recents: [RecentCheckIn] = []
    @State private var toast: String?

    var body: some View {
        if loginManager.isLoggedIn {
            checkInContent
        } else {
            LoginPromptView()
                .navigationTitle("活动签到")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var checkInContent: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            Group {
                switch stage {
                case .idle:
                    IdleScene(
                        savedActivity: activityName,
                        recents: recents,
                        nfcAvailable: NFCUIDReader.isReadingAvailable,
                        isReadingNFC: isReadingNFC,
                        onNFC: startNFCRead,
                        onScan: { scanning = true },
                        onManual: { showManualSheet = true },
                        onRecentClick: { recent in
                            stage = .cardRevealed(
                                member: recent.member,
                                cardId: recent.cardId,
                                submitting: false,
                                submitted: recent.submitted
                            )
                        },
                        onRemoveRecent: { code in
                            recents.removeAll { $0.cardId == code }
                        },
                        onClearRecents: { recents.removeAll() }
                    )

                case .reading:
                    ReadingScene()

                case .cardRevealed(let member, let cardId, let submitting, let submitted):
                    RevealScene(
                        member: member,
                        cardId: cardId,
                        submitted: submitted,
                        submitting: submitting,
                        activityName: activityName,
                        activityOptions: activityOptions,
                        duration: duration,
                        includeLocation: includeLocation,
                        onActivityChange: { activityName = $0 },
                        onDeleteActivity: { option in
                            activityOptions = CheckInPrefs.remove(activity: option)
                            if activityName == option { activityName = "" }
                        },
                        onDurationChange: { duration = $0 },
                        onLocationChange: { includeLocation = $0 },
                        onSubmit: submit,
                        onNext: { stage = .idle },
                        onScan: { scanning = true },
                        onManual: { showManualSheet = true },
                        onCopy: { copyCardId(cardId) }
                    )

                case .unknownCard(let cardId):
                    UnknownCardScene(
                        cardId: cardId,
                        onCopy: { copyCardId(cardId) },
                        onRetry: { stage = .idle }
                    )
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: stage)
        }
        .navigationTitle("活动签到")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $scanning, onDismiss: nil) {
            QRScannerView(
                onCodeDetected: { code in
                    scanning = false
                    lookup(code)
                },
                onDismiss: { scanning = false }
            )
            .ignoresSafeArea()
            .background(Color.black)
        }
        .sheet(isPresented: $showManualSheet) {
            NavigationStack {
                VStack(spacing: 14) {
                    TextField("社员识别码 / 卡号", text: $manualCode)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .submitLabel(.search)
                        .onSubmit {
                            showManualSheet = false
                            lookup(manualCode)
                        }

                    Button {
                        showManualSheet = false
                        lookup(manualCode)
                    } label: {
                        Text("查询")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(manualCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Text("与扫码识别使用同一套社员数据")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .navigationTitle("手动输入")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("取消") { showManualSheet = false }
                    }
                }
            }
            .presentationDetents([.height(240)])
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.75), in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - 交互逻辑

    private func lookup(_ raw: String) {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: ":", with: "")
        guard !code.isEmpty else { return }
        if case let .cardRevealed(_, _, submitting, _) = stage, submitting { return }

        stage = .reading
        Task {
            do {
                // 快照缓存优先（秒开/离线可识别），未命中再回退 Worker 实时查询
                let cached = await MemberSnapshotCache.shared.findCheckInMember(code: code)
                let found: CheckInMember?
                if let cached {
                    found = cached
                } else {
                    found = try await CheckInService.shared.lookupMember(rawCode: code)
                }

                if let found {
                    if cached == nil {
                        // 本地快照未命中（如刚登记的新卡）：在线查到后立即后台刷新快照，下次即可秒开
                        Task { _ = await MemberSnapshotCache.shared.refresh() }
                    }
                    addRecent(found, code: code)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        stage = .cardRevealed(member: found, cardId: code, submitting: false, submitted: false)
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        stage = .unknownCard(cardId: code)
                    }
                }
            } catch {
                withAnimation(.easeInOut(duration: 0.2)) {
                    stage = .idle
                }
                showToast(error.localizedDescription)
            }
        }
    }

    // MARK: - NFC 读卡

    private func startNFCRead() {
        guard !isReadingNFC else { return }
        isReadingNFC = true
        Task {
            do {
                let uid = try await NFCUIDReader.shared.readUID()
                isReadingNFC = false
                lookup(uid)
            } catch NFCReadError.canceled {
                isReadingNFC = false
            } catch {
                isReadingNFC = false
                showToast("NFC 读取失败：\(error.localizedDescription)")
            }
        }
    }

    private func submit() {
        guard case let .cardRevealed(member, cardId, submitting, submitted) = stage,
              !submitting, !submitted else { return }

        if includeLocation && !AppLocationService.shared.isAuthorized && !locationDenied {
            AppLocationService.shared.requestPermission()
            showToast("请允许定位后再次点击签到")
            return
        }

        stage = .cardRevealed(member: member, cardId: cardId, submitting: true, submitted: false)
        Task {
            var lat: Double?
            var lng: Double?
            if includeLocation, AppLocationService.shared.isAuthorized {
                let coordinate = await AppLocationService.shared.getLocationOnce()
                lat = coordinate?.latitude
                lng = coordinate?.longitude
            }

            let trimmedDuration = duration.trimmingCharacters(in: .whitespacesAndNewlines)
            let durationText = trimmedDuration.isEmpty ? "" : "\(trimmedDuration)小时"
            let trimmedActivity = activityName.trimmingCharacters(in: .whitespacesAndNewlines)

            do {
                let ok = try await CheckInService.shared.submitCheckIn(
                    uid: cardId,
                    name: member.name,
                    activity: trimmedActivity,
                    duration: durationText,
                    lat: lat,
                    lng: lng
                )
                if ok {
                    activityOptions = CheckInPrefs.save(activity: trimmedActivity, duration: trimmedDuration)
                    markRecentSubmitted(cardId)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        stage = .cardRevealed(member: member, cardId: cardId, submitting: false, submitted: true)
                    }
                    showToast("签到成功")
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        stage = .cardRevealed(member: member, cardId: cardId, submitting: false, submitted: false)
                    }
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    showToast("签到提交失败，请重试")
                }
            } catch {
                withAnimation(.easeInOut(duration: 0.2)) {
                    stage = .cardRevealed(member: member, cardId: cardId, submitting: false, submitted: false)
                }
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                showToast("签到失败：\(error.localizedDescription)")
            }
        }
    }

    private func copyCardId(_ code: String) {
        guard !code.isEmpty else { return }
        UIPasteboard.general.string = code
        showToast("卡号已复制")
    }

    private func addRecent(_ member: CheckInMember, code: String) {
        recents.removeAll { $0.cardId == code }
        recents.insert(RecentCheckIn(member: member, cardId: code, submitted: false), at: 0)
        if recents.count > 4 {
            recents.removeLast(recents.count - 4)
        }
    }

    private func markRecentSubmitted(_ code: String) {
        guard let index = recents.firstIndex(where: { $0.cardId == code }) else { return }
        recents[index] = RecentCheckIn(
            member: recents[index].member,
            cardId: code,
            submitted: true
        )
    }

    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) {
            toast = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation(.easeIn(duration: 0.25)) {
                toast = nil
            }
        }
    }
}

// MARK: - 待机幕

private struct IdleScene: View {
    let savedActivity: String
    let recents: [RecentCheckIn]
    let nfcAvailable: Bool
    let isReadingNFC: Bool
    let onNFC: () -> Void
    let onScan: () -> Void
    let onManual: () -> Void
    let onRecentClick: (RecentCheckIn) -> Void
    let onRemoveRecent: (String) -> Void
    let onClearRecents: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if !savedActivity.isEmpty {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                        Text("签到活动：\(savedActivity)")
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                }

                VStack(spacing: 12) {
                    ScanRadar()
                        .frame(width: 100, height: 100)
                    Text(nfcAvailable ? "贴卡、扫码或输入识别码" : "扫码或输入识别码")
                        .font(.title3.weight(.semibold))
                    Text("识别后自动亮出社员卡，一键盖章签到")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 34)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1.5)
                )

                if nfcAvailable {
                    Button(action: onNFC) {
                        HStack(spacing: 6) {
                            if isReadingNFC {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "wave.3.right")
                            }
                            Text("NFC 贴卡")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isReadingNFC)

                    HStack(spacing: 10) {
                        Button(action: onScan) {
                            Label("扫码签到", systemImage: "qrcode.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(action: onManual) {
                            Label("手动输入", systemImage: "keyboard")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    HStack(spacing: 10) {
                        Button(action: onScan) {
                            Label("扫码签到", systemImage: "qrcode.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: onManual) {
                            Label("手动输入", systemImage: "keyboard")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if !recents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("最近识别 · 点击可再次亮卡")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("清空", action: onClearRecents)
                                .font(.footnote)
                        }
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 150), spacing: 8)],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            ForEach(recents) { recent in
                                RecentChip(
                                    recent: recent,
                                    onClick: { onRecentClick(recent) },
                                    onDelete: { onRemoveRecent(recent.cardId) }
                                )
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text(nfcAvailable ? "支持 NFC 贴卡 · 扫码 · 手动输入" : "支持扫码与手动输入")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct RecentChip: View {
    let recent: RecentCheckIn
    let onClick: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(recent.submitted ? Color.secondary : Color.accentColor)
                .frame(width: 6, height: 6)
            Text("\(recent.member.name) · \(recent.submitted ? "已签到" : "未签到")")
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .onTapGesture(perform: onClick)
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            recent.submitted
                ? Color.accentColor.opacity(0.15)
                : Color(uiColor: .secondarySystemGroupedBackground),
            in: Capsule()
        )
        .overlay(Capsule().stroke(Color.primary.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - 读取幕

private struct ReadingScene: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("正在读取社员卡…")
                    .font(.title3.weight(.semibold))
                Text("请稍候")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1.5)
            )

            ProgressView(value: 1.0)
                .progressViewStyle(.linear)
                .frame(width: 200)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 亮卡幕

private struct RevealScene: View {
    let member: CheckInMember
    let cardId: String
    let submitted: Bool
    let submitting: Bool
    let activityName: String
    let activityOptions: [String]
    let duration: String
    let includeLocation: Bool
    let onActivityChange: (String) -> Void
    let onDeleteActivity: (String) -> Void
    let onDurationChange: (String) -> Void
    let onLocationChange: (Bool) -> Void
    let onSubmit: () -> Void
    let onNext: () -> Void
    let onScan: () -> Void
    let onManual: () -> Void
    let onCopy: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                MemberCardFace(member: member, showStamp: submitted)

                if submitted {
                    VStack(spacing: 4) {
                        Label("签到成功", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Text([member.name, activityName]
                            .filter { !$0.isEmpty }
                            .joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    HStack(spacing: 10) {
                        Button(action: onNext) {
                            Label("下一位", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: onScan) {
                            Label("扫码签到", systemImage: "qrcode.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack(spacing: 10) {
                        Button(action: onManual) {
                            Label("手动输入", systemImage: "keyboard")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(action: onCopy) {
                            Label("复制卡号", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("签到信息")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)

                        if !activityOptions.isEmpty {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 130), spacing: 8)],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(activityOptions.prefix(3), id: \.self) { option in
                                    ActivityChip(
                                        title: option,
                                        selected: activityName == option,
                                        action: { onActivityChange(option) },
                                        onDelete: { onDeleteActivity(option) }
                                    )
                                }
                                OptionChip(
                                    title: "自定义…",
                                    selected: activityName.isEmpty || !activityOptions.contains(activityName),
                                    action: { onActivityChange("") }
                                )
                            }
                        }

                        TextField(
                            "活动名称（可选）",
                            text: Binding(get: { activityName }, set: onActivityChange)
                        )
                        .textFieldStyle(.roundedBorder)

                        HStack(spacing: 8) {
                            ForEach(["1", "2", "3"], id: \.self) { value in
                                OptionChip(
                                    title: "\(value) 小时",
                                    selected: duration == value,
                                    action: { onDurationChange(value) }
                                )
                            }
                            OptionChip(
                                title: "自定义…",
                                selected: !["1", "2", "3"].contains(duration),
                                action: { onDurationChange("") }
                            )
                        }

                        if !["1", "2", "3"].contains(duration) {
                            TextField(
                                "时长（小时，可选）",
                                text: Binding(get: { duration }, set: onDurationChange)
                            )
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                        }

                        Toggle(isOn: Binding(get: { includeLocation }, set: onLocationChange)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("附带定位")
                                    .font(.subheadline.weight(.semibold))
                                Text("签到记录会带上活动现场位置")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)

                        Button(action: onSubmit) {
                            Group {
                                if submitting {
                                    HStack(spacing: 8) {
                                        ProgressView()
                                        Text("正在盖章…")
                                    }
                                } else {
                                    Label("盖章签到", systemImage: "checkmark.circle.fill")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(submitting)

                        Button("返回待机", action: onNext)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .disabled(submitting)
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 未知卡幕

private struct UnknownCardScene: View {
    let cardId: String
    let onCopy: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("DEEPMEI · 树莓社")
                            .font(.caption.weight(.medium))
                            .kerning(1.5)
                            .foregroundStyle(.secondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "questionmark.circle")
                                .font(.caption2)
                            Text("未登记")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
                    }

                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                .frame(width: 58, height: 58)
                            Text("?")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("未登记的树莓卡")
                                .font(.title3.weight(.semibold))
                            Text("这张卡还没有绑定社员档案")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(cardId)
                        .font(.footnote.weight(.medium))
                        .kerning(0.5)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())

                    Divider()

                    HStack {
                        UnknownStat(label: "持卡人", value: "—")
                        UnknownStat(label: "部门", value: "—")
                        UnknownStat(label: "签到", value: "—")
                    }
                }
                .padding(20)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1.5)
                )

                HStack(spacing: 10) {
                    Button(action: onCopy) {
                        Label("复制卡号", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: onRetry) {
                        Label("重新等待", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text("提示：请联系管理员绑定后重新识别")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct UnknownStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 通用小组件

private struct OptionChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    selected
                        ? Color.accentColor.opacity(0.15)
                        : Color(uiColor: .tertiarySystemGroupedBackground),
                    in: Capsule()
                )
                .foregroundStyle(selected ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

private struct ActivityChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button(action: action) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .padding(.leading, 12)
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, 4)
        .padding(.vertical, 5)
        .background(
            selected
                ? Color.accentColor.opacity(0.15)
                : Color(uiColor: .tertiarySystemGroupedBackground),
            in: Capsule()
        )
        .foregroundStyle(selected ? Color.accentColor : Color.primary)
    }
}

/// 雷达：两波交替辐射 + 静止中心能量核，带呼吸感的科技扩散。
private struct ScanRadar: View {
    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxRadius = size.width / 2

                for index in 0..<2 {
                    let phase = time.truncatingRemainder(dividingBy: 2)
                    let progress = (phase + Double(index) * 0.5).truncatingRemainder(dividingBy: 1)
                    let radius = maxRadius * progress
                    let alpha = (1 - progress) * 0.4
                    let rect = CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(Color.accentColor.opacity(alpha)),
                        lineWidth: 4
                    )
                }

                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 24, y: center.y - 24, width: 48, height: 48)),
                    with: .color(Color.accentColor.opacity(0.15))
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16)),
                    with: .color(Color.accentColor)
                )
            }
        }
    }
}
