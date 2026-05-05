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

    var isAuthenticated: Bool { state.activeEmail != nil }
    var activeAccount: Account? { state.accounts.first { $0.email == state.activeEmail } }
    var selectedChild: ChildProfile? { state.children.first { $0.id == state.selectedChildID } }

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
        save()
    }

    func login(email: String, password: String) {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let account = state.accounts.first(where: { $0.email == normalized && $0.password == password }) else {
            errorMessage = "邮箱或密码错误。"
            return
        }
        state.activeEmail = account.email
        save()
    }

    func logout() {
        state.activeEmail = nil
        save()
    }

    func createChild(nickname: String, birthday: Date, gender: String, note: String, storageMode: MediaStorageMode = .localReference, cloudProvider: CloudProvider? = nil) {
        let accountID: UUID?
        if storageMode == .userCloudBackup, let cloudProvider {
            accountID = connectCloudProvider(cloudProvider).id
        } else {
            accountID = nil
        }
        let child = ChildProfile(nickname: nickname.isEmpty ? "宝宝" : nickname, birthday: birthday, gender: gender, note: note, defaultMediaStorageMode: storageMode, cloudProviderAccountID: accountID)
        state.children.append(child)
        state.selectedChildID = child.id
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

    @discardableResult
    func connectCloudProvider(_ provider: CloudProvider) -> CloudProviderAccount {
        if let existing = state.cloudProviderAccounts.first(where: { $0.provider == provider && $0.authorizationStatus == .authorized }) {
            return existing
        }
        let account = CloudProviderAccount(provider: provider, displayName: "\(provider.title) 授权账号")
        state.cloudProviderAccounts.append(account)
        save()
        return account
    }

    func updateSelectedChildStorageMode(_ storageMode: MediaStorageMode, provider: CloudProvider? = nil) {
        guard let childID = state.selectedChildID,
              let index = state.children.firstIndex(where: { $0.id == childID }) else { return }
        state.children[index].defaultMediaStorageMode = storageMode
        if storageMode == .userCloudBackup {
            let account = connectCloudProvider(provider ?? .iCloudDrive)
            state.children[index].cloudProviderAccountID = account.id
        } else {
            state.children[index].cloudProviderAccountID = nil
        }
        save()
    }

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

    func addSamplePhoto(title: String = "成长照片", note: String = "一张模拟器样例照片", date: Date = Date()) {
        guard let childID = state.selectedChildID else {
            errorMessage = "请先创建孩子档案。"
            return
        }
        let filename = "photo-\(UUID().uuidString).png"
        let url = mediaDirectory.appendingPathComponent(filename)
        let image = Self.sampleImage(title: title)
        if let data = image.pngData() {
            try? data.write(to: url)
        }
        state.photos.append(MemoryPhoto(childID: childID, title: title, note: note, filename: filename, storageMode: .localReference, localAssetIdentifier: nil, localAssetStatus: .available, cloudSyncStatus: .notRequired, takenAt: date))
        save()
    }

    func importPhoto(assetIdentifier: String, title: String, note: String) {
        guard let childID = state.selectedChildID else { return }
        guard let child = selectedChild else { return }
        let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject
        let takenAt = asset?.creationDate ?? Date()
        var photo = MemoryPhoto(
            childID: childID,
            title: title,
            note: note,
            storageMode: child.defaultMediaStorageMode,
            localAssetIdentifier: assetIdentifier,
            localAssetStatus: asset == nil ? .missing : .available,
            takenAt: takenAt
        )
        if child.defaultMediaStorageMode == .userCloudBackup {
            guard let accountID = child.cloudProviderAccountID,
                  let account = state.cloudProviderAccounts.first(where: { $0.id == accountID && $0.authorizationStatus == .authorized }) else {
                photo.cloudSyncStatus = .authExpired
                state.photos.append(photo)
                errorMessage = "云端授权不可用，照片已先按本机索引保存。"
                save()
                return
            }
            photo.cloudProvider = account.provider
            photo.cloudPath = cloudPath(for: photo, provider: account.provider)
            photo.cloudSyncStatus = .pending
        }
        state.photos.append(photo)
        save()
        if photo.storageMode == .userCloudBackup {
            startCloudBackup(for: photo.id)
        }
    }

    func markLocalAssetStatus(photoID: UUID, status: LocalAssetStatus) {
        guard let index = state.photos.firstIndex(where: { $0.id == photoID }) else { return }
        state.photos[index].localAssetStatus = status
        save()
    }

    func markCloudSyncStatus(photoID: UUID, status: CloudSyncStatus) {
        guard let index = state.photos.firstIndex(where: { $0.id == photoID }) else { return }
        state.photos[index].cloudSyncStatus = status
        if status == .synced {
            state.photos[index].cloudSyncedAt = Date()
            state.photos[index].cloudFileID = "cloud-\(photoID.uuidString)"
        }
        save()
    }

    func startCloudBackup(for photoID: UUID) {
        guard let index = state.photos.firstIndex(where: { $0.id == photoID }) else { return }
        guard state.photos[index].storageMode == .userCloudBackup else { return }
        guard selectedCloudAccount?.authorizationStatus == .authorized else {
            state.photos[index].cloudSyncStatus = .authExpired
            save()
            return
        }
        state.photos[index].cloudSyncStatus = .uploading
        save()
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            await MainActor.run {
                self?.markCloudSyncStatus(photoID: photoID, status: .synced)
            }
        }
    }

    var selectedCloudAccount: CloudProviderAccount? {
        guard let accountID = selectedChild?.cloudProviderAccountID else { return nil }
        return state.cloudProviderAccounts.first { $0.id == accountID }
    }

    func createCollection(title: String, note: String, photoIDs: [UUID], layoutTemplate: String) {
        guard let childID = state.selectedChildID, !photoIDs.isEmpty else {
            errorMessage = "请先选择照片。"
            return
        }
        state.collections.append(PhotoCollection(childID: childID, title: title.isEmpty ? "新的照片集" : title, note: note, photoIDs: photoIDs, coverPhotoID: photoIDs.first, layoutTemplate: layoutTemplate))
        save()
    }

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

    func saveAudioFile(from url: URL, title: String, note: String, kind: AudioKind, duration: TimeInterval, bindTo target: (AudioTargetType, UUID)?) {
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
        let audio = AudioMemory(childID: childID, title: title.isEmpty ? "新的声音记录" : title, note: note, filename: filename, duration: duration, kind: kind)
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

    func timeline() -> [TimelineSummary] {
        guard let child = selectedChild else { return [] }
        return TimelineBucket.allCases.map { bucket in
            let photos = currentPhotos.filter { Self.bucket(for: $0.takenAt, birthday: child.birthday) == bucket }
            let collections = currentCollections.filter { collection in
                collection.photoIDs.contains { id in photos.contains(where: { $0.id == id }) }
            }
            let audios = currentAudios.filter { Self.bucket(for: $0.createdAt, birthday: child.birthday) == bucket }
            let latest = (photos.map(\.createdAt) + collections.map(\.createdAt) + audios.map(\.createdAt)).max()
            return TimelineSummary(bucket: bucket, photoCount: photos.count, collectionCount: collections.count, audioCount: audios.count, coverPhoto: photos.first, updatedAt: latest)
        }
    }

    func search(_ query: String) -> [SearchResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        var results: [SearchResult] = []
        results += currentPhotos.filter { $0.title.lowercased().contains(q) || $0.note.lowercased().contains(q) }.map(SearchResult.photo)
        results += currentCollections.filter { $0.title.lowercased().contains(q) || $0.note.lowercased().contains(q) }.map(SearchResult.collection)
        results += currentAudios.filter { $0.title.lowercased().contains(q) || $0.note.lowercased().contains(q) || $0.kind.rawValue.lowercased().contains(q) }.map(SearchResult.audio)
        results += state.tags.filter { $0.name.lowercased().contains(q) }.map(SearchResult.tag)
        results += state.categories.filter { $0.name.lowercased().contains(q) }.map(SearchResult.category)
        return results
    }

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

    func save() {
        do {
            let data = try JSONEncoder.babyTime.encode(state)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            errorMessage = "本地保存失败。"
        }
    }

    static func bucket(for date: Date, birthday: Date, calendar: Calendar = .current) -> TimelineBucket {
        let start = calendar.startOfDay(for: birthday)
        let current = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: start, to: current).day ?? 0
        let months = calendar.dateComponents([.month], from: start, to: current).month ?? 0
        if days <= 0 { return .birth }
        if days <= 7 { return .week1 }
        if months < 2 { return .month1 }
        if months < 3 { return .month2 }
        if months < 4 { return .month3 }
        if months < 5 { return .month4 }
        if months < 6 { return .month5 }
        if months < 7 { return .month6 }
        if months < 8 { return .month7 }
        if months < 9 { return .month8 }
        if months < 10 { return .month9 }
        if months < 11 { return .month10 }
        if months < 12 { return .month11 }
        if months < 13 { return .month12 }
        if months < 24 { return .year1 }
        if months < 36 { return .year2 }
        return .later
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

    private func cloudPath(for photo: MemoryPhoto, provider: CloudProvider) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/yyyyMMdd_HHmmss"
        let datedPath = formatter.string(from: photo.takenAt)
        return "BabyTime/\(photo.childID.uuidString)/\(datedPath)_\(photo.id.uuidString).jpg"
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
