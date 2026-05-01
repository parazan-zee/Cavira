import SwiftData
import SwiftUI

/// Swipeable collection viewer. **Toolbar chrome (date, `1 / N`, ⋯) is attached here**, not to each `PhotoDetailView` page, so paging does not drag or re-animate the navigation bar.
struct HomeCollectionViewer: View {
    let collection: HomeCollection

    @State private var page: Int = 0
    @State private var isPlacingPeopleTags = false

    private var entries: [PhotoEntry] {
        collection.orderedEntries
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "Empty collection",
                    systemImage: "square.stack",
                    description: Text("This collection has no items.")
                )
                .foregroundStyle(CaviraTheme.textSecondary)
            } else {
                TabView(selection: $page) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        PhotoDetailView(
                            entry: entry,
                            isEmbeddedInCollectionPager: true,
                            externalPlacingPeopleTag: Binding(
                                get: { page == index && isPlacingPeopleTags },
                                set: { newValue in
                                    if page == index {
                                        isPlacingPeopleTags = newValue
                                    }
                                }
                            )
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .bottom)
                .onChange(of: page) { _, _ in
                    isPlacingPeopleTags = false
                }
            }
        }
        .navigationTitle(collection.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            if !entries.isEmpty, entries.indices.contains(page) {
                ToolbarItem(placement: .principal) {
                    PhotoDetailNavChrome.principalToolbarContent(for: entries[page])
                        .transaction { $0.animation = nil }
                        .contentTransition(.identity)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Text("\(page + 1) / \(entries.count)")
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.92))
                        PhotoDetailPagerOverflowMenu(entry: entries[page], placingPeopleTags: $isPlacingPeopleTags)
                    }
                }
            }
        }
    }
}
