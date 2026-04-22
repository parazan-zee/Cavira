import AVKit
import Combine
import Photos
import SwiftUI

/// Full-screen Instagram-style story playback (10s per slide).
struct StoryViewerView: View {
    @Environment(\.appServices) private var appServices
    @Environment(\.dismiss) private var dismiss

    let story: Story
    var autoAdvance: Bool = true

    @State private var selectedIndex: Int = 0
    @State private var isPaused: Bool = false
    @State private var progress: Double = 0

    private let tickInterval: TimeInterval = 0.05
    private let secondsPerSlide: TimeInterval = 10

    private var slides: [StorySlide] { story.orderedSlides }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if slides.isEmpty {
                emptyStoryView
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { idx, slide in
                        SlideRenderView(slide: slide)
                            .tag(idx)
                            .ignoresSafeArea()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()

                chromeOverlay
            }
        }
        .onAppear {
            selectedIndex = 0
            progress = 0
            isPaused = false
        }
        .onChange(of: selectedIndex) { _, _ in
            progress = 0
        }
        .onReceive(timer) { _ in
            guard !slides.isEmpty else { return }
            guard autoAdvance else { return }
            guard !isPaused else { return }
            let delta = tickInterval / secondsPerSlide
            progress = min(1, progress + delta)
            if progress >= 1 {
                goForward()
            }
        }
        .gesture(exitSwipeGesture)
        .simultaneousGesture(tapAdvanceGesture)
        .simultaneousGesture(pauseGesture)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var timer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: tickInterval, on: .main, in: .common).autoconnect()
    }

    private var chromeOverlay: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                progressBar

                HStack(alignment: .top) {
                    Text(story.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            LinearGradient(
                                colors: [
                                    .black.opacity(0.55),
                                    .black.opacity(0.25),
                                    .clear,
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            in: Capsule()
                        )

                    Spacer(minLength: 0)

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .padding(10)
                            .background(.black.opacity(0.45), in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))
                    }
                    .accessibilityLabel("Close story")
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 12)

            Spacer(minLength: 0)
        }
        .allowsHitTesting(true)
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(slides.indices, id: \.self) { idx in
                GeometryReader { proxy in
                    let width = proxy.size.width
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.white.opacity(0.22))
                        Capsule()
                            .fill(.white.opacity(0.9))
                            .frame(width: width * fillAmount(for: idx))
                    }
                }
                .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Story progress")
    }

    private func fillAmount(for idx: Int) -> CGFloat {
        if idx < selectedIndex { return 1 }
        if idx > selectedIndex { return 0 }
        return CGFloat(progress)
    }

    private var emptyStoryView: some View {
        VStack(spacing: 12) {
            Image(systemName: "film")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.7))
            Text("This story has no photos.")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(24)
    }

    private var tapAdvanceGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onEnded { value in
                guard abs(value.translation.width) < 10, abs(value.translation.height) < 10 else { return }
                let x = value.location.x
                let w = UIScreen.main.bounds.width
                if x < w * 0.5 {
                    goBack()
                } else {
                    goForward()
                }
            }
    }

    private var pauseGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.18)
            .onChanged { _ in
                isPaused = true
            }
            .onEnded { _ in
                isPaused = false
            }
    }

    private var exitSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 22, coordinateSpace: .local)
            .onEnded { value in
                // Swipe up to exit (Instagram-style).
                if value.translation.height < -80 {
                    dismiss()
                }
            }
    }

    private func goForward() {
        if selectedIndex < slides.count - 1 {
            selectedIndex += 1
        } else {
            dismiss()
        }
    }

    private func goBack() {
        if selectedIndex > 0 {
            selectedIndex -= 1
        } else {
            progress = 0
        }
    }
}

#Preview {
    let story = Story(title: "Greece")
    story.slides = [
        StorySlide(order: 0, photo: PhotoEntry(storageMode: .reference, capturedDate: Date())),
        StorySlide(order: 1, photo: PhotoEntry(storageMode: .reference, capturedDate: Date())),
    ]
    return StoryViewerView(story: story)
        .caviraPreviewShell()
}

