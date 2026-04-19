import SwiftUI

struct StoriesTab: View {
    var body: some View {
        NavigationStack {
            StoriesListView()
        }
    }
}

#Preview {
    StoriesTab()
        .caviraPreviewShell()
}
