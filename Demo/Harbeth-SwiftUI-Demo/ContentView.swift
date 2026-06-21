//
//  ContentView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/3/21.
//

import SwiftUI
import Harbeth

struct ContentView: View {
    @State private var route: ShowcaseRoute = .showcase
    @State private var showsLabs = false
    @State private var showsCapabilities = false

    var body: some View {
        Group {
            switch route {
            case .showcase:
                ShowcaseHomeView(
                    openStudio: { route = .studio },
                    openLabs: { showsLabs = true },
                    openCapabilities: { showsCapabilities = true }
                )
            case .studio:
                PhotoStudioView(
                    onBackToShowcase: { route = .showcase },
                    onOpenLabs: { showsLabs = true },
                    onOpenCapabilities: { showsCapabilities = true }
                )
            }
        }
        .sheet(isPresented: $showsLabs) {
            NavigationView {
                LabsView()
                    .inlineNavigationBarTitle("Labs")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showsLabs = false
                            }
                        }
                    }
            }
            .stackNavigationViewStyle()
        }
        .sheet(isPresented: $showsCapabilities) {
            NavigationView {
                CapabilitySheetView(
                    openStudio: {
                        showsCapabilities = false
                        route = .studio
                    },
                    openLabs: {
                        showsCapabilities = false
                        showsLabs = true
                    }
                )
                .inlineNavigationBarTitle("Core Capabilities")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            showsCapabilities = false
                        }
                    }
                }
            }
            .stackNavigationViewStyle()
        }
    }
}

private enum ShowcaseRoute {
    case showcase
    case studio
}

private struct ShowcaseHomeView: View {
    let openStudio: () -> Void
    let openLabs: () -> Void
    let openCapabilities: () -> Void

    var body: some View {
        NavigationView {
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 28) {
                        ShowcaseHeroSection(
                            openStudio: openStudio,
                            openLabs: openLabs,
                            openCapabilities: openCapabilities,
                            isWide: proxy.size.width >= 960
                        )

                        ShowcaseBand(
                            title: "Image Editing Core",
                            subtitle: "Show the full chain from source image to recipe, preview surface, final render, and reusable derivative.",
                            icon: "slider.horizontal.3"
                        ) {
                            ShowcaseFeatureGrid(items: [
                                ShowcaseFeature(
                                    title: "Looks and LUT",
                                    detail: "3D LUT, 1D LUT, curves, HSL, and tone adjustments are composed into a single recipe."
                                ),
                                ShowcaseFeature(
                                    title: "Detail Recovery",
                                    detail: "Native unsharp mask, denoise, and resize quality controls demonstrate image finishing rather than single effects."
                                ),
                                ShowcaseFeature(
                                    title: "Preview and Final",
                                    detail: "The same recipe can target low-latency preview or final-quality readback without redefining the edit."
                                )
                            ])
                        }

                        ShowcaseBand(
                            title: "Frame Runtime",
                            subtitle: "Harbeth stays focused on how a frame is processed, not on camera session ownership or media orchestration.",
                            icon: "speedometer"
                        ) {
                            ShowcaseRuntimeStrip(items: [
                                ShowcaseMetric(
                                    title: "Interactive",
                                    value: "texture-first",
                                    detail: "Low-latency path for frequent parameter changes."
                                ),
                                ShowcaseMetric(
                                    title: "Stable Preview",
                                    value: "double buffer",
                                    detail: "Display-oriented path for repeatable visual review."
                                ),
                                ShowcaseMetric(
                                    title: "Readback",
                                    value: "final output",
                                    detail: "Completed GPU work before image delivery when needed."
                                )
                            ])
                        }

                        ShowcaseBand(
                            title: "Geometry and Optics",
                            subtitle: "The first Studio pass focuses on crop, rotate, and resize. Advanced perspective and optics remain capability-forward and can expand without changing the demo shell.",
                            icon: "crop.rotate"
                        ) {
                            HStack(alignment: .top, spacing: 20) {
                                CapabilityListColumn(
                                    title: "Now in Studio",
                                    items: [
                                        "Crop presets for 1:1, 4:5, and 16:9",
                                        "Rotation and resampling quality",
                                        "Detail-aware resize with Lanczos"
                                    ]
                                )
                                CapabilityListColumn(
                                    title: "Extensible Surface",
                                    items: [
                                        "Perspective correction",
                                        "Guided upright",
                                        "Lens and edge correction"
                                    ]
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ShowcaseBand(
                            title: "Labs",
                            subtitle: "Focused capability checks stay available without redefining the public story of the SwiftUI Showcase.",
                            icon: "flask"
                        ) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Labs preserve the original focused demos for curves, HSL, LUT loading, blending, double buffering, chroma key, custom kernels, and MPS checks.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                HStack(spacing: 12) {
                                    ShowcasePrimaryButton(title: "Browse Labs", action: openLabs)
                                    ShowcaseSecondaryButton(title: "Open Studio", action: openStudio)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, proxy.size.width >= 960 ? 28 : 16)
                    .padding(.vertical, 20)
                }
                .background(Color.background.opacity(0.35))
            }
            .inlineNavigationBarTitle("Harbeth Showcase")
        }
        .stackNavigationViewStyle()
    }
}

private struct ShowcaseHeroSection: View {
    let openStudio: () -> Void
    let openLabs: () -> Void
    let openCapabilities: () -> Void
    let isWide: Bool

    var body: some View {
        Group {
            if isWide {
                HStack(alignment: .center, spacing: 28) {
                    heroCopy
                    ShowcaseHeroPreview()
                        .frame(maxWidth: 520)
                }
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    heroCopy
                    ShowcaseHeroPreview()
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.background)
        )
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Apple image and frame processing core")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)

            Text("Build the edit, prove the frame path, and keep the media lifecycle outside the core.")
                .font(.system(size: 34, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)

            Text("Harbeth-SwiftUI-Demo is the public Showcase for how Harbeth can support a real editor shell. It demonstrates image recipes, preview and final render profiles, detail recovery, two-input compositing, and reusable frame outputs without pretending to be a camera SDK or a video editor.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                CapabilityTag(text: "LUT")
                CapabilityTag(text: "Preview/Final")
                CapabilityTag(text: "Geometry")
                CapabilityTag(text: "Detail")
                CapabilityTag(text: "Blend")
            }

            HStack(spacing: 12) {
                ShowcasePrimaryButton(title: "Open Studio", action: openStudio)
                ShowcaseSecondaryButton(title: "Browse Labs", action: openLabs)
                ShowcaseSecondaryButton(title: "Read Core Capabilities", action: openCapabilities)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ShowcaseHeroPreview: View {
    @State private var previewOutput: StudioRenderOutput?
    @State private var finalOutput: StudioRenderOutput?
    @State private var errorMessage: String?

    private let previewRecipe = StudioRecipe.heroRecipe

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Featured Edit Path")
                .font(.headline)

            if let errorMessage = errorMessage {
                StudioMessageView(message: errorMessage)
                    .frame(minHeight: 260)
            } else {
                HStack(spacing: 12) {
                    PreviewImageCard(title: "Source", image: previewRecipe.sourceImage)
                    if let previewOutput = previewOutput {
                        PreviewImageCard(title: "Preview", image: previewOutput.image)
                    }
                }

                if let finalOutput = finalOutput {
                    VStack(alignment: .leading, spacing: 8) {
                        PreviewImageCard(title: "Final Render", image: finalOutput.image)
                        Text(finalOutput.summary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear(perform: renderPreview)
    }

    private func renderPreview() {
        guard previewOutput == nil, finalOutput == nil else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let previewResult = Result(catching: {
                try StudioRenderer.render(recipe: previewRecipe, surface: .preview)
            })
            let finalResult = Result(catching: {
                try StudioRenderer.render(recipe: previewRecipe, surface: .export)
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

private struct ShowcaseBand<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.background)
        )
    }
}

private struct CapabilitySheetView: View {
    let openStudio: () -> Void
    let openLabs: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CapabilitySheetSection(
                    title: "Processing Inputs",
                    items: [
                        "Image, texture, pixelBuffer, and sampleBuffer entry paths",
                        "Texture-first and frame-first rendering paths",
                        "Preview and readback oriented render profiles"
                    ]
                )
                CapabilitySheetSection(
                    title: "Image Editing Core",
                    items: [
                        "LUT, curves, HSL, color adjustment, and tone shaping",
                        "Sharpen, noise reduction, and quality-aware resize",
                        "Blend, alpha, and dual-input compositing"
                    ]
                )
                CapabilitySheetSection(
                    title: "Geometry and Optics",
                    items: [
                        "Crop, rotate, and resize for Studio-first editing",
                        "Perspective, upright, and lens correction ready capability surface",
                        "Detail and edge quality recovery as a core concern"
                    ]
                )
                CapabilitySheetSection(
                    title: "Boundary",
                    items: [
                        "Harbeth owns frame processing quality",
                        "Your app owns camera session, recording, timeline, export orchestration, and persistence",
                        "Demo pages are integration examples, not product ownership claims"
                    ]
                )
                HStack(spacing: 12) {
                    ShowcasePrimaryButton(title: "Open Studio", action: openStudio)
                    ShowcaseSecondaryButton(title: "Browse Labs", action: openLabs)
                }
            }
            .padding(20)
        }
        .background(Color.background.opacity(0.25))
    }
}

private struct CapabilitySheetSection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.secondary)
                    Text(item)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.background)
        )
    }
}

private struct ShowcaseFeatureGrid: View {
    let items: [ShowcaseFeature]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.detail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct ShowcaseRuntimeStrip: View {
    let items: [ShowcaseMetric]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                    Text(item.value)
                        .font(.title3.weight(.semibold))
                    Text(item.detail)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct CapabilityListColumn: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ShowcasePrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.9))
                )
                .foregroundColor(Color.background)
        }
        .buttonStyle(.plain)
    }
}

private struct ShowcaseSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.08))
            )
    }
}

private struct ShowcaseFeature: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

private struct ShowcaseMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
}

private struct PhotoStudioView: View {
    let onBackToShowcase: () -> Void
    let onOpenLabs: () -> Void
    let onOpenCapabilities: () -> Void

    @State private var recipe = StudioRecipe()
    @State private var comparisonMode: StudioComparisonMode = .edited
    @State private var selectedTool: StudioToolGroup = .looks
    @State private var activeRenderSurface: StudioRenderSurface = .preview
    @State private var previewOutput: StudioRenderOutput?
    @State private var exportOutput: StudioRenderOutput?
    @State private var renderError: String?
    @State private var isRendering = false
    @State private var renderGeneration = UUID()

    var body: some View {
        NavigationView {
            GeometryReader { proxy in
                let isWide = proxy.size.width >= 1080
                ScrollView {
                    if isWide {
                        HStack(alignment: .top, spacing: 20) {
                            previewColumn
                                .frame(maxWidth: .infinity)
                            controlColumn
                                .frame(width: min(max(proxy.size.width * 0.3, 320), 380))
                        }
                        .padding(20)
                    } else {
                        VStack(spacing: 20) {
                            previewColumn
                            controlColumn
                        }
                        .padding(16)
                    }
                }
                .background(Color.background.opacity(0.45))
            }
            .inlineNavigationBarTitle("Harbeth Photo Studio")
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button("Showcase", action: onBackToShowcase)
                    sourceMenu
                    Button("Reset", action: resetRecipe)
                    Button("Labs", action: onOpenLabs)
                    Button("Core", action: onOpenCapabilities)
                }
            }
        }
        .stackNavigationViewStyle()
        .onAppear(perform: refreshRenders)
        .onChange(of: recipe) { _ in
            refreshRenders()
        }
    }

    private var sourceMenu: some View {
        Menu {
            Picker("Source", selection: $recipe.sourceName) {
                ForEach(StudioSourceAsset.allCases) { asset in
                    Text(asset.title).tag(asset)
                }
            }
            Divider()
            Button("Original") {
                comparisonMode = .original
            }
            Button("Edited") {
                comparisonMode = .edited
            }
            Button("Split") {
                comparisonMode = .split
            }
        } label: {
            Label(recipe.sourceName.title, systemImage: "photo.on.rectangle")
        }
    }

    private var previewColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            heroHeader
            previewCard
            renderSummaryCard
        }
    }

    private var controlColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            toolGroupPicker
            activeToolPanel
        }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Image and frame processing studio")
                .font(.title2.weight(.semibold))
            Text("Build a recipe once, inspect low-latency preview, then switch to final render semantics without leaving the editor shell.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Studio Preview")
                    .font(.headline)
                Spacer()
                Picker("Surface", selection: $activeRenderSurface) {
                    ForEach(StudioRenderSurface.allCases) { surface in
                        Text(surface.title).tag(surface)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: 220)
            }

            Picker("Compare", selection: $comparisonMode) {
                ForEach(StudioComparisonMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            Group {
                if let error = renderError {
                    StudioMessageView(message: error)
                        .frame(minHeight: 360)
                } else if isRendering && previewOutput == nil && exportOutput == nil {
                    ProgressView("Rendering...")
                        .frame(maxWidth: .infinity, minHeight: 360)
                } else {
                    previewContent
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(18)
        .background(panelBackground)
    }

    @ViewBuilder
    private var previewContent: some View {
        switch comparisonMode {
        case .original:
            PreviewImageCard(title: "Original", image: recipe.sourceImage)
        case .edited:
            if let output = activeOutput {
                PreviewImageCard(title: activeRenderSurface.previewTitle, image: output.image)
            } else {
                StudioMessageView(message: "No rendered output.")
            }
        case .split:
            adaptiveSplitPreview
        }
    }

    private var adaptiveSplitPreview: some View {
        GeometryReader { proxy in
            let vertical = proxy.size.width < 760
            Group {
                if vertical {
                    VStack(spacing: 12) {
                        PreviewImageCard(title: "Original", image: recipe.sourceImage)
                        if let output = activeOutput {
                            PreviewImageCard(title: activeRenderSurface.previewTitle, image: output.image)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        PreviewImageCard(title: "Original", image: recipe.sourceImage)
                        if let output = activeOutput {
                            PreviewImageCard(title: activeRenderSurface.previewTitle, image: output.image)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 380)
    }

    private var renderSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Render Path")
                .font(.headline)

            renderInfoRow(
                title: "Preview",
                profile: recipe.previewProfile,
                output: previewOutput,
                fallback: "Stable interactive display path"
            )
            renderInfoRow(
                title: "Final",
                profile: recipe.exportProfile,
                output: exportOutput,
                fallback: "High-quality delivery or readback path"
            )
        }
        .padding(18)
        .background(panelBackground)
    }

    private func renderInfoRow(title: String, profile: RenderProfile, output: StudioRenderOutput?, fallback: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(profile.studioLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(output?.summary ?? fallback)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var toolGroupPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tools")
                .font(.headline)
            Picker("Tool Group", selection: $selectedTool) {
                ForEach(StudioToolGroup.allCases) { group in
                    Text(group.title).tag(group)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding(18)
        .background(panelBackground)
    }

    @ViewBuilder
    private var activeToolPanel: some View {
        switch selectedTool {
        case .looks:
            looksPanel
        case .adjust:
            adjustPanel
        case .geometry:
            geometryPanel
        case .detail:
            detailPanel
        case .composite:
            compositePanel
        case .export:
            exportPanel
        }
    }

    private var looksPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Looks")
                .font(.headline)
            Picker("Look", selection: $recipe.lookPreset) {
                ForEach(StudioLookPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            Picker("Curve", selection: $recipe.curvePreset) {
                ForEach(StudioCurvePreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            sliderRow(title: "Hue Shift", value: $recipe.hsl.hue, range: -25...25)
            sliderRow(title: "HSL Saturation", value: $recipe.hsl.saturation, range: -0.4...0.4)
        }
        .padding(18)
        .background(panelBackground)
    }

    private var adjustPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Adjust")
                .font(.headline)
            sliderRow(title: "Exposure", value: $recipe.exposure, range: -1.2...1.2)
            sliderRow(title: "Contrast", value: $recipe.contrast, range: 0.6...1.8)
            sliderRow(title: "Saturation", value: $recipe.saturation, range: 0.0...2.0)
            sliderRow(title: "Temperature", value: $recipe.temperature, range: 3500...7500, format: "%.0f")
        }
        .padding(18)
        .background(panelBackground)
    }

    private var geometryPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Geometry")
                .font(.headline)
            Picker("Crop", selection: $recipe.cropMode) {
                ForEach(StudioCropMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            Picker("Rotation", selection: $recipe.rotationDegrees) {
                Text("0°").tag(Float(0))
                Text("-90°").tag(Float(-90))
                Text("90°").tag(Float(90))
            }
            .pickerStyle(SegmentedPickerStyle())

            Picker("Resize", selection: $recipe.resizeQuality) {
                ForEach(StudioResizeQuality.allCases) { quality in
                    Text(quality.title).tag(quality)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding(18)
        .background(panelBackground)
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detail")
                .font(.headline)
            sliderRow(title: "Sharpen", value: $recipe.sharpen, range: 0...1.6)
            sliderRow(title: "Noise Reduction", value: $recipe.noiseReduction, range: 0...1)
            sliderRow(title: "Edge Preserve", value: $recipe.edgePreservation, range: 0.2...0.95)
        }
        .padding(18)
        .background(panelBackground)
    }

    private var compositePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Composite")
                .font(.headline)
            Picker("Blend", selection: $recipe.blendMode) {
                ForEach(StudioRecipe.blendModes) { mode in
                    Text(mode.kernel).tag(mode)
                }
            }
            .pickerStyle(MenuPickerStyle())

            sliderRow(title: "Blend Intensity", value: $recipe.blendIntensity, range: 0...1)

            Text("Composite uses a secondary asset path to demonstrate Harbeth two-input blending without pulling camera or video lifecycle into the core demo.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(18)
        .background(panelBackground)
    }

    private var exportPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export")
                .font(.headline)
            Picker("Preview Profile", selection: $recipe.previewProfile) {
                ForEach(StudioRecipe.previewProfiles, id: \.self) { profile in
                    Text(profile.studioLabel).tag(profile)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Picker("Final Profile", selection: $recipe.exportProfile) {
                ForEach(StudioRecipe.exportProfiles, id: \.self) { profile in
                    Text(profile.studioLabel).tag(profile)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Picker("Display", selection: $activeRenderSurface) {
                ForEach(StudioRenderSurface.allCases) { surface in
                    Text(surface.title).tag(surface)
                }
            }
            .pickerStyle(SegmentedPickerStyle())

            Text("This panel exposes Harbeth preview and final render semantics directly. It does not write files, but it does render through separate profiles.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(18)
        .background(panelBackground)
    }

    private func sliderRow(title: String, value: Binding<Float>, range: ClosedRange<Float>, format: String = "%.2f") -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.background)
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
        recipe.reset()
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

private struct PreviewImageCard: View {
    let title: String
    let image: C7Image

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Image(c7Image: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, minHeight: 280)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.04))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StudioMessageView: View {
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.background)
        )
    }
}

private struct LabsView: View {
    var body: some View {
        List {
            Section("Integration Showcase") {
                NavigationLink(destination: CubeView()) {
                    LabsRow(title: "LUT Pipeline", subtitle: "3D LUT and cube resource loading")
                }
                NavigationLink(destination: DoubleBufferView()) {
                    LabsRow(title: "Runtime", subtitle: "Double buffer and frame-oriented throughput checks")
                }
                NavigationLink(destination: MetalKernelViews()) {
                    LabsRow(title: "Custom Kernels", subtitle: "Metal filters, lookup tables, and kernel examples")
                }
            }

            Section("Color") {
                NavigationLink(destination: CurvesView()) {
                    LabsRow(title: "Curves", subtitle: "RGB and channel curve shaping")
                }
                NavigationLink(destination: HSLView()) {
                    LabsRow(title: "HSL", subtitle: "Hue, saturation, and lightness adjustment")
                }
                NavigationLink(destination: ColorRGBAView()) {
                    LabsRow(title: "RGBA Controls", subtitle: "Channel-level color tuning")
                }
                NavigationLink(destination: HighlightShadowToneView()) {
                    LabsRow(title: "Highlight and Shadow", subtitle: "Tone recovery and local contrast")
                }
            }

            Section("Compositing") {
                NavigationLink(destination: BlendView()) {
                    LabsRow(title: "Blend", subtitle: "Two-input compositing and blend modes")
                }
                NavigationLink(destination: ChromaKeyView()) {
                    LabsRow(title: "Chroma Key", subtitle: "Alpha extraction and keying")
                }
                NavigationLink(destination: ChannelControlView()) {
                    LabsRow(title: "Channel Isolation", subtitle: "Selective channel routing")
                }
            }

            Section("MPS") {
                NavigationLink(destination: CustomViews(value: MPSGaussianBlur.range.value, filtering: {
                    MPSGaussianBlur(radius: $0)
                }, min: MPSGaussianBlur.range.min, max: MPSGaussianBlur.range.max)) {
                    LabsRow(title: "Gaussian Blur", subtitle: "Focused MPS capability check")
                }
            }
        }
        .textCase(.none)
        .groupedListStyle()
    }
}

private struct LabsRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
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
        var recipe = StudioRecipe()
        recipe.sourceName = .img0020
        recipe.lookPreset = .cinematic
        recipe.curvePreset = .liftedContrast
        recipe.exposure = 0.12
        recipe.contrast = 1.12
        recipe.saturation = 1.08
        recipe.temperature = 5400
        recipe.sharpen = 0.42
        recipe.noiseReduction = 0.14
        recipe.blendIntensity = 0.0
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

    mutating func reset() {
        self = StudioRecipe()
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
    case bear = "Bear"

    var id: String { rawValue }

    var resourceName: String { rawValue }

    var title: String {
        switch self {
        case .img2606:
            return "Street"
        case .img0020:
            return "Portrait"
        case .bear:
            return "Composite Bear"
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
    case geometry
    case detail
    case composite
    case export

    var id: String { rawValue }

    var title: String {
        switch self {
        case .looks:
            return "Looks"
        case .adjust:
            return "Adjust"
        case .geometry:
            return "Geometry"
        case .detail:
            return "Detail"
        case .composite:
            return "Composite"
        case .export:
            return "Export"
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
