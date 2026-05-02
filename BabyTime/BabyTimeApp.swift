import SwiftUI

@main
struct BabyTimeApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .onAppear {
                    routeFromIntentIfNeeded()
                }
                .onOpenURL { _ in
                    routeFromIntentIfNeeded()
                }
        }
    }

    private func routeFromIntentIfNeeded() {
        guard let raw = UserDefaults.standard.string(forKey: "BabyTimeIntentDestination"),
              let tab = AppTab(rawValue: raw) else { return }
        store.selectedTab = tab
        UserDefaults.standard.removeObject(forKey: "BabyTimeIntentDestination")
    }
}
