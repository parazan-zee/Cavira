import SwiftUI

struct CalendarTab: View {
    var body: some View {
        NavigationStack {
            CalendarView()
        }
    }
}

#Preview {
    CalendarTab()
        .caviraPreviewShell()
}

