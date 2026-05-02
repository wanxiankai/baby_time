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
}

struct MemoryPhoto: Identifiable, Codable, Equatable {
    var id = UUID()
    var childID: UUID
    var title: String
    var note: String
    var filename: String
    var takenAt: Date
    var createdAt = Date()
    var tagIDs: [UUID] = []
    var categoryIDs: [UUID] = []
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
    var tags: [MemoryTag] = []
    var categories: [MemoryCategory] = MemoryCategory.defaultCategories
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
