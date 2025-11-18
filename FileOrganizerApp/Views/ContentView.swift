import SwiftUI

struct ContentView: View {
    @State private var lastRunTime = UserDefaults.standard.string(forKey: "lastRunTime") ?? "Never"
    @StateObject private var keywordStore = KeywordStore()

    var body: some View {
        NavigationView {
            List {
                NavigationLink("Run Organizer") {
                    FolderSelectionView(defaultMode: .keywords)
                }
                NavigationLink("AI Classification") {
                    FolderSelectionView(defaultMode: .ai)
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
            .listStyle(SidebarListStyle())
            .frame(minWidth: 150)
            .navigationTitle("File Organizer")

            // Default view when nothing is selected
            VStack {
                Image(systemName: "folder.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text("Select an option from the sidebar")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
}
