//
//  ContentView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/3/21.
//

import SwiftUI
import Harbeth

struct ContentView: View {
    @Namespace private var showcaseNamespace
    @State private var route: ShowcaseRoute = .showcase
    @State private var showsLabs = false
    @State private var studioEntryID = UUID()
    @State private var studioSeed = StudioRecipe.heroRecipe

    var body: some View {
        ZStack {
            Color.black
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
            .stackNavigationViewStyle()
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

    private let timer = Timer.publish(every: 4.2, on: .main, in: .common).autoconnect()

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

                    showcaseSignalStrip
                    showcaseGallery
                }
                .padding(.horizontal, isWide ? 32 : 18)
                .padding(.top, isWide ? 24 : 16)
                .padding(.bottom, 28)
            }
            .background(
                ShowcaseBackdrop(image: activeStory.recipe.sourceImage)
            )
        }
        .onReceive(timer) { _ in
            guard let currentIndex = stories.firstIndex(where: { $0.id == activeStoryID }) else { return }
            let nextIndex = (currentIndex + 1) % stories.count
            withAnimation(.spring(response: 0.7, dampingFraction: 0.88)) {
                activeStoryID = stories[nextIndex].id
                heroSplit = heroSplit > 0.5 ? 0.34 : 0.68
            }
        }
    }

    private var showcaseTopBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Harbeth")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.96))
                Text("SwiftUI Showcase")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.52))
            }
            Spacer()
            ShowcaseGhostButton(title: "Open Labs", icon: "square.grid.2x2", action: openLabs)
        }
    }

    private var showcaseCopy: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(activeStory.kicker.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.62))

            Text(activeStory.title)
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(activeStory.subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.72))

            HStack(spacing: 10) {
                CapabilityTag(text: "Image Editing")
                CapabilityTag(text: "Realtime Preview")
                CapabilityTag(text: "Final Render")
            }

            HStack(spacing: 12) {
                ShowcasePrimaryButton(title: "Start Editing") {
                    openStory(activeStory)
                }
                ShowcaseGhostButton(title: "Open Labs", icon: "sparkles.tv", action: openLabs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var showcaseSignalStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ShowcaseSignalPill(title: "Texture-first", subtitle: "Interactive path")
                ShowcaseSignalPill(title: "Preview / Final", subtitle: "Same recipe")
                ShowcaseSignalPill(title: "Sharpen / Denoise", subtitle: "Detail recovery")
                ShowcaseSignalPill(title: "Blend", subtitle: "Dual input proof")
                ShowcaseSignalPill(title: "Crop / Rotate", subtitle: "Geometry layer")
            }
        }
    }

    private var showcaseGallery: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Selected Frames")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("Tap a scene to jump into the studio.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.52))
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
            Image(c7Image: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 90)
                .scaleEffect(1.18)
                .overlay(Color.black.opacity(0.42))
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.72),
                    Color.black.opacity(0.28),
                    Color.black.opacity(0.76)
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
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear(perform: renderStory)
        .onChange(of: story.id) { _ in
            previewOutput = nil
            finalOutput = nil
            errorMessage = nil
            renderStory()
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
            ShowcaseSignalCard(
                title: "Preview",
                subtitle: previewOutput?.summary ?? "Preparing preview surface"
            )
            ShowcaseSignalCard(
                title: "Final",
                subtitle: finalOutput?.summary ?? "Preparing final render"
            )
            ShowcaseSignalCard(
                title: "Recipe",
                subtitle: story.badgeText
            )
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
        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 8))
    }

    private func showcaseLabel(title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.46), in: Capsule())
    }

    private func renderStory() {
        let currentStory = story
        DispatchQueue.global(qos: .userInitiated).async {
            let previewResult = Result(catching: {
                try StudioRenderer.render(recipe: currentStory.recipe, surface: .preview)
            })
            let finalResult = Result(catching: {
                try StudioRenderer.render(recipe: currentStory.recipe, surface: .export)
            })
            DispatchQueue.main.async {
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
                                    Color.black.opacity(0.1),
                                    Color.black.opacity(0.84)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text(story.kicker.uppercased())
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.62))
                                Text(story.title)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(story.badgeText)
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.white.opacity(0.84))
                            }
                            .padding(16)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(activeStoryID == story.id ? Color.white.opacity(0.16) : Color.white.opacity(0.08))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(activeStoryID == story.id ? Color.white.opacity(0.32) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .scaleEffect(activeStoryID == story.id ? 1.0 : 0.97)
                    }
                    .buttonStyle(.plain)
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

private struct ShowcaseSignalPill: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.58))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
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

                LinearGradient(
                    colors: [
                        .clear,
                        Color.black.opacity(0.12),
                        Color.black.opacity(0.84)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(story.title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(story.cardSummary)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.72))
                    HStack {
                        CapabilityTag(text: story.badgeText)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundColor(.white.opacity(0.72))
                    }
                }
                .padding(16)
            }
            .frame(width: 280, height: 210)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.white.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.62))
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
                .foregroundColor(.white)
            Text(detail)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
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
                .foregroundColor(.white.opacity(0.52))
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
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
                .foregroundColor(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                )
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
                .foregroundColor(.white.opacity(0.92))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct CapabilityTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white.opacity(0.92))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08), in: Capsule())
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
            let isWide = proxy.size.width >= 980
            let compactWidth = max(proxy.size.width - 32, 0)
            ZStack {
                StudioBackdrop(image: activeOutput?.image ?? recipe.sourceImage)

                VStack(spacing: 0) {
                    studioTopBar(isWide: isWide)
                        .frame(maxWidth: isWide ? .infinity : compactWidth, alignment: .leading)
                        .padding(.horizontal, isWide ? 24 : 16)
                        .padding(.top, isWide ? 20 : 14)
                        .padding(.bottom, 12)

                    if isWide {
                        HStack(spacing: 20) {
                            studioCanvas(isCompact: false)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            studioInspector
                                .frame(width: 340)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 22)
                    } else {
                        VStack(spacing: 16) {
                            studioCanvas(isCompact: true)
                                .frame(width: compactWidth, alignment: .leading)
                                .frame(maxHeight: .infinity)
                            compactStudioControls
                                .frame(width: compactWidth, alignment: .leading)
                        }
                        .frame(width: compactWidth, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 18)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .onAppear(perform: refreshRenders)
            .onChange(of: recipe) { _ in
                refreshRenders()
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
                    labsButton
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    backButton
                    Spacer(minLength: 0)
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

    private var backButton: some View {
        Button(action: onBackToShowcase) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                Text("Showcase")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white.opacity(0.92))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
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

    private func studioTopChip(title: String, icon: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
            }
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundColor(.white.opacity(0.94))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: Capsule())
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

    private func studioCanvas(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 16) {
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
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                canvasStage
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
                .foregroundColor(.white)
                .lineLimit(isCompact ? 3 : 2)
                .multilineTextAlignment(.leading)
            Text(recipe.sourceName.heroSubtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.62))
                .lineLimit(isCompact ? 4 : 3)
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
                            .foregroundColor(comparisonMode == mode ? .black : .white.opacity(0.84))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(comparisonMode == mode ? Color.white : Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    private var canvasStage: some View {
        if let renderError {
            StudioMessageView(message: renderError)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isRendering && previewOutput == nil && exportOutput == nil {
            ProgressView("Rendering...")
                .tint(.white)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch comparisonMode {
            case .original:
                PreviewImageCard(title: "Original", image: recipe.sourceImage, height: 420)
            case .edited:
                if let output = activeOutput {
                    PreviewImageCard(title: activeRenderSurface.previewTitle, image: output.image, height: 420)
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
                    .frame(minHeight: 420)
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
        HStack(spacing: 8) {
            ForEach(StudioToolGroup.editingCases) { group in
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                        selectedTool = group
                    }
                } label: {
                    Image(systemName: group.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(selectedTool == group ? .black : .white.opacity(0.88))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(selectedTool == group ? Color.white : Color.black.opacity(0.32))
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
                .foregroundColor(.white.opacity(0.56))
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.34), in: Capsule())
    }

    private var studioInspector: some View {
        VStack(alignment: .leading, spacing: 16) {
            StudioToolRail(selectedTool: $selectedTool)
            activeToolPanel(isCompact: false)
            StudioStatusCard(recipe: recipe, previewOutput: previewOutput, exportOutput: exportOutput)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var compactStudioControls: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(Color.white.opacity(0.24))
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
                            .foregroundColor(selectedTool == group ? .black : .white.opacity(0.88))
                            .frame(width: 58, height: 58)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedTool == group ? Color.white : Color.white.opacity(0.08))
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
                .fill(Color.black.opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
                sliderRow(title: "Exposure", value: $recipe.exposure, range: -1.2...1.2)
                sliderRow(title: "Contrast", value: $recipe.contrast, range: 0.6...1.8)
                sliderRow(title: "Saturation", value: $recipe.saturation, range: 0...2)
                sliderRow(title: "Temperature", value: $recipe.temperature, range: 3500...7600, format: "%.0f")
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
                sliderRow(title: "Sharpen", value: $recipe.sharpen, range: 0...1.6)
                sliderRow(title: "Denoise", value: $recipe.noiseReduction, range: 0...1)
                sliderRow(title: "Edge Preserve", value: $recipe.edgePreservation, range: 0.2...0.95)
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
                sliderRow(title: "Intensity", value: $recipe.blendIntensity, range: 0...1)
                Text("Composite stays part of the frame processor. The Demo does not turn it into a media workflow.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.62))
            }
        }
    }

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
        let currentGeneration = UUID()
        let currentRecipe = recipe
        renderGeneration = currentGeneration
        renderError = nil
        isRendering = true

        DispatchQueue.global(qos: .userInitiated).async {
            let previewResult = Result(catching: {
                try StudioRenderer.render(recipe: currentRecipe, surface: .preview)
            })
            let exportResult = Result(catching: {
                try StudioRenderer.render(recipe: currentRecipe, surface: .export)
            })

            DispatchQueue.main.async {
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
}

private struct StudioBackdrop: View {
    let image: C7Image

    var body: some View {
        ZStack {
            Image(c7Image: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 100)
                .scaleEffect(1.16)
                .overlay(Color.black.opacity(0.54))
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.74),
                    Color.black.opacity(0.24),
                    Color.black.opacity(0.78)
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
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .offset(x: proxy.size.width * clamped)

                Circle()
                    .fill(Color.white)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "arrow.left.and.right")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.black)
                    )
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
                    .foregroundColor(selectedTool == group ? .black : .white.opacity(0.92))
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTool == group ? Color.white : Color.white.opacity(0.08))
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
            .foregroundColor(.white.opacity(0.86))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08), in: Capsule())
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
                    .foregroundColor(isSelected ? .black.opacity(0.74) : .white.opacity(0.6))
            }
            .foregroundColor(isSelected ? .black : .white)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.white.opacity(0.24) : Color.white.opacity(0.08), lineWidth: 1)
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
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.58))
            }
            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
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
                .foregroundColor(.white.opacity(0.52))
            Text(value)
                .font(.caption)
                .foregroundColor(.white.opacity(0.86))
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
                .foregroundColor(isSelected ? .black : .white.opacity(0.92))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.08))
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
                .foregroundColor(.white)
            Image(c7Image: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.04))
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
                .foregroundColor(.white)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
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
                        .foregroundColor(.white)
                    Text("Labs stays behind the Showcase. It keeps the narrow experiments, integration checks, and filter-specific surfaces available without defining the product story.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.66))
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
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.08, green: 0.08, blue: 0.12),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
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
                .foregroundColor(.white)
            VStack(spacing: 10) {
                content
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.62))
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.42))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
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
            )
        ]
    }
}

private struct StudioRenderer {
    static func render(recipe: StudioRecipe, surface: StudioRenderSurface) throws -> StudioRenderOutput {
        let profile = surface == .preview ? recipe.previewProfile : recipe.exportProfile
        let source = recipe.sourceImage
        let filters = try recipe.filters(source: source, surface: surface)
        var destination = HarbethIO(element: source, filters: filters)
        destination.renderProfile = profile
        destination.transmitOutputRealTimeCommit = profile.usesRealTimeCommit
        destination.enableDoubleBuffer = profile.enablesDoubleBuffer
        destination.createDestTexture = profile.createsDestinationTexture
        let image = try destination.output()
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

private struct StudioRecipe: Equatable {
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

private enum StudioRenderSurface: String, CaseIterable, Identifiable {
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
