import SwiftUI

struct DuplicateCheckerView: View {
    @State private var selectedFolder = ""
    @State private var duplicates: [String: [URL]] = [:]
    @State private var isScanning = false
    
    var body: some View {
        VStack {
            HStack {
                TextField("Select folder to scan", text: $selectedFolder)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Browse") {
                    selectFolder()
                }
                
                Button("Scan") {
                    scanForDuplicates()
                }
                .disabled(selectedFolder.isEmpty || isScanning)
            }
            .padding()
            
            if isScanning {
                ProgressView("Scanning for duplicates...")
                    .padding()
            }
            
            List {
                ForEach(Array(duplicates.keys.sorted()), id: \.self) { filename in
                    VStack(alignment: .leading) {
                        Text(filename)
                            .font(.headline)
                        ForEach(duplicates[filename] ?? [], id: \.self) { url in
                            Text(url.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Duplicate Checker")
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK {
            selectedFolder = panel.url?.path ?? ""
        }
    }
    
    private func scanForDuplicates() {
        guard !selectedFolder.isEmpty else { return }
        
        isScanning = true
        duplicates.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            let folderURL = URL(fileURLWithPath: selectedFolder)
            
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
                
                var fileHashes: [String: [URL]] = [:]
                
                for fileURL in fileURLs {
                    if let data = try? Data(contentsOf: fileURL) {
                        let hash = data.sha256()
                        if fileHashes[hash] == nil {
                            fileHashes[hash] = []
                        }
                        fileHashes[hash]?.append(fileURL)
                    }
                }
                
                DispatchQueue.main.async {
                    self.duplicates = fileHashes.filter { $0.value.count > 1 }
                    self.isScanning = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isScanning = false
                }
            }
        }
    }
}

extension Data {
    func sha256() -> String {
        // Simple hash function for demo purposes
        // In production, you'd want to use a proper cryptographic hash
        var hash = 0
        for byte in self {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        return String(format: "%x", abs(hash))
    }
} 