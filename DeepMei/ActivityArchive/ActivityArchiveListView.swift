//
//  ActivityArchiveListView.swift
//  DeepMei
//
//  活动记录列表页：原生 List + 右上角原生筛选菜单（年份 / 类型）+ 常驻原生搜索，
//  下拉刷新、触底分页，加载/错误/空态均使用系统组件。
//

import SwiftUI

private enum LoadState {
    case loading
    case ready
    case empty
    case error
}

struct ActivityArchiveListView: View {
    private enum PageSize {
        static let count = 20
    }

    @Environment(\.dismissSearch) private var dismissSearch
    @State private var items: [ActivityListItem] = []
    @State private var total = 0
    @State private var hasMore = false
    @State private var isLoadingMore = false
    @State private var state: LoadState = .loading
    @State private var errorMessage = ""
    @State private var searchText = ""
    @State private var searchReloadTask: Task<Void, Never>?

    // 筛选（"" = 不筛选）
    @State private var selectedYear = ""
    @State private var selectedType = ""

    // facets：年份/类型菜单选项（取最近一次响应，保持会话内可用）
    @State private var facetYears: [ActivityYearFacet] = []
    @State private var facetTypes: [ActivityTypeFacet] = []
    // .task 在视图被 NavigationStack 盖住时取消、返回时重新触发；
    // 用标记保证只有首次进入时才拉初始页，返回详情时不重置列表与滚动位置。
    @State private var hasLoadedInitialPage = false

    private var hasActiveFilter: Bool {
        !selectedYear.isEmpty || !selectedType.isEmpty
    }

    private var hasActiveSearch: Bool {
        !trimmedSearchText.isEmpty
    }

    private var filterSignature: String {
        "\(selectedYear)::\(selectedType)"
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink {
                    ActivityArchiveDetailView(item: item)
                } label: {
                    ActivityArchiveRow(item: item)
                }
                .onAppear {
                    // 触底自动加载下一页
                    if item.id == items.last?.id, hasMore, !isLoadingMore {
                        Task { await loadNextPage() }
                    }
                }
            }

            if !items.isEmpty {
                footerRow
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadFirstPage(clearExisting: false)
        }
        .overlay {
            if items.isEmpty {
                stateOverlay
            }
        }
        .navigationTitle("活动记录")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                filterMenu
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "搜索活动名称或地点"
        )
        .modifier(KeepLargeTitleWhileSearching())
        .scrollDismissesKeyboard(.immediately)
        .task {
            guard !hasLoadedInitialPage else { return }
            hasLoadedInitialPage = true
            await loadFirstPage()
        }
        .onChange(of: searchText) { _, _ in
            scheduleSearchReload()
        }
        .onChange(of: filterSignature) { _, _ in
            reloadAfterFilterChange()
        }
    }

    // MARK: - 子视图

    private var filterMenu: some View {
        Menu {
            Picker("年份", selection: $selectedYear) {
                Text("全部年份")
                    .tag("")
                ForEach(facetYears, id: \.year) { facet in
                    Text("\(facet.year)年")
                        .tag(facet.year)
                }
            }
            Divider()
            Picker("类型", selection: $selectedType) {
                Text("全部类型")
                    .tag("")
                ForEach(facetTypes, id: \.type) { facet in
                    Text(ActivityVisual.shortLabel(for: facet.type))
                        .tag(facet.type)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(hasActiveFilter ? Color.accentColor : Color.primary)
        }
        .accessibilityLabel("筛选活动")
        .accessibilityValue(hasActiveFilter ? "已筛选" : "未筛选")
    }

    private var footerRow: some View {
        Group {
            if isLoadingMore {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在加载…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            } else if !hasMore {
                Text("已显示全部 \(total) 个活动")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var stateOverlay: some View {
        switch state {
        case .loading:
            ProgressView("正在加载活动记录…")
        case .error:
            ContentUnavailableView {
                Label("加载失败", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage.isEmpty ? "网络异常，请稍后重试。" : errorMessage)
            } actions: {
                Button("重试") {
                    Task { await loadFirstPage() }
                }
                .buttonStyle(.borderedProminent)
            }
        case .empty:
            if hasActiveSearch {
                ContentUnavailableView {
                    Label("未找到活动", systemImage: "magnifyingglass")
                } description: {
                    Text("没有找到与“\(trimmedSearchText)”匹配的活动，换个关键词试试。")
                } actions: {
                    Button("清除搜索") {
                        searchText = ""
                        dismissSearch()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                ContentUnavailableView {
                    Label("暂无活动", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text(hasActiveFilter ? "该筛选条件下暂无活动记录。" : "活动记录正在整理中。")
                } actions: {
                    if hasActiveFilter {
                        Button("清除筛选") {
                            selectedYear = ""
                            selectedType = ""
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        case .ready:
            Color.clear
        }
    }

    // MARK: - 数据

    private func scheduleSearchReload() {
        searchReloadTask?.cancel()
        searchReloadTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await loadFirstPage()
        }
    }

    private func reloadAfterFilterChange() {
        Task {
            await loadFirstPage()
        }
    }

    private func loadFirstPage(clearExisting: Bool = true) async {
        if clearExisting {
            items = []
            total = 0
            hasMore = false
            isLoadingMore = false
        }
        if items.isEmpty {
            state = .loading
        }

        do {
            let response = try await ActivityArchiveService.shared.fetchList(
                year: selectedYear.isEmpty ? nil : selectedYear,
                type: selectedType.isEmpty ? nil : selectedType,
                q: trimmedSearchText,
                limit: PageSize.count,
                offset: 0
            )
            mergeFacets(response.facets)
            total = response.total
            items = response.items
            hasMore = response.items.count < response.total
            state = response.items.isEmpty ? .empty : .ready
        } catch {
            errorMessage = error.localizedDescription
            // 下拉刷新失败时保留已有列表；首次/筛选加载失败才切到错误态
            if items.isEmpty {
                state = .error
            }
        }
    }

    private func loadNextPage() async {
        guard !isLoadingMore, hasMore, items.count < total else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let response = try await ActivityArchiveService.shared.fetchList(
                year: selectedYear.isEmpty ? nil : selectedYear,
                type: selectedType.isEmpty ? nil : selectedType,
                q: trimmedSearchText,
                limit: PageSize.count,
                offset: items.count
            )
            mergeFacets(response.facets)
            total = response.total

            var seen = Set(items.map(\.id))
            let appended = response.items.filter { seen.insert($0.id).inserted }
            items.append(contentsOf: appended)
            hasMore = items.count < total
        } catch {
            // 触底加载失败：保留已有列表，允许再次上拉重试
        }
    }

    private func mergeFacets(_ facets: ActivityFacets?) {
        if let years = facets?.years, !years.isEmpty {
            // 服务端已倒序；仅在第一页时整体替换即可
            facetYears = years
        }
        if let types = facets?.types, !types.isEmpty {
            facetTypes = types
        }
    }
}

// iOS 17.1+：搜索常驻时仍保留导航栏大标题（17.0 无此 API，保持系统默认）
private struct KeepLargeTitleWhileSearching: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.1, *) {
            content.searchPresentationToolbarBehavior(.avoidHidingContent)
        } else {
            content
        }
    }
}

// MARK: - 列表行

private struct ActivityArchiveRow: View {
    let item: ActivityListItem

    private var metaText: String {
        var parts: [String] = [item.date.activityDisplayDate]
        if !item.place.isEmpty {
            parts.append(item.place)
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ActivityListCover(
                urlString: item.cover.isEmpty ? nil : item.cover,
                type: item.type,
                name: item.name,
                date: item.date
            )
            .frame(width: 76, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(2)

                Text(metaText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    if !item.type.isEmpty {
                        ActivityTypeBadge(type: item.type)
                    }
                    if item.people > 0 {
                        Label("\(item.people) 人", systemImage: "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if item.photoCount > 0 {
                        Label("\(item.photoCount) 张", systemImage: "photo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 2)
    }
}
