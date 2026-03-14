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
        view.layer.borderColor = UIColor(red: 0.36, green: 0.28, blue: 0.98, alpha: 1.0).cgColor
        view.layer.borderWidth = 0.5
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.2
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.clipsToBounds = false
        return view
    }()
    
    lazy var mourningButton: UIBarButtonItem = {
        let bar = UIBarButtonItem(title: "哀悼模式", style: .plain, target: self, action: #selector(mourningAction))
        return bar
    }()
    
    lazy var overlay: UIView = {
        let overlay = UIView()
        overlay.isUserInteractionEnabled = false
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = .lightGray
        overlay.layer.compositingFilter = "saturationBlendMode"
        overlay.alpha = 0 // 初始透明度为0
        return overlay
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupUI()
        self.unitTest()
    }
    
    func setupUI() {
        title = "Test"
        navigationItem.rightBarButtonItem = mourningButton
        view.backgroundColor = UIColor.systemBackground
        view.addSubview(renderView)
        
        // 添加标题标签
        let titleLabel = UILabel()
        titleLabel.text = "图像效果预览"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            renderView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            renderView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            renderView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            renderView.heightAnchor.constraint(equalTo: renderView.widthAnchor, multiplier: 1.5),
        ])
    }
    
    private var mourning: Bool = false
    
    @objc func mourningAction() {
        if mourning {
            // 移除哀悼模式，添加淡出动画
            UIView.animate(withDuration: 0.5) {
                self.overlay.alpha = 0
            } completion: { _ in
                self.overlay.removeFromSuperview()
            }
        } else {
            // 添加哀悼模式，添加淡入动画
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
        PerformanceMonitor.shared.beginMonitoring("unitTest")
        
        let filter2 = C7CombinationColorGrading()
        
        let dest = HarbethIO.init(element: inputImage, filters: [filter2])
        UIView.transition(with: renderView, duration: 0.5, options: .transitionCrossDissolve) {
            self.renderView.image = dest.filtered()
        }
        PerformanceMonitor.shared.endMonitoring("unitTest")
    }
}
