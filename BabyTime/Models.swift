import Foundation
import SwiftUI

enum AudioTargetType: String, Codable, CaseIterable {
    case photo
    case collection
    case node
}

enum AudioKind: String, Codable, CaseIterable, Identifiable {
    case parentMessage = "父母留言"
    case childVoice = "孩子声音"
    case blessing = "家人祝福"
    case moment = "现场声音"

    var id: String { rawValue }
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

    init(id: UUID = UUID(), nickname: String, birthday: Date, gender: String, note: String) {
        self.id = id
        self.nickname = nickname
        self.birthday = birthday
        self.gender = gender
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case birthday
        case gender
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        nickname = try container.decode(String.self, forKey: .nickname)
        birthday = try container.decode(Date.self, forKey: .birthday)
        gender = try container.decode(String.self, forKey: .gender)
        note = try container.decode(String.self, forKey: .note)
    }
}

/// 用户自定义的时间线节点。
/// 用户首次创建孩子档案时会自动生成一组预设节点（出生第一天、第一周、第 1~12 个月、1 周岁），
/// 也可以在首页右上角新增任意节点。
struct TimelineNode: Identifiable, Codable, Equatable {
    var id = UUID()
    var childID: UUID
    var name: String
    var date: Date
    var isDefault: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        childID: UUID,
        name: String,
        date: Date,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.childID = childID
        self.name = name
        self.date = date
        self.isDefault = isDefault
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case childID
        case name
        case date
        case isDefault
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        childID = try container.decode(UUID.self, forKey: .childID)
        name = try container.decode(String.self, forKey: .name)
        date = try container.decode(Date.self, forKey: .date)
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

/// 一张照片的本地索引记录。
/// 注意：Baby Time 不保存照片原文件，只保存系统相册资产 ID（localAssetIdentifier）和归属节点。
/// 删除一张照片记录只会解除与节点的关联，不会删除系统相册中的原图。
struct MemoryPhoto: Identifiable, Codable, Equatable {
    var id = UUID()
    var childID: UUID
    var nodeID: UUID?
    var title: String
    var note: String
    /// 兼容旧版样例照片：模拟器场景下的 fallback 文件名。真机正式使用时该字段为 nil。
    var filename: String?
    var localAssetIdentifier: String?
    var localAssetStatus: LocalAssetStatus = .available
    var takenAt: Date
    var createdAt = Date()
    var tagIDs: [UUID] = []
    var categoryIDs: [UUID] = []

    init(
        id: UUID = UUID(),
        childID: UUID,
        nodeID: UUID? = nil,
        title: String,
        note: String,
        filename: String? = nil,
        localAssetIdentifier: String? = nil,
        localAssetStatus: LocalAssetStatus = .available,
        takenAt: Date,
        createdAt: Date = Date(),
        tagIDs: [UUID] = [],
        categoryIDs: [UUID] = []
    ) {
        self.id = id
        self.childID = childID
        self.nodeID = nodeID
        self.title = title
        self.note = note
        self.filename = filename
        self.localAssetIdentifier = localAssetIdentifier
        self.localAssetStatus = localAssetStatus
        self.takenAt = takenAt
        self.createdAt = createdAt
        self.tagIDs = tagIDs
        self.categoryIDs = categoryIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case childID
        case nodeID
        case title
        case note
        case filename
        case localAssetIdentifier
        case localAssetStatus
        case takenAt
        case createdAt
        case tagIDs
        case categoryIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        childID = try container.decode(UUID.self, forKey: .childID)
        nodeID = try container.decodeIfPresent(UUID.self, forKey: .nodeID)
        title = try container.decode(String.self, forKey: .title)
        note = try container.decode(String.self, forKey: .note)
        filename = try container.decodeIfPresent(String.self, forKey: .filename)
        localAssetIdentifier = try container.decodeIfPresent(String.self, forKey: .localAssetIdentifier)
        localAssetStatus = try container.decodeIfPresent(LocalAssetStatus.self, forKey: .localAssetStatus) ?? .available
        takenAt = try container.decode(Date.self, forKey: .takenAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        tagIDs = try container.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
        categoryIDs = try container.decodeIfPresent([UUID].self, forKey: .categoryIDs) ?? []
    }
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
    var nodeID: UUID?
    var title: String
    var note: String
    var filename: String
    var duration: TimeInterval
    var kind: AudioKind
    var createdAt = Date()
    var tagIDs: [UUID] = []

    init(
        id: UUID = UUID(),
        childID: UUID,
        nodeID: UUID? = nil,
        title: String,
        note: String,
        filename: String,
        duration: TimeInterval,
        kind: AudioKind,
        createdAt: Date = Date(),
        tagIDs: [UUID] = []
    ) {
        self.id = id
        self.childID = childID
        self.nodeID = nodeID
        self.title = title
        self.note = note
        self.filename = filename
        self.duration = duration
        self.kind = kind
        self.createdAt = createdAt
        self.tagIDs = tagIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case childID
        case nodeID
        case title
        case note
        case filename
        case duration
        case kind
        case createdAt
        case tagIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        childID = try container.decode(UUID.self, forKey: .childID)
        nodeID = try container.decodeIfPresent(UUID.self, forKey: .nodeID)
        title = try container.decode(String.self, forKey: .title)
        note = try container.decode(String.self, forKey: .note)
        filename = try container.decode(String.self, forKey: .filename)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        kind = try container.decode(AudioKind.self, forKey: .kind)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        tagIDs = try container.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
    }
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

/// 一个时间线节点的聚合视图，供首页卡片使用。
struct TimelineNodeSummary: Identifiable, Equatable {
    var id: UUID { node.id }
    var node: TimelineNode
    var previewPhotos: [MemoryPhoto]      // 最多 3 张
    var totalPhotoCount: Int
    var audioCount: Int
    var updatedAt: Date?
}

enum SearchResult: Identifiable, Equatable {
    case photo(MemoryPhoto)
    case collection(PhotoCollection)
    case audio(AudioMemory)
    case tag(MemoryTag)
    case category(MemoryCategory)
    case node(TimelineNode)

    var id: String {
        switch self {
        case .photo(let item): "photo-\(item.id)"
        case .collection(let item): "collection-\(item.id)"
        case .audio(let item): "audio-\(item.id)"
        case .tag(let item): "tag-\(item.id)"
        case .category(let item): "category-\(item.id)"
        case .node(let item): "node-\(item.id)"
        }
    }

    var title: String {
        switch self {
        case .photo(let item): item.title.isEmpty ? "照片" : item.title
        case .collection(let item): item.title
        case .audio(let item): item.title
        case .tag(let item): "#\(item.name)"
        case .category(let item): "\(item.icon) \(item.name)"
        case .node(let item): item.name
        }
    }

    var typeLabel: String {
        switch self {
        case .photo: "照片"
        case .collection: "照片集"
        case .audio: "音频"
        case .tag: "Tag"
        case .category: "分类"
        case .node: "时间节点"
        }
    }
}

struct PersistedState: Codable, Equatable {
    var accounts: [Account] = []
    var activeEmail: String?
    var children: [ChildProfile] = []
    var selectedChildID: UUID?
    var nodes: [TimelineNode] = []
    var photos: [MemoryPhoto] = []
    var collections: [PhotoCollection] = []
    var audios: [AudioMemory] = []
    var bindings: [AudioBinding] = []
    var tags: [MemoryTag] = []
    var categories: [MemoryCategory] = MemoryCategory.defaultCategories

    private enum CodingKeys: String, CodingKey {
        case accounts
        case activeEmail
        case children
        case selectedChildID
        case nodes
        case photos
        case collections
        case audios
        case bindings
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
        nodes = try container.decodeIfPresent([TimelineNode].self, forKey: .nodes) ?? []
        photos = try container.decodeIfPresent([MemoryPhoto].self, forKey: .photos) ?? []
        collections = try container.decodeIfPresent([PhotoCollection].self, forKey: .collections) ?? []
        audios = try container.decodeIfPresent([AudioMemory].self, forKey: .audios) ?? []
        bindings = try container.decodeIfPresent([AudioBinding].self, forKey: .bindings) ?? []
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

extension TimelineNode {
    /// 按照孩子生日生成默认的成长时间节点：出生第一天、第一周、第 1~12 个月、1 周岁。
    static func defaultNodes(for child: ChildProfile, calendar: Calendar = .current) -> [TimelineNode] {
        let birthday = calendar.startOfDay(for: child.birthday)
        var presets: [(name: String, date: Date)] = []

        presets.append(("出生第一天", birthday))
        if let d = calendar.date(byAdding: .day, value: 7, to: birthday) {
            presets.append(("出生第一周", d))
        }
        for month in 1...12 {
            if let d = calendar.date(byAdding: .month, value: month, to: birthday) {
                presets.append(("第 \(month) 个月", d))
            }
        }
        if let d = calendar.date(byAdding: .year, value: 1, to: birthday) {
            presets.append(("一周岁", d))
        }

        return presets.map { item in
            TimelineNode(childID: child.id, name: item.name, date: item.date, isDefault: true)
        }
    }
}
