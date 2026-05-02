import AppIntents
import Foundation

enum BabyTimeIntentDestination: String, AppEnum {
    case timeline
    case album
    case recorder
    case search

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Baby Time 页面")
    static var caseDisplayRepresentations: [BabyTimeIntentDestination: DisplayRepresentation] = [
        .timeline: "时间线",
        .album: "相册",
        .recorder: "录音",
        .search: "搜索"
    ]
}

struct OpenBabyTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "打开 Baby Time"
    static var description = IntentDescription("打开 Baby Time 的常用记录入口。")
    static var openAppWhenRun = true

    @Parameter(title: "入口")
    var destination: BabyTimeIntentDestination

    init() {
        destination = .timeline
    }

    init(destination: BabyTimeIntentDestination) {
        self.destination = destination
    }

    static var parameterSummary: some ParameterSummary {
        Summary("打开 \(\.$destination)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(destination.rawValue, forKey: "BabyTimeIntentDestination")
        return .result()
    }
}

struct BabyTimeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenBabyTimeIntent(destination: .timeline),
            phrases: [
                "打开 \(.applicationName) 时间线",
                "查看 \(.applicationName) 成长记录"
            ],
            shortTitle: "打开时间线",
            systemImageName: "clock"
        )
        AppShortcut(
            intent: OpenBabyTimeIntent(destination: .recorder),
            phrases: [
                "用 \(.applicationName) 记录声音",
                "打开 \(.applicationName) 录音"
            ],
            shortTitle: "记录声音",
            systemImageName: "waveform"
        )
    }
}
