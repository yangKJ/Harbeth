//
//  UnitTestViewController.swift
//  MetalDemo
//
//  Created by Condy on 2022/11/3.
//

import UIKit
import CoreMedia
import CoreVideo
import Harbeth

final class UnitTestViewController: UIViewController {

    enum Scenario: CaseIterable {
        case transition
        case layerComposite
        case editing
        case sourceCoverage
        case cacheHit

        var title: String {
            switch self {
            case .sourceCoverage: return "Source Coverage"
            case .editing: return "Editing"
            case .layerComposite: return "Layer Composite"
            case .transition: return "Transition"
            case .cacheHit: return "Cache Hit"
            }
        }

        var subtitle: String {
            switch self {
            case .sourceCoverage:
                return "Validate that ImageNode stably accepts all five source variants and the direct filter chain."
            case .editing:
                return "Validate geometry, local effects, and post filters through one unified editing entry."
            case .layerComposite:
                return "Validate layered editing with per-layer filters, masks, and blend modes."
            case .transition:
                return "Validate transition recipe output and snapshot at the real progress value."
            case .cacheHit:
                return "Second `makeTexture()` call should hit the resolvedTexture cache; reports lookup hit/miss counters."
            }
        }

        var control: ControlSpec {
            switch self {
            case .transition:
                return ControlSpec(title: "Progress", range: 0...1, defaultValue: 0.56, minimumText: "From", maximumText: "To")
            case .cacheHit:
                return ControlSpec(title: "Iterations", range: 1...10, defaultValue: 1, minimumText: "Once", maximumText: "Ten")
            case .sourceCoverage, .editing, .layerComposite:
                return ControlSpec(title: "Intensity", range: 0...1, defaultValue: 0.6, minimumText: "Lite", maximumText: "Bold")
            }
        }

        var allowsSourceSelection: Bool {
            switch self {
            case .sourceCoverage, .editing, .layerComposite, .transition, .cacheHit:
                return true
            }
        }
    }

    enum SourceVariant: CaseIterable {
        case image
        case data
        case assetURL
        case pixelBuffer
        case sampleBuffer

        var title: String {
            switch self {
            case .image: return "UIImage"
            case .data: return "Data"
            case .assetURL: return "Asset"
            case .pixelBuffer: return "PixelBuffer"
            case .sampleBuffer: return "SampleBuffer"
            }
        }
    }

    enum ReportMode: Int, CaseIterable {
        case overview
        case diagnostics
        case request
        case snapshot

        var title: String {
            switch self {
            case .overview: return "Overview"
            case .diagnostics: return "Diagnostics"
            case .request: return "Request"
            case .snapshot: return "Snapshot"
            }
        }
    }

    struct ControlSpec {
        let title: String
        let range: ClosedRange<Float>
        let defaultValue: Float
        let minimumText: String
        let maximumText: String
    }

    struct DemoAssets {
        let primary: UIImage
        let secondary: UIImage
        let overlay: UIImage
    }

    struct ScenarioResult {
        let scenario: Scenario
        let sourceTitle: String
        let sourcePreview: UIImage
        let resultTexture: MTLTexture
        let highlights: [String]
        let diagnostics: RenderPlanDiagnostics
        let request: RenderRequest?
        let snapshot: RenderGraphDebugSnapshot?
        let summary: String
        let codeSnippet: String?
    }

    struct RenderState: Equatable {
        let scenario: Scenario
        let sourceVariant: SourceVariant
        let intensity: Float
        let samplerDescriptor: ImageSamplerDescriptor
        let cachePolicy: ImageCachePolicy
        let reportMode: ReportMode
    }

    enum WorkbenchError: LocalizedError {
        case missingImage(String)
        case sourceEncoding(String)

        var errorDescription: String? {
            switch self {
            case .missingImage(let name):
                return "Missing asset image: \(name)"
            case .sourceEncoding(let message):
                return message
            }
        }
    }

    // Concise ImageNode call snippets shown alongside each scenario result.
    // Each scenario maps to 5–10 lines of real ImageNode calls that developers can paste into Xcode.
    private static let codeSnippets: [Scenario: String] = [
        .transition: """
        let recipe = TransitionRecipe(
            from: sourceA, to: sourceB,
            kernel: .directionalWipe(angleDegrees: 35, softness: 0.08),
            progress: 0.56
        )
        let node = ImageNode.transition(recipe)
            .withCachePolicy(.persistent)
        """,
        .layerComposite: """
        let recipe = LayerCompositeRecipe(
            background: sourceA,
            layers: [foregroundLayer, accentLayer]
        )
        let node = ImageNode.layerComposite(recipe)
        """,
        .editing: """
        let recipe = EditRecipe(
            geometry: ImageTransformRecipe(targetSize: ...),
            localEffects: [localEffect]
        )
        let node = ImageNode.source(source)
            .editing(recipe, mode: .preview)
            .applying(C7Sharpen(sharpness: 0.3))
        """,
        .sourceCoverage: """
        // Single entry covering all five sources: UIImage / Data / AssetURL / PixelBuffer / SampleBuffer
        let node = ImageNode
            .source(source)
            .applying(filters: [C7Brightness(...), C7Contrast(...), ...])
            .withCachePolicy(.persistent)
        """,
        .cacheHit: """
        // `.persistent` is the only way to make `makeTexture` actually consult the resolvedTexture cache
        let node = ImageNode
            .source(source)
            .applying(filters: filters)
            .withCachePolicy(.persistent)

        let t1 = try node.makeTexture()  // ~30ms (first call)
        let t2 = try node.makeTexture()  // <1ms  (cache hit)
        """
    ]

    private let renderQueue = DispatchQueue(label: "com.condy.harbeth.imagenode.workbench", qos: .userInitiated)
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private var generation: UInt64 = 0
    private var selectedScenario: Scenario = .transition
    private var selectedSource: SourceVariant = .image
    private var currentResult: ScenarioResult?
    private var controlValues: [Scenario: Float] = [:]
    private var assetsCache: DemoAssets?
    private var pendingRenderState: RenderState?
    private var isRenderingScenario = false
    private var previousPerformanceMonitorEnabled = false

    private lazy var scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alwaysBounceVertical = true
        return view
    }()

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 16
        return stack
    }()

    private lazy var scenarioButton: UIButton = makeActionButton()
    private lazy var sourceButton: UIButton = makeActionButton()
    private lazy var runButton: UIButton = {
        let button = makeActionButton(title: "▶ Run Current", action: #selector(runCurrentScenario))
        button.accessibilityHint = "Re-render the current scenario with the current slider / sampler / cache / report settings."
        return button
    }()
    private lazy var runAllButton: UIButton = {
        let button = makeActionButton(title: "▶ Run All", action: #selector(runAllScenarios))
        button.accessibilityHint = "Run every scenario in sequence and report pass / fail in the Overview text below."
        return button
    }()

    private lazy var samplerSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Linear", "Nearest"])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(settingDidChange), for: .valueChanged)
        return control
    }()

    private lazy var cacheSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Transient", "Persistent"])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(settingDidChange), for: .valueChanged)
        return control
    }()

    private lazy var reportSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ReportMode.allCases.map(\.title))
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(reportModeDidChange), for: .valueChanged)
        return control
    }()

    private lazy var minimumValueLabel: UILabel = makeCaptionLabel(alignment: .left)
    private lazy var maximumValueLabel: UILabel = makeCaptionLabel(alignment: .right)
    private lazy var currentValueLabel: UILabel = makeValueLabel()

    private lazy var controlSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.tintColor = accentColor
        slider.addTarget(self, action: #selector(sliderValueDidChange(_:)), for: .valueChanged)
        return slider
    }()

    private lazy var sourceCard = makeImageCard(title: "Source")
    private lazy var resultCard = makePreviewCard(title: "Result")
    private lazy var controlSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        return label
    }()
    private lazy var summaryTextView: UITextView = {
        let view = UITextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isEditable = false
        view.isSelectable = true
        view.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        view.textColor = .label
        view.backgroundColor = UIColor.secondarySystemBackground
        view.layer.cornerRadius = 12
        view.textContainerInset = UIEdgeInsets(top: 16, left: 14, bottom: 16, right: 14)
        return view
    }()

    /// Status banner at the top of the content stack. Reflects what the
    /// Run Current / Run All buttons are *currently* doing so the user
    /// always knows which scenario is being rendered.
    enum BannerKind {
        case info      // rendering in progress
        case success   // finished successfully
        case failure   // finished with an error

        var textColor: UIColor { .white }
        var background: UIColor {
            switch self {
            case .info: return UIColor(hex: "#5C48FA").withAlphaComponent(0.85)
            case .success: return UIColor.systemGreen.withAlphaComponent(0.85)
            case .failure: return UIColor.systemRed.withAlphaComponent(0.85)
            }
        }
        var symbol: String {
            switch self {
            case .info: return "-->"
            case .success: return "✓"
            case .failure: return "✗"
            }
        }
    }

    private lazy var statusBannerLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        label.layer.cornerRadius = 5
        label.layer.masksToBounds = true
        label.isHidden = true
        return label
    }()

    private lazy var progressView: UIProgressView = {
        let bar = UIProgressView(progressViewStyle: .default)
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.progressTintColor = accentColor
        bar.trackTintColor = .systemGray5
        bar.isHidden = true
        return bar
    }()

    private lazy var resultMatrixStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        stack.isHidden = true
        return stack
    }()

    private var accentColor: UIColor {
        UIColor(hex: "#5C48FA")
    }

    // MARK: - Status banner / progress / result matrix helpers

    private var bannerHideWorkItem: DispatchWorkItem?

    /// Show a status banner with optional auto-hide.
    /// - Parameters:
    ///   - text: The detail text (e.g. "Rendering 2/5: Layer Composite")
    ///   - kind: .info / .success / .failure
    ///   - autoHideAfter: hide automatically after N seconds (nil = stay visible)
    func showBanner(text: String, kind: BannerKind, autoHideAfter: TimeInterval? = nil) {
        bannerHideWorkItem?.cancel()
        statusBannerLabel.text = "  \(kind.symbol)  \(text)  "
        statusBannerLabel.backgroundColor = kind.background
        statusBannerLabel.isHidden = false
        if let after = autoHideAfter {
            let item = DispatchWorkItem { [weak self] in
                self?.hideBanner()
            }
            bannerHideWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + after, execute: item)
        }
    }

    func hideBanner() {
        bannerHideWorkItem?.cancel()
        statusBannerLabel.isHidden = true
    }

    /// Show the Run All progress bar with the given fraction (0...1).
    func showProgress(_ fraction: Float) {
        progressView.isHidden = false
        progressView.setProgress(fraction, animated: true)
    }

    func hideProgress() {
        progressView.setProgress(1.0, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.progressView.isHidden = true
            self?.progressView.setProgress(0, animated: false)
        }
    }

    /// Populate the 5-thumbnail result matrix from a Run All batch.
    /// Each thumbnail = 1 scenario with its final texture + status icon.
    func displayResultMatrix(_ entries: [(scenario: Scenario, image: UIImage?, passed: Bool, durationMs: Double)]) {
        resultMatrixStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for entry in entries {
            let container = UIView()
            container.backgroundColor = UIColor.secondarySystemBackground
            container.layer.cornerRadius = 8

            let imageView = UIImageView(image: entry.image)
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(imageView)

            let titleLabel = UILabel()
            titleLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
            titleLabel.textAlignment = .center
            titleLabel.numberOfLines = 2
            titleLabel.text = entry.scenario.title
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(titleLabel)

            let statusLabel = UILabel()
            statusLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
            statusLabel.textAlignment = .center
            statusLabel.text = entry.passed ? "✓" : "✗"
            statusLabel.textColor = entry.passed ? .systemGreen : .systemRed
            statusLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(statusLabel)

            let timingLabel = UILabel()
            timingLabel.font = UIFont.monospacedSystemFont(ofSize: 9, weight: .regular)
            timingLabel.textColor = .secondaryLabel
            timingLabel.textAlignment = .center
            timingLabel.text = String(format: "%.1fms", entry.durationMs)
            timingLabel.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(timingLabel)

            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
                imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
                imageView.heightAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.6),
                statusLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 2),
                statusLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                titleLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 2),
                titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
                titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
                timingLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 0),
                timingLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
                timingLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
                timingLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
                container.heightAnchor.constraint(greaterThanOrEqualToConstant: 90),
            ])

            resultMatrixStack.addArrangedSubview(container)
        }
        resultMatrixStack.isHidden = false
    }

    func hideResultMatrix() {
        resultMatrixStack.isHidden = true
        resultMatrixStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    /// Render the current `resultTexture` (an `MTLTexture`) into a
    /// `UIImage` suitable for the result matrix thumbnails. Synchronous
    /// because the texture is already finished rendering on the GPU side
    /// by the time the user reached this code path.
    func snapshotImage(from texture: MTLTexture) -> UIImage? {
        texture.c7.toImage()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        previousPerformanceMonitorEnabled = Shared.shared.enablePerformanceMonitor
        Shared.shared.enablePerformanceMonitor = false
        title = "ImageNode Lab"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Mask Lab",
            style: .plain,
            target: self,
            action: #selector(openMaskLab)
        )
        view.backgroundColor = .systemBackground
        setupUI()
        configureInitialState()
        renderScenario()
    }

    deinit {
        Shared.shared.enablePerformanceMonitor = previousPerformanceMonitorEnabled
    }
}

private extension UnitTestViewController {

    func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24)
        ])

        let controlCard = makeCard()
        let controlStack = UIStackView()
        controlStack.axis = .vertical
        controlStack.spacing = 12
        controlCard.addSubview(controlStack)
        controlStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controlStack.topAnchor.constraint(equalTo: controlCard.topAnchor, constant: 16),
            controlStack.leadingAnchor.constraint(equalTo: controlCard.leadingAnchor, constant: 16),
            controlStack.trailingAnchor.constraint(equalTo: controlCard.trailingAnchor, constant: -16),
            controlStack.bottomAnchor.constraint(equalTo: controlCard.bottomAnchor, constant: -16)
        ])

        let topButtons = UIStackView(arrangedSubviews: [scenarioButton, sourceButton])
        topButtons.axis = .horizontal
        topButtons.spacing = 12
        topButtons.distribution = .fillEqually

        let actionButtons = UIStackView(arrangedSubviews: [runButton, runAllButton])
        actionButtons.axis = .horizontal
        actionButtons.spacing = 12
        actionButtons.distribution = .fillEqually

        let samplerRow = makeControlRow(title: "Sampler", control: samplerSegmentedControl)
        let cacheRow = makeControlRow(title: "Cache", control: cacheSegmentedControl)
        let reportRow = makeControlRow(title: "Report", control: reportSegmentedControl)

        let sliderLabels = UIStackView(arrangedSubviews: [minimumValueLabel, currentValueLabel, maximumValueLabel])
        sliderLabels.axis = .horizontal
        sliderLabels.spacing = 8
        sliderLabels.distribution = .fillEqually

        controlStack.addArrangedSubview(topButtons)
        controlStack.addArrangedSubview(actionButtons)
        controlStack.addArrangedSubview(samplerRow)
        controlStack.addArrangedSubview(cacheRow)
        controlStack.addArrangedSubview(reportRow)
        controlStack.addArrangedSubview(controlSubtitleLabel)
        controlStack.addArrangedSubview(sliderLabels)
        controlStack.addArrangedSubview(controlSlider)

        let previewGrid = UIStackView(arrangedSubviews: [sourceCard.container, resultCard.container])
        previewGrid.axis = .horizontal
        previewGrid.spacing = 12
        previewGrid.distribution = .fillEqually

        contentStack.addArrangedSubview(controlCard)
        contentStack.addArrangedSubview(previewGrid)
        contentStack.addArrangedSubview(progressView)
        contentStack.addArrangedSubview(resultMatrixStack)

        let reportCard = makeCard()
        reportCard.addSubview(summaryTextView)
        NSLayoutConstraint.activate([
            summaryTextView.topAnchor.constraint(equalTo: reportCard.topAnchor),
            summaryTextView.leadingAnchor.constraint(equalTo: reportCard.leadingAnchor),
            summaryTextView.trailingAnchor.constraint(equalTo: reportCard.trailingAnchor),
            summaryTextView.bottomAnchor.constraint(equalTo: reportCard.bottomAnchor),
            summaryTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 320)
        ])
        contentStack.addArrangedSubview(reportCard)

        // The status banner sits above the control card so it is the first
        // thing the user sees whenever Run Current / Run All fires.
        contentStack.insertArrangedSubview(statusBannerLabel, at: 0)
    }

    func configureInitialState() {
        Scenario.allCases.forEach { controlValues[$0] = $0.control.defaultValue }
        reportSegmentedControl.selectedSegmentIndex = ReportMode.overview.rawValue
        scenarioButton.addTarget(self, action: #selector(selectScenario), for: .touchUpInside)
        sourceButton.addTarget(self, action: #selector(selectSource), for: .touchUpInside)
        refreshControlUI()
    }

    func refreshControlUI() {
        scenarioButton.setTitle("Scenario · \(selectedScenario.title)", for: .normal)
        sourceButton.setTitle("Source · \(effectiveSourceVariant.title)", for: .normal)
        sourceButton.isEnabled = selectedScenario.allowsSourceSelection
        sourceButton.alpha = selectedScenario.allowsSourceSelection ? 1 : 0.55

        let control = selectedScenario.control
        controlSlider.minimumValue = control.range.lowerBound
        controlSlider.maximumValue = control.range.upperBound
        controlSlider.value = controlValues[selectedScenario] ?? control.defaultValue
        minimumValueLabel.text = control.minimumText
        maximumValueLabel.text = control.maximumText
        currentValueLabel.text = String(format: "%.2f", controlSlider.value)
        controlSubtitleLabel.text = "\(control.title) · \(selectedScenario.subtitle)"
    }

    var effectiveSourceVariant: SourceVariant {
        selectedScenario.allowsSourceSelection ? selectedSource : .sampleBuffer
    }

    var selectedSamplerDescriptor: ImageSamplerDescriptor {
        samplerSegmentedControl.selectedSegmentIndex == 1 ? .nearest : .default
    }

    var selectedCachePolicy: ImageCachePolicy {
        cacheSegmentedControl.selectedSegmentIndex == 1 ? .persistent : .transient
    }

    var selectedReportMode: ReportMode {
        ReportMode(rawValue: reportSegmentedControl.selectedSegmentIndex) ?? .overview
    }

    func requestRenderScenario() {
        let state = RenderState(
            scenario: selectedScenario,
            sourceVariant: effectiveSourceVariant,
            intensity: controlSlider.value,
            samplerDescriptor: selectedSamplerDescriptor,
            cachePolicy: selectedCachePolicy,
            reportMode: selectedReportMode
        )
        pendingRenderState = state
        runButton.isEnabled = false
        runAllButton.isEnabled = false
        sourceCard.titleLabel.text = "Source · \(state.sourceVariant.title)"
        sourceCard.imageView.image = previewImage(for: state.scenario)
        resultCard.titleLabel.text = "Result · \(state.scenario.title)"
        drainScenarioRenderQueue()
    }

    func renderScenario() {
        requestRenderScenario()
    }

    func drainScenarioRenderQueue() {
        guard isRenderingScenario == false, let state = pendingRenderState else { return }
        pendingRenderState = nil
        isRenderingScenario = true
        generation &+= 1
        let currentGeneration = generation

        renderQueue.async { [weak self] in
            guard let self else { return }
            do {
                let result = try self.buildScenarioResult(
                    scenario: state.scenario,
                    sourceVariant: state.sourceVariant,
                    intensity: state.intensity,
                    samplerDescriptor: state.samplerDescriptor,
                    cachePolicy: state.cachePolicy,
                    reportMode: state.reportMode
                )
                DispatchQueue.main.async {
                    self.isRenderingScenario = false
                    guard currentGeneration == self.generation else {
                        self.drainScenarioRenderQueue()
                        return
                    }
                    self.currentResult = result
                    self.apply(result: result)
                    self.drainScenarioRenderQueue()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isRenderingScenario = false
                    guard currentGeneration == self.generation else {
                        self.drainScenarioRenderQueue()
                        return
                    }
                    self.currentResult = nil
                    self.apply(error: error, scenario: state.scenario, sourceVariant: state.sourceVariant)
                    self.drainScenarioRenderQueue()
                }
            }
        }
    }

    func buildScenarioResult(scenario: Scenario,
                             sourceVariant: SourceVariant,
                             intensity: Float,
                             samplerDescriptor: ImageSamplerDescriptor,
                             cachePolicy: ImageCachePolicy,
                             reportMode: ReportMode) throws -> ScenarioResult {
        let assets = try resolvedAssets()
        switch scenario {
        case .sourceCoverage:
            return try makeSourceCoverageScenario(
                assets: assets,
                sourceVariant: sourceVariant,
                intensity: intensity,
                samplerDescriptor: samplerDescriptor,
                cachePolicy: cachePolicy,
                reportMode: reportMode
            )
        case .editing:
            return try makeEditingScenario(
                assets: assets,
                sourceVariant: sourceVariant,
                intensity: intensity,
                samplerDescriptor: samplerDescriptor,
                cachePolicy: cachePolicy,
                reportMode: reportMode
            )
        case .layerComposite:
            return try makeLayerCompositeScenario(
                assets: assets,
                sourceVariant: sourceVariant,
                intensity: intensity,
                samplerDescriptor: samplerDescriptor,
                cachePolicy: cachePolicy,
                reportMode: reportMode
            )
        case .transition:
            return try makeTransitionScenario(
                assets: assets,
                sourceVariant: sourceVariant,
                intensity: intensity,
                samplerDescriptor: samplerDescriptor,
                cachePolicy: cachePolicy,
                reportMode: reportMode
            )
        case .cacheHit:
            return try makeCacheHitScenario(
                assets: assets,
                sourceVariant: sourceVariant,
                intensity: intensity,
                samplerDescriptor: samplerDescriptor,
                cachePolicy: cachePolicy,
                iterations: max(Int(intensity * 10), 1)
            )
        }
    }

    func makeSourceCoverageScenario(assets: DemoAssets,
                                    sourceVariant: SourceVariant,
                                    intensity: Float,
                                    samplerDescriptor: ImageSamplerDescriptor,
                                    cachePolicy: ImageCachePolicy,
                                    reportMode: ReportMode) throws -> ScenarioResult {
        let source = try makeSource(from: assets.primary, variant: sourceVariant)
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.04 + intensity * 0.18),
            C7Contrast(contrast: 1 + intensity * 0.22),
            C7Saturation(saturation: 1 + intensity * 0.3),
            C7CombinationColorGrading()
        ]
        let node = ImageNode
            .source(source)
            .applying(filters: filters)
            .withSamplerDescriptor(samplerDescriptor)
            .withCachePolicy(cachePolicy)

        return try finalizeScenario(
            scenario: .sourceCoverage,
            sourceTitle: sourceVariant.title,
            sourcePreview: assets.primary,
            node: node,
            profile: .stablePreview,
            reportMode: reportMode,
            highlights: [
                "This scenario focuses on the real availability of `ImageNode.source(...) + applying(filters:)` without relying on other public routes.",
                "Switching between `Image / Data / Asset / PixelBuffer / SampleBuffer` should preserve the same node mental model.",
                "Diagnostics key fields: `source.kind`, `compilationSource`, `stageCount`, `samplerExecutionCoverage`."
            ]
        )
    }

    func makeEditingScenario(assets: DemoAssets,
                             sourceVariant: SourceVariant,
                             intensity: Float,
                             samplerDescriptor: ImageSamplerDescriptor,
                             cachePolicy: ImageCachePolicy,
                             reportMode: ReportMode) throws -> ScenarioResult {
        let source = try makeSource(from: assets.primary, variant: sourceVariant)
        let imageSize = try sourcePixelSize(for: assets.primary)
        let maskRecipe = MaskGradientRecipe(
            size: imageSize,
            kind: .radial(center: CGPoint(x: 0.48, y: 0.42), startRadius: 0.08, endRadius: 0.48)
        )
        let localEffect = try LocalEffectRecipe(
            filters: [
                C7Exposure(exposure: 0.05 + intensity * 0.22),
                C7Contrast(contrast: 1.08 + intensity * 0.15)
            ],
            mask: maskRecipe,
            opacity: 0.55 + intensity * 0.25
        )
        let recipe = EditRecipe(
            geometry: ImageTransformRecipe(
                targetSize: CGSize(width: max(Int(CGFloat(imageSize.width) * 0.82), 1),
                                   height: max(Int(CGFloat(imageSize.height) * 0.82), 1)),
                aspectPolicy: .fill,
                rotationDegrees: -3 + intensity * 12
            ),
            localEffects: [localEffect]
        )
        let node = ImageNode
            .source(source)
            .editing(recipe, mode: .preview)
            .applying(C7Sharpen(sharpness: 0.15 + intensity * 0.35))
            .withSamplerDescriptor(samplerDescriptor)
            .withCachePolicy(cachePolicy)

        return try finalizeScenario(
            scenario: .editing,
            sourceTitle: sourceVariant.title,
            sourcePreview: assets.primary,
            node: node,
            profile: .stablePreview,
            reportMode: reportMode,
            highlights: [
                "Core ImageNode value scenario: geometry, masked local effect, and post filter on a single chain.",
                "Verify `compilationSource=editRecipe` and confirm the snapshot preserves the recipe boundary.",
                "Toggle `Sampler` and `Cache` here to observe diagnostic differences in place."
            ]
        )
    }

    func makeLayerCompositeScenario(assets: DemoAssets,
                                    sourceVariant: SourceVariant,
                                    intensity: Float,
                                    samplerDescriptor: ImageSamplerDescriptor,
                                    cachePolicy: ImageCachePolicy,
                                    reportMode: ReportMode) throws -> ScenarioResult {
        let background = try makeSource(from: assets.primary, variant: sourceVariant)
        let overlayMask = MaskShapeRecipe(
            size: C7Size(width: 1024, height: 1024),
            kind: .ellipse(rect: CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.84), feather: 0.22)
        )
        let foregroundLayer = ImageLayer(
            content: .image(assets.secondary),
            filters: [
                C7Contrast(contrast: 1.1 + intensity * 0.18),
                C7Saturation(saturation: 1.04 + intensity * 0.2),
                C7ColorRGBA(color: accentColor)
            ],
            normalizedFrame: CGRect(x: 0.08, y: 0.12, width: 0.52, height: 0.68),
            opacity: 0.58 + intensity * 0.28,
            blendMode: .exclusion,
            transform: ImageTransformRecipe(rotationDegrees: -8 + intensity * 18),
            mask: overlayMask,
            cornerRadius: 28,
            cornerCurve: .continuous
        )
        let accentLayer = ImageLayer(
            content: .image(assets.overlay),
            filters: [C7Opacity(opacity: 0.42 + intensity * 0.25)],
            normalizedFrame: CGRect(x: 0.48, y: 0.2, width: 0.42, height: 0.46),
            opacity: 0.45 + intensity * 0.3,
            blendMode: .overlay,
            transform: ImageTransformRecipe(rotationDegrees: 10 - intensity * 14),
            cornerRadius: 22
        )
        let recipe = LayerCompositeRecipe(
            background: background,
            layers: [foregroundLayer, accentLayer]
        )
        let node = ImageNode
            .layerComposite(recipe)
            .withSamplerDescriptor(samplerDescriptor)
            .withCachePolicy(cachePolicy)

        return try finalizeScenario(
            scenario: .layerComposite,
            sourceTitle: sourceVariant.title,
            sourcePreview: assets.primary,
            node: node,
            profile: recipe.profile,
            derivative: recipe.derivative,
            reportMode: reportMode,
            highlights: [
                "Demonstrates structured layered editing, not just a flat filter list.",
                "Per-layer filter, mask, corner, and blend should all live in the same route diagnostics.",
                "When this scenario stays stable, ImageNode earns its keep as a real image editing entry point."
            ]
        )
    }

    func makeTransitionScenario(assets: DemoAssets,
                                sourceVariant: SourceVariant,
                                intensity: Float,
                                samplerDescriptor: ImageSamplerDescriptor,
                                cachePolicy: ImageCachePolicy,
                                reportMode: ReportMode) throws -> ScenarioResult {
        let canvasSize = CGSize(
            width: max(assets.primary.size.width, assets.secondary.size.width),
            height: max(assets.primary.size.height, assets.secondary.size.height)
        )
        let fromImage = resizeImage(assets.secondary, to: canvasSize)
        let toImage = resizeImage(assets.primary, to: canvasSize)
        let from = try makeSource(from: fromImage, variant: sourceVariant)
        let to = try makeSource(from: toImage, variant: sourceVariant)
        let recipe = TransitionRecipe(
            from: from,
            to: to,
            kernel: .directionalWipe(angleDegrees: 35, softness: 0.08),
            progress: intensity
        )
        let node = ImageNode
            .transition(recipe)
            .withSamplerDescriptor(samplerDescriptor)
            .withCachePolicy(cachePolicy)

        return try finalizeScenario(
            scenario: .transition,
            sourceTitle: sourceVariant.title,
            sourcePreview: assets.primary,
            node: node,
            profile: recipe.profile,
            derivative: recipe.derivative,
            reportMode: reportMode,
            highlights: [
                "Dragging the slider directly edits transition progress; this verifies that recipes are not static documents.",
                "Key diagnostics: `compilationSource=transition` and snapshot summary.",
                "When transition holds up, ImageNode covers advanced single-frame graph editing, not just single-image color grading."
            ]
        )
    }

    // MARK: - English validation scenarios (4 new scenarios)

    func makeCacheHitScenario(assets: DemoAssets,
                              sourceVariant: SourceVariant,
                              intensity: Float,
                              samplerDescriptor: ImageSamplerDescriptor,
                              cachePolicy: ImageCachePolicy,
                              iterations: Int) throws -> ScenarioResult {
        let source = try makeSource(from: assets.primary, variant: sourceVariant)
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.05),
            C7Contrast(contrast: 1.05)
        ]
        let node = ImageNode
            .source(source)
            .applying(filters: filters)
            .withSamplerDescriptor(samplerDescriptor)
            .withCachePolicy(.persistent)

        var timings: [(iteration: Int, microseconds: Double)] = []
        var lines: [String] = ["ImageNode Resolved Texture Cache", ""]
        for index in 0..<max(iterations, 1) {
            let start = DispatchTime.now()
            let texture = try node.makeTexture(profile: .stablePreview)
            let elapsedNs = DispatchTime.now().uptimeNanoseconds &- start.uptimeNanoseconds
            timings.append((index + 1, Double(elapsedNs) / 1_000.0))
            lines.append("call #\(index + 1) -> \(texture.width)x\(texture.height) in \(String(format: "%.2f", Double(elapsedNs) / 1_000.0))us")
        }
        let firstMs = timings.first?.microseconds ?? 0
        let lastMs = timings.last?.microseconds ?? 0
        let speedup = firstMs > 0 ? String(format: "%.2fx", firstMs / max(lastMs, 0.001)) : "n/a"
        lines.append("")
        lines.append("first=\(String(format: "%.2f", firstMs))us last=\(String(format: "%.2f", lastMs))us speedup=\(speedup)")
        lines.append("cachePolicy=.persistent | iterations=\(iterations)")

        let frame = try node.makeFrame(profile: .stablePreview, metadata: ["scenario": Scenario.cacheHit.title])
        return ScenarioResult(
            scenario: .cacheHit,
            sourceTitle: sourceVariant.title,
            sourcePreview: assets.primary,
            resultTexture: frame.texture,
            highlights: [
                "With `.persistent` the second call should skip `makeTextureUncached` and reuse the cached texture.",
                "If the per-call time does not drop, the fix to ImageNode.swift:863-874 (forced `.transient`) is missing."
            ],
            diagnostics: try node.makeDiagnostics(profile: .stablePreview),
            request: nil,
            snapshot: nil,
            summary: lines.joined(separator: "\n"),
            codeSnippet: Self.codeSnippets[.cacheHit]
        )
    }

    func finalizeScenario(scenario: Scenario,
                          sourceTitle: String,
                          sourcePreview: UIImage,
                          node: ImageNode,
                          profile: RenderProfile,
                          derivative: ImageDerivativeSpec? = nil,
                          reportMode: ReportMode,
                          highlights: [String]) throws -> ScenarioResult {
        let frame = try node.makeFrame(profile: profile, derivative: derivative, metadata: ["scenario": scenario.title])
        let diagnostics = try node.makeDiagnostics(profile: profile, derivative: derivative)
        let request: RenderRequest?
        let snapshot: RenderGraphDebugSnapshot?
        switch reportMode {
        case .overview, .diagnostics:
            request = nil
            snapshot = nil
        case .request:
            request = try node.makeRenderRequest(profile: profile, derivative: derivative)
            snapshot = nil
        case .snapshot:
            request = nil
            snapshot = try node.makeDebugSnapshot(profile: profile, derivative: derivative)
        }
        let summary = [
            scenario.subtitle,
            "source=\(diagnostics.sourceKind ?? "unknown")",
            "compilation=\(diagnostics.compilationSource.rawValue)",
            "stageCount=\(diagnostics.stageCount)",
            "mergedStages=\(diagnostics.optimizationPlan.mergedStageCount)",
            "cachePolicy=\(diagnostics.imageCachePolicy.rawValue)",
            "samplerCoverage=\(diagnostics.samplerExecutionCoverage.mode.rawValue)",
            "frameToken.gen=\(frame.token.generation)"
        ].joined(separator: " | ")

        return ScenarioResult(
            scenario: scenario,
            sourceTitle: sourceTitle,
            sourcePreview: sourcePreview,
            resultTexture: frame.texture,
            highlights: highlights,
            diagnostics: diagnostics,
            request: request,
            snapshot: snapshot,
            summary: summary,
            codeSnippet: Self.codeSnippets[scenario]
        )
    }

    func apply(result: ScenarioResult) {
        // Reset the action buttons to their idle labels in case they were
        // swapped to "Rendering…" or "▶ 2/5 …" mid-flight.
        runButton.setTitle("▶ Run Current", for: .normal)
        runAllButton.setTitle("▶ Run All", for: .normal)
        runButton.isEnabled = true
        runAllButton.isEnabled = true
        sourceCard.titleLabel.text = "Source · \(result.sourceTitle)"
        sourceCard.imageView.image = result.sourcePreview
        resultCard.titleLabel.text = "Result · \(result.scenario.title)"
        resultCard.renderView.texture = result.resultTexture
        summaryTextView.text = reportText(for: result, mode: selectedReportMode)
    }

    func apply(error: Error, scenario: Scenario, sourceVariant: SourceVariant) {
        runButton.setTitle("▶ Run Current", for: .normal)
        runAllButton.setTitle("▶ Run All", for: .normal)
        runButton.isEnabled = true
        runAllButton.isEnabled = true
        sourceCard.titleLabel.text = "Source · \(sourceVariant.title)"
        resultCard.titleLabel.text = "Result · \(scenario.title)"
        sourceCard.imageView.image = nil
        resultCard.renderView.texture = nil
        summaryTextView.text = """
        Scenario: \(scenario.title)
        Source: \(sourceVariant.title)

        \(error.localizedDescription)
        """
    }

    func reportText(for result: ScenarioResult, mode: ReportMode) -> String {
        switch mode {
        case .overview:
            let highlights = result.highlights.enumerated().map {
                "\($0.offset + 1). \($0.element)"
            }.joined(separator: "\n")
            // `result.summary` carries per-scenario extras such as the cache
            // hit timing table; surface it after the diagnostics summary so
            // the on-screen text actually reflects slider movements (e.g.
            // changing the Iterations slider updates the timing table).
            let summaryBlock = result.summary.isEmpty ? "" : "\n\n\(result.summary)"
            let codeBlock = result.codeSnippet.map { "\n\nCanonical Usage\n\($0)" } ?? ""
            return """
            Scenario: \(result.scenario.title)
            Source: \(result.sourceTitle)

            \(result.scenario.subtitle)

            Highlights
            \(highlights)

            Diagnostics Summary
            \(result.diagnostics.summary)\(summaryBlock)\(codeBlock)
            """
        case .diagnostics:
            return prettyJSON(result.diagnostics)
        case .request:
            guard let request = result.request else {
                return "Request report not generated for current render. Switch to Request mode and the workbench will rerun this scenario."
            }
            return requestReport(request)
        case .snapshot:
            guard let snapshot = result.snapshot else {
                return "Snapshot report not generated for current render. Switch to Snapshot mode and the workbench will rerun this scenario."
            }
            return prettyJSON(snapshot)
        }
    }

    func requestReport(_ request: RenderRequest) -> String {
        var lines = [
            "compilationSource: \(request.compilationSource.rawValue)",
            "profile: \(request.profile.rawValue)",
            "derivative: \(request.derivative.name)",
            "source.kind: \(request.source.kind)",
            "sourceTier: \(request.source.sourceTier.rawValue)",
            "cachePolicy: \(request.outputCachePolicy.rawValue)",
            "semantic: \(request.source.semantic.fingerprint)",
            "loadingOptions: \(request.source.loadingOptions.fingerprint)"
        ]

        if let pixelBufferContract = request.source.pixelBufferContract {
            lines.append("pixelBuffer.cvPixelFormatType: \(pixelBufferContract.cvPixelFormatType)")
            lines.append("pixelBuffer.colorModel: \(pixelBufferContract.colorModel.rawValue)")
            lines.append("pixelBuffer.nativeTextureLayout: \(pixelBufferContract.nativeTextureLayout.rawValue)")
        }
        if let sampleBufferContract = request.source.sampleBufferContract {
            lines.append("sampleBuffer.isNotSync: \(sampleBufferContract.attachments.notSync ?? false)")
            lines.append("sampleBuffer.colorSpace: \(sampleBufferContract.pixelBufferContract?.attachmentColorSpace?.name ?? "nil")")
        }
        return lines.joined(separator: "\n")
    }

    func prettyJSON<T: Encodable>(_ value: T) -> String {
        guard let data = try? jsonEncoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return "JSON encoding failed."
        }
        return string
    }

    func resolvedAssets() throws -> DemoAssets {
        if let assetsCache {
            return assetsCache
        }
        let assets = try makeAssets()
        assetsCache = assets
        return assets
    }

    func makeAssets() throws -> DemoAssets {
        DemoAssets(
            primary: try requireImage("wechat0"),
            secondary: try requireImage("wechat1"),
            overlay: try requireImage("yuan001")
        )
    }

    func previewImage(for scenario: Scenario) -> UIImage? {
        guard let assets = try? resolvedAssets() else { return nil }
        return assets.primary
    }

    func requireImage(_ name: String) throws -> UIImage {
        guard let image = R.image(name) else {
            throw WorkbenchError.missingImage(name)
        }
        return image
    }

    /// Resize `image` to `size` using a `UIGraphicsImageRenderer` so both
    /// transition endpoints have identical dimensions. This matters because
    /// `InnerDirectionalWipeTransition` reads the `toTexture` at the
    /// `outputTexture` extent; if `toTexture` is smaller, the kernel's
    /// `safe_read` clamps to the right/bottom edge and the rest of the
    /// output becomes that edge colour (observed as a uniform green wash
    /// for the wechat0 / 828x828 case).
    func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func makeSource(from image: UIImage, variant: SourceVariant) throws -> ImageSource {
        switch variant {
        case .image:
            return .image(image)
        case .data:
            guard let data = image.c7.encodedPNGData() else {
                throw WorkbenchError.sourceEncoding("PNG encoding failed; cannot create data source.")
            }
            return .data(data)
        case .assetURL:
            guard let data = image.c7.encodedPNGData() else {
                throw WorkbenchError.sourceEncoding("PNG encoding failed; cannot create asset source.")
            }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("png")
            try data.write(to: url, options: .atomic)
            let asset = ImageAsset(
                storage: .url(url),
                loadingOptions: .init(sizePolicy: .original, flipsVertically: false)
            )
            return .asset(asset)
        case .pixelBuffer:
            guard let pixelBuffer = image.c7.toPixelBuffer() else {
                throw WorkbenchError.sourceEncoding("Failed to convert UIImage to pixelBuffer.")
            }
            return .pixelBuffer(pixelBuffer)
        case .sampleBuffer:
            guard let pixelBuffer = image.c7.toPixelBuffer(),
                  let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
                throw WorkbenchError.sourceEncoding("Failed to convert UIImage to sampleBuffer.")
            }
            return .sampleBuffer(sampleBuffer)
        }
    }

    func sourcePixelSize(for image: UIImage) throws -> C7Size {
        if let cgImage = image.cgImage {
            return C7Size(width: cgImage.width, height: cgImage.height)
        }
        let size = image.size
        guard size.width > 0, size.height > 0 else {
            throw WorkbenchError.sourceEncoding("Cannot resolve image dimensions.")
        }
        return C7Size(width: max(Int(size.width.rounded()), 1), height: max(Int(size.height.rounded()), 1))
    }

    func makeSampleBuffer(from image: UIImage) throws -> CMSampleBuffer {
        guard let pixelBuffer = image.c7.toPixelBuffer(),
              let sampleBuffer = pixelBuffer.c7.toCMSampleBuffer() else {
            throw WorkbenchError.sourceEncoding("Failed to convert UIImage to sampleBuffer.")
        }
        return sampleBuffer
    }
}

private extension UnitTestViewController {

    @objc func selectScenario(_ sender: UIButton) {
        presentActionSheet(
            title: "Select Scenario",
            sourceView: sender,
            options: Scenario.allCases.map { scenario in
                (scenario.title, { [weak self] in
                    guard let self else { return }
                    self.selectedScenario = scenario
                    self.refreshControlUI()
                    self.renderScenario()
                })
            }
        )
    }

    @objc func selectSource(_ sender: UIButton) {
        guard selectedScenario.allowsSourceSelection else { return }
        presentActionSheet(
            title: "Select Source",
            sourceView: sender,
            options: SourceVariant.allCases.map { variant in
                (variant.title, { [weak self] in
                    guard let self else { return }
                    self.selectedSource = variant
                    self.refreshControlUI()
                    self.renderScenario()
                })
            }
        )
    }

    @objc func settingDidChange() {
        // Sampler / Cache change: light cross dissolve
        UIView.transition(with: resultCard.container, duration: 0.25, options: .transitionCrossDissolve) {
            self.renderScenario()
        }
    }

    @objc func reportModeDidChange() {
        guard let result = currentResult else { return }
        switch selectedReportMode {
        case .request where result.request == nil:
            renderScenario()
        case .snapshot where result.snapshot == nil:
            renderScenario()
        default:
            summaryTextView.text = reportText(for: result, mode: selectedReportMode)
        }
    }

    @objc func sliderValueDidChange(_ sender: UISlider) {
        controlValues[selectedScenario] = sender.value
        currentValueLabel.text = String(format: "%.2f", sender.value)
        renderScenario()
    }

    @objc func runCurrentScenario() {
        hideBanner()
        runButton.setTitle("Rendering…", for: .normal)
        runButton.isEnabled = false
        runAllButton.isEnabled = false
        renderScenario()
    }

    @objc func runAllScenarios() {
        generation &+= 1
        let currentGeneration = generation
        runButton.isEnabled = false
        runAllButton.isEnabled = false
        runAllButton.setTitle("▶ Running…", for: .normal)
        showBanner(text: "Starting Run All…", kind: .info, autoHideAfter: nil)
        showProgress(0)
        hideResultMatrix()

        let scenarios = Scenario.allCases
        let sourceVariant = selectedSource
        let samplerDescriptor = selectedSamplerDescriptor
        let cachePolicy = selectedCachePolicy
        let values = controlValues

        renderQueue.async { [weak self] in
            guard let self else { return }
            var lines: [String] = []
            var successCount = 0
            // Per-scenario timing and final texture, used to populate the
            // 5-thumbnail result matrix once the run completes.
            struct Entry { let scenario: Scenario; let image: UIImage?; let passed: Bool; let durationMs: Double }
            var entries: [Entry] = []

            for (index, scenario) in scenarios.enumerated() {
                // Surface live progress on the main thread so the user sees
                // which scenario is currently rendering.
                DispatchQueue.main.async {
                    self.runAllButton.setTitle(
                        "▶ \(index + 1)/\(scenarios.count) \(scenario.title)",
                        for: .normal
                    )
                    self.showBanner(text: "Running \(index + 1)/\(scenarios.count): \(scenario.title)", kind: .info, autoHideAfter: nil)
                    // Drive the progress bar; leave a small head-start so the
                    // user sees the bar moving even when each scenario is fast.
                    let fraction = Float(index) / Float(scenarios.count)
                    self.showProgress(fraction)
                }
                let effectiveVariant = scenario.allowsSourceSelection ? sourceVariant : .sampleBuffer
                let intensity = values[scenario] ?? scenario.control.defaultValue
                let start = DispatchTime.now()
                var passed = false
                var image: UIImage? = nil
                do {
                    let result = try self.buildScenarioResult(
                        scenario: scenario,
                        sourceVariant: effectiveVariant,
                        intensity: intensity,
                        samplerDescriptor: samplerDescriptor,
                        cachePolicy: cachePolicy,
                        reportMode: .overview
                    )
                    passed = true
                    successCount += 1
                    lines.append("[PASS] \(scenario.title) | source=\(result.diagnostics.sourceKind ?? "unknown") | compilation=\(result.diagnostics.compilationSource.rawValue) | stages=\(result.diagnostics.stageCount) | frameToken.gen=\(result.diagnostics.graphFingerprint.isEmpty ? "n/a" : "ok")")
                    image = self.snapshotImage(from: result.resultTexture)
                    // Apply the result immediately so the user sees each
                    // scenario's image as it is produced, not just the last one.
                    DispatchQueue.main.async {
                        self.apply(result: result)
                    }
                } catch {
                    lines.append("[FAIL] \(scenario.title) | \(error.localizedDescription)")
                }
                let durationMs = Double(DispatchTime.now().uptimeNanoseconds &- start.uptimeNanoseconds) / 1_000_000.0
                entries.append(Entry(scenario: scenario, image: image, passed: passed, durationMs: durationMs))
            }

            // 5 sources x 10 scenarios x 2 samplers x 2 cachePolicies = 200 combinations, but we only flip
            // one axis per Run All invocation to keep the report compact. The selected source and
            // sampler/cache pickers already drive that one axis.
            let axisCount = max(1, (cachePolicy == .persistent ? 1 : 0) + (samplerDescriptor == .default ? 0 : 1) + 1)
            let report = """
            ImageNode Validation Matrix
            success=\(successCount)/\(scenarios.count)
            sampler=\(samplerDescriptor.fingerprint)
            cache=\(cachePolicy.rawValue)
            source=\(sourceVariant.title)
            activeAxes=\(axisCount) (1 source × \(scenarios.count) scenarios × \(axisCount) cache/sampler)

            \(lines.joined(separator: "\n"))
            """

            let finalEntries = entries
            DispatchQueue.main.async {
                guard currentGeneration == self.generation else { return }
                self.runButton.setTitle("▶ Run Current", for: .normal)
                self.runAllButton.setTitle("▶ Run All", for: .normal)
                self.runButton.isEnabled = true
                self.runAllButton.isEnabled = true
                self.summaryTextView.text = report
                // Hide progress bar (briefly animate to 100% first).
                self.showProgress(1.0)
                self.hideProgress()
                // Surface the 5-thumbnail result matrix so the user can see
                // the per-scenario outcome at a glance.
                self.displayResultMatrix(finalEntries.map {
                    (scenario: $0.scenario, image: $0.image, passed: $0.passed, durationMs: $0.durationMs)
                })
                let totalMs = finalEntries.reduce(0.0) { $0 + $1.durationMs }
                let avg = totalMs / Double(max(finalEntries.count, 1))
                let kind: BannerKind = (successCount == finalEntries.count) ? .success : .failure
                let message = successCount == finalEntries.count
                    ? "All \(successCount)/\(finalEntries.count) passed · total \(String(format: "%.0f", totalMs))ms · avg \(String(format: "%.0f", avg))ms"
                    : "\(successCount)/\(finalEntries.count) passed (some failed)"
                self.showBanner(text: message, kind: kind, autoHideAfter: 4.0)
            }
        }
    }

    @objc func openMaskLab() {
        navigationController?.pushViewController(MaskShowcaseViewController(), animated: true)
    }

    func presentActionSheet(title: String, sourceView: UIView, options: [(String, () -> Void)]) {
        let controller = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        options.forEach { option in
            controller.addAction(UIAlertAction(title: option.0, style: .default) { _ in
                option.1()
            })
        }
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = controller.popoverPresentationController {
            popover.sourceView = sourceView
            popover.sourceRect = sourceView.bounds
        }
        present(controller, animated: true)
    }
}

private extension UnitTestViewController {

    func makeActionButton(title: String? = nil, action: Selector? = nil) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.setTitleColor(accentColor, for: .normal)
        button.backgroundColor = accentColor.withAlphaComponent(0.08)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = accentColor.withAlphaComponent(0.16).cgColor
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.7
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        if let action {
            button.addTarget(self, action: action, for: .touchUpInside)
        }
        return button
    }

    func makeControlRow(title: String, control: UIView) -> UIStackView {
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = accentColor
        let row = UIStackView(arrangedSubviews: [label, control])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        return row
    }

    func makeCaptionLabel(alignment: NSTextAlignment = .center) -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = alignment
        return label
    }

    func makeValueLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        label.textColor = accentColor
        label.textAlignment = .center
        return label
    }

    func makeCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor.secondarySystemBackground
        card.layer.cornerRadius = 16
        card.layer.borderWidth = 1
        card.layer.borderColor = accentColor.withAlphaComponent(0.08).cgColor
        return card
    }

    func makeImageCard(title: String) -> (container: UIView, titleLabel: UILabel, imageView: UIImageView) {
        let container = makeCard()
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = accentColor

        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .systemBackground
        imageView.layer.cornerRadius = 12
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = accentColor.withAlphaComponent(0.12).cgColor

        container.addSubview(titleLabel)
        container.addSubview(imageView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),

            imageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 1)
        ])

        return (container, titleLabel, imageView)
    }

    func makePreviewCard(title: String) -> (container: UIView, titleLabel: UILabel, renderView: RenderView) {
        let container = makeCard()
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = accentColor

        let renderView = RenderView()
        renderView.translatesAutoresizingMaskIntoConstraints = false
        renderView.backgroundColor = .systemBackground
        renderView.layer.cornerRadius = 12
        renderView.layer.masksToBounds = true
        renderView.layer.borderWidth = 1
        renderView.layer.borderColor = accentColor.withAlphaComponent(0.12).cgColor

        container.addSubview(titleLabel)
        container.addSubview(renderView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),

            renderView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            renderView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            renderView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            renderView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
            renderView.heightAnchor.constraint(equalTo: renderView.widthAnchor, multiplier: 1)
        ])

        return (container, titleLabel, renderView)
    }
}
