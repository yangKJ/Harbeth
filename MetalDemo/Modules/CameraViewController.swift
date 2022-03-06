//
//  CameraViewController.swift
//  MetalDemo
//
//  Created by Condy on 2022/2/25.
//

import Harbeth

class CameraViewController: UIViewController {
    
    var tuple: FilterResult?
    lazy var originImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = UIColor.background2?.withAlphaComponent(0.3)
        return imageView
    }()
    
    lazy var camera: C7CollectorCamera = {
        let camera = C7CollectorCamera(callback: { [weak self] (image) in
            self?.originImageView.image = image
            if let callback = self?.tuple?.callback {
                self?.camera.filters = [callback(self!.nextTime)]
            }
        })
        camera.captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
        camera.filters = [self.tuple!.filter]
        return camera
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
        camera.startCollector()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        camera.stopCollector()
    }
    
    func setupUI() {
        view.backgroundColor = UIColor.background
        view.addSubview(originImageView)
        NSLayoutConstraint.activate([
            originImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
            originImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            originImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            originImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100)
        ])
    }
}
