import SwiftUI
import SwiftData

@main
struct PresenceApp: App {
    @State private var appState = AppState()
    let modelContainer: ModelContainer

    init() {
        do {
            self.modelContainer = try ModelSchema.createContainer()
        } catch {
            fatalError("Failed to initialize SwiftData ModelContainer: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(appState)
        }
        .modelContainer(modelContainer)
    }
}
