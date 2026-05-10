import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.isAuthenticated {
                if store.selectedChild == nil {
                    ChildSetupView()
                } else {
                    MainTabView()
                }
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

                    Text("隐私优先：正式版可只记录系统相册引用，或备份到你授权的云盘；Baby Time 默认不托管儿童照片原文件。")
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

struct ChildSetupView: View {
    @EnvironmentObject private var store: AppStore
    @State private var nickname = "小宝"
    @State private var birthday = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var gender = "未设置"
    @State private var note = ""
    @State private var storageMode: MediaStorageMode = .localReference
    @State private var cloudProvider: CloudProvider = .iCloudDrive

    var body: some View {
        NavigationStack {
            Form {
                Section("隐私说明") {
                    Label("Baby Time 默认不托管儿童照片原文件", systemImage: "lock.shield")
                    Text("你可以只在本机记录系统相册引用，也可以把照片备份到自己授权的云端存储。")
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

                Section("媒体保存方式") {
                    Picker("保存方式", selection: $storageMode) {
                        ForEach(MediaStorageMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    ForEach(MediaStorageMode.allCases) { mode in
                        if mode == storageMode {
                            Text(mode.subtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if storageMode == .userCloudBackup {
                        Picker("云端服务", selection: $cloudProvider) {
                            ForEach(CloudProvider.allCases) { provider in
                                Label(provider.title, systemImage: provider.icon).tag(provider)
                            }
                        }
                        Text("当前 MVP 使用模拟授权状态，后续接入真实云端 Provider SDK。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !store.state.children.isEmpty {
                    Section("已有档案") {
                        ForEach(store.state.children) { child in
                            Button(child.nickname) {
                                store.selectChild(child)
                            }
                        }
                    }
                }
            }
            .navigationTitle("创建孩子档案")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.createChild(nickname: nickname, birthday: birthday, gender: gender, note: note, storageMode: storageMode, cloudProvider: storageMode == .userCloudBackup ? cloudProvider : nil)
                    }
                }
            }
        }
    }
}

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

struct TimelineView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.timeline()) { summary in
                        NavigationLink {
                            TimelineDetailView(bucket: summary.bucket)
                        } label: {
                            HStack(spacing: 14) {
                                PhotoThumb(photo: summary.coverPhoto)
                                    .frame(width: 68, height: 68)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(summary.bucket.rawValue)
                                        .font(.headline)
                                    Text("\(summary.photoCount) 张照片 · \(summary.collectionCount) 个照片集 · \(summary.audioCount) 段声音")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    if let updatedAt = summary.updatedAt {
                                        Text(updatedAt, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(BabyTimeTheme.card, in: RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(BabyTimeTheme.border, lineWidth: 1)
                            }
                            .shadow(color: BabyTimeTheme.teal.opacity(0.08), radius: 8, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .scrollIndicators(.visible)
            .background(BabyTimeTheme.page)
            .navigationTitle(store.selectedChild?.nickname ?? "时间线")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.addSamplePhoto(title: "今日成长")
                    } label: {
                        Label("添加样例照片", systemImage: "plus")
                    }
                }
            }
        }
    }
}

struct TimelineDetailView: View {
    @EnvironmentObject private var store: AppStore
    let bucket: TimelineBucket

    var photos: [MemoryPhoto] {
        guard let child = store.selectedChild else { return [] }
        return store.currentPhotos.filter { AppStore.bucket(for: $0.takenAt, birthday: child.birthday) == bucket }
    }

    var body: some View {
        List {
            Section("照片") {
                ForEach(photos) { photo in
                    NavigationLink {
                        PhotoDetailView(photo: photo)
                    } label: {
                        PhotoRow(photo: photo)
                    }
                }
            }
        }
        .navigationTitle(bucket.rawValue)
    }
}

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
                Section("导入") {
                    Button {
                        store.addSamplePhoto(title: "模拟器照片", note: "用于没有相册素材时快速体验。")
                    } label: {
                        Label("添加样例照片", systemImage: "sparkles")
                    }

                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 20, matching: .images) {
                        Label("从系统相册导入单张或多张", systemImage: "photo.on.rectangle")
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
                    Text("当前导入会保存系统相册引用；若宝宝档案启用云端备份，会模拟创建备份任务。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("保存方式") {
                    if let child = store.selectedChild {
                        LabeledContent("当前宝宝", value: child.defaultMediaStorageMode.title)
                        if let account = store.selectedCloudAccount {
                            LabeledContent("云端服务", value: "\(account.provider.title) · \(account.authorizationStatus.title)")
                        }
                    }
                    Picker("切换方式", selection: Binding(
                        get: { store.selectedChild?.defaultMediaStorageMode ?? .localReference },
                        set: { store.updateSelectedChildStorageMode($0, provider: .iCloudDrive) }
                    )) {
                        ForEach(MediaStorageMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    if store.selectedChild?.defaultMediaStorageMode == .userCloudBackup {
                        Menu {
                            ForEach(CloudProvider.allCases) { provider in
                                Button(provider.title) {
                                    store.updateSelectedChildStorageMode(.userCloudBackup, provider: provider)
                                }
                            }
                        } label: {
                            Label("选择云端服务", systemImage: "cloud")
                        }
                    }
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
                Text(photo.note)
            }
            Section("媒体保存") {
                LabeledContent("保存方式", value: photo.storageMode.title)
                LabeledContent("本机状态", value: photo.localAssetStatus.title)
                if let provider = photo.cloudProvider {
                    LabeledContent("云端服务", value: provider.title)
                    LabeledContent("备份状态", value: photo.cloudSyncStatus.title)
                    if let cloudPath = photo.cloudPath {
                        Text(cloudPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if photo.cloudSyncStatus != .synced {
                        Button {
                            store.startCloudBackup(for: photo.id)
                        } label: {
                            Label("重新备份", systemImage: "arrow.clockwise")
                        }
                    }
                }
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
        if parts[0] == "photo" {
            return (.photo, id)
        }
        if parts[0] == "collection" {
            return (.collection, id)
        }
        return nil
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

struct SearchScreen: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                let results = store.search(query)
                if query.isEmpty {
                    Text("搜索照片备注、照片集标题、tag、分类和音频。")
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

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var tagName = "笑脸"
    @State private var categoryName = "语言发展"

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
                    NavigationLink("新增孩子档案") {
                        ChildSetupView()
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

                Section("隐私与媒体保存") {
                    if let child = store.selectedChild {
                        LabeledContent("当前模式", value: child.defaultMediaStorageMode.title)
                    }
                    if let account = store.selectedCloudAccount {
                        LabeledContent("云端服务", value: "\(account.provider.title) · \(account.authorizationStatus.title)")
                    }
                    Text("照片默认不上传到 Baby Time 后端。本机索引模式只记录系统相册引用；授权云端备份模式会把照片备份到你授权的云端目录。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("我的")
        }
    }
}

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
                    Label(photo.storageMode.title, systemImage: photo.storageMode == .localReference ? "iphone" : "cloud")
                    if photo.localAssetStatus != .available {
                        Text(photo.localAssetStatus.title)
                    } else if photo.storageMode == .userCloudBackup {
                        Text(photo.cloudSyncStatus.title)
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
        .task(id: "\(photo.id)-\(photo.localAssetStatus.rawValue)-\(photo.cloudSyncStatus.rawValue)") {
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
        .task(id: photo.map { "\($0.id)-\($0.localAssetStatus.rawValue)-\($0.cloudSyncStatus.rawValue)" }) {
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
        if photo.cloudSyncStatus == .authExpired {
            return "icloud.slash"
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
