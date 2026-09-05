//
//  MemberProofsView.swift
//  DeepMei
//
//  社员证明：下载自入社日期以来各学期盖章证明 PDF。
//  数据链路：Worker /api/members/detail（joinDate）+ /api/proof-files + /api/file?token=
//  资格比较（发布时间 >= 入社日期）在客户端本地完成，与小程序 proofs 云函数同一规则。
//

import PDFKit
import SwiftUI
import UIKit

struct MemberProofsView: View {
    @ObservedObject private var loginManager = LoginManager.shared

    @State private var state: ProofLoadState = .loading
    @State private var items: [MemberProofItem] = []
    @State private var profile: MemberProofProfile?
    @State private var errorMessage = ""
    @State private var openingItemID: String?
    @State private var previewItem: ProofPreviewItem?
    @State private var showErrorAlert = false

    private enum ProofLoadState {
        case loading
        case ready
        case empty
        case error
        case needsLogin
    }

    var body: some View {
        proofList
            .overlay { stateOverlay }
            .navigationTitle("社员证明")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await load(fresh: false)
            }
            .sheet(item: $previewItem) { preview in
                PDFProofPreviewView(fileURL: preview.url, title: preview.title)
                    .tint(ProofPalette.accent)
            }
            .alert("无法打开证明", isPresented: $showErrorAlert) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage.isEmpty ? "下载失败，请稍后重试。" : errorMessage)
            }
    }

    // MARK: - 状态覆盖层（列表常驻，空/错/加载态也可下拉或点按钮刷新）

    @ViewBuilder
    private var stateOverlay: some View {
        switch state {
        case .loading:
            if items.isEmpty {
                ProgressView("正在获取证明文件…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .needsLogin:
            ContentUnavailableView {
                Label("需要登录", systemImage: "lock.fill")
            } description: {
                Text("登录后即可查看入社以来的学期证明。")
            }
        case .error:
            ContentUnavailableView {
                Label("无法获取证明", systemImage: "exclamationmark.triangle.fill")
            } description: {
                Text(errorMessage.isEmpty ? "网络异常，请稍后重试。" : errorMessage)
            } actions: {
                Button("重试") {
                    Task { await load(fresh: true) }
                }
                .buttonStyle(.borderedProminent)
                .tint(ProofPalette.accent)
            }
        case .empty:
            ContentUnavailableView {
                Label("暂无证明文件", systemImage: "doc.text")
            } description: {
                Text(emptyDescription)
            } actions: {
                Button("刷新") {
                    Task { await load(fresh: true) }
                }
                .buttonStyle(.borderedProminent)
                .tint(ProofPalette.accent)
            }
        case .ready:
            EmptyView()
        }
    }

    private var emptyDescription: String {
        let joinDisplay = joinDateDisplay
        if !joinDisplay.isEmpty {
            return "本学期证明印发后，可在此查看自\(joinDisplay)入社以来的证明。"
        }
        return "本学期证明印发后即可在此查看下载。"
    }

    // MARK: - 列表

    private var proofList: some View {
        List {
            if !items.isEmpty {
                Section {
                    ForEach(items) { item in
                        Button {
                            Task { await open(item) }
                        } label: {
                            proofRow(item)
                        }
                        .buttonStyle(.plain)
                        .disabled(openingItemID != nil && openingItemID != item.id)
                    }
                } header: {
                    Text("可下载证明")
                } footer: {
                    Text(listFooterText)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await load(fresh: true)
        }
    }

    private var summaryText: String {
        guard !items.isEmpty else { return emptyDescription }
        if !joinDateDisplay.isEmpty {
            return "自\(joinDateDisplay)入社以来 · 共 \(items.count) 份学期证明"
        }
        return "共 \(items.count) 份学期证明"
    }

    /// 入社时间早于现存首份整社档案时才补充历史说明，避免对普通社员显示无关解释。
    private var listFooterText: String {
        guard shouldShowArchiveOriginNote, !archiveOriginNote.isEmpty else {
            return summaryText
        }
        return summaryText + "\n" + archiveOriginNote
    }

    private var shouldShowArchiveOriginNote: Bool {
        guard let joinDate = profile?.joinDate,
              !joinDate.isEmpty,
              let earliestDate = earliestPublishedAt,
              !earliestDate.isEmpty else {
            return false
        }
        return joinDate.replacingOccurrences(of: "-", with: "")
            < earliestDate.replacingOccurrences(of: "-", with: "")
    }

    /// 现存最早一份整社档案的发布日期（items 已按日期升序）。
    private var earliestPublishedAt: String? {
        items.first(where: { !$0.publishedAt.isEmpty })?.publishedAt
    }

    private var archiveOriginNote: String {
        guard let earliest = items.first(where: { !$0.publishedAt.isEmpty }) else { return "" }
        let prefix = "树莓社社团证明-"
        let label = earliest.title.hasPrefix(prefix)
            ? String(earliest.title.dropFirst(prefix.count))
            : earliest.title
        return "现存整社档案从「\(label)」开始；更早学期当时为个人自行填表、去团委盖章，未留存整社统一档案。"
    }

    private var joinDateDisplay: String {
        guard let joinDate = profile?.joinDate, !joinDate.isEmpty else { return "" }
        return proofFullDate(joinDate)
    }

    /// 标题已写明印发月份时（如“（2021年1月）”），副行不再重复整条日期，避免逐行冗余。
    private func proofMetaText(for item: MemberProofItem) -> String {
        var parts: [String] = []
        if !item.owner.isEmpty {
            parts.append(item.owner)
        }

        let titleMonth = issueMonthDisplay(item.publishedAt)
        let titleAlreadyShowsMonth = !titleMonth.isEmpty
            && (item.title.contains(titleMonth) || item.fileName.contains(titleMonth))
        if !item.publishedAt.isEmpty, !titleAlreadyShowsMonth {
            parts.append(proofFullDate(item.publishedAt))
        }
        if !item.fileSizeText.isEmpty {
            parts.append(item.fileSizeText)
        }
        return parts.joined(separator: " · ")
    }

    /// "2021-01-01" → "2021年1月"；无法解析时原样返回。
    private func issueMonthDisplay(_ iso: String) -> String {
        let parts = iso.split(separator: "-")
        guard parts.count >= 2, let year = Int(parts[0]), let month = Int(parts[1]) else {
            return iso
        }
        return "\(year)年\(month)月"
    }

    /// "2021-01-01" → "2021年1月1日"；无法解析时原样返回。
    private func proofFullDate(_ iso: String) -> String {
        let parts = iso.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return iso
        }
        return "\(year)年\(month)月\(day)日"
    }

    private func proofRow(_ item: MemberProofItem) -> some View {
        let title = item.title.isEmpty ? item.fileName : item.title
        let metaText = proofMetaText(for: item)

        return HStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.title3)
                .foregroundStyle(ProofPalette.accent)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(metaText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if openingItemID == item.id {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title + (metaText.isEmpty ? "" : "，\(metaText)"))
        .accessibilityHint("预览 PDF，可分享或存储")
    }

    // MARK: - 数据

    private var memberCode: String {
        loginManager.loggedInMemberCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func load(fresh: Bool) async {
        guard loginManager.isLoggedIn else {
            state = .needsLogin
            return
        }
        guard !memberCode.isEmpty else {
            errorMessage = "缺少社员识别码，请重新登录后重试"
            state = .error
            return
        }

        if !fresh || state != .ready {
            state = .loading
        }

        do {
            async let profileTask = MemberProofsService.shared.fetchProfile(code: memberCode)
            async let catalogTask = MemberProofsService.shared.fetchProofs()
            let (profile, catalog) = try await (profileTask, catalogTask)

            guard let profile else {
                errorMessage = "未找到可用的社员档案"
                state = .error
                return
            }

            self.profile = profile
            let joinKey = profile.joinDate.replacingOccurrences(of: "-", with: "")
            let eligible = catalog
                .filter { item in
                    guard !joinKey.isEmpty else { return true }
                    let publishedKey = item.publishedAt.replacingOccurrences(of: "-", with: "")
                    return !publishedKey.isEmpty && publishedKey >= joinKey
                }
                .sorted {
                    ($0.publishedAt, $0.title) < ($1.publishedAt, $1.title)
                }
            items = eligible
            state = eligible.isEmpty ? .empty : .ready
        } catch {
            errorMessage = error.localizedDescription
            // 下拉刷新失败时保留旧列表
            if state == .ready {
                return
            }
            state = .error
        }
    }

    private func open(_ item: MemberProofItem) async {
        openingItemID = item.id
        defer { openingItemID = nil }
        do {
            let url = try await MemberProofsService.shared.fileURL(for: item)
            previewItem = ProofPreviewItem(id: item.id, title: item.fileName, url: url)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

// MARK: - PDF 预览

/// 社员证明页的强调色：与工作台紫色入口、小程序证明图标保持一致，
/// 不使用全局红色强调色（红色在页面里会被误解为错误提示）。
private enum ProofPalette {
    static let accent = Color(uiColor: UIColor { trait in
        if trait.userInterfaceStyle == .dark {
            // #C4B5FD：深色模式下用更浅的紫，保证对比度
            return UIColor(red: 196 / 255, green: 181 / 255, blue: 253 / 255, alpha: 1)
        }
        // #6D28D9
        return UIColor(red: 109 / 255, green: 40 / 255, blue: 217 / 255, alpha: 1)
    })
}

private struct ProofPreviewItem: Identifiable {
    let id: String
    let title: String
    let url: URL
}

/// 抽屉式 PDF 预览：从文件列表下方弹出，PDFKit 渲染，
/// ShareLink 交给系统分享/存储；下拉指示条 + 完成按钮按系统 sheet 惯例。
private struct PDFProofPreviewView: View {
    let fileURL: URL
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFKitDocumentView(fileURL: fileURL)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("完成") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: fileURL) {
                            Label("分享/存储", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityLabel("分享或存储证明")
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }
}

private struct PDFKitDocumentView: UIViewRepresentable {
    let fileURL: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.document = PDFDocument(url: fileURL)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != fileURL {
            uiView.document = PDFDocument(url: fileURL)
        }
    }
}
