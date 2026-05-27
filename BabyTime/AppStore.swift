import Foundation
import Photos
import SwiftUI
import UIKit

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var state: PersistedState
    @Published var selectedTab: AppTab = .timeline
    @Published var errorMessage: String?

    private let storageURL: URL
    private let mediaDirectory: URL

    init(storageURL: URL? = nil) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.storageURL = storageURL ?? documents.appendingPathComponent("babytime_store.json")
        self.mediaDirectory = documents.appendingPathComponent("BabyTimeMedia", isDirectory: true)
        self.state = Self.load(from: self.storageURL)
        try? FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Derived state

    var isAuthenticated: Bool { state.activeEmail != nil }
    var activeAccount: Account? { state.accounts.first { $0.email == state.activeEmail } }
    var selectedChild: ChildProfile? { state.children.first { $0.id == state.selectedChildID } }
    var hasSelectedChild: Bool { selectedChild != nil }

    var currentPhotos: [MemoryPhoto] {
        guard let childID = state.selectedChildID else { return [] }
        return state.photos.filter { $0.childID == childID }.sorted { $0.takenAt > $1.takenAt }
    }

    var currentCollections: [PhotoCollection] {
        guard let childID = state.selectedChildID else { return [] }
        return state.collections.filter { $0.childID == childID }.sorted { $0.createdAt > $1.createdAt }
    }

    var currentAudios: [AudioMemory] {
        guard let childID = state.selectedChildID else { return [] }
        return state.audios.filter { $0.childID == childID }.sorted { $0.createdAt > $1.createdAt }
    }

    /// 当前孩子的所有时间线节点，按时间正序（早 → 晚）。
    var currentNodes: [TimelineNode] {
        guard let childID = state.selectedChildID else { return [] }
        return state.nodes.filter { $0.childID == childID }.sorted { $0.date < $1.date }
    }

    // MARK: - Auth

    func register(email: String, password: String, displayName: String) {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.contains("@"), password.count >= 6 else {
            errorMessage = "请输入有效邮箱，密码至少 6 位。"
            return
        }
        guard !state.accounts.contains(where: { $0.email == normalized }) else {
            errorMessage = "该邮箱已注册。"
            return
        }
        state.accounts.append(Account(email: normalized, displayName: displayName.isEmpty ? "家长" : displayName, password: password))
        state.activeEmail = normalized
        // 登录完成后默认回到首页 Tab。
        selectedTab = .timeline
        save()
    }

    func login(email: String, password: String) {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let account = state.accounts.first(where: { $0.email == normalized && $0.password == password }) else {
            errorMessage = "邮箱或密码错误。"
            return
        }
        state.activeEmail = account.email
        // 登录完成后默认回到首页 Tab。
        selectedTab = .timeline
        save()
    }

    func logout() {
        state.activeEmail = nil
        save()
    }

    // MARK: - Child profile

    func createChild(nickname: String, birthday: Date, gender: String, note: String) {
        let child = ChildProfile(
            nickname: nickname.isEmpty ? "宝宝" : nickname,
            birthday: birthday,
            gender: gender,
            note: note
        )
        state.children.append(child)
        state.selectedChildID = child.id
        // 创建孩子档案后自动生成预设时间节点。
        let presets = TimelineNode.defaultNodes(for: child)
        state.nodes.append(contentsOf: presets)
        save()
    }

    func selectChild(_ child: ChildProfile) {
        state.selectedChildID = child.id
        save()
    }

    func updateChild(_ child: ChildProfile) {
        replace(&state.children, child)
        save()
    }

    // MARK: - Timeline nodes

    /// 新增一个时间节点。重名或同一天同名时不会重复创建。
    @discardableResult
    func addTimelineNode(name: String, date: Date) -> TimelineNode? {
        guard let childID = state.selectedChildID else {
            errorMessage = "请先创建孩子档案。"
            return nil
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "请填写节点名称。"
            return nil
        }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        if let existing = state.nodes.first(where: {
            $0.childID == childID
            && $0.name == trimmed
            && calendar.isDate($0.date, inSameDayAs: dayStart)
        }) {
            errorMessage = "已存在同名节点。"
            return existing
        }
        let node = TimelineNode(childID: childID, name: trimmed, date: date, isDefault: false)
        state.nodes.append(node)
        save()
        return node
    }

    func updateTimelineNode(_ node: TimelineNode, name: String, date: Date) {
        guard let index = state.nodes.firstIndex(where: { $0.id == node.id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        state.nodes[index].name = trimmed.isEmpty ? state.nodes[index].name : trimmed
        state.nodes[index].date = date
        save()
    }

    /// 删除一个时间节点。与该节点关联的照片/音频不会被删除，只会把 nodeID 置空。
    func deleteTimelineNode(_ node: TimelineNode) {
        state.nodes.removeAll { $0.id == node.id }
        for index in state.photos.indices where state.photos[index].nodeID == node.id {
            state.photos[index].nodeID = nil
        }
        for index in state.audios.indices where state.audios[index].nodeID == node.id {
            state.audios[index].nodeID = nil
        }
        save()
    }

    func photos(forNode nodeID: UUID) -> [MemoryPhoto] {
        state.photos
            .filter { $0.nodeID == nodeID }
            .sorted { $0.takenAt < $1.takenAt }
    }

    func audios(forNode nodeID: UUID) -> [AudioMemory] {
        state.audios
            .filter { $0.nodeID == nodeID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// 解除照片与节点的关联（不会删除照片记录本身，也不会删除系统相册原图）。
    func removePhotoFromNode(photoID: UUID, nodeID: UUID) {
        guard let index = state.photos.firstIndex(where: { $0.id == photoID }) else { return }
        guard state.photos[index].nodeID == nodeID else { return }
        state.photos[index].nodeID = nil
        save()
    }

    /// 把已有的照片挂到某个节点上（如导入时未自动归属，可后续手动指定）。
    func attachPhoto(photoID: UUID, toNode nodeID: UUID) {
        guard let index = state.photos.firstIndex(where: { $0.id == photoID }) else { return }
        state.photos[index].nodeID = nodeID
        save()
    }

    func attachAudio(audioID: UUID, toNode nodeID: UUID) {
        guard let index = state.audios.firstIndex(where: { $0.id == audioID }) else { return }
        state.audios[index].nodeID = nodeID
        save()
    }

    /// 时间线首页聚合：每个节点 + 前 3 张照片 + 总数 + 音频数。
    func timelineSummaries() -> [TimelineNodeSummary] {
        currentNodes.map { node in
            let nodePhotos = photos(forNode: node.id)
            let preview = Array(nodePhotos.prefix(3))
            let nodeAudios = audios(forNode: node.id)
            let latest = (nodePhotos.map(\.createdAt) + nodeAudios.map(\.createdAt)).max()
            return TimelineNodeSummary(
                node: node,
                previewPhotos: preview,
                totalPhotoCount: nodePhotos.count,
                audioCount: nodeAudios.count,
                updatedAt: latest
            )
        }
    }

    /// 根据日期匹配最合适的节点：取该日期 ≤ 节点日期且差值最小的节点；
    /// 若所有节点都在该日期之前，则取最晚的一个节点（兜底）。
    func bestNode(for date: Date) -> TimelineNode? {
        let nodes = currentNodes
        guard !nodes.isEmpty else { return nil }
        let later = nodes.filter { $0.date >= Calendar.current.startOfDay(for: date) }
        if let first = later.first { return first }
        return nodes.last
    }

    // MARK: - Tags & categories

    func addTag(name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        guard !state.tags.contains(where: { $0.name.caseInsensitiveCompare(clean) == .orderedSame }) else {
            errorMessage = "Tag 已存在。"
            return
        }
        state.tags.append(MemoryTag(name: clean, colorName: "blue"))
        save()
    }

    func addCategory(name: String, icon: String = "folder") {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        state.categories.append(MemoryCategory(name: clean, icon: icon, isSystem: false))
        save()
    }

    // MARK: - Photos

    /// 模拟器场景下生成一张样例照片，并自动按当前日期归属到最匹配的节点。
    @discardableResult
    func addSamplePhoto(title: String = "成长照片", note: String = "一张模拟器样例照片", date: Date = Date(), nodeID: UUID? = nil) -> MemoryPhoto? {
        guard let childID = state.selectedChildID else {
            errorMessage = "请先创建孩子档案。"
            return nil
        }
        let filename = "photo-\(UUID().uuidString).png"
        let url = mediaDirectory.appendingPathComponent(filename)
        let image = Self.sampleImage(title: title)
        if let data = image.pngData() {
            try? data.write(to: url)
        }
        let resolvedNodeID = nodeID ?? bestNode(for: date)?.id
        let photo = MemoryPhoto(
            childID: childID,
            nodeID: resolvedNodeID,
            title: title,
            note: note,
            filename: filename,
            localAssetIdentifier: nil,
            localAssetStatus: .available,
            takenAt: date
        )
        state.photos.append(photo)
        save()
        return photo
    }

    /// 从系统相册导入：只记录资产引用，不复制原文件。
    @discardableResult
    func importPhoto(assetIdentifier: String, title: String, note: String, nodeID: UUID? = nil) -> MemoryPhoto? {
        guard let childID = state.selectedChildID else { return nil }
        let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject
        let takenAt = asset?.creationDate ?? Date()
        let resolvedNodeID = nodeID ?? bestNode(for: takenAt)?.id
        let photo = MemoryPhoto(
            childID: childID,
            nodeID: resolvedNodeID,
            title: title,
            note: note,
            localAssetIdentifier: assetIdentifier,
            localAssetStatus: asset == nil ? .missing : .available,
            takenAt: takenAt
        )
        state.photos.append(photo)
        save()
        return photo
    }

    func markLocalAssetStatus(photoID: UUID, status: LocalAssetStatus) {
        guard let index = state.photos.firstIndex(where: { $0.id == photoID }) else { return }
        state.photos[index].localAssetStatus = status
        save()
    }

    // MARK: - Collections

    func createCollection(title: String, note: String, photoIDs: [UUID], layoutTemplate: String) {
        guard let childID = state.selectedChildID, !photoIDs.isEmpty else {
            errorMessage = "请先选择照片。"
            return
        }
        state.collections.append(PhotoCollection(
            childID: childID,
            title: title.isEmpty ? "新的照片集" : title,
            note: note,
            photoIDs: photoIDs,
            coverPhotoID: photoIDs.first,
            layoutTemplate: layoutTemplate
        ))
        save()
    }

    func updateCollection(_ collection: PhotoCollection, title: String, note: String, layoutTemplate: String, coverPhotoID: UUID?) {
        guard let index = state.collections.firstIndex(where: { $0.id == collection.id }) else { return }
        state.collections[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "照片集" : title
        state.collections[index].note = note
        state.collections[index].layoutTemplate = layoutTemplate
        state.collections[index].coverPhotoID = coverPhotoID ?? collection.photoIDs.first
        save()
    }

    // MARK: - Tag / Category attachment

    func attach(tagID: UUID, toPhoto photoID: UUID) {
        guard let index = state.photos.firstIndex(where: { $0.id == photoID }) else { return }
        if !state.photos[index].tagIDs.contains(tagID) {
            state.photos[index].tagIDs.append(tagID)
        }
        save()
    }

    func attach(categoryID: UUID, toPhoto photoID: UUID) {
        guard let index = state.photos.firstIndex(where: { $0.id == photoID }) else { return }
        if !state.photos[index].categoryIDs.contains(categoryID) {
            state.photos[index].categoryIDs.append(categoryID)
        }
        save()
    }

    func attach(tagID: UUID, toCollection collectionID: UUID) {
        guard let index = state.collections.firstIndex(where: { $0.id == collectionID }) else { return }
        if !state.collections[index].tagIDs.contains(tagID) {
            state.collections[index].tagIDs.append(tagID)
        }
        save()
    }

    func attach(categoryID: UUID, toCollection collectionID: UUID) {
        guard let index = state.collections.firstIndex(where: { $0.id == collectionID }) else { return }
        if !state.collections[index].categoryIDs.contains(categoryID) {
            state.collections[index].categoryIDs.append(categoryID)
        }
        save()
    }

    func attach(tagID: UUID, toAudio audioID: UUID) {
        guard let index = state.audios.firstIndex(where: { $0.id == audioID }) else { return }
        if !state.audios[index].tagIDs.contains(tagID) {
            state.audios[index].tagIDs.append(tagID)
        }
        save()
    }

    // MARK: - Audio

    func saveAudioFile(from url: URL, title: String, note: String, kind: AudioKind, duration: TimeInterval, bindTo target: (AudioTargetType, UUID)?, nodeID: UUID? = nil) {
        guard let childID = state.selectedChildID else { return }
        let filename = "audio-\(UUID().uuidString).m4a"
        let destination = mediaDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.copyItem(at: url, to: destination)
        } catch {
            errorMessage = "音频保存失败。"
            return
        }
        // 如果绑定对象是 node，优先记录到 audio.nodeID；
        // 否则若调用方主动传了 nodeID 也写入；都没有就按当前时间猜测最合适的节点。
        var resolvedNodeID = nodeID
        if resolvedNodeID == nil, let target, target.0 == .node {
            resolvedNodeID = target.1
        }
        if resolvedNodeID == nil {
            resolvedNodeID = bestNode(for: Date())?.id
        }
        let audio = AudioMemory(
            childID: childID,
            nodeID: resolvedNodeID,
            title: title.isEmpty ? "新的声音记录" : title,
            note: note,
            filename: filename,
            duration: duration,
            kind: kind
        )
        state.audios.append(audio)
        if let target {
            state.bindings.append(AudioBinding(audioID: audio.id, targetType: target.0, targetID: target.1))
        }
        save()
    }

    func bind(audioID: UUID, to targetType: AudioTargetType, targetID: UUID) {
        guard !state.bindings.contains(where: { $0.audioID == audioID && $0.targetType == targetType && $0.targetID == targetID }) else { return }
        state.bindings.append(AudioBinding(audioID: audioID, targetType: targetType, targetID: targetID))
        save()
    }

    func audios(for targetType: AudioTargetType, targetID: UUID) -> [AudioMemory] {
        let ids = state.bindings.filter { $0.targetType == targetType && $0.targetID == targetID }.map(\.audioID)
        return state.audios.filter { ids.contains($0.id) }
    }

    // MARK: - Search

    func search(_ query: String) -> [SearchResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        var results: [SearchResult] = []
        results += currentNodes.filter { $0.name.lowercased().contains(q) }.map(SearchResult.node)
        results += currentPhotos.filter { photo in
            photo.title.lowercased().contains(q)
            || photo.note.lowercased().contains(q)
            || taxonomyNames(tagIDs: photo.tagIDs, categoryIDs: photo.categoryIDs).contains { $0.contains(q) }
        }.map(SearchResult.photo)
        results += currentCollections.filter { collection in
            collection.title.lowercased().contains(q)
            || collection.note.lowercased().contains(q)
            || taxonomyNames(tagIDs: collection.tagIDs, categoryIDs: collection.categoryIDs).contains { $0.contains(q) }
        }.map(SearchResult.collection)
        results += currentAudios.filter { audio in
            audio.title.lowercased().contains(q)
            || audio.note.lowercased().contains(q)
            || audio.kind.rawValue.lowercased().contains(q)
            || taxonomyNames(tagIDs: audio.tagIDs, categoryIDs: []).contains { $0.contains(q) }
        }.map(SearchResult.audio)
        results += state.tags.filter { $0.name.lowercased().contains(q) }.map(SearchResult.tag)
        results += state.categories.filter { $0.name.lowercased().contains(q) }.map(SearchResult.category)
        return results
    }

    // MARK: - Image loading

    func image(for photo: MemoryPhoto) -> UIImage? {
        guard let filename = photo.filename else { return nil }
        return UIImage(contentsOfFile: mediaDirectory.appendingPathComponent(filename).path)
    }

    func requestImage(for photo: MemoryPhoto, targetSize: CGSize) async -> UIImage? {
        if let image = image(for: photo) {
            return image
        }
        guard photo.localAssetStatus == .available,
              let identifier = photo.localAssetIdentifier else {
            return nil
        }
        let results = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = results.firstObject else {
            markLocalAssetStatus(photoID: photo.id, status: .missing)
            return nil
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            var didResume = false
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if let image, !degraded, !didResume {
                    didResume = true
                    continuation.resume(returning: image)
                } else if image == nil, !didResume {
                    didResume = true
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func audioURL(for audio: AudioMemory) -> URL {
        mediaDirectory.appendingPathComponent(audio.filename)
    }

    // MARK: - Persistence

    func save() {
        do {
            let data = try JSONEncoder.babyTime.encode(state)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            errorMessage = "本地保存失败。"
        }
    }

    private static func load(from url: URL) -> PersistedState {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder.babyTime.decode(PersistedState.self, from: data) else {
            return PersistedState()
        }
        return decoded
    }

    private func replace<T: Identifiable & Equatable>(_ array: inout [T], _ value: T) {
        if let index = array.firstIndex(where: { $0.id == value.id }) {
            array[index] = value
        }
    }

    private func taxonomyNames(tagIDs: [UUID], categoryIDs: [UUID]) -> [String] {
        let tagNames = state.tags
            .filter { tagIDs.contains($0.id) }
            .map { $0.name.lowercased() }
        let categoryNames = state.categories
            .filter { categoryIDs.contains($0.id) }
            .map { $0.name.lowercased() }
        return tagNames + categoryNames
    }

    private static func sampleImage(title: String) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 900))
        return renderer.image { context in
            UIColor(red: 0.97, green: 0.88, blue: 0.70, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 900, height: 900))
            UIColor(red: 0.18, green: 0.40, blue: 0.47, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: 230, y: 180, width: 440, height: 440)).fill()
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 335, y: 330, width: 50, height: 50)).fill()
            UIBezierPath(ovalIn: CGRect(x: 515, y: 330, width: 50, height: 50)).fill()
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 56),
                .foregroundColor: UIColor(red: 0.12, green: 0.20, blue: 0.22, alpha: 1),
                .paragraphStyle: paragraph
            ]
            NSString(string: title).draw(in: CGRect(x: 70, y: 700, width: 760, height: 90), withAttributes: attributes)
        }
    }
}

extension JSONEncoder {
    static var babyTime: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

extension JSONDecoder {
    static var babyTime: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case timeline
    case album
    case recorder
    case search
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeline: "时间线"
        case .album: "相册"
        case .recorder: "录音"
        case .search: "搜索"
        case .settings: "我的"
        }
    }

    var icon: String {
        switch self {
        case .timeline: "clock"
        case .album: "photo.on.rectangle"
        case .recorder: "waveform"
        case .search: "magnifyingglass"
        case .settings: "person.crop.circle"
        }
    }
}
