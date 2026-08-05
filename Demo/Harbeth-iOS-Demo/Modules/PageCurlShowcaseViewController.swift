//
//  PageCurlShowcaseViewController.swift
//  Harbeth-iOS-Demo
//
//  Created by Condy on 2026/8/6.
//

import UIKit
import Harbeth

final class PageCurlShowcaseViewController: UIViewController {

    private struct DemoAssets {
        let from: UIImage
        let to: UIImage
        let backside: UIImage
    }

    private struct CurlState {
        var progress: Float = 0.52
        var angleDegrees: Float = 0
        var radius: Float = 0.22
        var shadowStrength: Float = 0.7
        var shadowRadius: Float = 0.06
        var usesBacksideImage = true
    }

    private enum Parameter: Int {
        case progress
        case angle
        case radius
        case shadowStrength
        case shadowRadius
    }

    private let renderQueue = DispatchQueue(label: "com.condy.harbeth.page-curl-showcase", qos: .userInitiated)
    private var pendingRender: DispatchWorkItem?
    private var renderRevision = 0
    private var assets: DemoAssets?
    private var state = CurlState()

    private var accentColor: UIColor { UIColor(hex: "#5C48FA") }

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

    private lazy var resultCard: UIView = makeCard()

    private lazy var resultTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = accentColor
        label.textAlignment = .center
        label.text = "Page Curl Result"
        return label
    }()

    private lazy var resultRenderView: RenderView = {
        let view = RenderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.resizingMode = .aspectFit
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = accentColor
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private lazy var errorLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .systemRed
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    private lazy var sourceCard: UIView = makeCard()
    private lazy var controlsCard: UIView = makeCard()

    private lazy var progressSlider = makeSlider(parameter: .progress, minimum: 0, maximum: 1, value: state.progress)
    private lazy var angleSlider = makeSlider(parameter: .angle, minimum: -180, maximum: 180, value: state.angleDegrees)
    private lazy var radiusSlider = makeSlider(parameter: .radius, minimum: 0.01, maximum: 0.5, value: state.radius)
    private lazy var shadowStrengthSlider = makeSlider(parameter: .shadowStrength, minimum: 0, maximum: 1, value: state.shadowStrength)
    private lazy var shadowRadiusSlider = makeSlider(parameter: .shadowRadius, minimum: 0.01, maximum: 0.25, value: state.shadowRadius)

    private lazy var progressValueLabel = makeValueLabel()
    private lazy var angleValueLabel = makeValueLabel()
    private lazy var radiusValueLabel = makeValueLabel()
    private lazy var shadowStrengthValueLabel = makeValueLabel()
    private lazy var shadowRadiusValueLabel = makeValueLabel()

    private lazy var backsideSwitch: UISwitch = {
        let control = UISwitch()
        control.onTintColor = accentColor
        control.isOn = state.usesBacksideImage
        control.addTarget(self, action: #selector(backsideDidChange(_:)), for: .valueChanged)
        return control
    }()

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.text = "ImageNode.transition → RenderView"
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Page Curl Showcase"
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        assets = try? resolvedAssets()
        setupUI()
        renderCurrentState()
    }

    deinit {
        pendingRender?.cancel()
    }
}

private extension PageCurlShowcaseViewController {

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

        setupResultCard()
        setupSourceCard()
        setupControlsCard()
        contentStack.addArrangedSubview(resultCard)
        contentStack.addArrangedSubview(sourceCard)
        contentStack.addArrangedSubview(controlsCard)
    }

    func setupResultCard() {
        resultCard.addSubview(resultTitleLabel)
        resultCard.addSubview(resultRenderView)
        resultCard.addSubview(activityIndicator)
        resultCard.addSubview(errorLabel)
        NSLayoutConstraint.activate([
            resultTitleLabel.topAnchor.constraint(equalTo: resultCard.topAnchor, constant: 16),
            resultTitleLabel.leadingAnchor.constraint(equalTo: resultCard.leadingAnchor, constant: 16),
            resultTitleLabel.trailingAnchor.constraint(equalTo: resultCard.trailingAnchor, constant: -16),
            resultRenderView.topAnchor.constraint(equalTo: resultTitleLabel.bottomAnchor, constant: 14),
            resultRenderView.leadingAnchor.constraint(equalTo: resultCard.leadingAnchor),
            resultRenderView.trailingAnchor.constraint(equalTo: resultCard.trailingAnchor),
            resultRenderView.heightAnchor.constraint(equalTo: resultRenderView.widthAnchor, multiplier: 0.75),
            resultRenderView.bottomAnchor.constraint(equalTo: resultCard.bottomAnchor, constant: -16),
            activityIndicator.centerXAnchor.constraint(equalTo: resultRenderView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: resultRenderView.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: resultCard.leadingAnchor, constant: 16),
            errorLabel.trailingAnchor.constraint(equalTo: resultCard.trailingAnchor, constant: -16),
            errorLabel.centerYAnchor.constraint(equalTo: resultRenderView.centerYAnchor)
        ])
    }

    func setupSourceCard() {
        let title = makeSectionTitle("Transition Sources")
        let subtitle = makeSecondaryLabel("From / To define the transition; Backside is sampled only while enabled.")
        let sourceStack = UIStackView(arrangedSubviews: [
            makeSourcePreview(image: assets?.from, title: "FROM"),
            makeSourcePreview(image: assets?.to, title: "TO"),
            makeSourcePreview(image: assets?.backside, title: "BACKSIDE")
        ])
        sourceStack.axis = .horizontal
        sourceStack.spacing = 10
        sourceStack.distribution = .fillEqually

        title.translatesAutoresizingMaskIntoConstraints = false
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        sourceStack.translatesAutoresizingMaskIntoConstraints = false
        sourceCard.addSubview(title)
        sourceCard.addSubview(subtitle)
        sourceCard.addSubview(sourceStack)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: sourceCard.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: sourceCard.leadingAnchor, constant: 16),
            title.trailingAnchor.constraint(equalTo: sourceCard.trailingAnchor, constant: -16),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            subtitle.leadingAnchor.constraint(equalTo: sourceCard.leadingAnchor, constant: 16),
            subtitle.trailingAnchor.constraint(equalTo: sourceCard.trailingAnchor, constant: -16),
            sourceStack.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 12),
            sourceStack.leadingAnchor.constraint(equalTo: sourceCard.leadingAnchor, constant: 12),
            sourceStack.trailingAnchor.constraint(equalTo: sourceCard.trailingAnchor, constant: -12),
            sourceStack.bottomAnchor.constraint(equalTo: sourceCard.bottomAnchor, constant: -12)
        ])
    }

    func setupControlsCard() {
        let title = makeSectionTitle("Page Curl Controls")
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        stack.addArrangedSubview(makeParameterRow("Progress", valueLabel: progressValueLabel, slider: progressSlider))
        stack.addArrangedSubview(makeParameterRow("Angle", valueLabel: angleValueLabel, slider: angleSlider))
        stack.addArrangedSubview(makeParameterRow("Curl Radius", valueLabel: radiusValueLabel, slider: radiusSlider))
        stack.addArrangedSubview(makeParameterRow("Shadow Strength", valueLabel: shadowStrengthValueLabel, slider: shadowStrengthSlider))
        stack.addArrangedSubview(makeParameterRow("Shadow Softness", valueLabel: shadowRadiusValueLabel, slider: shadowRadiusSlider))

        let backsideLabel = UILabel()
        backsideLabel.text = "Use backside image"
        backsideLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        let backsideRow = UIStackView(arrangedSubviews: [backsideLabel, backsideSwitch])
        backsideRow.axis = .horizontal
        backsideRow.alignment = .center
        backsideRow.distribution = .equalSpacing
        stack.addArrangedSubview(backsideRow)
        stack.addArrangedSubview(statusLabel)

        title.translatesAutoresizingMaskIntoConstraints = false
        controlsCard.addSubview(title)
        controlsCard.addSubview(stack)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: controlsCard.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: controlsCard.leadingAnchor, constant: 16),
            title.trailingAnchor.constraint(equalTo: controlsCard.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: controlsCard.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: controlsCard.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: controlsCard.bottomAnchor, constant: -16)
        ])
        updateValueLabels()
    }

    @objc func sliderDidChange(_ sender: UISlider) {
        switch Parameter(rawValue: sender.tag) {
        case .progress:
            state.progress = sender.value
        case .angle:
            state.angleDegrees = sender.value
        case .radius:
            state.radius = sender.value
        case .shadowStrength:
            state.shadowStrength = sender.value
        case .shadowRadius:
            state.shadowRadius = sender.value
        case .none:
            return
        }
        renderCurrentState()
    }

    @objc func backsideDidChange(_ sender: UISwitch) {
        state.usesBacksideImage = sender.isOn
        renderCurrentState()
    }

    func renderCurrentState() {
        guard let assets else {
            showError("Demo assets are unavailable.")
            return
        }

        renderRevision += 1
        let revision = renderRevision
        let state = state
        pendingRender?.cancel()
        updateValueLabels()
        errorLabel.isHidden = true
        activityIndicator.startAnimating()
        resultRenderView.alpha = 0.65

        let render = DispatchWorkItem { [weak self] in
            do {
                let recipe = TransitionRecipe(
                    from: .image(assets.from),
                    to: .image(assets.to),
                    kernel: .pageCurl(
                        angleDegrees: state.angleDegrees,
                        radius: state.radius,
                        shadowStrength: state.shadowStrength,
                        shadowRadius: state.shadowRadius,
                        backsideSource: state.usesBacksideImage ? .image(assets.backside) : nil
                    ),
                    progress: state.progress
                )
                let frame = try ImageNode.transition(recipe).makeFrame(
                    profile: .stablePreview,
                    metadata: [
                        "page": "Page Curl Showcase",
                        "revision": "\(revision)",
                        "backside": state.usesBacksideImage ? "image" : "fallback"
                    ]
                )
                DispatchQueue.main.async {
                    guard let self, self.renderRevision == revision else { return }
                    self.resultRenderView.texture = frame.texture
                    self.resultRenderView.alpha = 1
                    self.activityIndicator.stopAnimating()
                    self.resultTitleLabel.text = "Page Curl Result · \(Int(state.progress * 100))%"
                    self.statusLabel.text = "ImageNode.transition → RenderView · backside=\(state.usesBacksideImage ? "image" : "fallback")"
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self, self.renderRevision == revision else { return }
                    self.showError(error.localizedDescription)
                }
            }
        }
        pendingRender = render
        renderQueue.async(execute: render)
    }

    func showError(_ message: String) {
        activityIndicator.stopAnimating()
        resultRenderView.alpha = 1
        resultRenderView.texture = nil
        errorLabel.text = message
        errorLabel.isHidden = false
        statusLabel.text = "Page Curl render failed"
    }

    func updateValueLabels() {
        progressValueLabel.text = String(format: "%.0f%%", state.progress * 100)
        angleValueLabel.text = String(format: "%.0f°", state.angleDegrees)
        radiusValueLabel.text = String(format: "%.2f", state.radius)
        shadowStrengthValueLabel.text = String(format: "%.0f%%", state.shadowStrength * 100)
        shadowRadiusValueLabel.text = String(format: "%.2f", state.shadowRadius)
    }

    private func resolvedAssets() throws -> DemoAssets {
        guard let from = R.image("yuan001"), let to = R.image("yuan006"), let backside = R.image("yuan004") else {
            throw NSError(domain: "PageCurlShowcase", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing Page Curl demo assets."])
        }
        return DemoAssets(from: from, to: to, backside: backside)
    }
}

private extension PageCurlShowcaseViewController {

    func makeCard() -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 18
        return view
    }

    func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .label
        label.text = text
        return label
    }

    func makeSecondaryLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.text = text
        return label
    }

    func makeSourcePreview(image: UIImage?, title: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 12

        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 9

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.text = title

        container.addSubview(imageView)
        container.addSubview(label)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 0.7),
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 5),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -7)
        ])
        return container
    }

    private func makeSlider(parameter: Parameter, minimum: Float, maximum: Float, value: Float) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = minimum
        slider.maximumValue = maximum
        slider.value = value
        slider.tag = parameter.rawValue
        slider.tintColor = accentColor
        slider.addTarget(self, action: #selector(sliderDidChange(_:)), for: .valueChanged)
        return slider
    }

    func makeValueLabel() -> UILabel {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        label.textColor = accentColor
        label.textAlignment = .right
        return label
    }

    func makeParameterRow(_ title: String, valueLabel: UILabel, slider: UISlider) -> UIView {
        let container = UIView()
        let titleLabel = UILabel()
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.text = title
        let header = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        header.axis = .horizontal
        header.distribution = .fill
        header.translatesAutoresizingMaskIntoConstraints = false
        slider.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)
        container.addSubview(slider)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            slider.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            slider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            slider.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }
}
