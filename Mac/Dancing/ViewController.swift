//
//  ViewController.swift
//  Dancing
//
//  Created by Condy on 2022/11/6.
//

import Cocoa
import Harbeth

class ViewController: NSViewController {
    
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
        title = "Unit testing"
        view.addSubview(ImageView)
        NSLayoutConstraint.activate([
            ImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            ImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            ImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            ImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
        ])
    }
    
    //let filter = C7LookupFilter(name: "lut_abao")
    let filter = MPSGaussianBlur()
    
    func unitTest() {
        //originImage = originImage.mt.zipScale(size: CGSize(width: 800, height: 600))
        let dest = C7DestIO.init(element: originImage, filter: filter)
        ImageView.image = try? dest.output()
    }
}
