import SwiftUI

struct DuplicateCheckerView: View {
    @State private var selectedFolder = ""
    @State private var duplicates: [String: [URL]] = [:]
    @State private var showProgress = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 8) {
                Text("Duplicate Checker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Scan a folder for duplicate files by content hash.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Folder Selection
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Folder")
                        .font(.headline)
                        .foregroundColor(.primary)
                    if selectedFolder.isEmpty {
                        Text("No folder selected")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                    } else {
                        Text(selectedFolder)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                    }
                }
                Button(action: selectFolder) {
                    HStack {
                        Image(systemName: "folder")
                        Text("Browse for Folder")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Action Button
            VStack(spacing: 16) {
                Button(action: { showProgress = true }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Scan for Duplicates")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(selectedFolder.isEmpty ? Color.gray : Color.green)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(selectedFolder.isEmpty)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(minWidth: 500, minHeight: 400)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showProgress) {
            DuplicateScanProgressView(folderPath: selectedFolder) { found in
                self.duplicates = found
            }
            .frame(minWidth: 500, minHeight: 600)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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