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
    
    var originImage: C7Image = R.image("AR")
    
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
    
    //let filter = C7Storyboard.init(ranks: 2)
    //let filter = C7SoulOut.init(soul: 0.7)
    //let filter = C7Granularity.init()
    //let filter = C7MeanBlur.init(radius: 0.5)
    //let filter = C7Brightness.init(brightness: 0.25)
    //let filter = C7ConvolutionMatrix3x3(convolutionType: .sharpen(iterations: 2))
    //let filter = C7ColorConvert(with: .gray)
    let filter = C7LookupTable.init(image: R.image("lut_abao"))
    
    func unitTest() {
        //originImage = originImage.mt.zipScale(size: CGSize(width: 600, height: 600))
        
        let dest = BoxxIO.init(element: originImage, filter: filter)
        ImageView.image = try? dest.output()
        
        dest.filters.forEach {
            NSLog("%@", "\($0.parameterDescription)")
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
