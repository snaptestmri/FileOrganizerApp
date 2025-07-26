import SwiftUI

struct iCloudFileBrowserView: View {
    @State private var files: [URL] = []

    var body: some View {
        VStack {
            HStack {
                Button("Refresh") { loadFiles() }
                Spacer()
            }
            List {
                ForEach(files, id: \.self) { file in
                    HStack {
                        Text(file.lastPathComponent)
                        Spacer()
                        Button("Delete", role: .destructive) {
                            if iCloudFileManager.shared.deleteFile(at: file) {
                                loadFiles()
                            }
                        }
                    }
                }
            }
        }
        .onAppear { loadFiles() }
        .navigationTitle("iCloud Files")
    }

    func loadFiles() {
        files = iCloudFileManager.shared.listFiles()
    }
}
