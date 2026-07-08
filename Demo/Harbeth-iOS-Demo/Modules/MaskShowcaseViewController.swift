//
//  MaskShowcaseViewController.swift
//  Harbeth-iOS-Demo
//
//  Created by Condy on 2026/6/29.
//

import UIKit
import Harbeth

final class MaskShowcaseViewController: UIViewController {

    enum MaskFamily: Int, CaseIterable {
        case portrait
        case geometry
        case editorial

        var title: String {
            switch self {
            case .portrait: return "Portrait"
            case .geometry: return "Geometry"
            case .editorial: return "Editorial"
            }
        }

        var subtitle: String {
            switch self {
            case .portrait:
                return "人像/主体局部蒙板，接近 Awaking 常见用法。"
            case .geometry:
                return "几何蒙板目录和形状切换，验证基础路径行为。"
            case .editorial:
                return "风格化区域、色片和版式感，偏海报展示。"
            }
        }
    }

    enum MaskWorkbenchStyle: Int, CaseIterable {
        case spotlight
        case cutout
        case stacked

        var title: String {
            switch self {
            case .spotlight: return "Spotlight"
            case .cutout: return "Cutout"
            case .stacked: return "Stacked"
            }
        }

        func subtitle(for family: MaskFamily) -> String {
            switch (family, self) {
            case (.portrait, .spotlight):
                return "单主体提亮，最接近基础局部增强。"
            case (.portrait, .cutout):
                return "主体 + 挖空区域，强调删除和重建。"
            case (.portrait, .stacked):
                return "主体 + 辅助强调区，模拟多局部效果叠加。"
            case (.geometry, .spotlight):
                return "用单个规则形状验证基础 path 行为。"
            case (.geometry, .cutout):
                return "规则形状组合出 cutout，方便看复用错乱。"
            case (.geometry, .stacked):
                return "多几何区域共享多个效果组。"
            case (.editorial, .spotlight):
                return "单块风格化染色区，偏海报感。"
            case (.editorial, .cutout):
                return "主视觉区挖空，模拟版式型遮挡。"
            case (.editorial, .stacked):
                return "主视觉 + 色片 + 细节区，最接近完整展示稿。"
            }
        }
    }

    enum MaskShape: CaseIterable {
        case ellipse
        case triangle
        case hexagon
        case roundedRect

        var title: String {
            switch self {
            case .ellipse: return "Ellipse"
            case .triangle: return "Triangle"
            case .hexagon: return "Hexagon"
            case .roundedRect: return "Rounded Rect"
            }
        }

        func next() -> MaskShape {
            let all = MaskShape.allCases
            guard let index = all.firstIndex(of: self) else { return .ellipse }
            return all[(index + 1) % all.count]
        }
    }

    enum MaskRole: String {
        case subject = "Subject"
        case cutout = "Cutout"
        case accent = "Accent"
    }

    enum EffectGroupKind: Int, CaseIterable {
        case toneBoost
        case colorWash
        case detailEdge

        var title: String {
            switch self {
            case .toneBoost: return "Tone"
            case .colorWash: return "Color"
            case .detailEdge: return "Detail"
            }
        }

        var description: String {
            switch self {
            case .toneBoost:
                return "曝光、对比、饱和度，模拟基础提亮组。"
            case .colorWash:
                return "颜色染色 + 透明度，模拟风格色片组。"
            case .detailEdge:
                return "清晰度和结构感，模拟细节加强组。"
            }
        }
    }

    struct MaskEntry {
        let id: Int
        let role: MaskRole
        let rect: CGRect
        var shape: MaskShape
        var isDeleted: Bool
    }

    struct EffectGroupState {
        let kind: EffectGroupKind
        var isEnabled: Bool
        var assignedMaskIDs: [Int]
    }

    struct DemoAssets {
        let primary: UIImage
    }

    func resolvedAssets() throws -> DemoAssets {
        if let assetsCache { return assetsCache }
        let assets = DemoAssets(primary: try requireImage("yuan001"))
        assetsCache = assets
        return assets
    }

    private let renderQueue = DispatchQueue(label: "com.condy.harbeth.mask-workbench", qos: .userInitiated)
    private var assetsCache: DemoAssets?

    private var selectedFamily: MaskFamily = .portrait
    private var selectedStyle: MaskWorkbenchStyle = .stacked
    private var selectedGroupKind: EffectGroupKind = .toneBoost
    private var masks: [MaskEntry] = []
    private var effectGroups: [EffectGroupState] = []
    private var groupStrengths: [EffectGroupKind: Float] = [:]
    private var selectedMaskID: Int?
    private var overlayEnabled = true
    private var rebuildCount = 0
    private var nextMaskID = 1
    private var operationLog: [String] = []

    private var lastReportText: String = ""
    private var isRendering = false

    private var accentColor: UIColor { UIColor(hex: "#5C48FA") }
    private var dangerColor: UIColor { UIColor(hex: "#FF3B30") }
    private var successColor: UIColor { UIColor(hex: "#34C759") }

    private var activeMasks: [MaskEntry] {
        masks.filter { !$0.isDeleted }
    }

    private var selectedActiveMask: MaskEntry? {
        guard let selectedMaskID else { return nil }
        return activeMasks.first(where: { $0.id == selectedMaskID })
    }

    private var selectedGroupState: EffectGroupState? {
        effectGroups.first(where: { $0.kind == selectedGroupKind })
    }

    // MARK: - Views

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

    // Hero Result Area
    private lazy var resultHeroContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.shadowColor = accentColor.withAlphaComponent(0.25).cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 16
        view.layer.shadowOpacity = 1
        return view
    }()

    private lazy var resultTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.textColor = accentColor
        label.textAlignment = .center
        label.text = "Mask Result"
        return label
    }()

    private lazy var resultRenderView: RenderView = {
        let view = RenderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        view.layer.borderWidth = 1
        view.layer.borderColor = accentColor.withAlphaComponent(0.12).cgColor
        return view
    }()

    private lazy var renderActivityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = accentColor
        indicator.hidesWhenStopped = true
        indicator.isHidden = true
        return indicator
    }()

    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Retry", for: .normal)
        button.setTitleColor(accentColor, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.isHidden = true
        button.addTarget(self, action: #selector(retryRender), for: .touchUpInside)
        return button
    }()

    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = dangerColor
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private lazy var overlayView: MaskOverlayView = {
        let view = MaskOverlayView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }()

    // Controls
    private lazy var familyControl: UISegmentedControl = {
        let control = UISegmentedControl(items: MaskFamily.allCases.map(\.title))
        control.selectedSegmentIndex = MaskFamily.portrait.rawValue
        control.addTarget(self, action: #selector(familyDidChange(_:)), for: .valueChanged)
        return control
    }()

    private lazy var styleControl: UISegmentedControl = {
        let control = UISegmentedControl(items: MaskWorkbenchStyle.allCases.map(\.title))
        control.selectedSegmentIndex = MaskWorkbenchStyle.stacked.rawValue
        control.addTarget(self, action: #selector(styleDidChange(_:)), for: .valueChanged)
        return control
    }()

    private lazy var groupControl: UISegmentedControl = {
        let control = UISegmentedControl(items: EffectGroupKind.allCases.map(\.title))
        control.selectedSegmentIndex = EffectGroupKind.toneBoost.rawValue
        control.addTarget(self, action: #selector(groupDidChange(_:)), for: .valueChanged)
        return control
    }()

    private lazy var familySubtitleLabel: UILabel = makeSecondaryLabel()
    private lazy var styleSubtitleLabel: UILabel = makeSecondaryLabel()

    // Buttons — 2-column layout
    private lazy var addMaskButton: UIButton = makePrimaryButton(title: "+ Add Mask", action: #selector(addMask))
    private lazy var replaceShapeButton: UIButton = makeActionButton(title: "Replace Shape", action: #selector(replaceShape), style: .standard)
    private lazy var softDeleteButton: UIButton = makeActionButton(title: "Remove Mask", action: #selector(softDeleteSelectedMask), style: .danger)
    private lazy var assignGroupButton: UIButton = makeActionButton(title: "Assign To Group", action: #selector(assignSelectedMaskToGroup), style: .standard)
    private lazy var toggleGroupButton: UIButton = makeActionButton(title: "Toggle Group", action: #selector(toggleSelectedGroup), style: .standard)
    private lazy var smokeButton: UIButton = makeActionButton(title: "Lifecycle Smoke", action: #selector(runLifecycleSmoke), style: .standard)

    // Overlay Toggle (UISwitch)
    private lazy var overlaySwitchLabel: UILabel = {
        let label = UILabel()
        label.text = "Overlay"
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        return label
    }()

    private lazy var overlaySwitch: UISwitch = {
        let s = UISwitch()
        s.onTintColor = accentColor
        s.isOn = true
        s.addTarget(self, action: #selector(overlaySwitchDidChange(_:)), for: .valueChanged)
        return s
    }()

    // Slider
    private lazy var groupStrengthSlider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.tintColor = accentColor
        slider.addTarget(self, action: #selector(groupStrengthDidChange(_:)), for: .valueChanged)
        return slider
    }()

    private lazy var groupStrengthValueLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .center
        label.textColor = accentColor
        return label
    }()

    private lazy var workflowLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.text = "Workflow: Mask Family → Mask Type → Session Masks → Effect Groups → LocalEffectRecipe[] → EditRecipe → ImageNode → RenderView"
        return label
    }()

    private lazy var sessionSummaryLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private lazy var groupTextView: UITextView = makeMonoTextView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Mask Lab"
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "doc.text.magnifyingglass"),
            style: .plain,
            target: self,
            action: #selector(showReportModal)
        )
        navigationItem.rightBarButtonItem?.tintColor = accentColor
        setupUI()
        seedSession(family: .portrait, style: .stacked, logReason: "initial load")
    }
}

private extension MaskShowcaseViewController {

    func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32)
        ])

        // ── Hero Result Area ──
        resultHeroContainer.addSubview(resultTitleLabel)
        resultHeroContainer.addSubview(resultRenderView)
        resultHeroContainer.addSubview(renderActivityIndicator)
        resultHeroContainer.addSubview(retryButton)
        resultHeroContainer.addSubview(errorLabel)
        resultHeroContainer.addSubview(overlayView)
        NSLayoutConstraint.activate([
            resultTitleLabel.topAnchor.constraint(equalTo: resultHeroContainer.topAnchor),
            resultTitleLabel.leadingAnchor.constraint(equalTo: resultHeroContainer.leadingAnchor, constant: 16),
            resultTitleLabel.trailingAnchor.constraint(equalTo: resultHeroContainer.trailingAnchor, constant: -16),

            resultRenderView.topAnchor.constraint(equalTo: resultTitleLabel.bottomAnchor, constant: 14),
            resultRenderView.leadingAnchor.constraint(equalTo: resultHeroContainer.leadingAnchor),
            resultRenderView.trailingAnchor.constraint(equalTo: resultHeroContainer.trailingAnchor),
            resultRenderView.heightAnchor.constraint(equalTo: resultRenderView.widthAnchor, multiplier: 3/4),
            resultRenderView.bottomAnchor.constraint(equalTo: resultHeroContainer.bottomAnchor),

            renderActivityIndicator.centerXAnchor.constraint(equalTo: resultRenderView.centerXAnchor),
            renderActivityIndicator.centerYAnchor.constraint(equalTo: resultRenderView.centerYAnchor),

            retryButton.centerXAnchor.constraint(equalTo: resultRenderView.centerXAnchor),
            retryButton.centerYAnchor.constraint(equalTo: resultRenderView.centerYAnchor),

            errorLabel.topAnchor.constraint(equalTo: resultRenderView.bottomAnchor, constant: 8),
            errorLabel.leadingAnchor.constraint(equalTo: resultHeroContainer.leadingAnchor, constant: 24),
            errorLabel.trailingAnchor.constraint(equalTo: resultHeroContainer.trailingAnchor, constant: -24),

            overlayView.topAnchor.constraint(equalTo: resultRenderView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: resultRenderView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: resultRenderView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: resultRenderView.bottomAnchor),
        ])

        // ── Mask Family Card ──
        let familyCard = makeCard()
        let familyTitle = makeSectionTitle("Mask Family")
        familyCard.addSubview(familyTitle)
        familyCard.addSubview(familyControl)
        familyCard.addSubview(familySubtitleLabel)
        NSLayoutConstraint.activate([
            familyTitle.topAnchor.constraint(equalTo: familyCard.topAnchor, constant: 16),
            familyTitle.leadingAnchor.constraint(equalTo: familyCard.leadingAnchor, constant: 16),
            familyTitle.trailingAnchor.constraint(equalTo: familyCard.trailingAnchor, constant: -16),
            familyControl.topAnchor.constraint(equalTo: familyTitle.bottomAnchor, constant: 12),
            familyControl.leadingAnchor.constraint(equalTo: familyCard.leadingAnchor, constant: 16),
            familyControl.trailingAnchor.constraint(equalTo: familyCard.trailingAnchor, constant: -16),
            familySubtitleLabel.topAnchor.constraint(equalTo: familyControl.bottomAnchor, constant: 12),
            familySubtitleLabel.leadingAnchor.constraint(equalTo: familyCard.leadingAnchor, constant: 16),
            familySubtitleLabel.trailingAnchor.constraint(equalTo: familyCard.trailingAnchor, constant: -16),
            familySubtitleLabel.bottomAnchor.constraint(equalTo: familyCard.bottomAnchor, constant: -32)
        ])

        // ── Mask Type Card ──
        let styleCard = makeCard()
        let styleTitle = makeSectionTitle("Mask Type")
        styleCard.addSubview(styleTitle)
        styleCard.addSubview(styleControl)
        styleCard.addSubview(styleSubtitleLabel)
        NSLayoutConstraint.activate([
            styleTitle.topAnchor.constraint(equalTo: styleCard.topAnchor, constant: 16),
            styleTitle.leadingAnchor.constraint(equalTo: styleCard.leadingAnchor, constant: 16),
            styleTitle.trailingAnchor.constraint(equalTo: styleCard.trailingAnchor, constant: -16),
            styleControl.topAnchor.constraint(equalTo: styleTitle.bottomAnchor, constant: 12),
            styleControl.leadingAnchor.constraint(equalTo: styleCard.leadingAnchor, constant: 16),
            styleControl.trailingAnchor.constraint(equalTo: styleCard.trailingAnchor, constant: -16),
            styleSubtitleLabel.topAnchor.constraint(equalTo: styleControl.bottomAnchor, constant: 12),
            styleSubtitleLabel.leadingAnchor.constraint(equalTo: styleCard.leadingAnchor, constant: 16),
            styleSubtitleLabel.trailingAnchor.constraint(equalTo: styleCard.trailingAnchor, constant: -16),
            styleSubtitleLabel.bottomAnchor.constraint(equalTo: styleCard.bottomAnchor, constant: -32)
        ])

        // ── Workbench Card ──
        let workbenchCard = makeCard()
        let workbenchTitle = makeSectionTitle("Workbench")
        let workbenchStack = UIStackView()
        workbenchStack.translatesAutoresizingMaskIntoConstraints = false
        workbenchStack.axis = .vertical
        workbenchStack.spacing = 10
        workbenchCard.addSubview(workbenchTitle)
        workbenchCard.addSubview(workbenchStack)
        NSLayoutConstraint.activate([
            workbenchTitle.topAnchor.constraint(equalTo: workbenchCard.topAnchor, constant: 16),
            workbenchTitle.leadingAnchor.constraint(equalTo: workbenchCard.leadingAnchor, constant: 16),
            workbenchTitle.trailingAnchor.constraint(equalTo: workbenchCard.trailingAnchor, constant: -16),
            workbenchStack.topAnchor.constraint(equalTo: workbenchTitle.bottomAnchor, constant: 12),
            workbenchStack.leadingAnchor.constraint(equalTo: workbenchCard.leadingAnchor, constant: 16),
            workbenchStack.trailingAnchor.constraint(equalTo: workbenchCard.trailingAnchor, constant: -16),
            workbenchStack.bottomAnchor.constraint(equalTo: workbenchCard.bottomAnchor, constant: -16)
        ])

        // 2-column button rows
        let row1 = makeButtonRow([addMaskButton, softDeleteButton])
        let row2 = makeButtonRow([replaceShapeButton, smokeButton])
        let row3 = makeButtonRow([assignGroupButton, toggleGroupButton])
        workbenchStack.addArrangedSubview(row1)
        workbenchStack.addArrangedSubview(row2)
        workbenchStack.addArrangedSubview(row3)

        // Overlay switch row
        let overlayRow = UIStackView(arrangedSubviews: [overlaySwitchLabel, overlaySwitch])
        overlayRow.axis = .horizontal
        overlayRow.spacing = 12
        overlayRow.alignment = .center
        workbenchStack.addArrangedSubview(overlayRow)
        workbenchStack.addArrangedSubview(workflowLabel)

        let sliderRow = UIStackView(arrangedSubviews: [
            makeCaptionLabel(text: "Selected Group Strength", alignment: .left),
            groupStrengthValueLabel
        ])
        sliderRow.axis = .horizontal
        sliderRow.distribution = .fillEqually
        workbenchStack.addArrangedSubview(sliderRow)
        workbenchStack.addArrangedSubview(groupStrengthSlider)
        workbenchStack.addArrangedSubview(sessionSummaryLabel)

        // ── Effect Groups Card ──
        let groupCard = makeCard()
        let groupTitle = makeSectionTitle("Effect Groups")
        groupCard.addSubview(groupTitle)
        groupCard.addSubview(groupControl)
        groupCard.addSubview(groupTextView)
        NSLayoutConstraint.activate([
            groupTitle.topAnchor.constraint(equalTo: groupCard.topAnchor, constant: 16),
            groupTitle.leadingAnchor.constraint(equalTo: groupCard.leadingAnchor, constant: 16),
            groupTitle.trailingAnchor.constraint(equalTo: groupCard.trailingAnchor, constant: -16),
            groupControl.topAnchor.constraint(equalTo: groupTitle.bottomAnchor, constant: 12),
            groupControl.leadingAnchor.constraint(equalTo: groupCard.leadingAnchor, constant: 16),
            groupControl.trailingAnchor.constraint(equalTo: groupCard.trailingAnchor, constant: -16),
            groupTextView.topAnchor.constraint(equalTo: groupControl.bottomAnchor, constant: 12),
            groupTextView.leadingAnchor.constraint(equalTo: groupCard.leadingAnchor, constant: 16),
            groupTextView.trailingAnchor.constraint(equalTo: groupCard.trailingAnchor, constant: -16),
            groupTextView.bottomAnchor.constraint(equalTo: groupCard.bottomAnchor, constant: -16),
            groupTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])

        contentStack.addArrangedSubview(resultHeroContainer)
        contentStack.addArrangedSubview(makeSeparator())
        contentStack.addArrangedSubview(familyCard)
        contentStack.addArrangedSubview(styleCard)
        contentStack.addArrangedSubview(workbenchCard)
        contentStack.addArrangedSubview(groupCard)
    }

    func seedSession(family: MaskFamily, style: MaskWorkbenchStyle, logReason: String) {
        selectedFamily = family
        selectedStyle = style
        selectedGroupKind = .toneBoost
        nextMaskID = 1
        rebuildCount = 0
        operationLog = ["session reset: \(logReason)"]
        masks = makeBaseMasks(for: family, style: style)
        effectGroups = makeBaseGroups(for: family, style: style, masks: masks)
        groupStrengths = [
            .toneBoost: 0.66,
            .colorWash: 0.48,
            .detailEdge: 0.38
        ]
        selectedMaskID = activeMasks.first?.id
        refreshUI()
        renderCurrentState(reason: "seed \(family.title) \(style.title)")
    }

    func refreshUI() {
        familyControl.selectedSegmentIndex = selectedFamily.rawValue
        styleControl.selectedSegmentIndex = selectedStyle.rawValue
        groupControl.selectedSegmentIndex = selectedGroupKind.rawValue
        familySubtitleLabel.text = selectedFamily.subtitle
        styleSubtitleLabel.text = selectedStyle.subtitle(for: selectedFamily)
        overlaySwitch.isOn = overlayEnabled
        replaceShapeButton.isEnabled = selectedActiveMask != nil
        softDeleteButton.isEnabled = selectedActiveMask != nil
        assignGroupButton.isEnabled = selectedActiveMask != nil
        let selectedStrength = groupStrengths[selectedGroupKind] ?? 0
        groupStrengthSlider.value = selectedStrength
        groupStrengthValueLabel.text = "\(selectedGroupKind.title) \(String(format: "%.2f", selectedStrength))"
        sessionSummaryLabel.text = """
        family=\(selectedFamily.title)  style=\(selectedStyle.title)  active=\(activeMasks.count)  deleted=\(masks.filter(\.isDeleted).count)  rebuilds=\(rebuildCount)
        selectedMask=\(selectedMaskSummary)  selectedGroup=\(selectedGroupSummary)  overlay=\(overlayEnabled ? "on" : "off")
        """
        groupTextView.text = makeGroupText()
    }

    var selectedMaskSummary: String {
        guard let mask = selectedActiveMask else { return "none" }
        return "#\(mask.id) \(mask.role.rawValue) \(mask.shape.title)"
    }

    var selectedGroupSummary: String {
        guard let group = selectedGroupState else { return "none" }
        let strength = groupStrengths[group.kind] ?? 0
        return "\(group.kind.title) \(group.isEnabled ? "on" : "off") \(String(format: "%.2f", strength))"
    }

    // MARK: - Actions

    @objc func familyDidChange(_ sender: UISegmentedControl) {
        guard let family = MaskFamily(rawValue: sender.selectedSegmentIndex) else {
            sender.selectedSegmentIndex = selectedFamily.rawValue
            return
        }
        guard family != selectedFamily else { return }
        let familyTitle = family.title
        self.seedSession(family: family, style: self.selectedStyle, logReason: "switch family → \(familyTitle)")
    }

    @objc func styleDidChange(_ sender: UISegmentedControl) {
        guard let style = MaskWorkbenchStyle(rawValue: sender.selectedSegmentIndex) else {
            sender.selectedSegmentIndex = selectedStyle.rawValue
            return
        }
        guard style != selectedStyle else { return }
        let styleTitle = style.title
        self.seedSession(family: self.selectedFamily, style: style, logReason: "switch style → \(styleTitle)")
    }

    @objc func groupDidChange(_ sender: UISegmentedControl) {
        selectedGroupKind = EffectGroupKind(rawValue: sender.selectedSegmentIndex) ?? .toneBoost
        refreshUI()
    }

    @objc func addMask() {
        let newMask = makeSupplementMask(for: selectedFamily, style: selectedStyle, existingCount: activeMasks.count)
        masks.append(newMask)
        selectedMaskID = newMask.id
        appendLog("mask #\(newMask.id) added as \(newMask.role.rawValue) \(newMask.shape.title)")
        refreshUI()
        renderCurrentState(reason: "add mask")
    }

    @objc func replaceShape() {
        guard let selectedMaskID,
              let index = masks.firstIndex(where: { $0.id == selectedMaskID && !$0.isDeleted }) else { return }
        masks[index].shape = masks[index].shape.next()
        appendLog("mask #\(selectedMaskID) shape switched to \(masks[index].shape.title)")
        refreshUI()
        renderCurrentState(reason: "replace shape")
    }

    @objc func softDeleteSelectedMask() {
        guard let selectedMaskID,
              let index = masks.firstIndex(where: { $0.id == selectedMaskID && !$0.isDeleted }) else { return }
        masks[index].isDeleted = true
        removeMaskFromGroups(maskID: selectedMaskID)
        self.selectedMaskID = activeMasks.first?.id
        appendLog("mask #\(selectedMaskID) soft deleted and pruned from groups")
        refreshUI()
        renderCurrentState(reason: "soft delete")
    }

    @objc func assignSelectedMaskToGroup() {
        guard let selectedMaskID,
              let index = effectGroups.firstIndex(where: { $0.kind == selectedGroupKind }) else { return }
        if effectGroups[index].assignedMaskIDs.contains(selectedMaskID) {
            effectGroups[index].assignedMaskIDs.removeAll { $0 == selectedMaskID }
            appendLog("mask #\(selectedMaskID) removed from \(selectedGroupKind.title)")
        } else {
            effectGroups[index].assignedMaskIDs.append(selectedMaskID)
            appendLog("mask #\(selectedMaskID) assigned to \(selectedGroupKind.title)")
        }
        refreshUI()
        renderCurrentState(reason: "reassign group")
    }

    @objc func toggleSelectedGroup() {
        guard let index = effectGroups.firstIndex(where: { $0.kind == selectedGroupKind }) else { return }
        effectGroups[index].isEnabled.toggle()
        appendLog("\(selectedGroupKind.title) toggled \(effectGroups[index].isEnabled ? "on" : "off")")
        refreshUI()
        renderCurrentState(reason: "toggle group")
    }

    @objc func overlaySwitchDidChange(_ sender: UISwitch) {
        overlayEnabled = sender.isOn
        appendLog("overlay toggled \(overlayEnabled ? "on" : "off")")
        refreshUI()
        renderCurrentState(reason: "toggle overlay")
    }

    @objc func groupStrengthDidChange(_ sender: UISlider) {
        groupStrengths[selectedGroupKind] = sender.value
        appendLog("\(selectedGroupKind.title) strength -> \(String(format: "%.2f", sender.value))")
        refreshUI()
        renderCurrentState(reason: "group strength changed")
    }

    @objc func runLifecycleSmoke() {
        seedSession(family: .geometry, style: .cutout, logReason: "lifecycle smoke")
        if let cutoutID = masks.first(where: { $0.role == .cutout })?.id,
           let index = masks.firstIndex(where: { $0.id == cutoutID }) {
            masks[index].isDeleted = true
            removeMaskFromGroups(maskID: cutoutID)
            appendLog("smoke: cutout mask #\(cutoutID) soft deleted")
        }
        if let accentID = masks.first(where: { $0.role == .accent })?.id {
            assignMaskIfNeeded(accentID, to: .detailEdge)
        }
        groupStrengths[.detailEdge] = 0.72
        selectedMaskID = activeMasks.last?.id
        overlayEnabled = true
        refreshUI()
        renderCurrentState(reason: "lifecycle smoke")
    }

    @objc func retryRender() {
        renderCurrentState(reason: "retry")
    }

    @objc func showReportModal() {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        vc.title = "Workbench Report"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissReportModal)
        )

        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.textColor = .label
        textView.text = lastReportText.isEmpty ? "No report generated yet. Perform an action to generate one." : lastReportText
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        vc.view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor)
        ])

        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }

    @objc func dismissReportModal() {
        presentedViewController?.dismiss(animated: true)
    }

    // MARK: - Rendering

    func renderCurrentState(reason: String) {
        guard let assets = try? resolvedAssets() else {
            showError("Failed to load demo assets.")
            return
        }
        showLoading()

        let image = assets.primary
        let masks = self.masks
        let effectGroups = self.effectGroups
        let strengths = self.groupStrengths
        let family = self.selectedFamily
        let style = self.selectedStyle
        let overlayEnabled = self.overlayEnabled
        let selectedMaskID = self.selectedMaskID
        let selectedGroupKind = self.selectedGroupKind
        let rebuildCount = self.rebuildCount + 1
        let operationLog = self.operationLog

        renderQueue.async {
            do {
                let imageSize = try self.sourcePixelSize(for: image)
                let recipe = try self.makeRecipe(
                    from: masks,
                    effectGroups: effectGroups,
                    strengths: strengths,
                    imageSize: imageSize
                )
                let node = ImageNode
                    .source(.image(image))
                    .editing(recipe, mode: .preview)
                    .applying(C7Sharpen(sharpness: 0.06 + (strengths[.detailEdge] ?? 0) * 0.18))
                let frame = try node.makeFrame(
                    profile: .stablePreview,
                    metadata: [
                        "page": "Mask Lab",
                        "family": family.title,
                        "style": style.title,
                        "reason": reason
                    ]
                )
                let diagnostics = try node.makeDiagnostics(profile: .stablePreview)
                let reportText = self.makeReportText(
                    family: family,
                    style: style,
                    masks: masks,
                    effectGroups: effectGroups,
                    strengths: strengths,
                    selectedMaskID: selectedMaskID,
                    selectedGroupKind: selectedGroupKind,
                    rebuildCount: rebuildCount,
                    overlayEnabled: overlayEnabled,
                    diagnostics: diagnostics,
                    operationLog: operationLog
                )
                let overlayEntries = self.makeOverlayEntries(
                    masks: masks,
                    effectGroups: effectGroups,
                    selectedMaskID: selectedMaskID
                )

                DispatchQueue.main.async {
                    self.rebuildCount = rebuildCount
                    self.resultTitleLabel.text = "Mask Result · \(family.title) · \(style.title) · rebuild \(rebuildCount)"
                    self.resultRenderView.texture = frame.texture
                    self.lastReportText = reportText
                    self.overlayView.isHidden = !overlayEnabled
                    let aspect = image.size.height > 0 ? image.size.width / image.size.height : 1.0
                    self.overlayView.imageAspectRatio = aspect
                    self.overlayView.entries = overlayEntries
                    self.overlayView.selectedMaskID = selectedMaskID
                    self.hideLoading()
                    self.refreshUI()
                }
            } catch {
                DispatchQueue.main.async {
                    self.resultRenderView.texture = nil
                    self.overlayView.entries = []
                    self.showError(error.localizedDescription)
                    self.refreshUI()
                }
            }
        }
    }

    func showLoading() {
        isRendering = true
        renderActivityIndicator.isHidden = false
        renderActivityIndicator.startAnimating()
        retryButton.isHidden = true
        errorLabel.isHidden = true
        resultRenderView.alpha = 0.5
    }

    func hideLoading() {
        isRendering = false
        renderActivityIndicator.stopAnimating()
        retryButton.isHidden = true
        errorLabel.isHidden = true
        resultRenderView.alpha = 1
    }

    func showError(_ message: String) {
        isRendering = false
        renderActivityIndicator.stopAnimating()
        renderActivityIndicator.isHidden = true
        retryButton.isHidden = false
        errorLabel.isHidden = false
        errorLabel.text = message
        resultRenderView.alpha = 0.35
    }

    // MARK: - Recipe Building (unchanged logic)

    func makeRecipe(from masks: [MaskEntry],
                    effectGroups: [EffectGroupState],
                    strengths: [EffectGroupKind: Float],
                    imageSize: C7Size) throws -> EditRecipe {
        let activeMasksByID = Dictionary(uniqueKeysWithValues: masks.filter { !$0.isDeleted }.map { ($0.id, $0) })
        let localEffects = try effectGroups.compactMap { group -> LocalEffectRecipe? in
            guard group.isEnabled else { return nil }
            let groupMasks = group.assignedMaskIDs.compactMap { activeMasksByID[$0] }
            guard let composite = try makeMaskRecipe(from: groupMasks, imageSize: imageSize, strength: strengths[group.kind] ?? 0) else {
                return nil
            }
            return LocalEffectRecipe(
                filters: makeGroupFilters(for: group.kind, strength: strengths[group.kind] ?? 0),
                maskRecipe: composite
            )
        }
        return EditRecipe(localEffects: localEffects)
    }

    func makeMaskRecipe(from masks: [MaskEntry],
                        imageSize: C7Size,
                        strength: Float) throws -> MaskCompositeRecipe? {
        guard let base = masks.first(where: { $0.role == .subject }) ?? masks.first else {
            return nil
        }
        var composite = try MaskCompositeRecipe(
            baseRecipe: try makeRecipe(for: base, imageSize: imageSize),
            component: .red,
            opacity: 0.32 + strength * 0.42
        )
        for entry in masks where entry.id != base.id {
            let path = try makeRecipe(for: entry, imageSize: imageSize)
            switch entry.role {
            case .cutout:
                composite = try composite.excluding(path, component: .red, opacity: 1, name: "mask_\(entry.id)")
            case .subject, .accent:
                composite = try composite.adding(path, component: .red, opacity: 1, name: "mask_\(entry.id)")
            }
        }
        return composite
    }

    func makeRecipe(for entry: MaskEntry, imageSize: C7Size) throws -> any MaskRecipe {
        switch entry.shape {
        case .ellipse:
            return MaskShapeRecipe.ellipse(size: imageSize, rect: entry.rect, feather: 0)
        case .triangle:
            return MaskShapeRecipe.triangle(
                size: imageSize,
                rect: entry.rect,
                feather: 0,
                transform: MaskPathTransform(
                    rotationRadians: -.pi * 0.08,
                    anchor: CGPoint(x: entry.rect.midX, y: entry.rect.midY)
                ),
                profile: .stablePreview
            )
        case .hexagon:
            return MaskShapeRecipe.regularPolygon(
                size: imageSize,
                rect: entry.rect,
                sides: 6,
                feather: 0,
                profile: .stablePreview
            )
        case .roundedRect:
            // cornerRadius: 从绝对像素 (min(w,h) * 0.28) 归一化到 [0, 0.5]
            let minDim = min(entry.rect.width, entry.rect.height)
            let normalizedCorner: CGFloat = minDim > 0
                ? min(0.5, (min(entry.rect.width, entry.rect.height) * 0.28) / minDim * 0.5)
                : 0
            return MaskShapeRecipe.roundedRect(
                size: imageSize,
                rect: entry.rect,
                cornerRadius: Float(normalizedCorner),
                feather: 0
            )
        }
    }

    func makeGroupFilters(for kind: EffectGroupKind, strength: Float) -> [C7FilterProtocol] {
        switch kind {
        case .toneBoost:
            return [
                C7Exposure(exposure: 0.02 + strength * 0.16),
                C7Contrast(contrast: 1.03 + strength * 0.18),
                C7Saturation(saturation: 1.03 + strength * 0.20),
                C7SoulOut(), C7ColorCorrection()
            ]
        case .colorWash:
            return [
                C7ColorRGBA(color: .red),
                C7Opacity(opacity: 0.02 + strength * 0.10),
                C7Saturation(saturation: 1.01 + strength * 0.12)
            ]
        case .detailEdge:
            return [
                C7ColorConvert(with: .grba),
                C7Sharpen(sharpness: 0.04 + strength * 0.24),
                C7Contrast(contrast: 1.02 + strength * 0.10)
            ]
        }
    }

    func makeOverlayEntries(masks: [MaskEntry],
                            effectGroups: [EffectGroupState],
                            selectedMaskID: Int?) -> [MaskOverlayView.Entry] {
        let activeMaskIDs = Set(masks.filter { !$0.isDeleted }.map(\.id))
        return masks.compactMap { mask in
            guard activeMaskIDs.contains(mask.id) else { return nil }
            let activeGroups = effectGroups.filter { $0.isEnabled && $0.assignedMaskIDs.contains(mask.id) }
            let groupColor = overlayColor(for: activeGroups.first?.kind)
            return MaskOverlayView.Entry(
                id: mask.id,
                rect: mask.rect,
                shape: mask.shape,
                role: mask.role,
                color: groupColor,
                isSelected: mask.id == selectedMaskID,
                groupTitles: activeGroups.map { $0.kind.title }
            )
        }
    }

    func overlayColor(for kind: EffectGroupKind?) -> UIColor {
        switch kind {
        case .toneBoost: return UIColor(hex: "#A6E44D")
        case .colorWash: return UIColor(hex: "#F04FCB")
        case .detailEdge: return UIColor(hex: "#4BC8FF")
        case nil: return UIColor.white.withAlphaComponent(0.9)
        }
    }

    func makeGroupText() -> String {
        let lines = effectGroups.map { group in
            let marker = group.kind == selectedGroupKind ? ">" : " "
            let assigned = group.assignedMaskIDs.isEmpty ? "none" : group.assignedMaskIDs.map { "#\($0)" }.joined(separator: ", ")
            let strength = groupStrengths[group.kind] ?? 0
            return "\(marker) \(group.kind.title) \(group.isEnabled ? "enabled" : "disabled") S=\(String(format: "%.2f", strength)) → \(assigned)"
        }
        return lines.joined(separator: "\n")
    }

    func makeReportText(family: MaskFamily,
                        style: MaskWorkbenchStyle,
                        masks: [MaskEntry],
                        effectGroups: [EffectGroupState],
                        strengths: [EffectGroupKind: Float],
                        selectedMaskID: Int?,
                        selectedGroupKind: EffectGroupKind,
                        rebuildCount: Int,
                        overlayEnabled: Bool,
                        diagnostics: RenderPlanDiagnostics,
                        operationLog: [String]) -> String {
        let activeMasks = masks.filter { !$0.isDeleted }
        let enabledGroups = effectGroups.filter(\.isEnabled)
        let activeSummary = activeMasks.isEmpty ? "none" : activeMasks.map { "#\($0.id):\($0.role.rawValue)-\($0.shape.title)" }.joined(separator: ", ")
        let groupSummary = enabledGroups.isEmpty ? "none" : enabledGroups.map { "\($0.kind.title)=\(String(format: "%.2f", strengths[$0.kind] ?? 0))" }.joined(separator: ", ")

        return """
        Mask Lab Workbench Report

        Current State
        family=\(family.title)
        style=\(style.title)
        rebuildCount=\(rebuildCount)
        selectedMask=\(selectedMaskID.map { "#\($0)" } ?? "none")
        selectedGroup=\(selectedGroupKind.title)
        overlay=\(overlayEnabled ? "on" : "off")
        activeMasks=\(activeSummary)
        enabledGroups=\(groupSummary)

        Diagnostics
        \(diagnostics.summary)

        Operation Log
        \(operationLog.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))

        Canonical Usage
        \(makeCanonicalSnippet(effectGroups: effectGroups))
        """
    }

    func makeCanonicalSnippet(effectGroups: [EffectGroupState]) -> String {
        let groupLines = effectGroups.map { group in
            "// \(group.kind.title) group \(group.isEnabled ? "enabled" : "disabled")"
        }.joined(separator: "\n")

        return """
        let masks = session.activeMasks
        let groups = session.effectGroups.filter(\\.isEnabled)
        let localEffects = try groups.compactMap { group -> LocalEffectRecipe? in
            guard let composite = try buildComposite(from: group, masks: masks, size: size) else { return nil }
            return LocalEffectRecipe(filters: filters(for: group.kind, strength: group.strength), maskRecipe: composite)
        }
        let recipe = EditRecipe(localEffects: localEffects)
        let node = ImageNode.source(.image(image)).editing(recipe, mode: .preview)

        \(groupLines)
        """
    }

    // MARK: - Data Factories (unchanged)

    func makeBaseMasks(for family: MaskFamily, style: MaskWorkbenchStyle) -> [MaskEntry] {
        switch (family, style) {
        case (.portrait, .spotlight):
            return [
                makeMask(role: .subject, rect: CGRect(x: 0.18, y: 0.12, width: 0.42, height: 0.58), shape: .ellipse)
            ]
        case (.portrait, .cutout):
            return [
                makeMask(role: .subject, rect: CGRect(x: 0.16, y: 0.14, width: 0.44, height: 0.56), shape: .ellipse),
                makeMask(role: .cutout, rect: CGRect(x: 0.42, y: 0.28, width: 0.22, height: 0.24), shape: .triangle),
                makeMask(role: .accent, rect: CGRect(x: 0.60, y: 0.20, width: 0.16, height: 0.16), shape: .hexagon)
            ]
        case (.portrait, .stacked):
            return [
                makeMask(role: .subject, rect: CGRect(x: 0.14, y: 0.12, width: 0.42, height: 0.56), shape: .ellipse),
                makeMask(role: .accent, rect: CGRect(x: 0.58, y: 0.16, width: 0.18, height: 0.18), shape: .hexagon),
                makeMask(role: .accent, rect: CGRect(x: 0.18, y: 0.68, width: 0.24, height: 0.14), shape: .roundedRect),
                makeMask(role: .cutout, rect: CGRect(x: 0.40, y: 0.34, width: 0.18, height: 0.22), shape: .triangle)
            ]
        case (.geometry, .spotlight):
            return [
                makeMask(role: .subject, rect: CGRect(x: 0.24, y: 0.16, width: 0.34, height: 0.48), shape: .roundedRect)
            ]
        case (.geometry, .cutout):
            return [
                makeMask(role: .subject, rect: CGRect(x: 0.20, y: 0.18, width: 0.40, height: 0.44), shape: .roundedRect),
                makeMask(role: .cutout, rect: CGRect(x: 0.40, y: 0.30, width: 0.18, height: 0.18), shape: .triangle),
                makeMask(role: .accent, rect: CGRect(x: 0.62, y: 0.20, width: 0.16, height: 0.16), shape: .hexagon)
            ]
        case (.geometry, .stacked):
            return [
                makeMask(role: .subject, rect: CGRect(x: 0.18, y: 0.16, width: 0.34, height: 0.42), shape: .hexagon),
                makeMask(role: .accent, rect: CGRect(x: 0.54, y: 0.16, width: 0.18, height: 0.18), shape: .roundedRect),
                makeMask(role: .accent, rect: CGRect(x: 0.22, y: 0.64, width: 0.18, height: 0.18), shape: .hexagon),
                makeMask(role: .cutout, rect: CGRect(x: 0.42, y: 0.32, width: 0.16, height: 0.18), shape: .triangle)
            ]
        case (.editorial, .spotlight):
            return [
                makeMask(role: .subject, rect: CGRect(x: 0.12, y: 0.20, width: 0.64, height: 0.28), shape: .roundedRect)
            ]
        case (.editorial, .cutout):
            return [
                makeMask(role: .subject, rect: CGRect(x: 0.12, y: 0.18, width: 0.62, height: 0.30), shape: .roundedRect),
                makeMask(role: .cutout, rect: CGRect(x: 0.44, y: 0.22, width: 0.20, height: 0.20), shape: .triangle),
                makeMask(role: .accent, rect: CGRect(x: 0.18, y: 0.56, width: 0.48, height: 0.14), shape: .roundedRect)
            ]
        case (.editorial, .stacked):
            return [
                makeMask(role: .subject, rect: CGRect(x: 0.12, y: 0.18, width: 0.56, height: 0.28), shape: .roundedRect),
                makeMask(role: .accent, rect: CGRect(x: 0.16, y: 0.58, width: 0.52, height: 0.14), shape: .roundedRect),
                makeMask(role: .accent, rect: CGRect(x: 0.45, y: 0.16, width: 0.45, height: 0.55), shape: .hexagon),
                makeMask(role: .cutout, rect: CGRect(x: 0.46, y: 0.24, width: 0.18, height: 0.18), shape: .triangle)
            ]
        }
    }

    func makeBaseGroups(for family: MaskFamily,
                        style: MaskWorkbenchStyle,
                        masks: [MaskEntry]) -> [EffectGroupState] {
        let subjectIDs = masks.filter { $0.role == .subject && !$0.isDeleted }.map(\.id)
        let accentIDs = masks.filter { $0.role == .accent && !$0.isDeleted }.map(\.id)
        let cutoutIDs = masks.filter { $0.role == .cutout && !$0.isDeleted }.map(\.id)

        switch style {
        case .spotlight:
            return [
                EffectGroupState(kind: .toneBoost, isEnabled: true, assignedMaskIDs: subjectIDs),
                EffectGroupState(kind: .colorWash, isEnabled: family == .editorial, assignedMaskIDs: accentIDs.isEmpty ? subjectIDs : accentIDs),
                EffectGroupState(kind: .detailEdge, isEnabled: false, assignedMaskIDs: subjectIDs)
            ]
        case .cutout:
            return [
                EffectGroupState(kind: .toneBoost, isEnabled: true, assignedMaskIDs: subjectIDs + cutoutIDs),
                EffectGroupState(kind: .colorWash, isEnabled: true, assignedMaskIDs: accentIDs),
                EffectGroupState(kind: .detailEdge, isEnabled: family != .portrait, assignedMaskIDs: subjectIDs)
            ]
        case .stacked:
            return [
                EffectGroupState(kind: .toneBoost, isEnabled: true, assignedMaskIDs: subjectIDs),
                EffectGroupState(kind: .colorWash, isEnabled: true, assignedMaskIDs: subjectIDs + accentIDs),
                EffectGroupState(kind: .detailEdge, isEnabled: true, assignedMaskIDs: accentIDs + cutoutIDs)
            ]
        }
    }

    func makeSupplementMask(for family: MaskFamily, style: MaskWorkbenchStyle, existingCount: Int) -> MaskEntry {
        let cycle = existingCount % 3
        switch (family, style, cycle) {
        case (.portrait, _, 0):
            return makeMask(role: .accent, rect: CGRect(x: 0.60, y: 0.18, width: 0.16, height: 0.16), shape: .hexagon)
        case (.portrait, _, 1):
            return makeMask(role: .cutout, rect: CGRect(x: 0.42, y: 0.30, width: 0.20, height: 0.22), shape: .triangle)
        case (.portrait, _, _):
            return makeMask(role: .accent, rect: CGRect(x: 0.18, y: 0.68, width: 0.24, height: 0.14), shape: .roundedRect)
        case (.geometry, _, 0):
            return makeMask(role: .accent, rect: CGRect(x: 0.58, y: 0.18, width: 0.18, height: 0.18), shape: .hexagon)
        case (.geometry, _, 1):
            return makeMask(role: .cutout, rect: CGRect(x: 0.40, y: 0.30, width: 0.18, height: 0.18), shape: .triangle)
        case (.geometry, _, _):
            return makeMask(role: .accent, rect: CGRect(x: 0.20, y: 0.62, width: 0.18, height: 0.18), shape: .roundedRect)
        case (.editorial, _, 0):
            return makeMask(role: .accent, rect: CGRect(x: 0.18, y: 0.58, width: 0.48, height: 0.14), shape: .roundedRect)
        case (.editorial, _, 1):
            return makeMask(role: .cutout, rect: CGRect(x: 0.46, y: 0.24, width: 0.18, height: 0.18), shape: .triangle)
        case (.editorial, _, _):
            return makeMask(role: .accent, rect: CGRect(x: 0.62, y: 0.16, width: 0.16, height: 0.16), shape: .hexagon)
        }
    }

    func makeMask(role: MaskRole, rect: CGRect, shape: MaskShape) -> MaskEntry {
        defer { nextMaskID += 1 }
        return MaskEntry(id: nextMaskID, role: role, rect: rect, shape: shape, isDeleted: false)
    }

    func removeMaskFromGroups(maskID: Int) {
        for index in effectGroups.indices {
            effectGroups[index].assignedMaskIDs.removeAll { $0 == maskID }
        }
    }

    func assignMaskIfNeeded(_ maskID: Int, to kind: EffectGroupKind) {
        guard let index = effectGroups.firstIndex(where: { $0.kind == kind }),
              !effectGroups[index].assignedMaskIDs.contains(maskID) else { return }
        effectGroups[index].assignedMaskIDs.append(maskID)
    }

    func appendLog(_ message: String) {
        operationLog.append(message)
        if operationLog.count > 14 {
            operationLog.removeFirst(operationLog.count - 14)
        }
    }

    func requireImage(_ name: String) throws -> UIImage {
        guard let image = R.image(name) else {
            throw NSError(domain: "MaskShowcase", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing asset image: \(name)"])
        }
        return image
    }

    func sourcePixelSize(for image: UIImage) throws -> C7Size {
        if let cgImage = image.cgImage {
            return C7Size(width: cgImage.width, height: cgImage.height)
        }
        guard image.size.width > 0, image.size.height > 0 else {
            throw NSError(domain: "MaskShowcase", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot resolve image dimensions."])
        }
        return C7Size(width: max(Int(image.size.width.rounded()), 1), height: max(Int(image.size.height.rounded()), 1))
    }
}

// MARK: - UI Factories

private extension MaskShowcaseViewController {

    enum ButtonStyle {
        case standard
        case primary
        case danger
    }

    func makeActionButton(title: String, action: Selector, style: ButtonStyle = .standard) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.lineBreakMode = .byClipping
        button.layer.cornerRadius = 13
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        button.addTarget(self, action: action, for: .touchUpInside)

        switch style {
        case .primary:
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = accentColor
            button.layer.borderWidth = 0
        case .standard:
            button.setTitleColor(accentColor, for: .normal)
            button.backgroundColor = accentColor.withAlphaComponent(0.08)
            button.layer.borderWidth = 1
            button.layer.borderColor = accentColor.withAlphaComponent(0.16).cgColor
        case .danger:
            button.setTitleColor(dangerColor, for: .normal)
            button.backgroundColor = dangerColor.withAlphaComponent(0.08)
            button.layer.borderWidth = 1
            button.layer.borderColor = dangerColor.withAlphaComponent(0.20).cgColor
        }
        return button
    }

    func makePrimaryButton(title: String, action: Selector) -> UIButton {
        makeActionButton(title: title, action: action, style: .primary)
    }

    func makeButtonRow(_ buttons: [UIButton]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = .horizontal
        row.spacing = 10
        row.distribution = .fillEqually
        return row
    }

    func makeCaptionLabel(text: String, alignment: NSTextAlignment) -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = alignment
        label.text = text
        return label
    }

    func makeSecondaryLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }

    func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = accentColor
        return label
    }

    func makeCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor.secondarySystemBackground
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1
        card.layer.borderColor = accentColor.withAlphaComponent(0.10).cgColor
        return card
    }

    func makeSeparator() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .separator
        view.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
        return view
    }

    func makeMonoTextView() -> UITextView {
        let view = UITextView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isEditable = false
        view.isSelectable = true
        view.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        view.textColor = .label
        view.backgroundColor = UIColor.systemBackground
        view.layer.cornerRadius = 13
        view.textContainerInset = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        return view
    }
}

private extension CGRect {

    var prettyFraction: String {
        String(format: "[%.2f, %.2f, %.2f, %.2f]", origin.x, origin.y, size.width, size.height)
    }
}

private final class MaskOverlayView: UIView {

    struct Entry {
        let id: Int
        let rect: CGRect
        let shape: MaskShowcaseViewController.MaskShape
        let role: MaskShowcaseViewController.MaskRole
        let color: UIColor
        let isSelected: Bool
        let groupTitles: [String]
    }

    var entries: [Entry] = [] {
        didSet { setNeedsDisplay() }
    }

    var selectedMaskID: Int? {
        didSet { setNeedsDisplay() }
    }

    var imageAspectRatio: CGFloat = 1.0 {
        didSet {
            if abs(imageAspectRatio - oldValue) > 1e-6 { setNeedsDisplay() }
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.clear(rect)

        for entry in entries {
            let path = bezierPath(for: entry)
            let strokeColor = entry.color
            strokeColor.withAlphaComponent(0.20).setFill()
            path.fill()

            path.lineWidth = entry.isSelected ? 2 : 1
            if entry.role == .cutout {
                let dash: [CGFloat] = [8, 6]
                path.setLineDash(dash, count: dash.count, phase: 0)
            } else {
                path.setLineDash([], count: 0, phase: 0)
            }
            strokeColor.setStroke()
            path.stroke()

            let label = "#\(entry.id) \(entry.groupTitles.isEmpty ? entry.role.rawValue : entry.groupTitles.joined(separator: "+"))"
            let point = CGPoint(
                x: max(convert(entry.rect).minX + 6, 4),
                y: max(convert(entry.rect).minY + 4, 4)
            )
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 11, weight: entry.isSelected ? .bold : .medium),
                .foregroundColor: UIColor.white
            ]
            let textRect = CGRect(origin: point, size: CGSize(width: 180, height: 16))
            label.draw(in: textRect, withAttributes: attrs)
        }
    }

    private func bezierPath(for entry: Entry) -> UIBezierPath {
        let frame = convert(entry.rect)
        switch entry.shape {
        case .ellipse:
            return UIBezierPath(ovalIn: frame)
        case .roundedRect:
            return UIBezierPath(roundedRect: frame, cornerRadius: min(frame.width, frame.height) * 0.28)
        case .triangle:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: frame.midX, y: frame.minY))
            path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY))
            path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY))
            path.close()
            return path
        case .hexagon:
            let path = UIBezierPath()
            let center = CGPoint(x: frame.midX, y: frame.midY)
            let radiusX = frame.width * 0.5
            let radiusY = frame.height * 0.5
            for index in 0..<6 {
                let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * .pi / 6
                let point = CGPoint(
                    x: center.x + cos(angle) * radiusX,
                    y: center.y + sin(angle) * radiusY
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.close()
            return path
        }
    }

    private func convert(_ rect: CGRect) -> CGRect {
        let display = contentRect(in: bounds)
        return CGRect(
            x: display.origin.x + rect.origin.x * display.width,
            y: display.origin.y + rect.origin.y * display.height,
            width: rect.size.width * display.width,
            height: rect.size.height * display.height
        )
    }

    private func contentRect(in bounds: CGRect) -> CGRect {
        guard bounds.width > 0, bounds.height > 0, imageAspectRatio > 0 else { return bounds }
        let viewAspect = bounds.width / bounds.height
        if abs(imageAspectRatio - viewAspect) < 1e-6 {
            return bounds
        }
        if imageAspectRatio > viewAspect {
            let h = bounds.width / imageAspectRatio
            return CGRect(x: 0, y: (bounds.height - h) * 0.5, width: bounds.width, height: h)
        } else {
            let w = bounds.height * imageAspectRatio
            return CGRect(x: (bounds.width - w) * 0.5, y: 0, width: w, height: bounds.height)
        }
    }
}
