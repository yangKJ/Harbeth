//
//  FilterViewController.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/7.
//

import Foundation
import UIKit
import ATMetalBand

class FilterViewController: UIViewController {
    
    public var filter: C7FilterProtocol?
    public var callback: FilterCallback?
    public var originImage: UIImage = UIImage.init(named: "timg-3")!
    public lazy var slider: UISlider = {
        let slider = UISlider.init()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action:#selector(sliderDidchange(_:)), for: .valueChanged)
        return slider
    }()
    
    private lazy var originImageView: UIImageView = {
        let imageView = UIImageView.init()
        imageView.backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var filterImageView: UIImageView = {
        let imageView = UIImageView.init()
        imageView.backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var leftLabel: UILabel = {
        let label = UILabel.init()
        label.textAlignment = .left
        label.backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
        label.textColor = UIColor.systemPink
        label.font = UIFont.systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var rightLabel: UILabel = {
        let label = UILabel.init()
        label.textAlignment = .right
        label.backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
        label.textColor = UIColor.systemPink
        label.font = UIFont.systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var currentLabel: UILabel = {
        let label = UILabel.init()
        label.textAlignment = .center
        label.backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
        label.textColor = UIColor.systemPink
        label.font = UIFont.systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupFilter()
    }
    
    func setupUI() {
        view.backgroundColor = UIColor.white
        view.addSubview(originImageView)
        view.addSubview(filterImageView)
        view.addSubview(slider)
        view.addSubview(leftLabel)
        view.addSubview(rightLabel)
        view.addSubview(currentLabel)
        NSLayoutConstraint.activate([
            originImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
            filterImageView.topAnchor.constraint(equalTo: originImageView.bottomAnchor, constant: 15),
            filterImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            filterImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            filterImageView.heightAnchor.constraint(equalTo: filterImageView.widthAnchor, multiplier: 3/4),
            leftLabel.topAnchor.constraint(equalTo: filterImageView.bottomAnchor, constant: 20),
            leftLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            leftLabel.widthAnchor.constraint(equalToConstant: 100),
            leftLabel.heightAnchor.constraint(equalToConstant: 30),
            rightLabel.topAnchor.constraint(equalTo: filterImageView.bottomAnchor, constant: 20),
            rightLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            rightLabel.widthAnchor.constraint(equalToConstant: 100),
            rightLabel.heightAnchor.constraint(equalToConstant: 30),
            currentLabel.topAnchor.constraint(equalTo: filterImageView.bottomAnchor, constant: 20),
            currentLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            currentLabel.widthAnchor.constraint(equalToConstant: 100),
            currentLabel.heightAnchor.constraint(equalToConstant: 30),
            slider.topAnchor.constraint(equalTo: leftLabel.bottomAnchor, constant: 20),
            slider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            slider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            slider.heightAnchor.constraint(equalToConstant: 30),
        ])
        if slider.isHidden {
            NSLayoutConstraint.activate([
                originImageView.centerXAnchor.constraint(equalTo: filterImageView.centerXAnchor),
                originImageView.widthAnchor.constraint(equalTo: filterImageView.widthAnchor),
                originImageView.heightAnchor.constraint(equalTo: filterImageView.heightAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                originImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
                originImageView.widthAnchor.constraint(equalToConstant: 100),
                originImageView.heightAnchor.constraint(equalToConstant: 100),
            ])
        }
        leftLabel.text  = "\(slider.minimumValue)"
        rightLabel.text = "\(slider.maximumValue)"
        currentLabel.text = "\(slider.value)"
        filterImageView.image = originImage
        originImageView.image = originImage
        leftLabel.isHidden = slider.isHidden
        rightLabel.isHidden = slider.isHidden
        currentLabel.isHidden = slider.isHidden
    }
    
    func setupFilter() {
        filterImageView.image = originImage.makeImage(filter: filter!)
    }
    
    @objc func sliderDidchange(_ slider: UISlider) {
        currentLabel.text = String(format: "%.2f", slider.value)
        if let callback = callback {
            let filter = callback(slider.value)
            filterImageView.image = originImage.makeImage(filter: filter)
        }
    }
}
