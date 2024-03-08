//
//  UnitTestViewController.swift
//  MetalDemo
//
//  Created by Condy on 2022/11/3.
//

import Foundation
import Harbeth

class UnitTestViewController: UIViewController {
    
    let originImage = R.image("AX")
    
    lazy var ImageView: UIImageView = {
        let imageView = UIImageView(image: originImage)
        //imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.borderColor = UIColor.background2?.cgColor
        imageView.layer.borderWidth = 0.5
        return imageView
    }()
    
    lazy var leftBarButton: UIBarButtonItem = {
        let bar = UIBarButtonItem(title: "Mourning", style: .plain, target: self, action: #selector(mourningAction))
        if #available(iOS 15.0, *) {
            bar.isSelected = true
        } else {
            // Fallback on earlier versions
        }
        return bar
    }()
    
    lazy var overlay: UIView = {
        let overlay = UIView.init(frame: view.bounds)
        overlay.isUserInteractionEnabled = false
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = .lightGray
        overlay.layer.compositingFilter = "saturationBlendMode"
        overlay.layer.zPosition = CGFloat(Float.greatestFiniteMagnitude)
        return overlay
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
        self.unitTest()
    }
    
    func setupUI() {
        title = "Unit"
        navigationItem.rightBarButtonItem = leftBarButton
        view.backgroundColor = UIColor.background
        view.addSubview(ImageView)
        NSLayoutConstraint.activate([
            ImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            ImageView.heightAnchor.constraint(equalTo: ImageView.widthAnchor, multiplier: 1.0),
            //ImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100),
            ImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            ImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
        ])
    }
    
    private var mourning: Bool = false
    
    @objc func mourningAction() {
        if mourning {
            self.overlay.removeFromSuperview()
        } else {
            UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.addSubview(overlay)
        }
        self.mourning = !self.mourning
    }
}

extension UnitTestViewController {
    
    func unitTest() {
        let filter = C7Storyboard(ranks: 2)
        
        let dest = BoxxIO.init(element: originImage, filters: [filter])
        ImageView.image = try? dest.output()
    }
}
