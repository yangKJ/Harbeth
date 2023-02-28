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
        let rect = NSApplication.shared.mainWindow?.frame ?? .zero
        view = NSView(frame: rect)
        view.wantsLayer = true
    }
    
    var originImage: C7Image = R.image("AR")!
    
    private lazy var displayLink: CADisplayLink = {
        let display = CADisplayLink(target: self, selector: #selector(ViewController.onScreenUpdate(_:)))
        display.add(to: .current, forMode: RunLoop.Mode.default)
        display.isPaused = true
        return display
    }()
    
    lazy var ImageView: NSImageView = {
        let imageView = NSImageView.init(image: originImage)
        imageView.imageScaling = .scaleProportionallyDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer?.borderWidth = 2
        imageView.layer?.borderColor = C7Color.red.cgColor
        imageView.layer?.masksToBounds = true
        imageView.layer?.backgroundColor = C7Color.black.cgColor
        imageView.wantsLayer = true
        imageView.needsDisplay = true
        return imageView
    }()
    
    lazy var TextField: NSTextField = {
        func string(fromHTML html: String?, with font: NSFont? = nil) -> NSAttributedString {
            var html = html
            let font = font ?? .systemFont(ofSize: 0.0) // Default font
            html = String(format: "<span style=\"font-family:'%@'; font-size:%dpx;\">%@</span>", font.fontName, Int(font.pointSize), html ?? "")
            let data = html?.data(using: .utf8)
            let options = [NSAttributedString.DocumentReadingOptionKey.textEncodingName: "UTF-8"]
            var string: NSAttributedString? = nil
            if let data {
                string = NSAttributedString(html: data, options: options, documentAttributes: nil)
            }
            return string ?? NSAttributedString()
        }
        
        let html = ". Harbeth test case, <a href=\"https://github.com/yangKJ/Harbeth\">Please help me with a star.</a> Thanks!!!"
        let string = string(fromHTML: html, with: .systemFont(ofSize: 15))
        let label = NSTextField(labelWithAttributedString: string)
        label.allowsEditingTextAttributes = true
        label.isSelectable = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        self.setupUI()
        self.unitTest()
        //self.dynamicTest()
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    func setupUI() {
        view.addSubview(ImageView)
        view.addSubview(TextField)
        NSLayoutConstraint.activate([
            ImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            ImageView.heightAnchor.constraint(equalTo: ImageView.widthAnchor, multiplier: 1),
            ImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            ImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            TextField.topAnchor.constraint(equalTo: ImageView.bottomAnchor, constant: 10),
            TextField.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -10),
            TextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            TextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
        ])
    }
    
    let filters: [C7FilterProtocol] = [
        C7Storyboard.init(ranks: 2),
        C7SoulOut.init(soul: 0.7),
        C7Granularity.init(),
        C7MeanBlur.init(radius: 0.5),
        C7Brightness.init(brightness: 0.25),
        C7ConvolutionMatrix3x3(convolutionType: .sharpen(iterations: 2)),
        C7ColorConvert(with: .gray),
        C7LookupTable.init(image: R.image("lut_abao")),
        C7Rotate.init(angle: -30),
        C7ColorVector4.init(vector: Vector4.Color.warm),
        C7ColorMatrix4x4(matrix: Matrix4x4.Color.axix_red_rotate(90)),
        C7Hue.init(hue: 45),
        C7ThresholdSketch.init(edgeStrength: 2.5, threshold: 0.25),
        C7ColorPacking.init(horizontalTexel: 2.5, verticalTexel: 5),
        C7Fluctuate.init(extent: 50, amplitude: 0.003, fluctuate: 2.5),
        C7Nostalgic.init(intensity: 0.6),
        C7ComicStrip.init(),
        C7OilPainting.init(radius: 4, pixel: 1),
        C7ColorVector4(vector: Vector4.Color.warm),
        C7Contrast.init(contrast: 1.5),
        C7Exposure.init(exposure: 0.25),
        C7FalseColor.init(fristColor: .blue, secondColor: .green),
        C7Gamma.init(gamma: 3.0),
        C7Haze.init(distance: 0.25, slope: 0.5),
        C7Monochrome.init(intensity: 0.83, color: .blue),
        C7Opacity.init(opacity: 0.75),
        C7Posterize.init(colorLevels: 2.3),
        C7Vibrance.init(vibrance: -1.2),
        C7WhiteBalance.init(temperature: 4000, tint: -200),
        C7ColorSpace.init(with: .rgb_to_yuv),
        C7BilateralBlur.init(radius: 0.5),
    ]
    
    func unitTest() {
        //originImage = originImage.mt.zipScale(size: CGSize(width: 600, height: 600))
        guard let filter = filters.randomElement() else {
            return
        }
        NSLog("%@", "\(type(of: filter)) --- \(filter.parameterDescription)")
        let dest = BoxxIO.init(element: originImage, filter: filter)
        ImageView.image = try? dest.output()
    }
    
    func dynamicTest() {
        displayLink.isPaused = false
    }
    
    var soul = C7SoulOut.init(soul: 0.7)
    @objc func onScreenUpdate(_ sender: CADisplayLink) {
        soul.soul += 0.025
        if soul.soul == C7SoulOut.range.max {
            soul.soul = C7SoulOut.range.min
        }
        self.ImageView.image = originImage ->> soul
    }
}
