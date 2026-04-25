import SwiftUI

@main
struct WordcraftApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                
                DemoView()
                    .tabItem {
                        Label("Demo", systemImage: "star")
                    }
            }
        }
    }
}
