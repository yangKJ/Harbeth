//
//  UnitTestViewController.swift
//  MetalDemo
//
//  Created by Condy on 2022/11/3.
//

import Foundation
import Harbeth

class UnitTestViewController: UIViewController {
    
    let inputImage = [
        R.image("wechat0")!, R.image("wechat1")!
    ].randomElement()
    
    lazy var renderView: UIImageView = {
        let view = UIImageView(image: inputImage)
        view.contentMode = .scaleAspectFit
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = false
        view.backgroundColor = UIColor.systemBackground
        return view
    }()
    
    lazy var mourningButton: UIBarButtonItem = {
        let bar = UIBarButtonItem(title: "M", style: .plain, target: self, action: #selector(mourningAction))
        return bar
    }()
    
    lazy var overlay: UIView = {
        let overlay = UIView()
        overlay.isUserInteractionEnabled = false
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = .lightGray
        overlay.layer.compositingFilter = "saturationBlendMode"
        overlay.alpha = 0
        return overlay
    }()
    
    lazy var supportView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor(hex: "#5C48FA").withAlphaComponent(0.06)
        view.layer.cornerRadius = 2
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(hex: "#5C48FA").withAlphaComponent(0.15).cgColor
        view.layer.shadowColor = UIColor(hex: "#5C48FA").withAlphaComponent(0.1).cgColor
        view.layer.shadowOpacity = 0.6
        view.layer.shadowOffset = CGSize(width: 0, height: 6)
        view.layer.shadowRadius = 16
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
        self.unitTest()
    }
    
    func setupUI() {
        title = "Thanks"
        navigationItem.rightBarButtonItem = mourningButton
        view.backgroundColor = UIColor.systemBackground
        view.addSubview(renderView)
        view.addSubview(supportView)
        
        let decorView = UIView()
        decorView.translatesAutoresizingMaskIntoConstraints = false
        decorView.backgroundColor = UIColor(hex: "#5C48FA").withAlphaComponent(0.25)
        decorView.layer.cornerRadius = 4
        supportView.addSubview(decorView)
        
        let supportTitleLabel = UILabel()
        supportTitleLabel.text = "关于这个项目"
        supportTitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        supportTitleLabel.textColor = UIColor(hex: "#5C48FA")
        supportTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        supportView.addSubview(supportTitleLabel)
        
        let supportTextLabel = UILabel()
        supportTextLabel.text = "每一行代码都承载着对技术的热爱与追求，每一次优化都源于对完美的执着。\n\n在开源的世界里，你的认可与支持是我们前行的动力。如果这个项目曾为你带来帮助或启发，不妨给个 star ⭐，让更多人看到它的价值。\n\n当然，如果你愿意请作者喝杯咖啡 ☕，那将是对这份坚持最好的鼓励。"
        supportTextLabel.font = UIFont.systemFont(ofSize: 15)
        supportTextLabel.textColor = UIColor.systemGray
        supportTextLabel.numberOfLines = 0
        supportTextLabel.textAlignment = .center
        supportTextLabel.lineBreakMode = .byWordWrapping
        supportTextLabel.translatesAutoresizingMaskIntoConstraints = false
        supportView.addSubview(supportTextLabel)
        
        NSLayoutConstraint.activate([
            renderView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            renderView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            renderView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            renderView.heightAnchor.constraint(equalTo: renderView.widthAnchor, multiplier: 1),
            renderView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            supportView.topAnchor.constraint(equalTo: renderView.bottomAnchor, constant: 20),
            supportView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            supportView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            supportView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            decorView.topAnchor.constraint(equalTo: supportView.topAnchor, constant: 16),
            decorView.centerXAnchor.constraint(equalTo: supportView.centerXAnchor),
            decorView.widthAnchor.constraint(equalToConstant: 40),
            decorView.heightAnchor.constraint(equalToConstant: 4),
            
            supportTitleLabel.topAnchor.constraint(equalTo: decorView.bottomAnchor, constant: 16),
            supportTitleLabel.centerXAnchor.constraint(equalTo: supportView.centerXAnchor),
            
            supportTextLabel.topAnchor.constraint(equalTo: supportTitleLabel.bottomAnchor, constant: 12),
            supportTextLabel.leadingAnchor.constraint(equalTo: supportView.leadingAnchor, constant: 24),
            supportTextLabel.trailingAnchor.constraint(equalTo: supportView.trailingAnchor, constant: -24),
            supportTextLabel.bottomAnchor.constraint(equalTo: supportView.bottomAnchor, constant: -16),
        ])
    }
    
    private var mourning: Bool = false
    
    @objc func mourningAction() {
        if mourning {
            UIView.animate(withDuration: 0.5) {
                self.overlay.alpha = 0
            } completion: { _ in
                self.overlay.removeFromSuperview()
            }
        } else {
            UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.topAnchor.constraint(equalTo: UIApplication.shared.windows.first!.topAnchor),
                overlay.leadingAnchor.constraint(equalTo: UIApplication.shared.windows.first!.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: UIApplication.shared.windows.first!.trailingAnchor),
                overlay.bottomAnchor.constraint(equalTo: UIApplication.shared.windows.first!.bottomAnchor),
            ])
            UIView.animate(withDuration: 0.5) {
                self.overlay.alpha = 1
            }
        }
        self.mourning = !self.mourning
    }
}

extension UnitTestViewController {
    
    func unitTest() {
        let filters: [C7FilterProtocol] = [
            C7Brightness(brightness: 0.2),
            C7Contrast(contrast: 1.2),
            C7Saturation(saturation: 1.1),
            C7Sharpen(sharpness: 0.5),
            C7CombinationColorGrading()
        ]
        let dest = HarbethIO.init(element: inputImage, filters: filters)
        dest.transmitOutput(success: { image in
            DispatchQueue.main.async {
                self.renderView.image = image
            }
        })
    }
}
