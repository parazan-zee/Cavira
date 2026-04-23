import SwiftData
import SwiftUI

struct StoriesListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Story.lastEditedDate, order: .reverse) private var allStories: [Story]

    @State private var selectedStory: Story?
    @State private var showingBuilder = false
    @State private var storyToEdit: Story?

    @State private var storyForMenu: Story?
    @State private var showActionsSheet = false
    @State private var storyToDelete: Story?
    @State private var showDeleteConfirm = false

    private var pinnedStories: [Story] { allStories.filter(\.isPinned) }
    private var recentStories: [Story] { allStories.filter { !$0.isPinned } }

    var body: some View {
        VStack(spacing: 0) {
            if allStories.isEmpty {
                EmptyStateView(
                    systemImage: "film.stack",
                    title: "No stories yet",
                    subtitle: "Create your first story from your photos."
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if !pinnedStories.isEmpty {
                            sectionLabel("Pinned")
                                .padding(.horizontal, CaviraTheme.Spacing.lg)
                                .padding(.top, CaviraTheme.Spacing.sm)

                            ForEach(pinnedStories, id: \.id) { story in
                                StoryCardView(
                                    story: story,
                                    onTap: { selectedStory = story },
                                    onMenu: {
                                        storyForMenu = story
                                        showActionsSheet = true
                                    }
                                )
                                .padding(.horizontal, CaviraTheme.Spacing.lg)
                                .contextMenu { storyContextMenu(story) }
                            }
                        }

                        if !recentStories.isEmpty {
                            sectionLabel("Recent")
                                .padding(.horizontal, CaviraTheme.Spacing.lg)
                                .padding(.top, pinnedStories.isEmpty ? CaviraTheme.Spacing.sm : CaviraTheme.Spacing.lg)

                            ForEach(recentStories, id: \.id) { story in
                                StoryCardView(
                                    story: story,
                                    onTap: { selectedStory = story },
                                    onMenu: {
                                        storyForMenu = story
                                        showActionsSheet = true
                                    }
                                )
                                .padding(.horizontal, CaviraTheme.Spacing.lg)
                                .contextMenu { storyContextMenu(story) }
                            }
                        }

                        Spacer(minLength: CaviraTheme.Spacing.xl)
                    }
                    .padding(.top, CaviraTheme.Spacing.sm)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CaviraTheme.backgroundPrimary)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(CaviraTheme.backgroundPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Stories")
                    .font(CaviraTheme.Typography.headline)
                    .foregroundStyle(CaviraTheme.textPrimary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingBuilder = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CaviraTheme.accent)
                        .frame(width: 34, height: 34)
                        .background(CaviraTheme.surfaceCard)
                        .clipShape(Circle())
                }
                .accessibilityLabel("New story")
            }
        }
        .fullScreenCover(item: $selectedStory) { story in
            StoryViewerView(story: story)
        }
        .sheet(isPresented: $showingBuilder) {
            StoryBuilderView()
        }
        .sheet(item: $storyToEdit) { story in
            NavigationStack {
                StoryDraftEditorView(editingStory: story) {
                    storyToEdit = nil
                }
            }
        }
        .confirmationDialog("Story", isPresented: $showActionsSheet, titleVisibility: .hidden, presenting: storyForMenu) { story in
            Button(story.isPinned ? "Unpin from profile" : "Pin to profile") {
                togglePin(story)
            }
            Button("Edit story") {
                storyToEdit = story
            }
            Button("Delete story", role: .destructive) {
                storyToDelete = story
                showDeleteConfirm = true
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("")
        }
        .onChange(of: showActionsSheet) { _, isShowing in
            if !isShowing { storyForMenu = nil }
        }
        .alert("Delete story?", isPresented: $showDeleteConfirm, presenting: storyToDelete) { story in
            Button("Delete", role: .destructive) { deleteStory(story) }
            Button("Cancel", role: .cancel) {}
        } message: { story in
            Text("\"\(story.title)\" will be permanently deleted. Your photos will not be affected.")
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(CaviraTheme.textTertiary)
            .kerning(0.6)
    }

    @ViewBuilder
    private func storyContextMenu(_ story: Story) -> some View {
        Button {
            togglePin(story)
        } label: {
            Label(
                story.isPinned ? "Unpin from profile" : "Pin to profile",
                systemImage: story.isPinned ? "pin.slash" : "pin"
            )
        }

        Button {
            storyToEdit = story
        } label: {
            Label("Edit story", systemImage: "pencil")
        }

        Divider()

        Button(role: .destructive) {
            storyToDelete = story
            showDeleteConfirm = true
        } label: {
            Label("Delete story", systemImage: "trash")
        }
    }

    private func togglePin(_ story: Story) {
        story.isPinned.toggle()
        try? context.save()
    }

    private func deleteStory(_ story: Story) {
        context.delete(story)
        try? context.save()
    }
}

#Preview {
    NavigationStack {
        StoriesListView()
    }
    .caviraPreviewShell()
}
