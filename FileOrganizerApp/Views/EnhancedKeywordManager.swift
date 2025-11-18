import SwiftUI

struct EnhancedKeywordManager: View {
    @StateObject private var store = KeywordStore()
    @State private var selectedSubfolder = "General"
    @State private var selectedCategory = "Work"
    @State private var lastAddedKeyword = ""
    @State private var customKeyword = ""
    @FocusState private var isTextFieldFocused: Bool
    
    // Predefined keywords
    let commonKeywords = [
        "document", "spreadsheet", "presentation", "image", "video", 
        "audio", "archive", "backup", "project", "report", "invoice",
        "receipt", "contract", "proposal", "manual", "guide", "tutorial",
        "photo", "screenshot", "design", "code", "data", "log", "config"
    ]
    
    let subfolders = ["General", "Work", "Personal", "Documents", "Media", "Projects"]
    let categories = ["Work", "Personal", "Important", "Temporary"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Add custom keyword with TextField
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add Custom Keyword")
                        .font(.headline)

                    HStack(spacing: 8) {
                        TextField("Enter keyword...", text: $customKeyword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                addCustomKeyword()
                            }

                        Button("Add") {
                            addCustomKeyword()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(customKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                // Quick add buttons
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Add - Common Keywords")
                        .font(.headline)

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 8)
                    ], spacing: 8) {
                        ForEach(commonKeywords, id: \.self) { keyword in
                            Button(keyword) {
                                addKeyword(keyword)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                }
            
                // Settings
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
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
                        .frame(maxWidth: .infinity)

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
                        .frame(maxWidth: .infinity)
                    }

                    Button("Clear All") {
                        store.clearAllKeywords()
                        lastAddedKeyword = ""
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            
                // Last added keyword
                if !lastAddedKeyword.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Last Added:")
                            .font(.headline)
                        Text("'\(lastAddedKeyword)'")
                            .font(.title3)
                            .foregroundColor(.green)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                }

                // Keywords list
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Keywords (\(store.keywords.count))")
                        .font(.headline)

                    if store.keywords.isEmpty {
                        Text("No keywords added yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    } else {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(store.keywords, id: \.keyword) { entry in
                                HStack(spacing: 8) {
                                    Text("• \(entry.keyword)")
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                    Text("(\(entry.subfolder)/\(entry.category))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Button(action: {
                                        removeKeyword(entry)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                        .frame(maxHeight: 250)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            // Set focus to text field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func addCustomKeyword() {
        let trimmedKeyword = customKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else { return }

        store.add(keyword: trimmedKeyword, subfolder: selectedSubfolder, category: selectedCategory)
        lastAddedKeyword = trimmedKeyword
        customKeyword = "" // Clear the input field
        print("🔧 Added custom keyword: '\(trimmedKeyword)' to '\(selectedSubfolder)/\(selectedCategory)'")
    }

    private func addKeyword(_ keyword: String) {
        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKeyword.isEmpty else { return }

        store.add(keyword: trimmedKeyword, subfolder: selectedSubfolder, category: selectedCategory)
        lastAddedKeyword = trimmedKeyword
        print("🔧 Added keyword: '\(trimmedKeyword)' to '\(selectedSubfolder)/\(selectedCategory)'")
    }

    private func removeKeyword(_ entry: KeywordEntry) {
        if let index = store.keywords.firstIndex(where: { $0.keyword == entry.keyword && $0.subfolder == entry.subfolder && $0.category == entry.category }) {
            store.keywords.remove(at: index)
            store.save()
        }
    }
}

#Preview {
    EnhancedKeywordManager()
}

