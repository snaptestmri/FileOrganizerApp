import SwiftUI

struct KeywordManagerView: View {
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            EnhancedKeywordManager()
        }
        .frame(minWidth: 400, minHeight: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var headerSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Keyword Manager")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
}

#Preview {
    KeywordManagerView()
}