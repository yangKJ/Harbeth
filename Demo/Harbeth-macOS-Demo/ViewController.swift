//
//  ViewController.swift
//  Harbeth-macOS-Demo
//
//  Created by Condy on 2023/2/9.
//

import Cocoa
import Harbeth

class ViewController: NSViewController {
    
    override func loadView() {
        let rect = NSApplication.shared.mainWindow?.frame ?? NSRect(x: 0, y: 0, width: 1400, height: 900)
        view = NSView(frame: rect)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    var inputImage: C7Image = R.image("IMG_6781")!
    
    private var currentFilter: C7FilterProtocol?
    private var filterCallback: ((Float) -> C7FilterProtocol)?
    
    private lazy var splitViewController: NSSplitViewController = {
        let splitVC = NSSplitViewController()
        splitVC.splitView.isVertical = true
        splitVC.splitView.dividerStyle = .thick
        splitVC.splitView.autosaveName = "HarbethDemoSplitView"
        return splitVC
    }()
    
    lazy var sidebarViewController: SidebarViewController = {
        let vc = SidebarViewController()
        vc.delegate = self
        return vc
    }()
    
    lazy var mainViewController: MainViewController = {
        let vc = MainViewController()
        vc.originImage = inputImage
        return vc
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupSplitView()
        setupUI()
    }
    
    private func setupSplitView() {
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarViewController)
        sidebarItem.minimumThickness = 300
        sidebarItem.maximumThickness = 420
        sidebarItem.canCollapse = true
        
        let mainItem = NSSplitViewItem(viewController: mainViewController)
        mainItem.minimumThickness = 700
        
        splitViewController.splitViewItems = [sidebarItem, mainItem]
        
        addChild(splitViewController)
        splitViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splitViewController.view)
        
        NSLayoutConstraint.activate([
            splitViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            splitViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splitViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splitViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupUI() {
        title = "Harbeth Demo"
    }
}

extension ViewController: SidebarDelegate, MainViewControllerSliderDelegate {
    func didSelectFilter(_ filter: C7FilterProtocol, name: String, hasSlider: Bool, sliderRange: (min: Float, max: Float, current: Float)?, callback: ((Float) -> C7FilterProtocol)?) {
        currentFilter = filter
        filterCallback = callback
        applyFilter(filter)
        updateFilterInfo(name: name, hasSlider: hasSlider, sliderRange: sliderRange)
    }
    
    func sliderValueChanged(_ value: Float) {
        guard let callback = filterCallback else { return }
        let filter = callback(value)
        currentFilter = filter
        applyFilter(filter)
    }
    
    private func applyFilter(_ filter: C7FilterProtocol) {
        let dest = HarbethIO.init(element: inputImage, filter: filter)
        let image = dest.filtered()
        self.mainViewController.updateProcessedImage(image)
    }
    
    private func updateFilterInfo(name: String, hasSlider: Bool, sliderRange: (min: Float, max: Float, current: Float)?) {
        mainViewController.updateFilterName(name)
        if hasSlider, let range = sliderRange {
            mainViewController.showSlider(min: range.min, max: range.max, current: range.current, delegate: self)
        } else {
            mainViewController.hideSlider()
        }
    }
}

protocol SidebarDelegate: AnyObject {
    func didSelectFilter(_ filter: C7FilterProtocol, name: String, hasSlider: Bool, sliderRange: (min: Float, max: Float, current: Float)?, callback: ((Float) -> C7FilterProtocol)?)
    func sliderValueChanged(_ value: Float)
}

class SidebarViewController: NSViewController {
    
    weak var delegate: SidebarDelegate?
    
    private var scrollView: NSScrollView!
    private var outlineView: NSOutlineView!
    private var dataSource: SidebarDataSource!
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 700))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        view.layer?.cornerRadius = 2
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupTitleLabel()
        setupOutlineView()
        setupDataSource()
    }
    
    private func setupTitleLabel() {
        let titleLabel = NSTextField(labelWithString: "🎨 Harbeth Filters")
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.textColor = NSColor(hex: "96D35F")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        let subtitleLabel = NSTextField(labelWithString: "Metal-based image processing")
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)
        
        let githubButton = NSButton(title: "⭐ Star on GitHub", target: self, action: #selector(openGitHub))
        githubButton.bezelStyle = .rounded
        githubButton.font = .systemFont(ofSize: 12, weight: .medium)
        githubButton.translatesAutoresizingMaskIntoConstraints = false
        githubButton.wantsLayer = true
        githubButton.layer?.cornerRadius = 2
        view.addSubview(githubButton)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 36),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            githubButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 15),
            githubButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            githubButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            githubButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/yangKJ/Harbeth") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func setupOutlineView() {
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = NSColor.clear.cgColor
        view.addSubview(scrollView)
        
        outlineView = NSOutlineView()
        outlineView.delegate = self
        outlineView.headerView = nil
        outlineView.indentationPerLevel = 18
        outlineView.allowsMultipleSelection = false
        outlineView.style = .sourceList
        outlineView.selectionHighlightStyle = .regular
        outlineView.intercellSpacing = NSSize(width: 0, height: 6)
        outlineView.wantsLayer = true
        outlineView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("Column"))
        column.width = 280
        outlineView.addTableColumn(column)
        
        scrollView.documentView = outlineView
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 120),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
    }
    
    private func setupDataSource() {
        dataSource = SidebarDataSource()
        outlineView.dataSource = dataSource
        outlineView.reloadData()
        for i in 0..<dataSource.numberOfGroups {
            outlineView.expandItem(dataSource.group(at: i))
        }
    }
}

extension SidebarViewController: NSOutlineViewDelegate {
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let cellIdentifier = NSUserInterfaceItemIdentifier("Cell")
        
        if let group = item as? FilterGroup {
            let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTextField ?? NSTextField(labelWithString: group.name)
            cell.stringValue = group.name
            cell.font = .boldSystemFont(ofSize: 12)
            cell.textColor = NSColor(hex: "96D35F")
            cell.alignment = .left
            cell.backgroundColor = NSColor.windowBackgroundColor
            return cell
        } else if let item = item as? FilterItem {
            let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTextField ?? NSTextField(labelWithString: item.name)
            cell.stringValue = item.name
            cell.font = .systemFont(ofSize: 13, weight: .regular)
            cell.textColor = .labelColor
            cell.alignment = .left
            return cell
        }
        return nil
    }
    
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        let rowView = NSTableRowView()
        rowView.wantsLayer = true
        rowView.selectionHighlightStyle = .none
        return rowView
    }
    
    func outlineView(_ outlineView: NSOutlineView, didAdd rowView: NSTableRowView, forRow row: Int) {
        updateRowView(rowView, forRow: row, outlineView: outlineView)
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return item is FilterItem
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard outlineView.selectedRow >= 0,
              let item = outlineView.item(atRow: outlineView.selectedRow) as? FilterItem else {
            return
        }
        delegate?.didSelectFilter(
            item.filter,
            name: item.name,
            hasSlider: item.hasSlider,
            sliderRange: item.sliderRange,
            callback: item.callback
        )
    }
    
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        return item is FilterGroup
    }
    
    private func updateRowView(_ rowView: NSTableRowView, forRow row: Int, outlineView: NSOutlineView) {
        let item = outlineView.item(atRow: row)
        if item is FilterItem {
            rowView.backgroundColor = NSColor.clear
            rowView.layer?.cornerRadius = 2
            rowView.layer?.masksToBounds = true
            rowView.layer?.backgroundColor = NSColor.clear.cgColor
        } else {
            rowView.backgroundColor = NSColor.clear
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
        return true
    }
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if item is FilterGroup {
            return 32
        }
        return 36
    }
}

class SidebarDataSource: NSObject, NSOutlineViewDataSource {
    
    private let groups: [FilterGroup] = FilterGroup.datas
    
    var numberOfGroups: Int {
        groups.count
    }
    
    func group(at index: Int) -> FilterGroup {
        groups[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let group = item as? FilterGroup {
            return group.items.count
        }
        return groups.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let group = item as? FilterGroup {
            return group.items[index]
        }
        return groups[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is FilterGroup
    }
}

protocol MainViewControllerSliderDelegate: AnyObject {
    func sliderValueChanged(_ value: Float)
}

class MainViewController: NSViewController {
    
    var originImage: C7Image!
    var processedImage: C7Image?
    weak var sliderDelegate: MainViewControllerSliderDelegate?
    
    private var originImageView: NSImageView!
    private var processedImageView: NSImageView!
    private var filterNameLabel: NSTextField!
    private var sliderContainer: NSView!
    private var slider: NSSlider!
    private var sliderValueLabel: NSTextField!
    private var stackView: NSStackView!
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        view.layer?.cornerRadius = 2
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupFilterNameLabel()
        setupImageViews()
        setupSlider()
        setupStackView()
    }
    
    private func setupFilterNameLabel() {
        filterNameLabel = NSTextField(labelWithString: "Select a filter from the sidebar")
        filterNameLabel.font = .boldSystemFont(ofSize: 24)
        filterNameLabel.textColor = NSColor(hex: "96D35F")
        filterNameLabel.alignment = .center
        filterNameLabel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.8)
        filterNameLabel.isBezeled = false
        filterNameLabel.isEditable = false
        filterNameLabel.translatesAutoresizingMaskIntoConstraints = false
        filterNameLabel.layer?.cornerRadius = 2
        filterNameLabel.layer?.masksToBounds = true
        filterNameLabel.layer?.borderWidth = 1
        filterNameLabel.layer?.borderColor = NSColor(hex: "96D35F").withAlphaComponent(0.4).cgColor
        view.addSubview(filterNameLabel)
    }
    
    private func setupImageViews() {
        originImageView = createImageView(image: originImage, title: "Original")
        processedImageView = createImageView(image: originImage, title: "Processed")
    }
    
    private func createImageView(image: C7Image, title: String) -> NSImageView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.black.cgColor
        container.layer?.cornerRadius = 2
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor(hex: "96D35F").withAlphaComponent(0.6).cgColor
        container.layer?.masksToBounds = true
        container.layer?.shadowColor = NSColor(hex: "96D35F").withAlphaComponent(0.3).cgColor
        container.layer?.shadowOffset = CGSize(width: 0, height: 8)
        container.layer?.shadowRadius = 16
        container.layer?.shadowOpacity = 0.4
        
        let imageView = NSImageView(image: image)
        imageView.imageScaling = .scaleProportionallyDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.wantsLayer = true
        imageView.layer?.borderColor = NSColor(hex: "96D35F").withAlphaComponent(0.3).cgColor
        container.addSubview(imageView)
        
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.textColor = NSColor(hex: "96D35F")
        titleLabel.alignment = .center
        titleLabel.backgroundColor = NSColor.black.withAlphaComponent(0.8)
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: 40),
            imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            imageView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 25),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -25),
            titleLabel.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        view.addSubview(container)
        
        return imageView
    }
    
    private func setupSlider() {
        sliderContainer = NSView()
        sliderContainer.translatesAutoresizingMaskIntoConstraints = false
        sliderContainer.isHidden = true
        sliderContainer.wantsLayer = true
        sliderContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.98).cgColor
        sliderContainer.layer?.cornerRadius = 2
        sliderContainer.layer?.borderWidth = 1
        sliderContainer.layer?.borderColor = NSColor(hex: "96D35F").withAlphaComponent(0.3).cgColor
        sliderContainer.layer?.shadowColor = NSColor(hex: "96D35F").withAlphaComponent(0.15).cgColor
        sliderContainer.layer?.shadowOffset = CGSize(width: 0, height: 4)
        sliderContainer.layer?.shadowRadius = 8
        sliderContainer.layer?.shadowOpacity = 0.2
        view.addSubview(sliderContainer)
        
        let sliderTitleLabel = NSTextField(labelWithString: "Adjust Parameter:")
        sliderTitleLabel.font = .boldSystemFont(ofSize: 14)
        sliderTitleLabel.textColor = NSColor(hex: "96D35F")
        sliderTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        sliderContainer.addSubview(sliderTitleLabel)
        
        slider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: self, action: #selector(sliderValueChanged(_:)))
        slider.tickMarkPosition = NSSlider.TickMarkPosition(rawValue: 0)!
        slider.allowsTickMarkValuesOnly = false
        slider.isContinuous = true
        slider.translatesAutoresizingMaskIntoConstraints = false
        sliderContainer.addSubview(slider)
        
        sliderValueLabel = NSTextField(labelWithString: "0.00")
        sliderValueLabel.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        sliderValueLabel.textColor = NSColor(hex: "96D35F")
        sliderValueLabel.alignment = .center
        sliderValueLabel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.8)
        sliderValueLabel.isBezeled = true
        sliderValueLabel.isEditable = false
        sliderValueLabel.translatesAutoresizingMaskIntoConstraints = false
        sliderValueLabel.layer?.cornerRadius = 6
        sliderValueLabel.layer?.masksToBounds = true
        sliderContainer.addSubview(sliderValueLabel)
        
        NSLayoutConstraint.activate([
            sliderTitleLabel.topAnchor.constraint(equalTo: sliderContainer.topAnchor, constant: 20),
            sliderTitleLabel.leadingAnchor.constraint(equalTo: sliderContainer.leadingAnchor, constant: 24),
            
            slider.topAnchor.constraint(equalTo: sliderTitleLabel.bottomAnchor, constant: 12),
            slider.leadingAnchor.constraint(equalTo: sliderContainer.leadingAnchor, constant: 24),
            slider.trailingAnchor.constraint(equalTo: sliderValueLabel.leadingAnchor, constant: -20),
            slider.bottomAnchor.constraint(equalTo: sliderContainer.bottomAnchor, constant: -20),
            
            sliderValueLabel.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
            sliderValueLabel.trailingAnchor.constraint(equalTo: sliderContainer.trailingAnchor, constant: -24),
            sliderValueLabel.widthAnchor.constraint(equalToConstant: 90),
            sliderValueLabel.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    private func setupStackView() {
        let imageStack = NSStackView(views: [originImageView.superview!, processedImageView.superview!])
        imageStack.orientation = .horizontal
        imageStack.alignment = .centerY
        imageStack.distribution = .fillEqually
        imageStack.spacing = 40
        imageStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageStack)
        
        let githubLink = createGitHubLink()
        let infoText = createInfoText()
        
        NSLayoutConstraint.activate([
            filterNameLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            filterNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            filterNameLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            imageStack.topAnchor.constraint(equalTo: filterNameLabel.bottomAnchor, constant: 20),
            imageStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            imageStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            imageStack.heightAnchor.constraint(equalTo: imageStack.widthAnchor, multiplier: 0.5),
            imageStack.heightAnchor.constraint(lessThanOrEqualToConstant: 500),
            
            sliderContainer.topAnchor.constraint(equalTo: imageStack.bottomAnchor, constant: 30),
            sliderContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            sliderContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
            
            githubLink.topAnchor.constraint(equalTo: sliderContainer.bottomAnchor, constant: 20),
            githubLink.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            
            infoText.topAnchor.constraint(equalTo: githubLink.bottomAnchor, constant: 10),
            infoText.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            infoText.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            infoText.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }
    
    private func createInfoText() -> NSTextField {
        let textField = NSTextField()
        textField.stringValue = "Harbeth is a powerful Metal-based image processing framework for macOS and iOS.\n\n" +
        "Features:\n" +
        "• High-performance image processing using Metal\n" +
        "• Wide range of built-in filters\n" +
        "• Easy-to-use API\n" +
        "• Real-time processing capabilities\n\n" +
        "Thank you for using Harbeth!\n" +
        "If you find this project useful, please consider starring it on GitHub."
        textField.font = .systemFont(ofSize: 13)
        textField.textColor = .secondaryLabelColor
        textField.alignment = .left
        textField.isBezeled = false
        textField.isEditable = false
        textField.isSelectable = true
        textField.maximumNumberOfLines = 0
        textField.cell?.wraps = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textField)
        return textField
    }
    
    private func createGitHubLink() -> NSButton {
        let button = NSButton()
        button.title = "🌟 GitHub: https://github.com/yangKJ/Harbeth"
        button.setButtonType(.momentaryLight)
        button.bezelStyle = .texturedRounded
        button.font = .systemFont(ofSize: 13, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.action = #selector(openGitHub)
        button.target = self
        button.wantsLayer = true
        button.layer?.cornerRadius = 0
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.layer?.borderWidth = 0
        view.addSubview(button)
        return button
    }
    
    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/yangKJ/Harbeth") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func updateProcessedImage(_ image: C7Image) {
        processedImage = image
        processedImageView.image = image
    }
    
    func updateFilterName(_ name: String) {
        filterNameLabel.stringValue = "\(name)"
    }
    
    func showSlider(min: Float, max: Float, current: Float, delegate: MainViewControllerSliderDelegate) {
        sliderDelegate = delegate
        sliderContainer.isHidden = false
        slider.minValue = Double(min)
        slider.maxValue = Double(max)
        slider.doubleValue = Double(current)
        updateSliderValueLabel(current)
    }
    
    func hideSlider() {
        sliderContainer.isHidden = true
    }
    
    @objc private func sliderValueChanged(_ sender: NSSlider) {
        let value = Float(sender.doubleValue)
        updateSliderValueLabel(value)
        sliderDelegate?.sliderValueChanged(value)
    }
    
    private func updateSliderValueLabel(_ value: Float) {
        sliderValueLabel.stringValue = String(format: "%.2f", value)
    }
}

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}
