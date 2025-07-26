import SwiftUI

struct ContentView: View {
    @State private var lastRunTime = UserDefaults.standard.string(forKey: "lastRunTime") ?? "Never"
    @StateObject private var keywordStore = KeywordStore()

    var body: some View {
        NavigationView {
            List {
                NavigationLink("Run Organizer") {
                    FolderSelectionView()
                }
                NavigationLink("Manage Keywords") {
                    KeywordManagerView()
                }
                NavigationLink("Duplicate Checker") {
                    DuplicateCheckerView()
                }
                NavigationLink("iCloud File Browser") {
                    iCloudFileBrowserView()
                }
            }
            .navigationTitle("File Organizer")
        }
    }
}
