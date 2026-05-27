import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Root

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .alert("提示", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("知道了", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .foregroundStyle(BabyTimeTheme.ink)
    }
}

// MARK: - Auth

struct AuthView: View {
    @EnvironmentObject private var store: AppStore
    @State private var email = "parent@example.com"
    @State private var password = "password"
    @State private var displayName = "家长"
    @State private var isRegistering = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
                        Text("Baby Time")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(BabyTimeTheme.ink)
                        Text("带声音的成长档案")
                            .foregroundStyle(BabyTimeTheme.teal)
                    }

                    Picker("模式", selection: $isRegistering) {
                        Text("注册").tag(true)
                        Text("登录").tag(false)
                    }
                    .pickerStyle(.segmented)

                    TextField("邮箱", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)

                    SecureField("密码", text: $password)
                        .textFieldStyle(.roundedBorder)

                    if isRegistering {
                        TextField("称呼", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        if isRegistering {
                            store.register(email: email, password: password, displayName: displayName)
                        } else {
                            store.login(email: email, password: password)
                        }
                    } label: {
                        Label(isRegistering ? "创建账号" : "登录", systemImage: "person.crop.circle.badge.checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryBabyTimeButton())

                    Text("隐私优先：Baby Time 只记录系统相册中照片的引用，不会上传或保存你的照片原文件。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BabyTimeTheme.heroGradient.ignoresSafeArea())
        }
    }
}

// MARK: - Child Setup

struct ChildSetupView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = "小宝"
    @State private var birthday = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var gender = "未设置"
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("隐私说明") {
                    Label("Baby Time 不会上传或保存你的照片", systemImage: "lock.shield")
                    Text("App 只在本机记录系统相册中照片的引用与节点关联关系。照片原文件始终在你自己手机的相册中。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("孩子档案") {
                    TextField("昵称", text: $nickname)
                    DatePicker("生日", selection: $birthday, displayedComponents: .date)
                    Picker("性别", selection: $gender) {
                        Text("未设置").tag("未设置")
                        Text("男孩").tag("男孩")
                        Text("女孩").tag("女孩")
                    }
                    TextField("备注", text: $note, axis: .vertical)
                }

                if !store.state.children.isEmpty {
                    Section("已有档案") {
                        ForEach(store.state.children) { child in
                            Button(child.nickname) {
                                store.selectChild(child)
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle("创建孩子档案")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.createChild(nickname: nickname, birthday: birthday, gender: gender, note: note)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Tabs

struct MainTabView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            TimelineView()
                .tabItem { Label(AppTab.timeline.title, systemImage: AppTab.timeline.icon) }
                .tag(AppTab.timeline)
            AlbumView()
                .tabItem { Label(AppTab.album.title, systemImage: AppTab.album.icon) }
                .tag(AppTab.album)
            RecorderView()
                .tabItem { Label(AppTab.recorder.title, systemImage: AppTab.recorder.icon) }
                .tag(AppTab.recorder)
            SearchScreen()
                .tabItem { Label(AppTab.search.title, systemImage: AppTab.search.icon) }
                .tag(AppTab.search)
            SettingsView()
                .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.icon) }
                .tag(AppTab.settings)
        }
        .tint(BabyTimeTheme.coral)
    }
}

// MARK: - Timeline (首页)

struct TimelineView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showAddNode = false
    @State private var showChildSetup = false

    var body: some View {
        NavigationStack {
            Group {
                if !store.hasSelectedChild {
                    emptyChildHint
                } else {
                    timelineList
                }
            }
            .background(BabyTimeTheme.page)
            .navigationTitle(store.selectedChild?.nickname ?? "时间线")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if store.hasSelectedChild {
                        Button {
                            showAddNode = true
                        } label: {
                            Label("新增时间节点", systemImage: "plus.circle")
                        }
                        .accessibilityIdentifier("addTimelineNodeButton")
                    }
                }
            }
            .sheet(isPresented: $showAddNode) {
                AddTimelineNodeSheet()
            }
            .sheet(isPresented: $showChildSetup) {
                ChildSetupView()
            }
        }
    }

    private var emptyChildHint: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(BabyTimeTheme.teal)
            Text("先创建一个孩子档案")
                .font(.headline)
            Text("创建后会自动生成出生第一天到一周岁的成长时间节点。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                showChildSetup = true
            } label: {
                Label("创建孩子档案", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryBabyTimeButton())
            .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var timelineList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(store.timelineSummaries()) { summary in
                    NavigationLink {
                        TimelineNodeDetailView(node: summary.node)
                    } label: {
                        TimelineNodeCard(summary: summary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("timelineNodeRow-\(summary.node.id.uuidString)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.visible)
    }
}

struct TimelineNodeCard: View {
    let summary: TimelineNodeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.node.name)
                        .font(.headline)
                        .foregroundStyle(BabyTimeTheme.ink)
                    Text(summary.node.date.formatted(date: .long, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if summary.audioCount > 0 {
                    Label("\(summary.audioCount)", systemImage: "waveform")
                        .font(.caption)
                        .foregroundStyle(BabyTimeTheme.teal)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            if summary.totalPhotoCount == 0 {
                emptyPlaceholder
            } else {
                previewRow
                if summary.totalPhotoCount > 3 {
                    Text("共 \(summary.totalPhotoCount) 张照片")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(BabyTimeTheme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(BabyTimeTheme.border, lineWidth: 1)
        }
        .shadow(color: BabyTimeTheme.teal.opacity(0.08), radius: 8, y: 3)
    }

    private var emptyPlaceholder: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.dashed")
                .font(.title2)
                .foregroundStyle(BabyTimeTheme.teal)
            VStack(alignment: .leading, spacing: 2) {
                Text("去添加")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BabyTimeTheme.ink)
                Text("还没有记录，点击为这个节点添加照片或录音")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BabyTimeTheme.tealSoft.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }

    private var previewRow: some View {
        HStack(spacing: 8) {
            ForEach(summary.previewPhotos) { photo in
                PhotoThumb(photo: photo)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            // 不足 3 张时补占位，保持视觉对齐。
            ForEach(0..<max(0, 3 - summary.previewPhotos.count), id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .fill(BabyTimeTheme.tealSoft.opacity(0.25))
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }
}

// MARK: - 新增时间节点弹窗

struct AddTimelineNodeSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var date: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("节点信息") {
                    TextField("名称（例如：抓周）", text: $name)
                        .accessibilityIdentifier("nodeNameField")
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }

                Section {
                    Text("新增的节点会自动按时间正确插入到已有时间线中。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("新增时间节点")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        if store.addTimelineNode(name: name, date: date) != nil {
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("confirmAddNodeButton")
                }
            }
        }
    }
}

// MARK: - 时间节点详情页

struct TimelineNodeDetailView: View {
    @EnvironmentObject private var store: AppStore
    let node: TimelineNode

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var deletingPhotoID: UUID?
    @State private var fullscreenPhoto: MemoryPhoto?
    @State private var enabledRemoveMode: Bool = false

    private var currentNode: TimelineNode {
        store.state.nodes.first { $0.id == node.id } ?? node
    }

    private var photos: [MemoryPhoto] {
        store.photos(forNode: node.id)
    }

    private var nodeAudios: [AudioMemory] {
        store.audios(forNode: node.id)
    }

    var body: some View {
        List {
            Section("节点信息") {
                LabeledContent("名称", value: currentNode.name)
                LabeledContent("时间", value: currentNode.date.formatted(date: .long, time: .omitted))
                if currentNode.isDefault {
                    Label("系统默认节点", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                PhotosPicker(selection: $pickerItems, maxSelectionCount: 20, matching: .images) {
                    Label("从系统相册添加照片", systemImage: "photo.on.rectangle")
                }
                .onChange(of: pickerItems) { _, newItems in
                    guard !newItems.isEmpty else { return }
                    for (offset, item) in newItems.enumerated() {
                        if let identifier = item.itemIdentifier {
                            store.importPhoto(
                                assetIdentifier: identifier,
                                title: newItems.count == 1 ? currentNode.name : "\(currentNode.name) \(offset + 1)",
                                note: "",
                                nodeID: currentNode.id
                            )
                        }
                    }
                    pickerItems.removeAll()
                }
                Button {
                    store.addSamplePhoto(title: currentNode.name, note: "节点 \(currentNode.name) 的样例照片", date: currentNode.date, nodeID: currentNode.id)
                } label: {
                    Label("添加样例照片（仅模拟器）", systemImage: "sparkles")
                }
            } header: {
                Text("添加照片")
            } footer: {
                Text("Baby Time 不会保存或上传你的照片，仅在本机记录它在系统相册中的位置。")
            }

            if photos.isEmpty {
                Section("照片集") {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title)
                                .foregroundStyle(BabyTimeTheme.teal)
                            Text("还没有照片，从上方添加吧")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
            } else {
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(photos) { photo in
                            DeletableNodePhotoCell(
                                photo: photo,
                                removeMode: enabledRemoveMode,
                                onTap: {
                                    if enabledRemoveMode {
                                        deletingPhotoID = photo.id
                                    } else {
                                        fullscreenPhoto = photo
                                    }
                                },
                                onLongPress: {
                                    withAnimation {
                                        enabledRemoveMode = true
                                    }
                                },
                                onRemove: {
                                    deletingPhotoID = photo.id
                                }
                            )
                        }
                    }
                    if enabledRemoveMode {
                        Button {
                            withAnimation { enabledRemoveMode = false }
                        } label: {
                            Label("完成", systemImage: "checkmark.circle")
                        }
                    }
                } header: {
                    HStack {
                        Text("照片集（\(photos.count)）")
                        Spacer()
                        if enabledRemoveMode {
                            Text("点击照片上的叉可解除关联")
                                .font(.caption2)
                                .foregroundStyle(BabyTimeTheme.coral)
                        }
                    }
                } footer: {
                    Text("长按任一张照片可进入解除关联模式。点击照片可查看大图。")
                }
            }

            Section("音频") {
                if nodeAudios.isEmpty {
                    Text("暂无音频，可在录音页录制并绑定到本节点。")
                        .foregroundStyle(.secondary)
                } else {
                    AudioList(audios: nodeAudios)
                }
            }
        }
        .navigationTitle(currentNode.name)
        .sheet(item: $fullscreenPhoto) { photo in
            PhotoFullscreenViewer(photo: photo)
        }
        .alert(
            "确认解除关联？",
            isPresented: Binding(
                get: { deletingPhotoID != nil },
                set: { if !$0 { deletingPhotoID = nil } }
            )
        ) {
            Button("取消", role: .cancel) { deletingPhotoID = nil }
            Button("确定", role: .destructive) {
                if let id = deletingPhotoID {
                    store.removePhotoFromNode(photoID: id, nodeID: currentNode.id)
                }
                deletingPhotoID = nil
            }
        } message: {
            Text("此操作只会移除当前节点与该照片的关联关系，不会删除你系统相册中的原始照片。")
        }
    }
}

/// 节点详情中的照片单元：支持点击查看大图、长按进入删除模式、删除模式下右上角显示叉。
struct DeletableNodePhotoCell: View {
    let photo: MemoryPhoto
    let removeMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PhotoThumb(photo: photo)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    onTap()
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    onLongPress()
                }
                .overlay {
                    if removeMode {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(BabyTimeTheme.coral, lineWidth: 2)
                    }
                }

            if removeMode {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, BabyTimeTheme.coral)
                        .font(.title3)
                        .padding(4)
                }
                .accessibilityIdentifier("removePhotoButton-\(photo.id.uuidString)")
                .offset(x: 6, y: -6)
            }
        }
    }
}

/// 简单的全屏看图。
struct PhotoFullscreenViewer: View {
    @Environment(\.dismiss) private var dismiss
    let photo: MemoryPhoto

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                PhotoFullImage(photo: photo)
                    .padding()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Album

struct AlbumView: View {
    @EnvironmentObject private var store: AppStore
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var collectionTitle = "满月照"
    @State private var collectionNote = ""
    @State private var collectionTemplate = "grid"
    @State private var selectedPhotoIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        store.addSamplePhoto(title: "模拟器照片", note: "用于没有相册素材时快速体验。")
                    } label: {
                        Label("添加样例照片", systemImage: "sparkles")
                    }

                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 20, matching: .images) {
                        Label("从系统相册导入", systemImage: "photo.on.rectangle")
                    }
                    .onChange(of: pickerItems) { _, newItems in
                        guard !newItems.isEmpty else { return }
                        var importedCount = 0
                        for (offset, item) in newItems.enumerated() {
                            if let identifier = item.itemIdentifier {
                                store.importPhoto(assetIdentifier: identifier, title: newItems.count == 1 ? "导入照片" : "导入照片 \(offset + 1)", note: "")
                                importedCount += 1
                            }
                        }
                        pickerItems.removeAll()
                        if importedCount == 0 {
                            store.errorMessage = "系统未返回相册资产标识，无法按本机索引导入。"
                        }
                    }
                } header: {
                    Text("导入")
                } footer: {
                    Text("App 只在本机记录照片在系统相册中的引用，照片原文件不会被上传或复制。导入时会自动归属到最匹配的时间节点。")
                }

                Section("创建照片集") {
                    TextField("照片集标题", text: $collectionTitle)
                    TextField("照片集备注", text: $collectionNote, axis: .vertical)
                    Picker("模板", selection: $collectionTemplate) {
                        Text("网格").tag("grid")
                        Text("封面大图").tag("cover")
                        Text("时间顺序").tag("timeline")
                    }
                    ForEach(store.currentPhotos) { photo in
                        Button {
                            if selectedPhotoIDs.contains(photo.id) {
                                selectedPhotoIDs.remove(photo.id)
                            } else {
                                selectedPhotoIDs.insert(photo.id)
                            }
                        } label: {
                            HStack {
                                PhotoRow(photo: photo)
                                Spacer()
                                Image(systemName: selectedPhotoIDs.contains(photo.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedPhotoIDs.contains(photo.id) ? BabyTimeTheme.coral : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Button("保存照片集") {
                        store.createCollection(title: collectionTitle, note: collectionNote, photoIDs: Array(selectedPhotoIDs), layoutTemplate: collectionTemplate)
                        selectedPhotoIDs.removeAll()
                        collectionNote = ""
                    }
                    .disabled(selectedPhotoIDs.isEmpty)
                }

                Section("照片") {
                    ForEach(store.currentPhotos) { photo in
                        NavigationLink {
                            PhotoDetailView(photo: photo)
                        } label: {
                            PhotoRow(photo: photo)
                        }
                    }
                }

                Section("照片集") {
                    ForEach(store.currentCollections) { collection in
                        NavigationLink {
                            CollectionDetailView(collection: collection)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(collection.title)
                                    .font(.headline)
                                Text("\(collection.photoIDs.count) 张照片 · 模板 \(collection.layoutTemplate)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("相册")
        }
    }
}

struct PhotoDetailView: View {
    @EnvironmentObject private var store: AppStore
    let photo: MemoryPhoto

    var currentPhoto: MemoryPhoto {
        store.state.photos.first { $0.id == photo.id } ?? photo
    }

    var body: some View {
        let photo = currentPhoto
        List {
            Section {
                PhotoFullImage(photo: photo)
            }
            Section("信息") {
                LabeledContent("标题", value: photo.title)
                LabeledContent("拍摄时间", value: photo.takenAt.formatted(date: .abbreviated, time: .omitted))
                if let nodeID = photo.nodeID,
                   let node = store.state.nodes.first(where: { $0.id == nodeID }) {
                    LabeledContent("所属节点", value: node.name)
                }
                Text(photo.note)
            }
            Section("本机状态") {
                LabeledContent("状态", value: photo.localAssetStatus.title)
                Menu {
                    Button("标记原照片不存在") {
                        store.markLocalAssetStatus(photoID: photo.id, status: .missing)
                    }
                    Button("标记相册权限失效") {
                        store.markLocalAssetStatus(photoID: photo.id, status: .permissionDenied)
                    }
                    Button("恢复为可用") {
                        store.markLocalAssetStatus(photoID: photo.id, status: .available)
                    }
                } label: {
                    Label("模拟本机状态", systemImage: "wrench.and.screwdriver")
                }
            }
            TaxonomyPicker(photo: photo)
            Section("绑定音频") {
                let audios = store.audios(for: .photo, targetID: photo.id)
                if audios.isEmpty {
                    Text("暂无绑定音频")
                        .foregroundStyle(.secondary)
                } else {
                    AudioList(audios: audios)
                }
            }
        }
        .navigationTitle(photo.title.isEmpty ? "照片详情" : photo.title)
    }
}

struct CollectionDetailView: View {
    @EnvironmentObject private var store: AppStore
    let collection: PhotoCollection
    @State private var title = ""
    @State private var note = ""
    @State private var layoutTemplate = "grid"
    @State private var coverPhotoID: UUID?

    var currentCollection: PhotoCollection {
        store.state.collections.first { $0.id == collection.id } ?? collection
    }

    var photos: [MemoryPhoto] {
        currentCollection.photoIDs.compactMap { id in
            store.state.photos.first { $0.id == id }
        }
    }

    var body: some View {
        let collection = currentCollection
        List {
            Section("照片") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                    ForEach(photos) { photo in
                        PhotoThumb(photo: photo)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            Section("信息") {
                LabeledContent("模板", value: collection.layoutTemplate)
                Text(collection.note.isEmpty ? "暂无备注" : collection.note)
                    .foregroundStyle(collection.note.isEmpty ? .secondary : .primary)
            }
            Section("编辑照片集") {
                TextField("标题", text: $title)
                TextField("备注", text: $note, axis: .vertical)
                Picker("模板", selection: $layoutTemplate) {
                    Text("网格").tag("grid")
                    Text("封面大图").tag("cover")
                    Text("时间顺序").tag("timeline")
                }
                Picker("封面", selection: $coverPhotoID) {
                    Text("默认第一张").tag(UUID?.none)
                    ForEach(photos) { photo in
                        Text(photo.title.isEmpty ? "照片" : photo.title).tag(UUID?.some(photo.id))
                    }
                }
                Button {
                    store.updateCollection(collection, title: title, note: note, layoutTemplate: layoutTemplate, coverPhotoID: coverPhotoID)
                } label: {
                    Label("保存照片集信息", systemImage: "square.and.arrow.down")
                }
            }
            CollectionTaxonomyPicker(collection: collection)
            Section("绑定音频") {
                let audios = store.audios(for: .collection, targetID: collection.id)
                if audios.isEmpty {
                    Text("暂无绑定音频，可在录音页保存时选择绑定照片集。")
                        .foregroundStyle(.secondary)
                } else {
                    AudioList(audios: audios)
                }
            }
        }
        .navigationTitle(collection.title)
        .onAppear {
            title = collection.title
            note = collection.note
            layoutTemplate = collection.layoutTemplate
            coverPhotoID = collection.coverPhotoID
        }
    }
}

// MARK: - Recorder

struct RecorderView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var recorder = RecorderService()
    @State private var title = "给宝宝的一句话"
    @State private var note = ""
    @State private var kind: AudioKind = .parentMessage
    @State private var bindTarget = "none"
    @State private var isImportingAudio = false

    var body: some View {
        NavigationStack {
            List {
                Section("录音") {
                    HStack {
                        Text(recorder.elapsed.formattedDuration)
                            .font(.title2.monospacedDigit())
                        Spacer()
                        controls
                    }
                }

                Section("保存信息") {
                    TextField("音频标题", text: $title)
                    TextField("备注", text: $note, axis: .vertical)
                    Picker("类型", selection: $kind) {
                        ForEach(AudioKind.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    Picker("绑定对象", selection: $bindTarget) {
                        Text("不绑定").tag("none")
                        if !store.currentNodes.isEmpty {
                            Section("时间节点") {
                                ForEach(store.currentNodes) { node in
                                    Text(node.name).tag("node:\(node.id.uuidString)")
                                }
                            }
                        }
                        if !store.currentPhotos.isEmpty {
                            Section("照片") {
                                ForEach(store.currentPhotos) { photo in
                                    Text(photo.title.isEmpty ? "照片" : photo.title).tag("photo:\(photo.id.uuidString)")
                                }
                            }
                        }
                        if !store.currentCollections.isEmpty {
                            Section("照片集") {
                                ForEach(store.currentCollections) { collection in
                                    Text(collection.title).tag("collection:\(collection.id.uuidString)")
                                }
                            }
                        }
                    }
                }

                Section("导入音频") {
                    Button {
                        isImportingAudio = true
                    } label: {
                        Label("导入本地音频文件", systemImage: "waveform.badge.plus")
                    }
                    Text("导入的音频会复制到 App 本地 Documents 目录，并写入本地 JSON 索引。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if case .finished(let url, let duration) = recorder.state {
                    Section {
                        Button {
                            store.saveAudioFile(from: url, title: title, note: note, kind: kind, duration: duration, bindTo: selectedAudioTarget())
                            recorder.reset()
                        } label: {
                            Label("保存录音", systemImage: "square.and.arrow.down")
                        }
                    }
                }

                Section("声音记录") {
                    AudioList(audios: store.currentAudios)
                }
            }
            .navigationTitle("录音")
            .fileImporter(isPresented: $isImportingAudio, allowedContentTypes: [.audio]) { result in
                guard case .success(let url) = result else { return }
                Task {
                    let didStart = url.startAccessingSecurityScopedResource()
                    defer {
                        if didStart {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    store.saveAudioFile(from: url, title: title, note: note, kind: kind, duration: await audioDuration(for: url), bindTo: selectedAudioTarget())
                }
            }
        }
    }

    private func selectedAudioTarget() -> (AudioTargetType, UUID)? {
        let parts = bindTarget.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let id = UUID(uuidString: parts[1]) else { return nil }
        switch parts[0] {
        case "photo": return (.photo, id)
        case "collection": return (.collection, id)
        case "node": return (.node, id)
        default: return nil
        }
    }

    private func audioDuration(for url: URL) async -> TimeInterval {
        let seconds = (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0
        return seconds.isFinite ? seconds : 0
    }

    @ViewBuilder
    private var controls: some View {
        switch recorder.state {
        case .idle, .failed:
            Button {
                Task { await recorder.start() }
            } label: {
                Image(systemName: "record.circle")
                    .font(.title)
            }
        case .recording:
            Button { recorder.pause() } label: { Image(systemName: "pause.circle").font(.title) }
            Button { recorder.stop() } label: { Image(systemName: "stop.circle").font(.title) }
        case .paused:
            Button { recorder.resume() } label: { Image(systemName: "play.circle").font(.title) }
            Button { recorder.stop() } label: { Image(systemName: "stop.circle").font(.title) }
        case .finished:
            Button { recorder.reset() } label: { Image(systemName: "arrow.counterclockwise.circle").font(.title) }
        }
    }
}

// MARK: - Search

struct SearchScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                let results = store.search(query)
                if query.isEmpty {
                    Text("搜索时间节点、照片备注、照片集标题、tag、分类和音频。")
                        .foregroundStyle(.secondary)
                } else if results.isEmpty {
                    Text("没有找到相关内容")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(results) { result in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(result.title)
                                    .font(.headline)
                                Text(result.typeLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("搜索")
            .searchable(text: $query, prompt: "笑脸、生日、父母留言")
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var tagName = "笑脸"
    @State private var categoryName = "语言发展"
    @State private var showChildSetup = false

    var body: some View {
        NavigationStack {
            List {
                Section("账号") {
                    LabeledContent("当前账号", value: store.activeAccount?.email ?? "")
                    Button("退出登录", role: .destructive) {
                        store.logout()
                    }
                }

                Section("孩子档案") {
                    ForEach(store.state.children) { child in
                        Button {
                            store.selectChild(child)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(child.nickname)
                                    Text(child.birthday, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if child.id == store.selectedChild?.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Button {
                        showChildSetup = true
                    } label: {
                        Label("新增孩子档案", systemImage: "plus")
                    }
                }

                Section("Tag 管理") {
                    HStack {
                        TextField("Tag 名称", text: $tagName)
                        Button("添加") {
                            store.addTag(name: tagName)
                            tagName = ""
                        }
                    }
                    ForEach(store.state.tags) { tag in
                        Text("#\(tag.name)")
                    }
                }

                Section("分类管理") {
                    HStack {
                        TextField("分类名称", text: $categoryName)
                        Button("添加") {
                            store.addCategory(name: categoryName)
                            categoryName = ""
                        }
                    }
                    ForEach(store.state.categories) { category in
                        Label(category.name, systemImage: category.icon)
                    }
                }

                Section {
                    Text("Baby Time 不会上传或保存你的照片。App 中保存的只是系统相册中照片的引用以及节点关联关系。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("隐私")
                }
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showChildSetup) {
                ChildSetupView()
            }
        }
    }
}

// MARK: - Reusable components

struct TaxonomyPicker: View {
    @EnvironmentObject private var store: AppStore
    let photo: MemoryPhoto

    var body: some View {
        Section("Tag") {
            ForEach(store.state.tags) { tag in
                Button("#\(tag.name)") {
                    store.attach(tagID: tag.id, toPhoto: photo.id)
                }
            }
        }
        Section("分类") {
            ForEach(store.state.categories) { category in
                Button {
                    store.attach(categoryID: category.id, toPhoto: photo.id)
                } label: {
                    Label(category.name, systemImage: category.icon)
                }
            }
        }
    }
}

struct CollectionTaxonomyPicker: View {
    @EnvironmentObject private var store: AppStore
    let collection: PhotoCollection

    var body: some View {
        Section("Tag") {
            ForEach(store.state.tags) { tag in
                Button("#\(tag.name)") {
                    store.attach(tagID: tag.id, toCollection: collection.id)
                }
            }
        }
        Section("分类") {
            ForEach(store.state.categories) { category in
                Button {
                    store.attach(categoryID: category.id, toCollection: collection.id)
                } label: {
                    Label(category.name, systemImage: category.icon)
                }
            }
        }
    }
}

struct PhotoRow: View {
    @EnvironmentObject private var store: AppStore
    let photo: MemoryPhoto

    var body: some View {
        HStack(spacing: 12) {
            PhotoThumb(photo: photo)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(photo.title.isEmpty ? "照片" : photo.title)
                    .font(.headline)
                Text(photo.note.isEmpty ? photo.takenAt.formatted(date: .abbreviated, time: .omitted) : photo.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Label("本机相册", systemImage: "iphone")
                    if photo.localAssetStatus != .available {
                        Text(photo.localAssetStatus.title)
                    }
                }
                .font(.caption2)
                .foregroundStyle(photo.localAssetStatus == .available ? .secondary : BabyTimeTheme.coral)
            }
        }
    }
}

struct PhotoFullImage: View {
    @EnvironmentObject private var store: AppStore
    let photo: MemoryPhoto
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                PhotoMissingPlaceholder(photo: photo)
                    .frame(maxWidth: .infinity, minHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .task(id: "\(photo.id)-\(photo.localAssetStatus.rawValue)") {
            image = nil
            image = await store.requestImage(for: photo, targetSize: CGSize(width: 1100, height: 1100))
        }
    }
}

struct PhotoThumb: View {
    @EnvironmentObject private var store: AppStore
    let photo: MemoryPhoto?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let photo {
                PhotoMissingPlaceholder(photo: photo)
            } else {
                PhotoMissingPlaceholder(photo: nil)
            }
        }
        .task(id: photo.map { "\($0.id)-\($0.localAssetStatus.rawValue)" }) {
            guard let photo else {
                image = nil
                return
            }
            image = nil
            image = await store.requestImage(for: photo, targetSize: CGSize(width: 220, height: 220))
        }
    }
}

struct PhotoMissingPlaceholder: View {
    let photo: MemoryPhoto?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(BabyTimeTheme.tealSoft.opacity(0.45))
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(BabyTimeTheme.teal)
                if let photo, photo.localAssetStatus != .available {
                    Text(photo.localAssetStatus.title)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
        }
    }

    private var icon: String {
        guard let photo else { return "photo" }
        if photo.localAssetStatus != .available {
            return "photo.badge.exclamationmark"
        }
        return "photo"
    }
}

struct AudioList: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var player = AudioPlayerService()
    let audios: [AudioMemory]

    var body: some View {
        ForEach(audios) { audio in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(audio.title)
                    Text("\(audio.kind.rawValue) · \(audio.duration.formattedDuration)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let tags = store.state.tags.filter { audio.tagIDs.contains($0.id) }
                    if !tags.isEmpty {
                        Text(tags.map { "#\($0.name)" }.joined(separator: " "))
                            .font(.caption2)
                            .foregroundStyle(BabyTimeTheme.teal)
                    }
                }
                Spacer()
                if !store.state.tags.isEmpty {
                    Menu {
                        ForEach(store.state.tags) { tag in
                            Button("#\(tag.name)") {
                                store.attach(tagID: tag.id, toAudio: audio.id)
                            }
                        }
                    } label: {
                        Image(systemName: "tag")
                            .font(.title3)
                    }
                }
                Button {
                    player.play(url: store.audioURL(for: audio))
                } label: {
                    Image(systemName: "play.circle")
                        .font(.title3)
                }
            }
        }
    }
}

extension TimeInterval {
    var formattedDuration: String {
        let total = Int(self.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
