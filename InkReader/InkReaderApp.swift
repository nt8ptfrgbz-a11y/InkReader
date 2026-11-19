import SwiftUI

@main
struct InkReaderApp: App {
    @StateObject private var library = LibraryStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library)
                .tint(.ink)
                .preferredColorScheme(.light)
                .onOpenURL { url in _ = library.importBooks([url]) }
                .alert("提示", isPresented: Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })) {
                    Button("知道了", role: .cancel) { library.errorMessage = nil }
                } message: { Text(library.errorMessage ?? "") }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { library.saveNow() } }
    }
}
