import SwiftUI

struct FileMoverView: View {
    var body: some View {
        VStack {
            Button("Choose Folder & Run Organizer") {
                if let selectedFolder = FileMover.chooseSourceFolder() {
                    let mover = FileMover(sourceFolder: selectedFolder)
                    mover.run(with: KeywordStore().keywords)

                    let now = Date()
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    UserDefaults.standard.set(formatter.string(from: now), forKey: "lastRunTime")
                }
            }
            .padding()
        }
        .navigationTitle("Run Organizer")
    }
}
