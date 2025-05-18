import SwiftUI

@main
struct SlimMateApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 200, height: 100)
                .background(Color.clear)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowResizability(.contentSize)
    }
}
