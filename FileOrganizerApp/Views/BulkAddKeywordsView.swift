import SwiftUI

struct BulkAddKeywordsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = KeywordStore()
    
    let selectedKeywords: [String]
    let scannedKeywords: [ScannedKeyword]
    
    @State private var selectedSubfolder = "General"
    @State private var selectedCategory = "Work"
    
    let subfolders = ["General", "Work", "Personal", "Documents", "Media", "Projects"]
    let categories = ["Work", "Personal", "Important", "Temporary"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Bulk Add Keywords")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Add multiple keywords at once")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Settings
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subfolder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Subfolder", selection: $selectedSubfolder) {
                        ForEach(subfolders, id: \.self) { subfolder in
                            Text(subfolder).tag(subfolder)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Spacer()
            }
            
            // Keywords to add
            VStack(alignment: .leading, spacing: 8) {
                Text("Keywords to Add (\(selectedKeywords.count))")
                    .font(.headline)
                
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(selectedKeywords, id: \.self) { keyword in
                            Text(keyword)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            
            // Action buttons
            HStack {
                Button("Add All Keywords") {
                    addAllKeywords()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 400)
    }
    
    private func addAllKeywords() {
        for keyword in selectedKeywords {
            store.add(keyword: keyword, subfolder: selectedSubfolder, category: selectedCategory)
        }
        print("🔧 Added \(selectedKeywords.count) keywords to '\(selectedSubfolder)/\(selectedCategory)'")
        dismiss()
    }
}

#Preview {
    BulkAddKeywordsView(
        selectedKeywords: ["document", "spreadsheet", "presentation"],
        scannedKeywords: []
    )
}
