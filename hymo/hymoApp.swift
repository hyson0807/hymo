import SwiftUI

@main
struct hymoApp: App {
    var body: some Scene {
        MenuBarExtra("Hymo", systemImage: "note.text") {
            ContentView()
        }
        .menuBarExtraStyle(.window) // 팝오버를 창 스타일로 표시
    }
}
