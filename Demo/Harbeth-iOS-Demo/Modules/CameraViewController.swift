//
//  CameraViewController.swift
//  MetalDemo
//
//  Created by Condy on 2022/2/25.
//

import Harbeth
import AVFoundation
import QuartzCore

class CameraViewController: UIViewController {
    
    var tuple: FilterResult?
    private var originalFilter: C7FilterProtocol?
    
    lazy var originImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = .black
        return imageView
    }()
    
    lazy var camera: C7CollectorCamera = {
        let camera = C7CollectorCamera.init(delegate: self)
        camera.captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
        camera.filters = [self.tuple!.filter]
        return camera
    }()
    
    lazy var photoOutput: AVCapturePhotoOutput = {
        let output = AVCapturePhotoOutput()
        if camera.captureSession.canAddOutput(output) {
            camera.captureSession.addOutput(output)
        }
        return output
    }()
    
    lazy var captureButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.layer.cornerRadius = 40
        button.layer.borderWidth = 4
        button.layer.borderColor = UIColor.systemGray2.cgColor
        button.addTarget(self, action: #selector(captureAction), for: .touchUpInside)
        return button
    }()
    
    lazy var flipButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 25
        button.addTarget(self, action: #selector(flipCameraAction), for: .touchUpInside)
        return button
    }()
    
    enum FlashMode {
        case off
        case on
        case auto
        case torch
    }
    
    private var currentFlashMode: FlashMode = .off
    
    lazy var flashButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 25
        button.addTarget(self, action: #selector(flashAction), for: .touchUpInside)
        return button
    }()
    
    lazy var filterScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        scrollView.showsHorizontalScrollIndicator = false
        return scrollView
    }()
    
    private var selectedFilterButton: UIButton? = nil
    
    lazy var performanceView: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 11)
        label.layer.cornerRadius = 2
        label.clipsToBounds = true
        label.textAlignment = .left
        label.numberOfLines = 4
        return label
    }()
    
    private var lastTimestamp: TimeInterval = 0
    private var frameCount: Int = 0
    private var fps: Double = 0
    
    deinit {
        print("CameraViewController is deinit.")
        Shared.shared.deinitDevice()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupFilterOptions()
        if let filter = tuple?.filter {
            originalFilter = filter
        }
        camera.startRunning()
    }
    
    func setupUI() {
        view.backgroundColor = .black
        view.addSubview(originImageView)
        let controlContainer = UIView()
        controlContainer.translatesAutoresizingMaskIntoConstraints = false
        controlContainer.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.addSubview(controlContainer)
        controlContainer.addSubview(captureButton)
        controlContainer.addSubview(flipButton)
        controlContainer.addSubview(flashButton)
        view.addSubview(filterScrollView)
        view.addSubview(performanceView)
        
        NSLayoutConstraint.activate([
            originImageView.topAnchor.constraint(equalTo: view.topAnchor),
            originImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            originImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            originImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            controlContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            controlContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlContainer.heightAnchor.constraint(equalToConstant: 100),
            
            captureButton.centerXAnchor.constraint(equalTo: controlContainer.centerXAnchor),
            captureButton.centerYAnchor.constraint(equalTo: controlContainer.centerYAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 80),
            captureButton.heightAnchor.constraint(equalToConstant: 80),
            
            flipButton.trailingAnchor.constraint(equalTo: controlContainer.trailingAnchor, constant: -30),
            flipButton.centerYAnchor.constraint(equalTo: controlContainer.centerYAnchor),
            flipButton.widthAnchor.constraint(equalToConstant: 50),
            flipButton.heightAnchor.constraint(equalToConstant: 50),
            
            flashButton.leadingAnchor.constraint(equalTo: controlContainer.leadingAnchor, constant: 30),
            flashButton.centerYAnchor.constraint(equalTo: controlContainer.centerYAnchor),
            flashButton.widthAnchor.constraint(equalToConstant: 50),
            flashButton.heightAnchor.constraint(equalToConstant: 50),
            
            filterScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterScrollView.bottomAnchor.constraint(equalTo: controlContainer.topAnchor),
            filterScrollView.heightAnchor.constraint(equalToConstant: 80),
            
            performanceView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 5),
            performanceView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            performanceView.widthAnchor.constraint(equalToConstant: 80),
            performanceView.heightAnchor.constraint(equalToConstant: 40),
        ])
    }
    
    func setupFilterOptions() {
        let filters = ["原始", "素描", "黑白", "复古", "明亮", "柔和", "锐化", "模糊", "反色", "曝光", "对比度"]
        
        var previousButton: UIButton? = nil
        var firstButton: UIButton? = nil
        
        for (index, filterName) in filters.enumerated() {
            let filterButton = UIButton(type: .custom)
            filterButton.translatesAutoresizingMaskIntoConstraints = false
            filterButton.setTitle(filterName, for: .normal)
            filterButton.setTitleColor(.white, for: .normal)
            filterButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            filterButton.layer.cornerRadius = 2
            filterButton.tag = index
            filterButton.addTarget(self, action: #selector(filterSelected(_:)), for: .touchUpInside)
            
            filterScrollView.addSubview(filterButton)
            NSLayoutConstraint.activate([
                filterButton.topAnchor.constraint(equalTo: filterScrollView.topAnchor, constant: 15),
                filterButton.bottomAnchor.constraint(equalTo: filterScrollView.bottomAnchor, constant: -15),
                filterButton.widthAnchor.constraint(equalToConstant: 80),
            ])
            
            if index == 0 {
                filterButton.leadingAnchor.constraint(equalTo: filterScrollView.leadingAnchor, constant: 15).isActive = true
                firstButton = filterButton
            } else if let prevButton = previousButton {
                filterButton.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor, constant: 10).isActive = true
            }
            
            if index == filters.count - 1 {
                filterButton.trailingAnchor.constraint(equalTo: filterScrollView.trailingAnchor, constant: -15).isActive = true
            }
            
            previousButton = filterButton
        }
        
        if let firstButton = firstButton {
            updateFilterButtonSelection(selectedButton: firstButton)
        }
    }
    
    @objc func captureAction() {
        capturePhoto()
    }
    
    private func capturePhoto() {
        UIView.animate(withDuration: 0.1, animations: {
            self.originImageView.alpha = 0.5
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.originImageView.alpha = 1.0
            }
        }
        let photoSettings = AVCapturePhotoSettings()
        switch currentFlashMode {
        case .off:
            photoSettings.flashMode = .off
        case .on:
            photoSettings.flashMode = .on
        case .auto:
            photoSettings.flashMode = .auto
        case .torch:
            photoSettings.flashMode = .off
        }
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let _ = error {
            showAlert(title: "保存失败", message: "图片保存失败，请重试")
        } else {
            showAlert(title: "保存成功", message: "图片已保存到相册")
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    @objc func flipCameraAction() {
        sessionQueue.async {
            self.camera.stopRunning()
            let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
            let cameras = discoverySession.devices
            var targetPosition: AVCaptureDevice.Position = .back
            if let currentInput = self.camera.deviceInput,
               currentInput.device.position == .back {
                targetPosition = .front
            }
            if let targetCamera = cameras.first(where: { $0.position == targetPosition }) {
                do {
                    let newInput = try AVCaptureDeviceInput(device: targetCamera)
                    self.camera.deviceInput = newInput
                    if let connection = self.camera.videoOutput.connection(with: .video), connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                        if targetCamera.position == .front {
                            connection.automaticallyAdjustsVideoMirroring = false
                            connection.isVideoMirrored = true
                        } else {
                            connection.automaticallyAdjustsVideoMirroring = false
                            connection.isVideoMirrored = false
                        }
                    }
                    self.camera.startRunning()
                } catch {
                    print("Error switching camera: \(error)")
                }
            }
        }
    }
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    
    @objc func flashAction() {
        sessionQueue.async {
            self.toggleFlashMode()
        }
    }
    
    private func toggleFlashMode() {
        switch currentFlashMode {
        case .off:
            currentFlashMode = .on
            updateFlashButtonIcon()
            setFlashMode(.on)
        case .on:
            currentFlashMode = .auto
            updateFlashButtonIcon()
            setFlashMode(.auto)
        case .auto:
            currentFlashMode = .torch
            updateFlashButtonIcon()
            setFlashMode(.torch)
        case .torch:
            currentFlashMode = .off
            updateFlashButtonIcon()
            setFlashMode(.off)
        }
    }
    
    private func updateFlashButtonIcon() {
        var iconName: String
        switch currentFlashMode {
        case .off:
            iconName = "bolt.slash.fill"
        case .on:
            iconName = "bolt.fill"
        case .auto:
            iconName = "bolt.badge.a.fill"
        case .torch:
            iconName = "bolt.circle.fill"
        }
        DispatchQueue.main.async {
            self.flashButton.setImage(UIImage(systemName: iconName), for: .normal)
        }
    }
    
    private func setFlashMode(_ mode: FlashMode) {
        guard let device = camera.deviceInput?.device else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            switch mode {
            case .off:
                if device.isTorchModeSupported(.off) {
                    device.torchMode = .off
                }
            case .on:
                if device.isTorchModeSupported(.off) {
                    device.torchMode = .off
                }
            case .auto:
                if device.isTorchModeSupported(.off) {
                    device.torchMode = .off
                }
            case .torch:
                if device.hasTorch && device.isTorchModeSupported(.on) {
                    try device.setTorchModeOn(level: 1.0)
                }
            }
        } catch {
            print("Error setting flash mode: \(error)")
        }
    }
    
    @objc func filterSelected(_ sender: UIButton) {
        updateFilterButtonSelection(selectedButton: sender)
        switch sender.tag {
        case 0:
            if let originalFilter = originalFilter {
                camera.filters = [originalFilter]
            }
        case 1:
            let filter = C7Sketch(edgeStrength: 0.5)
            camera.filters = [filter]
        case 2:
            let filter = C7ColorMatrix4x4(matrix: Matrix4x4.Color.blackAndWhite)
            camera.filters = [filter]
        case 3:
            let filter = C7ColorMatrix4x4(matrix: Matrix4x4.Color.retroStyle)
            camera.filters = [filter]
        case 4:
            let filter = C7Exposure(exposure: 0.5)
            camera.filters = [filter]
        case 5:
            let filter = MPSGaussianBlur(radius: 1.0)
            camera.filters = [filter]
        case 6:
            let filter = C7Sharpen(sharpness: 1.0)
            camera.filters = [filter]
        case 7:
            let filter = C7GaussianBlur(radius: 3.0)
            camera.filters = [filter]
        case 8:
            let filter = C7ColorConvert(with: .invert)
            camera.filters = [filter]
        case 9:
            let filter = C7Exposure(exposure: 1.0)
            camera.filters = [filter]
        case 10:
            let filter = C7Contrast(contrast: 1.5)
            camera.filters = [filter]
        default:
            break
        }
    }
    
    private func updateFilterButtonSelection(selectedButton: UIButton) {
        if let previousButton = selectedFilterButton {
            previousButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            previousButton.setTitleColor(.white, for: .normal)
        }
        selectedButton.backgroundColor = UIColor(hex: "#5C48FA")
        selectedButton.setTitleColor(.white, for: .normal)
        selectedFilterButton = selectedButton
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            showAlert(title: "拍照失败", message: "拍照失败，请重试")
            return
        }
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            showAlert(title: "拍照失败", message: "无法处理拍摄的照片")
            return
        }
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
}

extension CameraViewController: C7CollectorImageDelegate {
    
    func preview(_ collector: C7Collector, fliter image: C7Image) {
        PerformanceMonitor.shared.beginMonitoring("camera_preview")
        self.originImageView.image = image
        calculateFPS()
        PerformanceMonitor.shared.endMonitoring("camera_preview")
        updatePerformanceView()
    }
    
    func captureOutput(_ collector: C7Collector, pixelBuffer: CVPixelBuffer) {
        
    }
    
    func captureOutput(_ collector: C7Collector, texture: MTLTexture) {
        
    }
    
    private func calculateFPS() {
        let currentTimestamp = CACurrentMediaTime()
        frameCount += 1
        if currentTimestamp - lastTimestamp >= 1.0 {
            fps = Double(frameCount) / (currentTimestamp - lastTimestamp)
            frameCount = 0
            lastTimestamp = currentTimestamp
        }
    }
    
    private func updatePerformanceView() {
        let fpsText = String(format: "%.1f FPS", fps)
        let summary = PerformanceMonitor.shared.getSummary()
        let avgTime = String(format: "%.2fms", summary.averageProcessingTime * 1000)
        performanceView.text = "\(fpsText)\nCPU: \(avgTime)"
    }
}
