//
//  ImageViewController.swift
//  MetalQueen
//
//  Created by Condy on 2021/8/7.
//

import Harbeth

class ImageViewController: UIViewController {
    
    var filter: C7FilterProtocol?
    var callback: FilterCallback?
    var originImage: UIImage! {
        didSet {
            inputTexture = originImage.c7.toTexture()
        }
    }
    
    private var inputTexture: MTLTexture!
    
    weak var timer: Timer?
    lazy var autoBarButton: UIBarButtonItem = {
        let barButton = UIBarButtonItem(title: "Auto", style: .plain, target: self, action: #selector(autoTestAction))
        return barButton
    }()
    
    lazy var slider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addTarget(self, action:#selector(sliderDidchange(_:)), for: .valueChanged)
        slider.tintColor = UIColor.systemBlue
        return slider
    }()
    
    lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.borderColor = UIColor.systemBlue.cgColor
        imageView.layer.borderWidth = 0.5
        imageView.layer.cornerRadius = 2
        imageView.clipsToBounds = true
        return imageView
    }()
    
    lazy var renderView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.layer.borderColor = UIColor.systemBlue.cgColor
        imageView.layer.borderWidth = 0.5
        imageView.layer.cornerRadius = 2
        imageView.clipsToBounds = true
        return imageView
    }()
    
    lazy var leftLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.textColor = UIColor.systemBlue
        label.font = UIFont.systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var rightLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.textColor = UIColor.systemBlue
        label.font = UIFont.systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var currentLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = UIColor.systemBlue
        label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var originTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "原图"
        label.textAlignment = .left
        label.textColor = UIColor.systemBlue
        label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    deinit {
        print("ImageViewController is Deinit.")
        //Shared.shared.deinitDevice()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupFilter()
    }
    
    func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        view.addSubview(originTitleLabel)
        view.addSubview(imageView)
        view.addSubview(renderView)
        view.addSubview(slider)
        view.addSubview(leftLabel)
        view.addSubview(rightLabel)
        view.addSubview(currentLabel)
        
        let bg = UIColor.systemBlue.withAlphaComponent(0.2)
        imageView.backgroundColor = bg
        renderView.backgroundColor = bg
        
        leftLabel.text  = "\(slider.minimumValue)"
        rightLabel.text = "\(slider.maximumValue)"
        currentLabel.text = String(format: "%.2f", slider.value)
        
        renderView.image = originImage
        imageView.image = originImage
        
        let safeArea = view.safeAreaLayoutGuide
        if slider.isHidden {
            navigationItem.rightBarButtonItem = nil
            leftLabel.isHidden = true
            rightLabel.isHidden = true
            currentLabel.isHidden = true
            originTitleLabel.isHidden = true
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 20),
                imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 3/4),
                
                renderView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
                renderView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                renderView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                renderView.heightAnchor.constraint(equalTo: renderView.widthAnchor, multiplier: 3/4),
                renderView.bottomAnchor.constraint(lessThanOrEqualTo: safeArea.bottomAnchor, constant: -20),
            ])
        } else {
            navigationItem.rightBarButtonItem = autoBarButton
            leftLabel.isHidden = false
            rightLabel.isHidden = false
            currentLabel.isHidden = false
            originTitleLabel.isHidden = false
            NSLayoutConstraint.activate([
                originTitleLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
                originTitleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 20),
                originTitleLabel.widthAnchor.constraint(equalToConstant: 100),
                originTitleLabel.heightAnchor.constraint(equalToConstant: 24),
                
                imageView.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 20),
                imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                imageView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5, constant: -16),
                imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
                
                renderView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
                renderView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                renderView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                renderView.heightAnchor.constraint(equalTo: renderView.widthAnchor, multiplier: 3/4),
                
                leftLabel.topAnchor.constraint(equalTo: renderView.bottomAnchor, constant: 20),
                leftLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                leftLabel.widthAnchor.constraint(equalToConstant: 80),
                leftLabel.heightAnchor.constraint(equalToConstant: 24),
                
                rightLabel.topAnchor.constraint(equalTo: renderView.bottomAnchor, constant: 20),
                rightLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                rightLabel.widthAnchor.constraint(equalToConstant: 80),
                rightLabel.heightAnchor.constraint(equalToConstant: 24),
                
                currentLabel.topAnchor.constraint(equalTo: renderView.bottomAnchor, constant: 20),
                currentLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                currentLabel.widthAnchor.constraint(equalToConstant: 80),
                currentLabel.heightAnchor.constraint(equalToConstant: 24),
                
                slider.topAnchor.constraint(equalTo: leftLabel.bottomAnchor, constant: 2),
                slider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                slider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                slider.heightAnchor.constraint(equalToConstant: 40),
                
                slider.bottomAnchor.constraint(lessThanOrEqualTo: safeArea.bottomAnchor, constant: -20),
            ])
        }
    }
}

extension ImageViewController {
    func setupFilter() {
        if slider.isHidden {
            self.asynchronousProcessingImage(with: filter)
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
            let timer = Timer(timeInterval: 0.025, repeats: true, block: { [weak self] _ in
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
                self.currentLabel.text = String(format: "%.2f", self.slider.value)
                let filter = self.callback?(self.slider.value)
                self.asynchronousProcessingImage(with: filter)
            })
            RunLoop.current.add(timer, forMode: .common)
            timer.fire()
            self.timer = timer
        }
    }
    
    @objc func sliderDidchange(_ slider: UISlider) {
        self.currentLabel.text = String(format: "%.2f", slider.value)
        let filter = self.callback?(slider.value)
        self.asynchronousProcessingImage(with: filter)
    }
    
    func asynchronousProcessingImage(with filter: C7FilterProtocol?) {
        guard let filter = filter else {
            return
        }
        PerformanceMonitor.shared.beginMonitoring("Render")
        let dest = HarbethIO(element: inputTexture, filter: filter)
        dest.transmitOutput { [weak self] t in
            DispatchQueue.main.async {
                self?.renderView.image = t?.c7.toImage()
            }
            PerformanceMonitor.shared.endMonitoring("Render")
        }
    }
}
