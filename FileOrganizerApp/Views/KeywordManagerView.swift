import SwiftUI

struct KeywordManagerView: View {
    @StateObject private var store = KeywordStore()
    @State private var newKeyword = ""
    @State private var newSubfolder = ""
    @State private var selectedCategory = "Work"
    let categories = ["Work", "Personal"]

    var body: some View {
        Form {
            Section("Add Keyword") {
                TextField("Keyword", text: $newKeyword)
                TextField("Subfolder", text: $newSubfolder)
                Picker("Category", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { Text($0) }
                }
                Button("Add") {
                    store.add(keyword: newKeyword, subfolder: newSubfolder, category: selectedCategory)
                    newKeyword = ""
                    newSubfolder = ""
                }
            }

            Section("Current Keywords") {
                List(store.keywords) { entry in
                    HStack {
                        Text(entry.keyword)
                        Spacer()
                        Text(entry.subfolder)
                        Text(entry.category).foregroundColor(.gray)
                    }
                }
            }
        }
        .navigationTitle("Keyword Manager")
    }
}
