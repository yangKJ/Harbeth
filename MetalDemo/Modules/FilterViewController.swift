//
//  FilterViewController.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/7.
//

import Harbeth

class FilterViewController: UIViewController {
    
    var filter: C7FilterProtocol?
    var callback: FilterCallback?
    var originImage: UIImage!
    weak var timer: Timer?
    lazy var autoBarButton: UIBarButtonItem = {
        let barButton = UIBarButtonItem(title: "Auto",
                                        style: .plain,
                                        target: self,
                                        action: #selector(autoTestAction))
        return barButton
    }()
    
    lazy var slider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action:#selector(sliderDidchange(_:)), for: .valueChanged)
        return slider
    }()
    
    lazy var originImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.borderColor = UIColor.background2?.cgColor
        imageView.layer.borderWidth = 0.5
        return imageView
    }()
    
    lazy var filterImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.borderColor = UIColor.background2?.cgColor
        imageView.layer.borderWidth = 0.5
        return imageView
    }()
    
    lazy var leftLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.textColor = UIColor.background2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var rightLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.textColor = UIColor.background2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var currentLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = UIColor.background2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    deinit {
        print("FilterViewController is Deinit.")
        Shared.shared.deinitDevice()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupFilter()
    }
    
    func setupUI() {
        navigationItem.rightBarButtonItem = autoBarButton
        view.backgroundColor = UIColor.background
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
                filterImageView.heightAnchor.constraint(equalTo: filterImageView.widthAnchor, multiplier: 3/4),
                originImageView.centerXAnchor.constraint(equalTo: filterImageView.centerXAnchor),
                originImageView.widthAnchor.constraint(equalTo: filterImageView.widthAnchor),
                originImageView.heightAnchor.constraint(equalTo: filterImageView.heightAnchor),
            ])
        } else {
            originImageView.layer.borderWidth = 0
            NSLayoutConstraint.activate([
                filterImageView.heightAnchor.constraint(equalTo: filterImageView.widthAnchor, multiplier: 3.5/4),
                originImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
                originImageView.widthAnchor.constraint(equalToConstant: 100),
                originImageView.heightAnchor.constraint(equalToConstant: 100),
            ])
        }
        let bg = UIColor.background2?.withAlphaComponent(0.3)
        originImageView.backgroundColor = bg
        filterImageView.backgroundColor = bg
        leftLabel.backgroundColor = bg
        rightLabel.backgroundColor = bg
        currentLabel.backgroundColor = bg
        leftLabel.text  = "\(slider.minimumValue)"
        rightLabel.text = "\(slider.maximumValue)"
        currentLabel.text = "\(slider.value)"
        filterImageView.image = originImage
        originImageView.image = originImage
        leftLabel.isHidden = slider.isHidden
        rightLabel.isHidden = slider.isHidden
        currentLabel.isHidden = slider.isHidden
    }
}

// MARK: - filter process
extension FilterViewController {
    func setupFilter() {
        if slider.isHidden {
            filterImageView.image = originImage ->> filter!
            return
        }
        autoTestAction()
    }
    
    @objc func autoTestAction() {
        if slider.isHidden { return }
        
        if let _ = timer {
            autoBarButton.title = "Auto"
            timer?.invalidate()
            timer = nil
        } else {
            autoBarButton.title = "Stop"
            var add = true
            let timer = Timer(timeInterval: 0.01, repeats: true, block: { [weak self] _ in
                guard let `self` = self else { return }
                if self.slider.value >= self.slider.maximumValue {
                    add = false
                    //self.slider.value = self.slider.minimumValue
                } else if self.slider.value <= self.slider.minimumValue {
                    add = true
                }
                if add {
                    self.slider.value += (self.slider.maximumValue - self.slider.minimumValue) / 77
                } else {
                    self.slider.value -= (self.slider.maximumValue - self.slider.minimumValue) / 77
                }
                self.currentLabel.text = String(format: "%.4f", self.slider.value)
                if let callback = self.callback {
                    let filter = callback(self.slider.value)
                    self.filterImageView.image = try? self.originImage.make(filter: filter)
                }
            })
            RunLoop.current.add(timer, forMode: .common)
            timer.fire()
            self.timer = timer
        }
    }
    
    @objc func sliderDidchange(_ slider: UISlider) {
        currentLabel.text = String(format: "%.4f", slider.value)
        if let callback = callback {
            let filter = callback(slider.value)
            filterImageView.image = try? originImage.makeGroup(filters: [filter])
        }
    }
}
