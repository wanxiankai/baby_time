import Foundation
import SwiftUI

enum TimelineBucket: String, Codable, CaseIterable, Identifiable {
    case birth = "出生当天"
    case week1 = "第 1 周"
    case month1 = "第 1 个月"
    case month2 = "第 2 个月"
    case month3 = "第 3 个月"
    case month4 = "第 4 个月"
    case month5 = "第 5 个月"
    case month6 = "半岁"
    case month7 = "第 7 个月"
    case month8 = "第 8 个月"
    case month9 = "第 9 个月"
    case month10 = "第 10 个月"
    case month11 = "第 11 个月"
    case month12 = "第 12 个月"
    case year1 = "1 岁"
    case year2 = "2 岁"
    case later = "更久以后"

    var id: String { rawValue }
}

enum AudioTargetType: String, Codable, CaseIterable {
    case photo
    case collection
}

enum AudioKind: String, Codable, CaseIterable, Identifiable {
    case parentMessage = "父母留言"
    case childVoice = "孩子声音"
    case blessing = "家人祝福"
    case moment = "现场声音"

    var id: String { rawValue }
}

enum MediaStorageMode: String, Codable, CaseIterable, Identifiable {
    case localReference
    case userCloudBackup

    var id: String { rawValue }

    var title: String {
        switch self {
        case .localReference: "本机索引"
        case .userCloudBackup: "授权云端备份"
        }
    }

    var subtitle: String {
        switch self {
        case .localReference: "只记录系统相册引用，不复制、不上传照片原文件。"
        case .userCloudBackup: "照片备份到你授权的云端目录，Baby Time 不托管原文件。"
        }
    }
}

enum CloudProvider: String, Codable, CaseIterable, Identifiable {
    case iCloudDrive
    case googleDrive
    case oneDrive
    case dropbox

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iCloudDrive: "iCloud Drive"
        case .googleDrive: "Google Drive"
        case .oneDrive: "OneDrive"
        case .dropbox: "Dropbox"
        }
    }

    var icon: String {
        switch self {
        case .iCloudDrive: "icloud"
        case .googleDrive: "g.circle"
        case .oneDrive: "cloud"
        case .dropbox: "shippingbox"
        }
    }
}

enum CloudAuthorizationStatus: String, Codable, Equatable {
    case authorized
    case expired
    case revoked
    case failed

    var title: String {
        switch self {
        case .authorized: "已授权"
        case .expired: "授权过期"
        case .revoked: "已断开"
        case .failed: "授权失败"
        }
    }
}

enum LocalAssetStatus: String, Codable, Equatable {
    case available
    case missing
    case permissionDenied
    case limitedAccessRemoved
    case unknown

    var title: String {
        switch self {
        case .available: "本机原图可用"
        case .missing: "原照片不存在"
        case .permissionDenied: "相册权限失效"
        case .limitedAccessRemoved: "不在授权范围"
        case .unknown: "状态未知"
        }
    }
}

enum CloudSyncStatus: String, Codable, Equatable {
    case notRequired
    case pending
    case uploading
    case synced
    case failed
    case missing
    case authExpired
    case quotaExceeded

    var title: String {
        switch self {
        case .notRequired: "无需云端备份"
        case .pending: "等待备份"
        case .uploading: "备份中"
        case .synced: "已备份"
        case .failed: "备份失败"
        case .missing: "云端文件缺失"
        case .authExpired: "云端授权失效"
        case .quotaExceeded: "云端空间不足"
        }
    }
}

struct Account: Codable, Equatable {
    var email: String
    var displayName: String
    var password: String
}

struct ChildProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var nickname: String
    var birthday: Date
    var gender: String
    var note: String
    var defaultMediaStorageMode: MediaStorageMode = .localReference
    var cloudProviderAccountID: UUID?

    init(id: UUID = UUID(), nickname: String, birthday: Date, gender: String, note: String, defaultMediaStorageMode: MediaStorageMode = .localReference, cloudProviderAccountID: UUID? = nil) {
        self.id = id
        self.nickname = nickname
        self.birthday = birthday
        self.gender = gender
        self.note = note
        self.defaultMediaStorageMode = defaultMediaStorageMode
        self.cloudProviderAccountID = cloudProviderAccountID
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case birthday
        case gender
        case note
        case defaultMediaStorageMode
        case cloudProviderAccountID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        nickname = try container.decode(String.self, forKey: .nickname)
        birthday = try container.decode(Date.self, forKey: .birthday)
        gender = try container.decode(String.self, forKey: .gender)
        note = try container.decode(String.self, forKey: .note)
        defaultMediaStorageMode = try container.decodeIfPresent(MediaStorageMode.self, forKey: .defaultMediaStorageMode) ?? .localReference
        cloudProviderAccountID = try container.decodeIfPresent(UUID.self, forKey: .cloudProviderAccountID)
    }
}

struct MemoryPhoto: Identifiable, Codable, Equatable {
    var id = UUID()
    var childID: UUID
    var title: String
    var note: String
    var filename: String?
    var storageMode: MediaStorageMode = .localReference
    var localAssetIdentifier: String?
    var localAssetStatus: LocalAssetStatus = .available
    var cloudProvider: CloudProvider?
    var cloudFileID: String?
    var cloudPath: String?
    var cloudSyncStatus: CloudSyncStatus = .notRequired
    var cloudSyncedAt: Date?
    var takenAt: Date
    var createdAt = Date()
    var tagIDs: [UUID] = []
    var categoryIDs: [UUID] = []

    init(
        id: UUID = UUID(),
        childID: UUID,
        title: String,
        note: String,
        filename: String? = nil,
        storageMode: MediaStorageMode = .localReference,
        localAssetIdentifier: String? = nil,
        localAssetStatus: LocalAssetStatus = .available,
        cloudProvider: CloudProvider? = nil,
        cloudFileID: String? = nil,
        cloudPath: String? = nil,
        cloudSyncStatus: CloudSyncStatus = .notRequired,
        cloudSyncedAt: Date? = nil,
        takenAt: Date,
        createdAt: Date = Date(),
        tagIDs: [UUID] = [],
        categoryIDs: [UUID] = []
    ) {
        self.id = id
        self.childID = childID
        self.title = title
        self.note = note
        self.filename = filename
        self.storageMode = storageMode
        self.localAssetIdentifier = localAssetIdentifier
        self.localAssetStatus = localAssetStatus
        self.cloudProvider = cloudProvider
        self.cloudFileID = cloudFileID
        self.cloudPath = cloudPath
        self.cloudSyncStatus = cloudSyncStatus
        self.cloudSyncedAt = cloudSyncedAt
        self.takenAt = takenAt
        self.createdAt = createdAt
        self.tagIDs = tagIDs
        self.categoryIDs = categoryIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case childID
        case title
        case note
        case filename
        case storageMode
        case localAssetIdentifier
        case localAssetStatus
        case cloudProvider
        case cloudFileID
        case cloudPath
        case cloudSyncStatus
        case cloudSyncedAt
        case takenAt
        case createdAt
        case tagIDs
        case categoryIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        childID = try container.decode(UUID.self, forKey: .childID)
        title = try container.decode(String.self, forKey: .title)
        note = try container.decode(String.self, forKey: .note)
        filename = try container.decodeIfPresent(String.self, forKey: .filename)
        storageMode = try container.decodeIfPresent(MediaStorageMode.self, forKey: .storageMode) ?? .localReference
        localAssetIdentifier = try container.decodeIfPresent(String.self, forKey: .localAssetIdentifier)
        localAssetStatus = try container.decodeIfPresent(LocalAssetStatus.self, forKey: .localAssetStatus) ?? .available
        cloudProvider = try container.decodeIfPresent(CloudProvider.self, forKey: .cloudProvider)
        cloudFileID = try container.decodeIfPresent(String.self, forKey: .cloudFileID)
        cloudPath = try container.decodeIfPresent(String.self, forKey: .cloudPath)
        cloudSyncStatus = try container.decodeIfPresent(CloudSyncStatus.self, forKey: .cloudSyncStatus) ?? .notRequired
        cloudSyncedAt = try container.decodeIfPresent(Date.self, forKey: .cloudSyncedAt)
        takenAt = try container.decode(Date.self, forKey: .takenAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        tagIDs = try container.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
        categoryIDs = try container.decodeIfPresent([UUID].self, forKey: .categoryIDs) ?? []
    }
}

struct CloudProviderAccount: Identifiable, Codable, Equatable {
    var id = UUID()
    var provider: CloudProvider
    var displayName: String
    var authorizationStatus: CloudAuthorizationStatus = .authorized
    var rootPath: String = "BabyTime"
    var lastVerifiedAt = Date()
}

struct PhotoCollection: Identifiable, Codable, Equatable {
    var id = UUID()
    var childID: UUID
    var title: String
    var note: String
    var photoIDs: [UUID]
    var coverPhotoID: UUID?
    var layoutTemplate: String
    var createdAt = Date()
    var tagIDs: [UUID] = []
    var categoryIDs: [UUID] = []
}

struct AudioMemory: Identifiable, Codable, Equatable {
    var id = UUID()
    var childID: UUID
    var title: String
    var note: String
    var filename: String
    var duration: TimeInterval
    var kind: AudioKind
    var createdAt = Date()
    var tagIDs: [UUID] = []
}

struct AudioBinding: Identifiable, Codable, Equatable {
    var id = UUID()
    var audioID: UUID
    var targetType: AudioTargetType
    var targetID: UUID
}

struct MemoryTag: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var colorName: String
}

struct MemoryCategory: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var icon: String
    var isSystem: Bool
}

struct TimelineSummary: Identifiable, Equatable {
    var id: TimelineBucket { bucket }
    var bucket: TimelineBucket
    var photoCount: Int
    var collectionCount: Int
    var audioCount: Int
    var coverPhoto: MemoryPhoto?
    var updatedAt: Date?
}

enum SearchResult: Identifiable, Equatable {
    case photo(MemoryPhoto)
    case collection(PhotoCollection)
    case audio(AudioMemory)
    case tag(MemoryTag)
    case category(MemoryCategory)

    var id: String {
        switch self {
        case .photo(let item): "photo-\(item.id)"
        case .collection(let item): "collection-\(item.id)"
        case .audio(let item): "audio-\(item.id)"
        case .tag(let item): "tag-\(item.id)"
        case .category(let item): "category-\(item.id)"
        }
    }

    var title: String {
        switch self {
        case .photo(let item): item.title.isEmpty ? "照片" : item.title
        case .collection(let item): item.title
        case .audio(let item): item.title
        case .tag(let item): "#\(item.name)"
        case .category(let item): "\(item.icon) \(item.name)"
        }
    }

    var typeLabel: String {
        switch self {
        case .photo: "照片"
        case .collection: "照片集"
        case .audio: "音频"
        case .tag: "Tag"
        case .category: "分类"
        }
    }
}

struct PersistedState: Codable, Equatable {
    var accounts: [Account] = []
    var activeEmail: String?
    var children: [ChildProfile] = []
    var selectedChildID: UUID?
    var photos: [MemoryPhoto] = []
    var collections: [PhotoCollection] = []
    var audios: [AudioMemory] = []
    var bindings: [AudioBinding] = []
    var cloudProviderAccounts: [CloudProviderAccount] = []
    var tags: [MemoryTag] = []
    var categories: [MemoryCategory] = MemoryCategory.defaultCategories

    private enum CodingKeys: String, CodingKey {
        case accounts
        case activeEmail
        case children
        case selectedChildID
        case photos
        case collections
        case audios
        case bindings
        case cloudProviderAccounts
        case tags
        case categories
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try container.decodeIfPresent([Account].self, forKey: .accounts) ?? []
        activeEmail = try container.decodeIfPresent(String.self, forKey: .activeEmail)
        children = try container.decodeIfPresent([ChildProfile].self, forKey: .children) ?? []
        selectedChildID = try container.decodeIfPresent(UUID.self, forKey: .selectedChildID)
        photos = try container.decodeIfPresent([MemoryPhoto].self, forKey: .photos) ?? []
        collections = try container.decodeIfPresent([PhotoCollection].self, forKey: .collections) ?? []
        audios = try container.decodeIfPresent([AudioMemory].self, forKey: .audios) ?? []
        bindings = try container.decodeIfPresent([AudioBinding].self, forKey: .bindings) ?? []
        cloudProviderAccounts = try container.decodeIfPresent([CloudProviderAccount].self, forKey: .cloudProviderAccounts) ?? []
        tags = try container.decodeIfPresent([MemoryTag].self, forKey: .tags) ?? []
        categories = try container.decodeIfPresent([MemoryCategory].self, forKey: .categories) ?? MemoryCategory.defaultCategories
    }
}

extension MemoryCategory {
    static let defaultCategories: [MemoryCategory] = [
        .init(name: "日常", icon: "sun.max", isSystem: true),
        .init(name: "纪念日", icon: "gift", isSystem: true),
        .init(name: "第一次", icon: "sparkles", isSystem: true),
        .init(name: "声音记录", icon: "waveform", isSystem: true),
        .init(name: "家庭合影", icon: "person.3", isSystem: true),
        .init(name: "成长变化", icon: "chart.line.uptrend.xyaxis", isSystem: true),
        .init(name: "节日", icon: "party.popper", isSystem: true),
        .init(name: "外出", icon: "figure.walk", isSystem: true),
        .init(name: "健康", icon: "heart", isSystem: true),
        .init(name: "睡眠", icon: "moon", isSystem: true)
    ]
}
