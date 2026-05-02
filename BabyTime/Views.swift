import AVFoundation
import PhotosUI
import SwiftUI

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
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Baby Time")
                        .font(.system(size: 44, weight: .bold))
                    Text("带声音的成长档案")
                        .foregroundStyle(.secondary)
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
                .buttonStyle(.borderedProminent)

                Text("模拟器 MVP 使用本地账号和本地文件存储。后续接入后端后，账号、云同步和对象存储会替换这里的本地实现。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(24)
        }
    }
}

struct ChildSetupView: View {
    @EnvironmentObject private var store: AppStore
    @State private var nickname = "小宝"
    @State private var birthday = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    @State private var gender = "未设置"
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
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
                            .background(.background, in: RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.quaternary, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .scrollIndicators(.visible)
            .background(Color(uiColor: .systemGroupedBackground))
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
    @State private var pickerItem: PhotosPickerItem?
    @State private var collectionTitle = "满月照"
    @State private var selectedPhotoIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                Section("上传") {
                    Button {
                        store.addSamplePhoto(title: "模拟器照片", note: "用于没有相册素材时快速体验。")
                    } label: {
                        Label("添加样例照片", systemImage: "sparkles")
                    }

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("从系统相册导入", systemImage: "photo")
                    }
                    .onChange(of: pickerItem) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                await MainActor.run {
                                    store.importPhoto(data: data, title: "导入照片", note: "")
                                }
                            }
                        }
                    }
                }

                Section("创建照片集") {
                    TextField("照片集标题", text: $collectionTitle)
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
                                    .foregroundStyle(selectedPhotoIDs.contains(photo.id) ? .blue : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Button("保存照片集") {
                        store.createCollection(title: collectionTitle, note: "", photoIDs: Array(selectedPhotoIDs), layoutTemplate: "grid")
                        selectedPhotoIDs.removeAll()
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

    var body: some View {
        List {
            Section {
                if let image = store.image(for: photo) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            Section("信息") {
                LabeledContent("标题", value: photo.title)
                LabeledContent("拍摄时间", value: photo.takenAt.formatted(date: .abbreviated, time: .omitted))
                Text(photo.note)
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

    var photos: [MemoryPhoto] {
        collection.photoIDs.compactMap { id in
            store.state.photos.first { $0.id == id }
        }
    }

    var body: some View {
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
    }
}

struct RecorderView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var recorder = RecorderService()
    @State private var title = "给宝宝的一句话"
    @State private var note = ""
    @State private var kind: AudioKind = .parentMessage
    @State private var bindToCollectionID: UUID?

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
                    Picker("绑定照片集", selection: $bindToCollectionID) {
                        Text("不绑定").tag(UUID?.none)
                        ForEach(store.currentCollections) { collection in
                            Text(collection.title).tag(UUID?.some(collection.id))
                        }
                    }
                }

                if case .finished(let url, let duration) = recorder.state {
                    Section {
                        Button {
                            let target: (AudioTargetType, UUID)? = bindToCollectionID.map { (.collection, $0) }
                            store.saveAudioFile(from: url, title: title, note: note, kind: kind, duration: duration, bindTo: target)
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
        }
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

                Section("云同步状态") {
                    Label("本地 MVP 模式", systemImage: "externaldrive")
                    Text("账号、照片、音频和搜索数据当前保存在模拟器本地。真实上线需要接入 API、PostgreSQL 和对象存储。")
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
            }
        }
    }
}

struct PhotoThumb: View {
    @EnvironmentObject private var store: AppStore
    let photo: MemoryPhoto?

    var body: some View {
        Group {
            if let photo, let image = store.image(for: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle()
                        .fill(.quaternary)
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
        }
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
                }
                Spacer()
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
