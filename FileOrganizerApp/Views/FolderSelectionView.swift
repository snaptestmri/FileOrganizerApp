import SwiftUI
import AppKit

struct FolderSelectionView: View {
    @State private var selectedFolderPath = ""
    @State private var showOrganizer = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        Group {
            if showOrganizer {
                OrganizationProgressView(folderPath: selectedFolderPath)
                    .onDisappear {
                        showOrganizer = false
                    }
            } else {
                VStack(spacing: 30) {
            // Header
            VStack(spacing: 8) {
                Text("Choose Folder to Organize")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Select a folder containing files you want to organize automatically")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Folder Selection Section
            VStack(spacing: 20) {
                // Folder Path Display
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Folder")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if selectedFolderPath.isEmpty {
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
                        Text(selectedFolderPath)
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
                
                // Browse Button
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
                
                // Change Folder Button (only show if folder is selected)
                if !selectedFolderPath.isEmpty {
                    Button(action: selectFolder) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Change Folder")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 16) {
                // Run Organizer Button
                Button(action: runOrganizer) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Run File Organizer")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(selectedFolderPath.isEmpty ? Color.gray : Color.green)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(selectedFolderPath.isEmpty)
                
                // Back Button
                Button("Back to Main Menu") {
                    // This would navigate back in a real app
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func selectFolder() {
        let dialog = NSOpenPanel()
        dialog.canChooseDirectories = true
        dialog.canChooseFiles = false
        dialog.allowsMultipleSelection = false
        dialog.title = "Select Folder to Organize"
        dialog.message = "Choose the folder containing files you want to organize"
        
        if dialog.runModal() == .OK {
            selectedFolderPath = dialog.url?.path ?? ""
        }
    }
    
    private func runOrganizer() {
        guard !selectedFolderPath.isEmpty else {
            showError(message: "Please select a folder first")
            return
        }
        
        print("Opening organizer for folder: \(selectedFolderPath)")
        showOrganizer = true
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
} 