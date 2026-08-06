//
//  ContentView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/3/21.
//

import SwiftUI
import Harbeth

// MARK: - Platform Layout Strategy
private enum StudioLayout {
    case macOSWide, macOSCompact, iOSPhone, iOSiPad

    @MainActor
    static func resolved(size: CGSize) -> StudioLayout {
        #if os(iOS)
        let idiom = UIDevice.current.userInterfaceIdiom
        if idiom == .phone { return .iOSPhone }
        return size.width >= 980 ? .macOSWide : .macOSCompact
        #else
        return size.width >= 980 ? .macOSWide : .macOSCompact
        #endif
    }
}

// MARK: - Design System Colors
fileprivate let dsAccentBlue = Color(red: 94.0 / 255.0, green: 158.0 / 255.0, blue: 255.0 / 255.0) // #5E9EFF
fileprivate let dsAccentPurple = Color(red: 167.0 / 255.0, green: 139.0 / 255.0, blue: 250.0 / 255.0) // #A78BFA
fileprivate let dsAccentGreen = Color(red: 52.0 / 255.0, green: 211.0 / 255.0, blue: 153.0 / 255.0) // #34D399
fileprivate let dsAccentAmber = Color(red: 251.0 / 255.0, green: 191.0 / 255.0, blue: 36.0 / 255.0) // #FBBF24
fileprivate let dsSurfaceDeep = Color(red: 10.0 / 255.0, green: 10.0 / 255.0, blue: 12.0 / 255.0) // #0A0A0C
fileprivate let dsSurfaceCard = Color(red: 20.0 / 255.0, green: 20.0 / 255.0, blue: 24.0 / 255.0) // #141418
fileprivate let dsSurfaceElevated = Color(red: 28.0 / 255.0, green: 28.0 / 255.0, blue: 34.0 / 255.0) // #1C1C22
fileprivate let dsGlassBg = Color.white.opacity(0.06)
fileprivate let dsGlassBorder = Color.white.opacity(0.10)
fileprivate let dsBorderSubtle = Color.white.opacity(0.06)
fileprivate let dsTextPrimary = Color.white.opacity(0.94)
fileprivate let dsTextSecondary = Color.white.opacity(0.62)
fileprivate let dsTextTertiary = Color.white.opacity(0.38)

struct ContentView: View {
    @Namespace private var showcaseNamespace
    @State private var route: ShowcaseRoute = .showcase
    @State private var showsLabs = false
    @State private var studioEntryID = UUID()
    @State private var studioSeed = StudioRecipe.heroRecipe

    @Environment(\.colorScheme) private var systemColorScheme

    var body: some View {
        ZStack {
            (systemColorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()

            if route == .showcase {
                ShowcaseHomeView(
                    namespace: showcaseNamespace,
                    openStory: openStory,
                    openLabs: { showsLabs = true }
                )
                .transition(.opacity)
            }

            if route == .studio {
                PhotoStudioView(
                    namespace: showcaseNamespace,
                    entryID: studioEntryID,
                    initialRecipe: studioSeed,
                    onBackToShowcase: {
                        withAnimation(.spring(response: 0.58, dampingFraction: 0.88)) {
                            route = .showcase
                        }
                    },
                    onOpenLabs: { showsLabs = true }
                )
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showsLabs) {
            NavigationView {
                LabsView(onDone: { showsLabs = false })
                    .inlineNavigationBarTitle("Labs")
            }
            #if os(macOS)
            .navigationViewStyle(.automatic)
            .frame(minWidth: 800, minHeight: 600)
            #endif
        }
    }

    private func openStory(_ story: StudioStory) {
        studioSeed = story.recipe
        studioEntryID = UUID()
        withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) {
            route = .studio
        }
    }
}

private enum ShowcaseRoute {
    case showcase
    case studio
}

private struct ShowcaseHomeView: View {
    let namespace: Namespace.ID
    let openStory: (StudioStory) -> Void
    let openLabs: () -> Void

    @State private var activeStoryID = StudioStory.showcaseStories[0].id
    @State private var heroSplit: CGFloat = 0.64

    private var stories: [StudioStory] {
        StudioStory.showcaseStories
    }

    private var activeStory: StudioStory {
        stories.first(where: { $0.id == activeStoryID }) ?? stories[0]
    }

    var body: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width >= 980
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    showcaseTopBar

                    if isWide {
                        HStack(alignment: .center, spacing: 28) {
                            showcaseCopy
                                .frame(maxWidth: 420, alignment: .leading)
                            ShowcaseHeroStage(
                                namespace: namespace,
                                story: activeStory,
                                splitPosition: $heroSplit
                            )
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(spacing: 24) {
                            showcaseCopy
                            ShowcaseHeroStage(
                                namespace: namespace,
                                story: activeStory,
                                splitPosition: $heroSplit
                            )
                        }
                    }

                    ShowcaseStoryPicker(
                        stories: stories,
                        activeStoryID: $activeStoryID,
                        onOpenStory: openStory
                    )

                    HStack(spacing: 0) {
                        Spacer()
                        ShowcasePageIndicator(
                            total: stories.count,
                            activeIndex: stories.firstIndex(where: { $0.id == activeStoryID }) ?? 0,
                            onSelect: { idx in
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) {
                                    activeStoryID = stories[idx].id
                                }
                            }
                        )
                        Spacer()
                    }

                    showcaseSignalStrip
                    showcaseGallery
                    showcaseLabsEntry
                }
                .padding(.horizontal, isWide ? 32 : 18)
                .padding(.top, isWide ? 24 : 16)
                .padding(.bottom, 28)
            }
            .background(
                ShowcaseBackdrop(image: activeStory.recipe.sourceImage)
            )
        }
    }

    private var showcaseTopBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Harbeth")
                    .font(.headline)
                    .foregroundColor(dsTextPrimary)
                Text("SwiftUI Showcase")
                    .font(.caption)
                    .foregroundColor(dsTextTertiary)
            }
            Spacer()
            HStack(spacing: 8) {
                Link(destination: URL(string: "https://github.com/yangKJ/Harbeth")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                        Text("GitHub")
                    }
                    .font(.caption)
                    .foregroundColor(dsTextSecondary)
                }
                ShowcaseGhostButton(title: "Open Labs", icon: "square.grid.2x2", action: openLabs)
            }
        }
    }

    private var showcaseCopy: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(activeStory.kicker.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(dsTextSecondary)

            Text(activeStory.title)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, dsAccentBlue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .fixedSize(horizontal: false, vertical: true)

            Text(activeStory.subtitle)
                .font(.subheadline)
                .foregroundColor(dsTextSecondary)

            HStack(spacing: 10) {
                CapabilityTag(text: "Image Editing")
                CapabilityTag(text: "Realtime Preview")
                CapabilityTag(text: "Final Render")
            }

            HStack(spacing: 12) {
                ShowcasePrimaryButton(title: "Start Editing") {
                    openStory(activeStory)
                }
                .accessibilityLabel("Start editing \(activeStory.title)")
                .accessibilityHint("Opens the photo studio editor with this filter recipe")
                ShowcaseGhostButton(title: "Open Labs", icon: "sparkles.tv", action: openLabs)
            }

            DisclosureGroup {
                Text(codeSnippet)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(dsTextPrimary.opacity(0.85))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(dsGlassBg, in: RoundedRectangle(cornerRadius: 10))
            } label: {
                Text("Show code snippet")
                    .font(.caption.weight(.medium))
                    .foregroundColor(dsTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var codeSnippet: String {
        return """
            // HarbethIO direct route
            guard let source = C7Image(named: "\(activeStory.recipe.sourceName.resourceName)") else { return }
            let filters: [C7FilterProtocol] = [
            \(activeStory.recipe.codeLookFilter)
                C7Exposure(exposure: \(String(format: "%.2f", activeStory.recipe.exposure))),
                C7Contrast(contrast: \(String(format: "%.2f", activeStory.recipe.contrast))),
                C7Saturation(saturation: \(String(format: "%.2f", activeStory.recipe.saturation))),
                C7Temperature(temperature: \(String(format: "%.0f", activeStory.recipe.temperature)))
            ]
            let result = try HarbethIO(element: source, filters: filters).output()
            """
    }

    private var showcaseSignalStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ShowcaseSignalPill(title: "Metal render engine", subtitle: "Texture-first output pipeline")
                ShowcaseSignalPill(title: "Preview / Final", subtitle: "Same recipe, dual-surface render")
                ShowcaseSignalPill(title: "Sharpen / Denoise", subtitle: "Unsharp mask + noise reduction")
                ShowcaseSignalPill(title: "Dual-input Blend", subtitle: "Multi-texture compositing proof")
                ShowcaseSignalPill(title: "Crop / Rotate", subtitle: "Geometry layer with resize")
            }
        }
    }

    private var showcaseLabsEntry: some View {
        Button(action: openLabs) {
            HStack(spacing: 0) {
                // Accent glow bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(dsAccentBlue)
                    .frame(width: 4)
                    .padding(.vertical, 20)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Explore Labs")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(dsTextPrimary)
                        Text("Color pipeline, composite tests, kernel experiments, and focused capability checks.")
                            .font(.subheadline)
                            .foregroundColor(dsTextSecondary)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 8) {
                            CapabilityTag(text: "LUT · Curves · HSL")
                            CapabilityTag(text: "Blend · Key · Buffer")
                            CapabilityTag(text: "Kernel Examples")
                        }
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Open Labs")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(dsAccentBlue)
                }
                .padding(22)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(dsGlassBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(dsGlassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var showcaseGallery: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Selected Frames")
                    .font(.headline)
                    .foregroundColor(dsTextPrimary)
                Spacer()
                Text("Tap a scene to jump into the studio.")
                    .font(.caption)
                    .foregroundColor(dsTextTertiary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(stories) { story in
                        ShowcaseThumbnailCard(story: story, isActive: activeStoryID == story.id) {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) {
                                activeStoryID = story.id
                            }
                            openStory(story)
                        }
                    }
                }
            }
        }
    }
}

private struct ShowcaseBackdrop: View {
    let image: C7Image

    var body: some View {
        ZStack {
            // Deep base layer
            dsSurfaceDeep.ignoresSafeArea()

            Image(c7Image: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 90)
                .scaleEffect(1.18)
                .overlay(Color.black.opacity(0.34))
                .ignoresSafeArea()

            // Subtle radial accent glow
            RadialGradient(
                colors: [
                    dsAccentBlue.opacity(0.06),
                    dsAccentBlue.opacity(0.02),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 120,
                endRadius: 600
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.48),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.52)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

private struct ShowcaseHeroStage: View {
    let namespace: Namespace.ID
    let story: StudioStory
    @Binding var splitPosition: CGFloat

    @State private var previewOutput: StudioRenderOutput?
    @State private var finalOutput: StudioRenderOutput?
    @State private var errorMessage: String?
    @State private var renderTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let errorMessage {
                StudioMessageView(message: errorMessage)
                    .frame(minHeight: 520)
            } else {
                heroCanvas
                heroFooter
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(dsSurfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(dsGlassBorder, lineWidth: 1)
        )
        .onAppear(perform: renderStory)
        .onChange(of: story.id) { _ in
            previewOutput = nil
            finalOutput = nil
            errorMessage = nil
            renderStory()
        }
        .onDisappear {
            renderTask?.cancel()
        }
    }

    @ViewBuilder
    private var heroCanvas: some View {
        if let previewOutput {
            ZStack(alignment: .bottomLeading) {
                SplitComparisonView(
                    original: story.recipe.sourceImage,
                    edited: previewOutput.image,
                    splitPosition: $splitPosition
                )
                .frame(minHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    showcaseLabel(title: "Original")
                        .padding(12)
                }
                .overlay(alignment: .topTrailing) {
                    showcaseLabel(title: previewOutput.profile.studioLabel)
                        .padding(12)
                }

                heroStageOverlay
                    .padding(18)
            }
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 420)
        }
    }

    private var heroFooter: some View {
        HStack(spacing: 12) {
            ShowcaseSignalCard(title: "Preview", subtitle: previewOutput?.summary ?? "Preparing preview surface")
            ShowcaseSignalCard(title: "Final", subtitle: finalOutput?.summary ?? "Preparing final render")
            ShowcaseSignalCard(title: "Recipe", subtitle: story.badgeText)
        }
    }

    private var heroStageOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(story.badgeText.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.6))
            Text(story.title)
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
            HStack(spacing: 8) {
                CapabilityTag(text: "Split Compare")
                CapabilityTag(text: "Metal Native")
            }
        }
        .padding(14)
        .background(dsGlassBg, in: RoundedRectangle(cornerRadius: 10))
    }

    private func showcaseLabel(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(dsTextPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(dsSurfaceElevated.opacity(0.7), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(dsGlassBorder, lineWidth: 1)
            )
    }

    private func renderStory() {
        renderTask?.cancel()
        let currentRecipe = story.recipe
        renderTask = Task.detached(priority: .userInitiated) {
            let previewResult = Result(catching: {
                try StudioRenderer.render(recipe: currentRecipe, surface: .preview)
            })
            guard !Task.isCancelled else { return }
            let finalResult = Result(catching: {
                try StudioRenderer.render(recipe: currentRecipe, surface: .export)
            })
            guard !Task.isCancelled else { return }
            await MainActor.run {
                switch previewResult {
                case .success(let output):
                    previewOutput = output
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
                switch finalResult {
                case .success(let output):
                    finalOutput = output
                case .failure(let error):
                    if errorMessage == nil {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

private struct ShowcaseStoryPicker: View {
    let stories: [StudioStory]
    @Binding var activeStoryID: UUID
    let onOpenStory: (StudioStory) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(stories) { story in
                    Button {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) {
                            activeStoryID = story.id
                        }
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            Image(c7Image: story.recipe.sourceImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 248, height: 172)
                                .clipped()

                            LinearGradient(
                                colors: [
                                    .clear,
                                    dsSurfaceCard.opacity(0.3),
                                    dsSurfaceCard.opacity(0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            VStack(alignment: .leading, spacing: 8) {
                                Text(story.kicker.uppercased())
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(dsTextSecondary)
                                Text(story.title)
                                    .font(.headline)
                                    .foregroundColor(dsTextPrimary)
                                Text(story.badgeText)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(dsAccentBlue.opacity(0.85))
                            }
                            .padding(16)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(activeStoryID == story.id ? dsGlassBg : dsSurfaceCard.opacity(0.5))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(activeStoryID == story.id ? dsAccentBlue.opacity(0.4) : dsGlassBorder, lineWidth: activeStoryID == story.id ? 1.5 : 1)
                        )
                        .scaleEffect(activeStoryID == story.id ? 1.0 : 0.96)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(story.title)
                    .accessibilityHint("Double-tap to view \(story.kicker) preview")
                    .contextMenu {
                        Button("Start Editing") {
                            onOpenStory(story)
                        }
                    }
                }
            }
        }
    }
}

private struct ShowcasePageIndicator: View {
    let total: Int
    let activeIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Button {
                    onSelect(index)
                } label: {
                    Circle()
                        .fill(index == activeIndex ? dsAccentBlue : Color.white.opacity(0.24))
                        .frame(width: 8, height: 8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct ShowcaseSignalPill: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(dsAccentBlue)
                .frame(width: 3)
                .padding(.vertical, 8)
                .padding(.trailing, 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(dsTextPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(dsTextTertiary)
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 14)
        .background(dsGlassBg, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(dsGlassBorder, lineWidth: 1)
        )
    }
}

private struct ShowcaseThumbnailCard: View {
    let story: StudioStory
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Image(c7Image: story.recipe.sourceImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 280, height: 210)
                    .clipped()

                // Glass gradient overlay
                LinearGradient(
                    colors: [
                        .clear,
                        dsSurfaceCard.opacity(0.4),
                        dsSurfaceCard.opacity(0.92)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 8) {
                    if isActive {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(dsAccentBlue)
                            .frame(width: 24, height: 3)
                    }
                    Text(story.title)
                        .font(.headline)
                        .foregroundColor(dsTextPrimary)
                    Text(story.cardSummary)
                        .font(.caption)
                        .foregroundColor(dsTextSecondary)
                    HStack {
                        CapabilityTag(text: story.badgeText)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(dsTextSecondary)
                    }
                }
                .padding(16)
            }
            .frame(width: 280, height: 210)
            .background(dsGlassBg, in: RoundedRectangle(cornerRadius: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isActive ? dsAccentBlue.opacity(0.5) : dsGlassBorder, lineWidth: isActive ? 1.5 : 1)
            )
            .scaleEffect(isActive ? 1.02 : 0.98)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isActive)
        .accessibilityLabel(story.title)
        .accessibilityHint("Double-tap to open \(story.kicker) in the studio editor")
    }
}

private struct ShowcaseBandCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(dsTextPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(dsTextSecondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(dsGlassBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(dsGlassBorder, lineWidth: 1)
        )
    }
}

private struct ShowcaseResultCard: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(dsTextPrimary)
            Text(detail)
                .font(.subheadline)
                .foregroundColor(dsTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(dsGlassBg)
        )
    }
}

private struct ShowcaseSignalCard: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(dsTextSecondary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(dsTextPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(dsGlassBg)
        )
    }
}

private struct ShowcasePrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(dsAccentBlue)
                )
                .shadow(color: dsAccentBlue.opacity(0.35), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

private struct ShowcaseGhostButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.medium))
                .foregroundColor(dsTextSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(dsGlassBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(dsGlassBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct CapabilityTag: View {
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dsAccentBlue.opacity(0.7))
                .frame(width: 5, height: 5)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundColor(dsTextPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(dsGlassBg, in: Capsule())
        .overlay(
            Capsule()
                .stroke(dsGlassBorder, lineWidth: 1)
        )
    }
}

private struct AdaptiveShowcaseGrid<Content: View>: View {
    let minimumWidth: CGFloat
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: spacing, alignment: .top)],
            alignment: .leading,
            spacing: spacing
        ) {
            content
        }
    }
}

private struct PhotoStudioView: View {
    let namespace: Namespace.ID
    let entryID: UUID
    let initialRecipe: StudioRecipe
    let onBackToShowcase: () -> Void
    let onOpenLabs: () -> Void

    @State private var recipe: StudioRecipe
    @State private var selectedTool: StudioToolGroup = .looks
    @State private var comparisonMode: StudioComparisonMode = .edited
    @State private var activeRenderSurface: StudioRenderSurface = .preview
    @State private var previewOutput: StudioRenderOutput?
    @State private var exportOutput: StudioRenderOutput?
    @State private var renderError: String?
    @State private var isRendering = false
    @State private var renderGeneration = UUID()
    @State private var splitPosition: CGFloat = 0.52
    @State private var renderTask: Task<Void, Never>?
    @State private var isSaving = false
    @State private var isParamExpanded = false

    init(
        namespace: Namespace.ID,
        entryID: UUID,
        initialRecipe: StudioRecipe,
        onBackToShowcase: @escaping () -> Void,
        onOpenLabs: @escaping () -> Void
    ) {
        self.namespace = namespace
        self.entryID = entryID
        self.initialRecipe = initialRecipe
        self.onBackToShowcase = onBackToShowcase
        self.onOpenLabs = onOpenLabs
        _recipe = State(initialValue: initialRecipe)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = StudioLayout.resolved(size: proxy.size)
            ZStack {
                StudioBackdrop(image: activeOutput?.image ?? recipe.sourceImage)
                switch layout {
                case .macOSWide:
                    macOSWideBody(proxy: proxy)
                case .macOSCompact:
                    macOSCompactBody(proxy: proxy)
                case .iOSPhone:
                    iOSPhoneBody(proxy: proxy)
                case .iOSiPad:
                    macOSWideBody(proxy: proxy)
                }
            }
            .onAppear(perform: refreshRenders)
            .onChange(of: recipe) { _ in
                refreshRenders()
            }
            .onDisappear {
                renderTask?.cancel()
            }
        }
        .id(entryID)
    }

    @ViewBuilder
    private func studioTopBar(isWide: Bool) -> some View {
        if isWide {
            HStack(spacing: 12) {
                backButton
                Spacer()
                HStack(spacing: 10) {
                    studioTopChip(title: recipe.sourceName.title)
                    studioTopChip(title: activeRenderSurface.title)
                    controlsMenu
                    saveShareButton
                    labsButton
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    backButton
                    Spacer(minLength: 0)
                    saveShareButton
                    labsButton
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        studioTopChip(title: recipe.sourceName.title)
                        studioTopChip(title: activeRenderSurface.title)
                        controlsMenu
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var saveShareButton: some View {
        Button {
            saveImage()
        } label: {
            HStack(spacing: 6) {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                Text("Export")
            }
            .font(.caption.weight(.medium))
            .foregroundColor(dsTextPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(dsGlassBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(dsGlassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSaving || (activeOutput == nil && exportOutput == nil))
        .fixedSize(horizontal: true, vertical: false)
    }

    private func saveImage() {
        guard let image = (activeOutput?.image ?? exportOutput?.image) else { return }
        isSaving = true
        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Harbeth_Export.png"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let data = image.pngData() {
                    try? data.write(to: url)
                }
            }
            isSaving = false
        }
        #else
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        isSaving = false
        #endif
    }

    private var backButton: some View {
        Button(action: onBackToShowcase) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                Text("Showcase")
            }
            .accessibilityLabel("Back to Showcase")
            .accessibilityHint("Returns to the filter story gallery")
            .font(.subheadline.weight(.semibold))
            .foregroundColor(dsTextSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(dsGlassBg, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(dsGlassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var controlsMenu: some View {
        Menu {
            sourcePickerMenu
            Divider()
            profileMenu
            Divider()
            Button("Reset Recipe", action: resetRecipe)
        } label: {
            studioTopChip(title: "Controls", icon: "slider.horizontal.3")
        }
    }

    private var labsButton: some View {
        Button(action: onOpenLabs) {
            studioTopChip(title: "Labs", icon: "square.grid.2x2")
        }
        .buttonStyle(.plain)
    }

    private func studioTopChip(title: String, icon: String? = nil, compact: Bool = false) -> some View {
        HStack(spacing: compact ? 4 : 6) {
            if let icon {
                Image(systemName: icon)
                #if os(iOS)
                    .font(compact ? .caption2 : .caption)
                #endif
            }
            Text(title)
        }
        .font(compact ? .caption2 : .caption.weight(.semibold))
        .foregroundColor(dsTextPrimary)
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 6 : 8)
        .background(dsGlassBg, in: Capsule())
        .overlay(
            Capsule()
                .stroke(dsGlassBorder, lineWidth: 1)
        )
        .fixedSize(horizontal: true, vertical: false)
    }

    private var sourcePickerMenu: some View {
        Group {
            Picker("Source", selection: $recipe.sourceName) {
                ForEach(StudioSourceAsset.editingCases) { asset in
                    Text(asset.title).tag(asset)
                }
            }
        }
    }

    private var profileMenu: some View {
        Group {
            Picker("Preview Profile", selection: $recipe.previewProfile) {
                ForEach(StudioRecipe.previewProfiles, id: \.self) { profile in
                    Text(profile.studioLabel).tag(profile)
                }
            }
            Picker("Final Profile", selection: $recipe.exportProfile) {
                ForEach(StudioRecipe.exportProfiles, id: \.self) { profile in
                    Text(profile.studioLabel).tag(profile)
                }
            }
        }
    }

    private func studioCanvas(isCompact: Bool, canvasStageHeight: CGFloat? = nil) -> some View {
        let stageHeight = canvasStageHeight ?? 420
        return VStack(alignment: .leading, spacing: 16) {
            if isCompact {
                VStack(alignment: .leading, spacing: 12) {
                    studioCanvasTitle(isCompact: true)
                    comparisonPicker
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: 12) {
                    studioCanvasTitle(isCompact: false)
                    Spacer()
                    comparisonPicker
                }
            }

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(dsSurfaceCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(dsBorderSubtle, lineWidth: 1)
                    )

                canvasStage(height: stageHeight)
                    .padding(18)

                VStack(alignment: .leading, spacing: 12) {
                    renderBadgeStrip
                    if activeOutput != nil {
                        floatingModeStrip
                    }
                }
                    .padding(18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(StudioSourceAsset.editingCases) { asset in
                        StudioAssetPill(
                            title: asset.title,
                            isSelected: recipe.sourceName == asset
                        ) {
                            recipe = StudioRecipe.seed(for: asset)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func studioCanvasTitle(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(recipe.sourceName.heroTitle)
                .font((isCompact ? Font.title3 : Font.title2).weight(.semibold))
                .foregroundColor(dsTextPrimary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
            Text(recipe.sourceName.heroSubtitle)
                .font(.subheadline)
                .foregroundColor(dsTextSecondary)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
            studioRecipeSummary
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var comparisonPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StudioComparisonMode.allCases) { mode in
                    Button {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                            comparisonMode = mode
                        }
                    } label: {
                        Text(mode.title)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(comparisonMode == mode ? .white : dsTextSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(comparisonMode == mode ? dsAccentBlue : dsGlassBg)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(comparisonMode == mode ? dsAccentBlue.opacity(0.4) : dsGlassBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(-1)
    }

    private var studioRecipeSummary: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                StudioMetaPill(title: recipe.lookPreset.title)
                StudioMetaPill(title: recipe.resizeQuality.title)
                StudioMetaPill(title: recipe.cropMode.title)
                if recipe.noiseReduction > 0.05 {
                    StudioMetaPill(title: "Denoise")
                }
                if recipe.sharpen > 0.05 {
                    StudioMetaPill(title: "Sharpen")
                }
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func canvasStage(height: CGFloat = 420) -> some View {
        if let renderError {
            StudioMessageView(message: renderError)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isRendering && previewOutput == nil && exportOutput == nil {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                Text("Processing filters via Metal GPU pipeline...")
                    .font(.caption)
                    .foregroundColor(dsTextTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch comparisonMode {
            case .original:
                PreviewImageCard(title: "Original", image: recipe.sourceImage, height: height)
            case .edited:
                if let output = activeOutput {
                    PreviewImageCard(title: activeRenderSurface.previewTitle, image: output.image, height: height)
                } else {
                    StudioMessageView(message: "No rendered output.")
                }
            case .split:
                if let output = activeOutput {
                    SplitComparisonView(
                        original: recipe.sourceImage,
                        edited: output.image,
                        splitPosition: $splitPosition
                    )
                    .frame(minHeight: height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    StudioMessageView(message: "No rendered output.")
                }
            }
        }
    }

    private var renderBadgeStrip: some View {
        HStack(spacing: 10) {
            if let previewOutput {
                renderBadge(title: "Preview", value: previewOutput.profile.studioLabel)
            }
            if let exportOutput {
                renderBadge(title: "Final", value: exportOutput.profile.studioLabel)
            }
        }
    }

    private var floatingModeStrip: some View {
        HStack(spacing: 12) {
            ForEach(StudioToolGroup.editingCases) { group in
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                        selectedTool = group
                    }
                } label: {
                    Image(systemName: group.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(selectedTool == group ? .white : dsTextSecondary)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(selectedTool == group ? dsAccentBlue : dsGlassBg)
                        )
                        .overlay(
                            Circle()
                                .stroke(selectedTool == group ? dsAccentBlue.opacity(0.4) : dsGlassBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func renderBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(dsTextTertiary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(dsTextPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(dsSurfaceElevated.opacity(0.6), in: Capsule())
        .overlay(
            Capsule()
                .stroke(dsGlassBorder, lineWidth: 1)
        )
    }

    private var studioInspector: some View {
        VStack(alignment: .leading, spacing: 20) {
            StudioToolRail(selectedTool: $selectedTool)
            activeToolPanel(isCompact: false)
            StudioStatusCard(recipe: recipe, previewOutput: previewOutput, exportOutput: exportOutput)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(dsSurfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(dsBorderSubtle, lineWidth: 1)
        )
    }

    private var compactStudioControls: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(dsTextTertiary)
                .frame(width: 38, height: 4)
                .padding(.top, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(StudioToolGroup.editingCases) { group in
                        Button {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                                selectedTool = group
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: group.symbolName)
                            }
                            .foregroundColor(selectedTool == group ? .white : dsTextSecondary)
                            .frame(width: 58, height: 58)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedTool == group ? dsAccentBlue : dsGlassBg)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedTool == group ? dsAccentBlue.opacity(0.4) : dsGlassBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            activeToolPanel(isCompact: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(dsSurfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(dsBorderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func activeToolPanel(isCompact: Bool) -> some View {
        switch selectedTool {
        case .looks:
            StudioPanelCard(title: "Looks", subtitle: "Shape the mood before touching the technical knobs.") {
                AdaptiveShowcaseGrid(minimumWidth: 132, spacing: 10) {
                    ForEach(StudioLookPreset.allCases) { preset in
                        StudioPresetCard(
                            title: preset.title,
                            subtitle: preset.subtitle,
                            isSelected: recipe.lookPreset == preset
                        ) {
                            recipe.lookPreset = preset
                        }
                    }
                }

                Picker("Curve", selection: $recipe.curvePreset) {
                    ForEach(StudioCurvePreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(isCompact ? AnyLayoutPickerStyle.menu : AnyLayoutPickerStyle.segmented)
            }
        case .adjust:
            StudioPanelCard(title: "Adjust", subtitle: "Exposure, tone, and warmth remain immediate and cinematic.") {
                FilterSlider(title: "Exposure", value: $recipe.exposure, range: -1.2...1.2)
                FilterSlider(title: "Contrast", value: $recipe.contrast, range: 0.6...1.8)
                FilterSlider(title: "Saturation", value: $recipe.saturation, range: 0...2)
                FilterSlider(title: "Temperature", value: $recipe.temperature, range: 3500...7600, format: "%.0f")
            }
        case .crop:
            StudioPanelCard(title: "Crop", subtitle: "Frame the image first, then let the edit breathe.") {
                Picker("Crop", selection: $recipe.cropMode) {
                    ForEach(StudioCropMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(isCompact ? AnyLayoutPickerStyle.menu : AnyLayoutPickerStyle.segmented)

                Picker("Rotation", selection: $recipe.rotationDegrees) {
                    Text("0°").tag(Float(0))
                    Text("-90°").tag(Float(-90))
                    Text("90°").tag(Float(90))
                }
                .pickerStyle(isCompact ? AnyLayoutPickerStyle.menu : AnyLayoutPickerStyle.segmented)

                Picker("Surface", selection: $activeRenderSurface) {
                    ForEach(StudioRenderSurface.allCases) { surface in
                        Text(surface.title).tag(surface)
                    }
                }
                .pickerStyle(isCompact ? AnyLayoutPickerStyle.menu : AnyLayoutPickerStyle.segmented)
            }
        case .detail:
            StudioPanelCard(title: "Detail", subtitle: "Recover sharpness and suppress noise without over-explaining the pipeline.") {
                FilterSlider(title: "Sharpen", value: $recipe.sharpen, range: 0...1.6)
                FilterSlider(title: "Denoise", value: $recipe.noiseReduction, range: 0...1)
                FilterSlider(title: "Edge Preserve", value: $recipe.edgePreservation, range: 0.2...0.95)
                Picker("Resize", selection: $recipe.resizeQuality) {
                    ForEach(StudioResizeQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }
                .pickerStyle(isCompact ? AnyLayoutPickerStyle.menu : AnyLayoutPickerStyle.segmented)
            }
        case .blend:
            StudioPanelCard(title: "Blend", subtitle: "Use the second input as a visual proof of Harbeth's compositing layer.") {
                Picker("Blend", selection: $recipe.blendMode) {
                    ForEach(StudioRecipe.blendModes) { mode in
                        Text(mode.kernel).tag(mode)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                FilterSlider(title: "Intensity", value: $recipe.blendIntensity, range: 0...1)
                Text("Composite stays part of the frame processor. The Demo does not turn it into a media workflow.")
                    .font(.caption)
                    .foregroundColor(dsTextTertiary)
            }
        }
    }

    @available(*, deprecated, message: "Use FilterSlider instead")
    private func sliderRow(
        title: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        format: String = "%.2f"
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .foregroundColor(.white.opacity(0.62))
            }
            Slider(value: value, in: range)
                .tint(.white)
        }
    }

    private var activeOutput: StudioRenderOutput? {
        switch activeRenderSurface {
        case .preview:
            return previewOutput
        case .export:
            return exportOutput
        }
    }

    private func resetRecipe() {
        recipe = StudioRecipe.seed(for: recipe.sourceName)
    }

    private func refreshRenders() {
        renderTask?.cancel()
        let currentGeneration = UUID()
        let currentRecipe = recipe
        renderGeneration = currentGeneration
        renderError = nil
        isRendering = true

        renderTask = Task.detached(priority: .userInitiated) {
            let previewResult = Result(catching: {
                try StudioRenderer.render(recipe: currentRecipe, surface: .preview)
            })
            guard !Task.isCancelled else { return }
            let exportResult = Result(catching: {
                try StudioRenderer.render(recipe: currentRecipe, surface: .export)
            })
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard renderGeneration == currentGeneration else { return }
                isRendering = false
                switch previewResult {
                case .success(let output):
                    previewOutput = output
                case .failure(let error):
                    previewOutput = nil
                    renderError = error.localizedDescription
                }
                switch exportResult {
                case .success(let output):
                    exportOutput = output
                case .failure(let error):
                    exportOutput = nil
                    if renderError == nil {
                        renderError = error.localizedDescription
                    }
                }
            }
        }
    }

    // MARK: - Platform Body Methods

    private func macOSWideBody(proxy: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            studioTopBar(isWide: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)
            HStack(spacing: 20) {
                studioCanvas(isCompact: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                ScrollView(.vertical, showsIndicators: false) {
                    studioInspector
                }
                .frame(width: 340)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
        }
        //.frame(minWidth: proxy.size.width, maxHeight: proxy.size.height, alignment: .topLeading)
    }

    private func macOSCompactBody(proxy: GeometryProxy) -> some View {
        let compactWidth = max(proxy.size.width - 32, 0)
        return VStack(spacing: 0) {
            studioTopBar(isWide: false)
                .frame(maxWidth: compactWidth, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    studioCanvas(isCompact: true)
                        .frame(width: compactWidth, alignment: .leading)
                        .frame(minHeight: 420)
                    compactStudioControls
                        .frame(width: compactWidth, alignment: .leading)
                }
                .frame(width: compactWidth, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
            }
        }
        .frame(minWidth: proxy.size.width, minHeight: proxy.size.height, alignment: .topLeading)
    }

    private func iOSPhoneBody(proxy: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top bar 44pt — backButton + source · renderSurface chips only
            HStack(spacing: 8) {
                backButton
                Spacer()
                studioTopChip(title: recipe.sourceName.title, compact: true)
                studioTopChip(title: activeRenderSurface.title, compact: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(height: 44)
            .background(dsGlassBg)

            // Full-screen canvas area
            studioCanvas(isCompact: true, canvasStageHeight: 280)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            // Asset horizontal scroll bar 36pt
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(StudioSourceAsset.editingCases) { asset in
                        StudioAssetPillCompact(
                            title: asset.title,
                            isSelected: recipe.sourceName == asset
                        ) {
                            recipe = StudioRecipe.seed(for: asset)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 36)

            // Bottom toolbar 56pt — 4 tool icons + export
            HStack(spacing: 16) {
                ForEach(StudioToolGroup.editingCases) { group in
                    Button {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                            if selectedTool == group {
                                isParamExpanded.toggle()
                            } else {
                                selectedTool = group
                                isParamExpanded = true
                            }
                        }
                    } label: {
                        Image(systemName: group.symbolName)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(selectedTool == group ? .white : dsTextSecondary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(selectedTool == group ? dsAccentBlue : dsGlassBg)
                            )
                            .overlay(
                                Circle()
                                    .stroke(selectedTool == group ? dsAccentBlue.opacity(0.4) : dsGlassBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                saveShareButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(height: 56)
            .background(dsGlassBg)

            // Parameter panel — slides up from bottom when a tool is selected
            if isParamExpanded {
                VStack(spacing: 0) {
                    Capsule()
                        .fill(dsTextTertiary)
                        .frame(width: 38, height: 4)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    ScrollView {
                        activeToolPanel(isCompact: true)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                }
                .frame(maxHeight: proxy.size.height * 0.45)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(dsSurfaceCard)
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(minWidth: proxy.size.width, minHeight: proxy.size.height, alignment: .topLeading)
    }
}

private struct StudioBackdrop: View {
    let image: C7Image

    var body: some View {
        ZStack {
            dsSurfaceDeep.ignoresSafeArea()

            Image(c7Image: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 100)
                .scaleEffect(1.16)
                .overlay(Color.black.opacity(0.40))
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.50),
                    Color.black.opacity(0.16),
                    Color.black.opacity(0.54)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

private struct SplitComparisonView: View {
    let original: C7Image
    let edited: C7Image
    @Binding var splitPosition: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(splitPosition, 0.08), 0.92)
            ZStack(alignment: .leading) {
                Image(c7Image: edited)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Image(c7Image: original)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle().frame(width: proxy.size.width * clamped)
                            Spacer(minLength: 0)
                        }
                    )

                Rectangle()
                    .fill(dsAccentBlue.opacity(0.8))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .offset(x: proxy.size.width * clamped)

                Circle()
                    .fill(dsAccentBlue)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "arrow.left.and.right")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: dsAccentBlue.opacity(0.4), radius: 8, x: 0, y: 2)
                    .offset(x: proxy.size.width * clamped - 17)
                    .frame(maxHeight: .infinity)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        splitPosition = gesture.location.x / max(proxy.size.width, 1)
                    }
            )
        }
    }
}

private struct StudioToolRail: View {
    @Binding var selectedTool: StudioToolGroup

    var body: some View {
        AdaptiveShowcaseGrid(minimumWidth: 100, spacing: 10) {
            ForEach(StudioToolGroup.editingCases) { group in
                Button {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        selectedTool = group
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: group.symbolName)
                            .font(.headline)
                        Text(group.title)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(selectedTool == group ? .white : dsTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedTool == group ? dsAccentBlue : dsGlassBg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedTool == group ? dsAccentBlue.opacity(0.4) : dsGlassBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct StudioMetaPill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundColor(dsTextSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(dsGlassBg, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(dsGlassBorder, lineWidth: 1)
            )
    }
}

private struct StudioPresetCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(isSelected ? dsTextPrimary.opacity(0.8) : dsTextTertiary)
            }
            .foregroundColor(isSelected ? dsTextPrimary : dsTextSecondary)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? dsAccentBlue.opacity(0.25) : dsGlassBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? dsAccentBlue.opacity(0.45) : dsGlassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct StudioPanelCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(dsTextPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(dsTextSecondary)
            }
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(dsSurfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(dsBorderSubtle, lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum AnyLayoutPickerStyle {
    case segmented
    case menu
}

private extension View {
    @ViewBuilder
    func pickerStyle(_ style: AnyLayoutPickerStyle) -> some View {
        switch style {
        case .segmented:
            self.pickerStyle(SegmentedPickerStyle())
        case .menu:
            self.pickerStyle(MenuPickerStyle())
        }
    }
}

private struct FilterSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    var format: String = "%.2f"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundColor(dsTextPrimary)
                Spacer()
                Text(String(format: format, value))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundColor(dsAccentBlue)
            }
            Slider(value: $value, in: range)
                .accentColor(dsAccentBlue)
        }
    }
}

private struct StudioStatusCard: View {
    let recipe: StudioRecipe
    let previewOutput: StudioRenderOutput?
    let exportOutput: StudioRenderOutput?

    var body: some View {
        StudioPanelCard(
            title: "Render Contract",
            subtitle: "A compact readout that stays available without taking over the screen."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                statusRow(title: "Preview", value: previewOutput?.summary ?? recipe.previewProfile.studioLabel)
                statusRow(title: "Final", value: exportOutput?.summary ?? recipe.exportProfile.studioLabel)
                statusRow(title: "Blend", value: recipe.blendIntensity > 0.01 ? recipe.blendMode.kernel : "Off")
            }
        }
    }

    private func statusRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(dsTextSecondary)
            Text(value)
                .font(.caption)
                .foregroundColor(dsTextSecondary)
        }
    }
}

private struct StudioAssetPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(isSelected ? .white : dsTextSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(isSelected ? dsAccentBlue : dsGlassBg)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? dsAccentBlue.opacity(0.4) : dsGlassBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct StudioAssetPillCompact: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundColor(isSelected ? .white : dsTextSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? dsAccentBlue : dsGlassBg)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? dsAccentBlue.opacity(0.4) : dsGlassBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct PreviewImageCard: View {
    let title: String
    let image: C7Image
    var height: CGFloat = 280

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(dsTextSecondary)
            Image(c7Image: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(dsSurfaceCard.opacity(0.6))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StudioMessageView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(dsAccentAmber)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(dsTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(dsGlassBg)
        )
    }
}

private struct LabsView: View {
    let onDone: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Focused Capability Checks")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(dsTextPrimary)
                    Text("Labs stays behind the Showcase. It keeps the narrow experiments, integration checks, and filter-specific surfaces available without defining the product story.")
                        .font(.subheadline)
                        .foregroundColor(dsTextSecondary)
                    HStack(spacing: 8) {
                        CapabilityTag(text: "Color")
                        CapabilityTag(text: "Composite")
                        CapabilityTag(text: "Runtime")
                    }
                }

                LabsSectionCard(title: "Color") {
                    NavigationLink(destination: CubeView()) {
                        LabsRow(title: "LUT Pipeline", subtitle: "3D LUT and cube resource loading")
                    }
                    NavigationLink(destination: CurvesView()) {
                        LabsRow(title: "Curves", subtitle: "RGB and channel curve shaping")
                    }
                    NavigationLink(destination: HSLView()) {
                        LabsRow(title: "HSL", subtitle: "Hue, saturation, and lightness adjustment")
                    }
                    NavigationLink(destination: ColorRGBAView()) {
                        LabsRow(title: "RGBA Controls", subtitle: "Channel-level color tuning")
                    }
                }

                LabsSectionCard(title: "Composite and Runtime") {
                    NavigationLink(destination: BlendView()) {
                        LabsRow(title: "Blend", subtitle: "Two-input compositing and blend modes")
                    }
                    NavigationLink(destination: ChromaKeyView()) {
                        LabsRow(title: "Chroma Key", subtitle: "Alpha extraction and keying")
                    }
                    NavigationLink(destination: DoubleBufferView()) {
                        LabsRow(title: "Double Buffer", subtitle: "Texture reuse and frame throughput checks")
                    }
                    NavigationLink(destination: MetalKernelViews()) {
                        LabsRow(title: "Kernel Examples", subtitle: "Focused experiments and custom filter coverage")
                    }
                }

                LabsSectionCard(title: "Additional Checks") {
                    NavigationLink(destination: HighlightShadowToneView()) {
                        LabsRow(title: "Highlight and Shadow", subtitle: "Tone recovery and local contrast")
                    }
                    NavigationLink(destination: ChannelControlView()) {
                        LabsRow(title: "Channel Isolation", subtitle: "Selective channel routing")
                    }
                    NavigationLink(destination: CustomViews(
                        value: MPSGaussianBlur.range.value,
                        filtering: { MPSGaussianBlur(radius: $0) },
                        min: MPSGaussianBlur.range.min,
                        max: MPSGaussianBlur.range.max
                    )) {
                        LabsRow(title: "Gaussian Blur", subtitle: "Focused MPS capability check")
                    }
                }
            }
            .padding(20)
        }
        .background(
            ZStack {
                dsSurfaceDeep.ignoresSafeArea()
                RadialGradient(
                    colors: [dsAccentPurple.opacity(0.04), Color.clear],
                    center: .top,
                    startRadius: 100,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }
        )
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done", action: onDone)
            }
        }
    }
}

private struct LabsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundColor(dsTextPrimary)
            VStack(spacing: 10) {
                content
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(dsGlassBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(dsGlassBorder, lineWidth: 1)
        )
    }
}

private struct LabsRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(dsTextPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(dsTextSecondary)
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(dsTextTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(dsSurfaceCard.opacity(0.5))
        )
    }
}

private struct StudioStory: Identifiable {
    let id = UUID()
    let kicker: String
    let title: String
    let subtitle: String
    let cardSummary: String
    let badgeText: String
    let recipe: StudioRecipe

    var matchID: String {
        recipe.sourceName.resourceName + "-hero"
    }

    static var showcaseStories: [StudioStory] {
        [
            StudioStory(
                kicker: "Portrait Editing",
                title: "Shape skin, fabric, and contrast without leaving the frame.",
                subtitle: "A cinematic portrait path with tone, warmth, and detail layered into one render story.",
                cardSummary: "Looks, curves, temperature, and detail tuned for a dark portrait stage.",
                badgeText: "Portrait / LUT / Detail",
                recipe: .seed(for: .gothicPortrait)
            ),
            StudioStory(
                kicker: "Street And Motion",
                title: "Let the preview move fast while the final render stays deliberate.",
                subtitle: "Harbeth keeps preview and final semantics close to the image instead of burying them in setup code.",
                cardSummary: "A low-latency street recipe with crop, contrast, and layered clarity.",
                badgeText: "Street / Preview / Final",
                recipe: .seed(for: .img2606)
            ),
            StudioStory(
                kicker: "Outdoor Showcase",
                title: "Push color, edge contrast, and export presence for a promo-grade image.",
                subtitle: "The Showcase can feel bold and dramatic while still running through the same recipe pipeline.",
                cardSummary: "High-chroma snow rider demo tuned for quality and obvious before/after payoff.",
                badgeText: "Outdoor / Export / Tone",
                recipe: .seed(for: .snowRider)
            ),
            StudioStory(
                kicker: "Warm Portrait",
                title: "Layer glow, curve shaping, and blend intensity into a polished portrait finish.",
                subtitle: "Harbeth's compositing layer remains transparent while delivering multi-input results.",
                cardSummary: "A cinematic portrait recipe with soft blend, faded curves, and temperature warmth.",
                badgeText: "Portrait / Blend / Warmth",
                recipe: .seed(for: .img0020)
            ),
            StudioStory(
                kicker: "Color Adjustment",
                title: "Saturation, exposure, and temperature control driven by the same GPU pipeline.",
                subtitle: "Adjustments remain reactive at preview quality and accurate at final export resolution.",
                cardSummary: "Bear asset tuned for exposure, temperature, and saturation demonstration.",
                badgeText: "Adjust / Exposure / Temp",
                recipe: .seed(for: .bear)
            )
        ]
    }
}

private struct StudioRenderer {
    static func render(recipe: StudioRecipe, surface: StudioRenderSurface) throws -> StudioRenderOutput {
        let profile = surface == .preview ? recipe.previewProfile : recipe.exportProfile
        let source = recipe.sourceImage
        let filters = try recipe.filters(source: source, surface: surface)
        let frame = try ImageNode
            .image(source)
            .applying(filters: filters)
            .makeFrame(profile: profile)
        guard let image = try frame.makeImage() else {
            throw HarbethError.texture2Image
        }
        let size = image.pixelSize
        let summary = "\(profile.studioLabel) · \(Int(size.width))x\(Int(size.height)) · \(filters.count) filters"
        return StudioRenderOutput(image: image, profile: profile, summary: summary)
    }
}

private struct StudioRenderOutput {
    let image: C7Image
    let profile: RenderProfile
    let summary: String
}

private struct FilterParameter<T: Hashable>: Identifiable where T: CaseIterable & Identifiable {
    let id: T
    let title: String
    let range: ClosedRange<Float>?
    let defaultValue: Float?

    static func all(from cases: T.Type, titles: [T: String]) -> [FilterParameter<T>] {
        T.allCases.map { FilterParameter(id: $0, title: titles[$0] ?? "\($0)", range: nil, defaultValue: nil) }
    }
}

private struct StudioRecipe: Equatable, @unchecked Sendable {
    struct HSLAdjustment: Equatable {
        var hue: Float = 0
        var saturation: Float = 0
        var lightness: Float = 0
    }

    static let previewProfiles: [RenderProfile] = [
        .interactiveLatency,
        .responseLatency,
        .stablePreview,
        .inspectionQuality
    ]

    static let exportProfiles: [RenderProfile] = [
        .exportQuality,
        .readbackQuality
    ]

    static let blendModes: [C7Blend.BlendType] = [
        .normal,
        .overlay,
        .softLight,
        .screen,
        .multiply,
        .sourceOver
    ]

    static var heroRecipe: StudioRecipe {
        seed(for: .gothicPortrait)
    }

    static func seed(for source: StudioSourceAsset) -> StudioRecipe {
        var recipe = StudioRecipe()
        recipe.sourceName = source

        switch source {
        case .img2606:
            recipe.lookPreset = .cinematic
            recipe.curvePreset = .liftedContrast
            recipe.exposure = 0.06
            recipe.contrast = 1.14
            recipe.saturation = 1.04
            recipe.temperature = 5200
            recipe.sharpen = 0.34
            recipe.noiseReduction = 0.08
            recipe.cropMode = .cinematic169
            recipe.previewProfile = .stablePreview
            recipe.exportProfile = .exportQuality
        case .img0020:
            recipe.lookPreset = .vintage
            recipe.curvePreset = .fade
            recipe.exposure = 0.08
            recipe.contrast = 1.06
            recipe.saturation = 0.96
            recipe.temperature = 5850
            recipe.sharpen = 0.28
            recipe.noiseReduction = 0.14
            recipe.cropMode = .portrait45
            recipe.blendIntensity = 0.12
        case .gothicPortrait:
            recipe.lookPreset = .mono
            recipe.curvePreset = .liftedContrast
            recipe.exposure = -0.06
            recipe.contrast = 1.18
            recipe.saturation = 0.84
            recipe.temperature = 5050
            recipe.sharpen = 0.46
            recipe.noiseReduction = 0.16
            recipe.cropMode = .portrait45
            recipe.blendMode = .softLight
            recipe.blendIntensity = 0.24
            recipe.previewProfile = .stablePreview
            recipe.exportProfile = .exportQuality
        case .snowRider:
            recipe.lookPreset = .cinematic
            recipe.curvePreset = .liftedContrast
            recipe.exposure = 0.12
            recipe.contrast = 1.24
            recipe.saturation = 1.18
            recipe.temperature = 4800
            recipe.sharpen = 0.54
            recipe.noiseReduction = 0.1
            recipe.cropMode = .portrait45
            recipe.previewProfile = .responseLatency
            recipe.exportProfile = .readbackQuality
        case .bear:
            recipe.lookPreset = .clean
            recipe.curvePreset = .none
            recipe.exposure = 0
            recipe.contrast = 1
            recipe.saturation = 1
            recipe.temperature = 5600
            recipe.sharpen = 0.22
            recipe.noiseReduction = 0
            recipe.cropMode = .original
        }

        return recipe
    }

    var sourceName: StudioSourceAsset = .img2606
    var lookPreset: StudioLookPreset = .cinematic
    var exposure: Float = 0.08
    var contrast: Float = 1.08
    var saturation: Float = 1.05
    var temperature: Float = 5600
    var hsl = HSLAdjustment()
    var curvePreset: StudioCurvePreset = .liftedContrast
    var sharpen: Float = 0.35
    var noiseReduction: Float = 0.12
    var cropMode: StudioCropMode = .original
    var blendMode: C7Blend.BlendType = .softLight
    var previewProfile: RenderProfile = .stablePreview
    var exportProfile: RenderProfile = .exportQuality
    var rotationDegrees: Float = 0
    var resizeQuality: StudioResizeQuality = .lanczos
    var edgePreservation: Float = 0.82
    var blendIntensity: Float = 0.18

    var sourceImage: C7Image {
        R.image(sourceName.resourceName) ?? R.image("IMG_2606")!
    }

    var codeLookFilter: String {
        switch lookPreset {
        case .clean:
            return ""
        case .cinematic:
            return "    C7ColorCube(cubeName: \"violet\", intensity: 0.8),"
        case .vintage:
            return "    C7ColorCube(cubeName: \"vista200 v1\", intensity: 0.9),"
        case .mono:
            return "    C7LookupTable1D(name: \"bw_vintage_curves1\", intensity: 0.95),"
        }
    }

    func filters(source: C7Image, surface: StudioRenderSurface) throws -> [C7FilterProtocol] {
        var filters: [C7FilterProtocol] = []

        if let geometryFilter = geometryFilter(for: source) {
            filters.append(geometryFilter)
        }
        if rotationDegrees != 0 {
            filters.append(C7Rotate(mode: .fit, angle: rotationDegrees))
        }

        filters.append(contentsOf: lookFilters())
        filters.append(C7Exposure(exposure: exposure))
        filters.append(C7Contrast(contrast: contrast))
        filters.append(C7Saturation(saturation: saturation))
        filters.append(C7Temperature(temperature: temperature))

        if hsl != .init() {
            filters.append(C7HSL(hue: hsl.hue, saturation: hsl.saturation, lightness: hsl.lightness))
        }

        if let curve = curveFilter() {
            filters.append(curve)
        }

        if noiseReduction > 0.01 {
            filters.append(
                C7NoiseReduction(
                    radius: max(1.0, 3.0 * noiseReduction),
                    amount: noiseReduction,
                    edgePreservation: edgePreservation
                )
            )
        }

        if sharpen > 0.01 {
            filters.append(
                C7UnsharpMask(
                    radius: 2.0,
                    intensity: sharpen,
                    threshold: 0.02
                )
            )
        }

        if let resizeFilter = resizeFilter(for: source, surface: surface) {
            filters.append(resizeFilter)
        }

        if blendIntensity > 0.01, let blendFilter = try compositeFilter() {
            filters.append(blendFilter)
        }

        return filters
    }

    private func lookFilters() -> [C7FilterProtocol] {
        switch lookPreset {
        case .clean:
            return []
        case .cinematic:
            return [C7ColorCube(cubeName: "violet", intensity: 0.8)]
        case .vintage:
            return [C7ColorCube(cubeName: "vista200 v1", intensity: 0.9)]
        case .mono:
            return [C7LookupTable1D(name: "bw_vintage_curves1", intensity: 0.95)]
        }
    }

    private func curveFilter() -> C7Curves? {
        switch curvePreset {
        case .none:
            return nil
        case .liftedContrast:
            return C7Curves(
                rgbPoints: [
                    C7Point2D(x: 0.0, y: 0.03),
                    C7Point2D(x: 0.25, y: 0.22),
                    C7Point2D(x: 0.75, y: 0.82),
                    C7Point2D(x: 1.0, y: 0.98)
                ]
            )
        case .fade:
            return C7Curves(
                rgbPoints: [
                    C7Point2D(x: 0.0, y: 0.08),
                    C7Point2D(x: 0.45, y: 0.48),
                    C7Point2D(x: 1.0, y: 0.95)
                ]
            )
        }
    }

    private func geometryFilter(for source: C7Image) -> C7FilterProtocol? {
        let size = source.pixelSize
        guard size.width > 0, size.height > 0 else { return nil }
        switch cropMode {
        case .original:
            return nil
        case .square:
            let edge = min(size.width, size.height)
            let rect = CGRect(
                x: (size.width - edge) * 0.5,
                y: (size.height - edge) * 0.5,
                width: edge,
                height: edge
            )
            return C7Crop(rect: rect)
        case .portrait45:
            let targetRatio = CGFloat(4.0 / 5.0)
            let width = min(size.width, size.height * targetRatio)
            let height = width / targetRatio
            let rect = CGRect(
                x: (size.width - width) * 0.5,
                y: (size.height - height) * 0.5,
                width: width,
                height: height
            )
            return C7Crop(rect: rect)
        case .cinematic169:
            let targetRatio = CGFloat(16.0 / 9.0)
            let width = min(size.width, size.height * targetRatio)
            let height = width / targetRatio
            let rect = CGRect(
                x: (size.width - width) * 0.5,
                y: (size.height - height) * 0.5,
                width: width,
                height: height
            )
            return C7Crop(rect: rect)
        }
    }

    private func resizeFilter(for source: C7Image, surface: StudioRenderSurface) -> C7FilterProtocol? {
        let size = source.pixelSize
        guard size.width > 0, size.height > 0 else { return nil }

        let longestEdge: CGFloat = surface == .preview ? 1400 : 1800
        let sourceLongest = max(size.width, size.height)
        guard sourceLongest > longestEdge else { return nil }

        let ratio = longestEdge / sourceLongest
        let target = CGSize(width: size.width * ratio, height: size.height * ratio)
        switch resizeQuality {
        case .fast:
            return C7Resize(size: target)
        case .lanczos:
            return C7LanczosResize(size: target)
        }
    }

    private func compositeFilter() throws -> C7Blend? {
        guard let blendImage = R.image("Bear"),
              let blendTexture = blendImage.c7.toTexture() else {
            return nil
        }
        var filter = C7Blend(with: blendMode, blendTexture: blendTexture, intensity: blendIntensity)
        filter.intensity = blendIntensity
        return filter
    }
}

private enum StudioSourceAsset: String, CaseIterable, Identifiable {
    case img2606 = "IMG_2606"
    case img0020 = "IMG_0020"
    case gothicPortrait = "GothicPortrait"
    case snowRider = "SnowRider"
    case bear = "Bear"

    static let editingCases: [StudioSourceAsset] = [
        .gothicPortrait,
        .img2606,
        .snowRider,
        .img0020
    ]

    var id: String { rawValue }

    var resourceName: String { rawValue }

    var title: String {
        switch self {
        case .img2606:
            return "Street"
        case .img0020:
            return "Portrait"
        case .gothicPortrait:
            return "Gothic"
        case .snowRider:
            return "Snow"
        case .bear:
            return "Bear"
        }
    }

    var heroTitle: String {
        switch self {
        case .img2606:
            return "Street Preview Core"
        case .img0020:
            return "Portrait Look Studio"
        case .gothicPortrait:
            return "High-Contrast Portrait Stage"
        case .snowRider:
            return "Promo-Grade Outdoor Render"
        case .bear:
            return "Composite Test Surface"
        }
    }

    var heroSubtitle: String {
        switch self {
        case .img2606:
            return "A quiet city frame tuned for preview and final cadence."
        case .img0020:
            return "Warmth, curve shaping, and blend-led portrait finishing."
        case .gothicPortrait:
            return "A dramatic portrait setup built to show off filter layering."
        case .snowRider:
            return "Strong color, edge detail, and export posture for showcase capture."
        case .bear:
            return "Secondary asset used to prove two-input compositing."
        }
    }
}

private enum StudioLookPreset: String, CaseIterable, Identifiable {
    case clean
    case cinematic
    case vintage
    case mono

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clean:
            return "Clean"
        case .cinematic:
            return "Cinematic"
        case .vintage:
            return "Vintage"
        case .mono:
            return "Mono"
        }
    }

    var subtitle: String {
        switch self {
        case .clean:
            return "Neutral tone and restrained contrast."
        case .cinematic:
            return "Cooler shadows and a shaped highlight rolloff."
        case .vintage:
            return "Softer contrast with aged color drift."
        case .mono:
            return "Black-and-white emphasis with tonal separation."
        }
    }
}

private enum StudioCurvePreset: String, CaseIterable, Identifiable {
    case none
    case liftedContrast
    case fade

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "Linear"
        case .liftedContrast:
            return "Lifted"
        case .fade:
            return "Fade"
        }
    }
}

private enum StudioCropMode: String, CaseIterable, Identifiable {
    case original
    case square
    case portrait45
    case cinematic169

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            return "Original"
        case .square:
            return "1:1"
        case .portrait45:
            return "4:5"
        case .cinematic169:
            return "16:9"
        }
    }
}

private enum StudioResizeQuality: String, CaseIterable, Identifiable {
    case fast
    case lanczos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast:
            return "Fast"
        case .lanczos:
            return "Lanczos"
        }
    }
}

private enum StudioToolGroup: String, CaseIterable, Identifiable {
    case looks
    case adjust
    case crop
    case detail
    case blend

    static let editingCases: [StudioToolGroup] = [
        .looks,
        .adjust,
        .crop,
        .detail,
        .blend
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .looks:
            return "Looks"
        case .adjust:
            return "Adjust"
        case .crop:
            return "Crop"
        case .detail:
            return "Detail"
        case .blend:
            return "Blend"
        }
    }

    var symbolName: String {
        switch self {
        case .looks:
            return "sparkles"
        case .adjust:
            return "slider.horizontal.3"
        case .crop:
            return "crop.rotate"
        case .detail:
            return "wand.and.stars"
        case .blend:
            return "square.stack.3d.up"
        }
    }
}

private enum StudioComparisonMode: String, CaseIterable, Identifiable {
    case original
    case edited
    case split

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            return "Original"
        case .edited:
            return "Edited"
        case .split:
            return "Split"
        }
    }
}

private enum StudioRenderSurface: String, CaseIterable, Identifiable, Sendable {
    case preview
    case export

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preview:
            return "Preview"
        case .export:
            return "Final"
        }
    }

    var previewTitle: String {
        switch self {
        case .preview:
            return "Edited Preview"
        case .export:
            return "Final Render"
        }
    }
}

private extension C7Image {
    var pixelSize: CGSize {
        if let cgImage = cgImage {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
        #if os(macOS)
        return c7.size
        #else
        return CGSize(width: size.width * scale, height: size.height * scale)
        #endif
    }
}

private extension RenderProfile {
    var studioLabel: String {
        switch self {
        case .interactiveLatency:
            return "Interactive"
        case .responseLatency:
            return "Responsive"
        case .stablePreview:
            return "Stable Preview"
        case .inspectionQuality:
            return "Inspection"
        case .exportQuality:
            return "Export Quality"
        case .readbackQuality:
            return "Readback"
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPad (8th generation)")
    }
}
