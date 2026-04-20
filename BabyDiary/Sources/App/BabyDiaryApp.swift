import SwiftUI

@main
struct BabyDiaryApp: App {
    @State private var store = AppStore.loadedOrSeeded()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .tint(store.theme.primary600)
                .preferredColorScheme(.light)
        }
    }
}
