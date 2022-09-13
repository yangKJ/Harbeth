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
        let camera = C7CollectorCamera.init(delegate: self)
        camera.captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
        camera.filters = [self.tuple!.filter]
        return camera
    }()
    
    deinit {
        print("CameraViewController is deinit.")
        Shared.shared.deinitDevice()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        camera.startRunning()
    }
    
    func setupUI() {
        view.backgroundColor = UIColor.background
        view.addSubview(originImageView)
        NSLayoutConstraint.activate([
            originImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 84),
            originImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            originImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            originImageView.heightAnchor.constraint(equalTo: originImageView.widthAnchor, multiplier: view.frame.size.height/view.frame.size.width),
        ])
    }
}

extension CameraViewController: C7CollectorImageDelegate {
    
    func preview(_ collector: C7Collector, fliter image: C7Image) {
        DispatchQueue.main.async {
            self.originImageView.image = image
        }
    }
}
