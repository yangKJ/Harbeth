//
//  UnitTestViewController.swift
//  MetalDemo
//
//  Created by Condy on 2022/11/3.
//

import Foundation
import Harbeth

class UnitTestViewController: UIViewController {
    
    let originImage = R.image("timg-2")
    
    lazy var ImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.borderColor = UIColor.background2?.cgColor
        imageView.layer.borderWidth = 0.5
        imageView.image = self.originImage
        return imageView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
        self.unitTest()
    }
    
    func setupUI() {
        title = "Unit testing"
        view.backgroundColor = UIColor.background
        view.addSubview(ImageView)
        NSLayoutConstraint.activate([
            ImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
            ImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100),
            ImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            ImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
        ])
    }
}

extension UnitTestViewController {
    
    func unitTest() {
        //let filter = C7LookupTable(name: "ll")
        var filter = C7Levels()
        filter.minimum = .green

        let dest = BoxxIO.init(element: originImage, filter: filter)

        ImageView.image = try? dest.output()
    }
}
