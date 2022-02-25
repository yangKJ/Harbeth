//
//  CameraViewController.swift
//  MetalDemo
//
//  Created by Condy on 2022/2/25.
//

import Harbeth
import AVFoundation

class CameraViewController: UIViewController {
    
    var tuple: FilterResult?
    lazy var originImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = UIColor.background2?.withAlphaComponent(0.3)
        return imageView
    }()
    
    lazy var collector: C7FilterCollector = {
        let collector = C7FilterCollector(callback: { [weak self] (image) in
            self?.originImageView.image = image
            if let callback = self?.tuple?.callback {
                self?.collector.filter = callback(self!.nextTime)
            }
        })
        collector.captureSession.sessionPreset = AVCaptureSession.Preset.vga640x480
        collector.filter = self.tuple?.filter
        return collector
    }()
    
    lazy var displayLink: CADisplayLink = {
        let displayLink = CADisplayLink(target: self, selector: #selector(readBuffer(_:)))
        displayLink.add(to: .current, forMode: .default)
        displayLink.isPaused = true
        return displayLink
    }()
    
    // random time(actually NOT random)
    private let times: [Float] = (0..<50).map { 0.1 + Float($0) * 0.03 }
    private var current = 0
    var nextTime: Float {
        let time = times[current]
        current = (current + 1) % times.count
        return time
    }
    
    deinit {
        print("🎨 is Deinit.")
        Shared.shared.deinitDevice()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.global().async{
            self.collector.captureSession.startRunning()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        DispatchQueue.global().async{
            self.collector.captureSession.stopRunning()
        }
    }
    
    func setupUI() {
        view.backgroundColor = UIColor.background
        view.addSubview(originImageView)
        originImageView.layer.addSublayer(collector)
        NSLayoutConstraint.activate([
            originImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
            originImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            originImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            originImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100)
        ])
    }
    
    @objc func readBuffer(_ sender: CADisplayLink) {
        
    }
}
