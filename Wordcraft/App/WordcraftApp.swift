import SwiftUI

@main
struct WordcraftApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                DemoView()
                    .tabItem {
                        Label("Demo", systemImage: "text.word.spacing")
                    }
                ContentView()
                    .tabItem {
                        Label("Keyboard setup", systemImage: "keyboard")
                    }
            }
        }
    }
}
