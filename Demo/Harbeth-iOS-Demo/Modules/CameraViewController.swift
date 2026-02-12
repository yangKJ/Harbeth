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
        imageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        imageView.frame = self.view.frame
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
        view.backgroundColor = UIColor.systemBackground
        view.addSubview(originImageView)
    }
}

extension CameraViewController: C7CollectorImageDelegate {
    
    func preview(_ collector: C7Collector, fliter image: C7Image) {
        self.originImageView.image = image
    }
    
    func captureOutput(_ collector: C7Collector, pixelBuffer: CVPixelBuffer) {
        
    }
    
    func captureOutput(_ collector: C7Collector, texture: MTLTexture) {
        
    }
}
