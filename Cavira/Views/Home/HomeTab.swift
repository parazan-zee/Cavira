import SwiftUI

/// One `NavigationStack` per tab (HIG): home pushes live inside this stack only.
struct HomeTab: View {
    var body: some View {
        NavigationStack {
            HomeScreen()
        }
    }
}

#Preview {
    HomeTab()
        .caviraPreviewShell()
}
