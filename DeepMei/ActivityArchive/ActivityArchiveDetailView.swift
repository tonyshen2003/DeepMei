//
//  ActivityArchiveDetailView.swift
//  DeepMei
//
//  活动详情页：头图、元信息与统计、介绍/成果/记录正文、活动照片墙。
//  全部使用原生布局组件，空态/错误态用 ContentUnavailableView。
//

import SwiftUI

private enum DetailState {
    case loading
    case ready
    case notFound
    case error
}

struct ActivityArchiveDetailView: View {
    let item: ActivityListItem

    @State private var detail: ActivityDetailItem?
    @State private var state: DetailState = .loading
    @State private var errorMessage = ""
    @State private var viewerSelection: PhotoViewerSelection?
    @State private var imageRetryNonce = 0

    private var typeColor: Color {
        ActivityVisual.color(for: detail?.type ?? item.type)
    }

    private var metaText: String {
        let date = detail?.date ?? item.date
        let place = detail?.place ?? item.place
        var parts: [String] = [date.activityDisplayDate]
        if !place.isEmpty {
            parts.append(place)
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        ScrollView {
            if let detail {
                detailContent(detail)
            }
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await refreshDetailAndImages()
        }
        .overlay {
            if detail == nil {
                placeholderState
            }
        }
        .navigationTitle("活动详情")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
        .fullScreenCover(item: $viewerSelection) { selection in
            ActivityPhotoViewer(photos: selection.photos, startIndex: selection.startIndex)
                .id(selection.id)
        }
    }

    // MARK: - 内容

    private func detailContent(_ activity: ActivityDetailItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 头图
            Group {
                if let hero = heroURL(for: activity) {
                    FeishuAsyncImage(
                        urlString: hero,
                        placeholderName: activity.name,
                        contentMode: .fill,
                        placeholderText: activity.date.activityMonthDay.isEmpty ? "活" : activity.date.activityMonthDay,
                        placeholderColors: [typeColor, typeColor.opacity(0.72)],
                        autoRetry: true,
                        retryNonce: imageRetryNonce
                    )
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [typeColor, typeColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Text(activity.date.activityMonthDay)
                            .font(.title.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(height: 240)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                // 标题与元信息
                VStack(alignment: .leading, spacing: 8) {
                    Text(activity.name)
                        .font(.title2.weight(.bold))

                    Text(metaText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        if !activity.type.isEmpty {
                            ActivityTypeBadge(type: activity.type)
                        }
                        if activity.isVolunteer {
                            ActivityVolunteerBadge()
                        }
                    }
                }

                // 统计条
                ActivityStatsBar(stats: activity.stats, hoursPer: activity.hoursPer)

                // 正文
                if !activity.intro.isEmpty {
                    ActivityTextSection(title: "活动介绍", text: activity.intro)
                }
                if !activity.result.isEmpty {
                    ActivityTextSection(title: "成果回顾", text: activity.result)
                }
                if !activity.record.isEmpty {
                    ActivityTextSection(title: "活动记录", text: activity.record)
                }

                // 照片墙
                if !activity.photos.isEmpty {
                    photoSection(activity.photos)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }

    private func photoSection(_ photos: [ActivityPhotoItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("活动照片")
                    .font(.headline)
                Spacer()
                Text("共 \(photos.count) 张")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 3),
                spacing: 3
            ) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    Button {
                        // 用 item 形式驱动弹层：选择项与展示同步提交，避免首次点开拿到旧索引
                        viewerSelection = PhotoViewerSelection(
                            photos: photos,
                            startIndex: index
                        )
                    } label: {
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                FeishuAsyncImage(
                                    urlString: photo.thumb.isEmpty ? nil : photo.thumb,
                                    placeholderName: photo.name,
                                    contentMode: .fill,
                                    placeholderSystemImage: "photo",
                                    autoRetry: true,
                                    retryNonce: imageRetryNonce
                                )
                            }
                            .clipped()
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(SqueezeButtonStyle())
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityLabel(photo.name)
                }
            }
        }
    }

    // MARK: - 占位状态

    @ViewBuilder
    private var placeholderState: some View {
        switch state {
        case .loading:
            ProgressView("正在加载活动详情…")
        case .notFound:
            ContentUnavailableView {
                Label("活动不存在", systemImage: "calendar.badge.minus")
            } description: {
                Text("该活动记录可能已被移除。")
            }
        case .error:
            ContentUnavailableView {
                Label("加载失败", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage.isEmpty ? "网络异常，请稍后重试。" : errorMessage)
            } actions: {
                Button("重试") {
                    Task { await loadDetail() }
                }
                .buttonStyle(.borderedProminent)
            }
        case .ready:
            Color.clear
        }
    }

    // MARK: - 数据

    private func heroURL(for activity: ActivityDetailItem) -> String? {
        // 不用照片墙第一张充当封面：活动未设置封面时，顶部就显示类型色日期占位。
        return activityPhotoURL(item.cover, width: 800)
    }

    private func loadDetail() async {
        detail = nil
        state = .loading
        do {
            let response = try await ActivityArchiveService.shared.fetchDetail(id: item.id)
            guard response.found, let activity = response.activity else {
                state = .notFound
                return
            }
            detail = activity
            state = .ready
        } catch {
            errorMessage = error.localizedDescription
            state = .error
        }
    }

    /// 下拉刷新：静默重拉详情（失败保留旧内容），并让已失败/陈旧的图片重新加载。
    private func refreshDetailAndImages() async {
        if detail != nil {
            do {
                let response = try await ActivityArchiveService.shared.fetchDetail(id: item.id)
                if response.found, let activity = response.activity {
                    detail = activity
                }
            } catch {
                // 刷新失败保留当前内容，不打断浏览
            }
        } else {
            await loadDetail()
        }
        imageRetryNonce += 1
    }
}

/// 照片查看器打开请求：每次点缩略图生成一个新请求，全屏弹层按 item 展示。
private struct PhotoViewerSelection: Identifiable {
    let id = UUID()
    let photos: [ActivityPhotoItem]
    let startIndex: Int
}
