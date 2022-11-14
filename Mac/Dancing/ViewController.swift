//
//  ViewController.swift
//  Dancing
//
//  Created by Condy on 2022/11/6.
//

import Cocoa
import Harbeth

class ViewController: NSViewController {
    
    override func loadView() {
        let rect = NSApplication.shared.mainWindow?.frame ?? .zero
        view = NSView(frame: rect)
        view.wantsLayer = true
    }
    
    var originImage: C7Image = R.image("AX")
    
    lazy var ImageView: NSImageView = {
        let imageView = NSImageView.init(image: originImage)
        imageView.imageScaling = .scaleAxesIndependently
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
        let html = ". Harbeth test case, <a href=\"https://github.com/yangKJ/Harbeth\">Please help me with a star.</a> Thanks!!!"
        let string = self.string(fromHTML: html, with: .systemFont(ofSize: 15))
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
    
    let filter0 = C7LookupTable(name: "lut_ll")
    let filter1 = C7SoulOut()
    let filter2 = C7Granularity()
    let filter3 = C7Storyboard.init()
    let filter4 = C7ConvolutionMatrix3x3(matrix: Matrix3x3.Kernel.sharpen(2))
    let filter5 = C7ColorMatrix4x4(matrix: Matrix4x4.Color.rgb_to_bgr)
    
    func unitTest() {
        originImage = originImage.mt.zipScale(size: CGSize(width: 600, height: 600))
        
        let dest = BoxxIO.init(element: originImage, filters: [filter0, filter1, filter2, filter3])
        ImageView.image = try? dest.output()
        
        dest.filters.forEach {
            NSLog("\($0.parameterDescription)")
        }
    }
}

extension ViewController {
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
}
