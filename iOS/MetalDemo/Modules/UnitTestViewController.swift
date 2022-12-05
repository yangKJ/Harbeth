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
    
    lazy var leftBarButton: UIBarButtonItem = {
        UIBarButtonItem(title: "Mourning", style: .plain, target: self, action: #selector(mourningAction))
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
        self.setupGrayWindow()
    }
    
    func setupUI() {
        title = "Unit testing"
        navigationItem.rightBarButtonItem = leftBarButton
        view.backgroundColor = UIColor.background
        view.addSubview(ImageView)
        NSLayoutConstraint.activate([
            ImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
            ImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100),
            ImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            ImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
        ])
    }
    
    func setupGrayWindow() {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
            return
        }
        window.addSubview(overlay)
    }
    
    @objc func mourningAction() {
        if #available(iOS 15.0, *) {
            leftBarButton.isSelected = !leftBarButton.isSelected
            if leftBarButton.isSelected {
                self.overlay.removeFromSuperview()
            } else {
                self.setupGrayWindow()
            }
        } else {
            self.overlay.removeFromSuperview()
        }
    }
}

extension UnitTestViewController {
    
    func unitTest() {
        let filter = C7LookupTable(name: "ll")

        let dest = BoxxIO.init(element: originImage, filter: filter)

        ImageView.image = try? dest.output()
        
        // 方案1:
        //ImageView.image = try? BoxxIO.init(element: originImage, filters: [filter, filter2]).output()
        
        // 方案2:
        //ImageView.image = originImage.filtering(filter, filter2, filter3)
                
        // 方案3:
        //ImageView.image = originImage ->> filter ->> filter2 ->> filter3
        
        // 方案4:
        //ImageView.image = try? originImage.makeGroup(filters: [filter, filter2, filter3])
    }
}
