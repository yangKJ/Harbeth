//
//  CameraViewController.swift
//  MetalDemo
//
//  Created by Condy on 2022/2/25.
//

import Harbeth
import AVFoundation
import QuartzCore
import Photos

class CameraViewController: UIViewController {

    var tuple: FilterResult?
    private var originalFilter: C7FilterProtocol?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let sampleBufferQueue = DispatchQueue(label: "camera.samplebuffer.queue", qos: .userInitiated)
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private lazy var previewPipeline = RealtimeFramePipeline()
    private lazy var videoOutputDelegate = CameraVideoOutputDelegate(pipeline: previewPipeline)
    private lazy var photoCaptureDelegate = CameraPhotoCaptureDelegate { [weak self] result in
        self?.handlePhotoCaptureResult(result)
    }
    private let cameraStateLock = NSLock()
    private var deviceInput: AVCaptureDeviceInput?
    private var selectedFilterButton: UIButton?
    private var lastTimestamp: TimeInterval = 0
    private var frameCount: Int = 0
    private var fps: Double = 0
    private var renderFailureCount: Int = 0
    private let renderFailureFallbackThreshold = 3
    private let renderFailureFallbackCooldown: TimeInterval = 2
    private var currentFlashMode: FlashMode = .off
    private var isCapturingPhoto = false

    private struct CameraRealtimeState {
        var renderFailureSequence = 0
        var currentVideoPixelFormatType: OSType = kCVPixelFormatType_32BGRA
        var didFallbackToBGRA = false
        var lastRenderFallbackAt: TimeInterval = 0
        var pendingVideoPixelFormatType: OSType?
    }

    private var cameraRealtimeState = CameraRealtimeState()

    lazy var previewRenderView: RenderView = {
        let view = RenderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black
        view.resizingMode = .aspectFit
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        return view
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

    lazy var performanceView: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 11)
        label.layer.cornerRadius = 2
        label.clipsToBounds = true
        label.textAlignment = .left
        label.numberOfLines = 7
        return label
    }()

    deinit {
        print("CameraViewController is deinit.")
        stopSession()
        HarbethContext.shared.recoverExecution()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupFilterOptions()
        originalFilter = tuple?.filter
        setActiveFilters([originalFilter].compactMap { $0 })
        previewPipeline.resetMetrics()
        previewPipeline.onFrameRendered = { [weak self] frame, metrics in
            guard let self else { return }
            self.previewRenderView.display(frame)
            self.markRenderSucceeded()
            self.updatePerformanceView(metrics: metrics, status: nil)
        }
        previewPipeline.onFrameDropped = { [weak self] reason, metrics in
            self?.updatePerformanceView(metrics: metrics, status: .dropped(reason))
        }
        previewPipeline.onRenderFailure = { [weak self] error, metrics, context in
            guard let self else { return }
            self.renderFailureCount += 1
            let didFallback = self.handleConsecutiveRenderFailuresIfNeeded()
            if didFallback {
                self.recordCameraFallbackEventIfNeeded(error: error, context: context)
            }
            self.updatePerformanceView(metrics: metrics, status: .renderFailure)
        }
        previewRenderView.onPreviewHostExecutionReportUpdated = { [weak self] _ in
            DispatchQueue.main.async {
                self?.updatePerformanceView(metrics: self?.previewPipeline.metrics() ?? .init(
                    renderedFrames: 0,
                    droppedFrames: 0,
                    averageRenderDuration: 0,
                    lastRenderDuration: 0,
                    lastFrameAgeMs: 0,
                    queueDepth: 0
                ), status: nil)
            }
        }
        previewRenderView.onPreviewHostFleetSnapshotUpdated = { [weak self] snapshot in
            DispatchQueue.main.async {
                self?.updatePerformanceViewWithHostSnapshot(snapshot)
            }
        }
        configureSessionAndStart()
    }

    private enum RealtimeStatusHint: CustomStringConvertible {
        case dropped(RealtimeFrameDropReason)
        case renderFailure

        var description: String {
            switch self {
            case .dropped(let reason):
                switch reason {
                case .staleOrDuplicatePTS:
                    return "dropped stale/dup"
                case .supersededWhileBusy:
                    return "dropped superseded"
                }
            case .renderFailure:
                return "render fail"
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        renderFailureCount = 0
        resetCameraRealtimeStateForPreview()
        previewPipeline.resetMetrics()
        startSessionIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopSession()
        previewRenderView.texture = nil
        resetCameraRealtimeStateForPreview()
        previewPipeline.resetMetrics()
    }

    private func setupUI() {
        title = ""
        view.backgroundColor = .black
        view.addSubview(previewRenderView)

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
            previewRenderView.topAnchor.constraint(equalTo: view.topAnchor),
            previewRenderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewRenderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewRenderView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

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
            performanceView.widthAnchor.constraint(equalToConstant: 140),
            performanceView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }

    private func configureSessionAndStart() {
        sessionQueue.async {
            self.captureSession.beginConfiguration()
            defer { self.captureSession.commitConfiguration() }

            if self.captureSession.canSetSessionPreset(.hd1280x720) {
                self.captureSession.sessionPreset = .hd1280x720
            }

            self.configureInputsIfNeeded(position: .back)
            self.configureOutputsIfNeeded()
            self.configureConnection(for: self.currentCameraPosition())
        }
    }

    private func configureInputsIfNeeded(position: AVCaptureDevice.Position) {
        guard let device = cameraDevice(position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            return
        }
        if let existingInput = deviceInput {
            captureSession.removeInput(existingInput)
        }
        captureSession.addInput(input)
        deviceInput = input
    }

    private func configureOutputsIfNeeded() {
        let pixelFormatType = preferredVideoPixelFormatType()
        withCameraRealtimeState {
            $0.currentVideoPixelFormatType = pixelFormatType
        }
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormatType
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(videoOutputDelegate, queue: sampleBufferQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
    }

    private func preferredVideoPixelFormatType() -> OSType {
        let activePixelFormatType = withCameraRealtimeState {
            $0.pendingVideoPixelFormatType ?? $0.currentVideoPixelFormatType
        }
        if activePixelFormatType != kCVPixelFormatType_32BGRA {
            let availableTypes = Set((videoOutput.value(forKey: "availableVideoCVPixelFormatTypes") as? [NSNumber])?.map { $0.uint32Value } ?? [])
            if availableTypes.isEmpty || availableTypes.contains(activePixelFormatType) {
                return activePixelFormatType
            }
            return kCVPixelFormatType_32BGRA
        }
        let supportedTypes = Set((videoOutput.value(forKey: "availableVideoCVPixelFormatTypes") as? [NSNumber])?.map { $0.uint32Value } ?? [])
        let preferredTypes: [OSType] = [
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelFormatType_32BGRA
        ]
        for type in preferredTypes {
            if supportedTypes.isEmpty || supportedTypes.contains(type) {
                return type
            }
        }
        return kCVPixelFormatType_32BGRA
    }

    private func handleConsecutiveRenderFailuresIfNeeded() -> Bool {
        let now = CACurrentMediaTime()
        let shouldFallback = withCameraRealtimeState { state in
            guard state.currentVideoPixelFormatType != kCVPixelFormatType_32BGRA else {
                return false
            }
            state.renderFailureSequence += 1
            guard state.renderFailureSequence >= renderFailureFallbackThreshold else {
                return false
            }
            guard now - state.lastRenderFallbackAt >= renderFailureFallbackCooldown else {
                return false
            }
            state.lastRenderFallbackAt = now
            state.didFallbackToBGRA = true
            state.renderFailureSequence = 0
            return true
        }
        guard shouldFallback else { return false }
        previewPipeline.discardPendingFrame()
        switchVideoOutput(to: kCVPixelFormatType_32BGRA)
        return true
    }

    private func switchVideoOutput(to pixelFormat: OSType) {
        sessionQueue.async {
            let shouldSkip = self.withCameraRealtimeState { state in
                guard state.currentVideoPixelFormatType != pixelFormat else {
                    state.pendingVideoPixelFormatType = nil
                    return true
                }
                state.pendingVideoPixelFormatType = pixelFormat
                return false
            }
            guard shouldSkip == false else {
                return
            }
            let wasRunning = self.captureSession.isRunning
            if wasRunning {
                self.captureSession.stopRunning()
            }
            self.captureSession.beginConfiguration()
            self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: pixelFormat]
            self.captureSession.commitConfiguration()
            self.withCameraRealtimeState {
                $0.pendingVideoPixelFormatType = nil
                $0.currentVideoPixelFormatType = pixelFormat
            }
            if wasRunning {
                self.captureSession.startRunning()
            }
        }
    }

    private func configureConnection(for position: AVCaptureDevice.Position) {
        guard let connection = videoOutput.connection(with: .video) else {
            return
        }
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = position == .front
        }
    }

    private func cameraDevice(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices.first(where: { $0.position == position })
    }

    private func currentCameraPosition() -> AVCaptureDevice.Position {
        deviceInput?.device.position ?? .back
    }

    private func stopSession() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }

    private func startSessionIfNeeded() {
        sessionQueue.async {
            if self.captureSession.isRunning == false {
                self.captureSession.startRunning()
            }
        }
    }

    private func setActiveFilters(_ filters: [C7FilterProtocol]) {
        previewPipeline.setFilters(filters)
    }

    private func activeFilters() -> [C7FilterProtocol] {
        previewPipeline.currentFilters()
    }

    private func filter(for index: Int) -> C7FilterProtocol? {
        switch index {
        case 0:
            return originalFilter
        case 1:
            return C7Sketch(edgeStrength: 0.5)
        case 2:
            return C7ColorMatrix4x4(matrix: Matrix4x4.Color.blackAndWhite)
        case 3:
            return C7ColorMatrix4x4(matrix: Matrix4x4.Color.retroStyle)
        case 4:
            return C7Exposure(exposure: 0.5)
        case 5:
            return MPSGaussianBlur(radius: 1.0)
        case 6:
            return C7Sharpen(sharpness: 1.0)
        case 7:
            return C7GaussianBlur(radius: 3.0)
        case 8:
            return C7ColorConvert(with: .invert)
        case 9:
            return C7Exposure(exposure: 1.0)
        case 10:
            return C7Contrast(contrast: 1.5)
        default:
            return nil
        }
    }

    private func filterTitles() -> [String] {
        [
            "原始", "素描", "黑白", "复古", "明亮",
            "柔和", "锐化", "模糊", "反色", "曝光", "对比度"
        ]
    }

    private func updatePerformanceView(metrics: RealtimeFramePipelineMetrics, status: RealtimeStatusHint?) {
        calculateFPS()
        let cameraState = cameraStateSnapshot()
        let fpsText = String(format: "%.1f FPS", fps)
        let renderText = String(format: "Render: %.2fms", metrics.averageRenderDuration * 1000)
        let queueText = "Q:\(metrics.queueDepth)"
        let dropText = "Dropped:\(metrics.droppedFrames)"
        let frameText = String(format: "Latest:%.2fms", metrics.lastRenderDuration * 1000)
        let ageText = String(format: "Age:%.0fms", metrics.lastFrameAgeMs)
        let hostText = "Host:\(previewRenderView.currentPreviewHostStrategy)"
        let cameraStateText = "Cam:\(pixelFormatDescription(cameraState.format)) Seq:\(cameraState.sequence) FB:\(cameraState.didFallback ? "Y" : "N")"
        var lines = [fpsText, renderText, "\(queueText) \(dropText) \(frameText)", "\(ageText) \(hostText)", cameraStateText]
        if let status {
            lines.append(status.description)
        }
        performanceView.text = lines.joined(separator: "\n")
    }

    private func pixelFormatDescription(_ pixelFormat: OSType) -> String {
        switch pixelFormat {
        case kCVPixelFormatType_32BGRA:
            return "32BGRA"
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            return "420YpCbCr8BiPlanarFullRange"
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            return "420YpCbCr8BiPlanarVideoRange"
        default:
            return String(format: "0x%08X", pixelFormat)
        }
    }

    private func recordCameraFallbackEventIfNeeded(error: Error, context: RealtimeFramePipelineFailureContext) {
        guard cameraStateSnapshot().didFallback else { return }
        HarbethLogger.log(
            .warning,
            category: "camera",
            code: "harbeth.camera.yuv_fallback",
            outcome: .fallback,
            metadata: [
                "sourcePixelFormat": pixelFormatDescription(context.sourcePixelFormat),
                "targetPixelFormat": "32BGRA",
                "reason": fallbackReasonToken(error.localizedDescription),
                "pts": String(format: "%.3f", context.sampleBufferPTSSeconds),
                "size": "\(context.sourceWidth)x\(context.sourceHeight)"
            ],
            correlationID: "camera.preview",
            message: "Camera realtime rendering fell back to BGRA."
        )
    }

    private func fallbackReasonToken(_ reason: String) -> String {
        let characters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return reason.unicodeScalars.map { characters.contains($0) ? Character($0) : "_" }.reduce(into: "") { $0.append($1) }
    }

    private func cameraStateSnapshot() -> (format: OSType, sequence: Int, didFallback: Bool) {
        withCameraRealtimeState {
            ($0.currentVideoPixelFormatType, $0.renderFailureSequence, $0.didFallbackToBGRA)
        }
    }

    private func markRenderSucceeded() {
        withCameraRealtimeState {
            $0.renderFailureSequence = 0
            $0.lastRenderFallbackAt = 0
        }
    }

    private func resetCameraRealtimeStateForPreview() {
        withCameraRealtimeState {
            $0.renderFailureSequence = 0
            $0.didFallbackToBGRA = false
            $0.lastRenderFallbackAt = 0
        }
    }

    @discardableResult
    private func withCameraRealtimeState<T>(_ body: (inout CameraRealtimeState) -> T) -> T {
        cameraStateLock.lock()
        defer { cameraStateLock.unlock() }
        return body(&cameraRealtimeState)
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

    private func updatePerformanceViewWithHostSnapshot(_ snapshot: PreviewHostFleetSnapshot) {
        guard let currentText = performanceView.text else { return }
        let hostText = "Host H:\(snapshot.activeHostCount) R:\(snapshot.totalRecoveryCount) F:\(snapshot.totalFallbackCount)"
        if currentText.contains("Host H:") {
            let compacted = currentText
                .split(separator: "\n")
                .filter { !$0.hasPrefix("Host H:") }
                .joined(separator: "\n")
            performanceView.text = compacted.isEmpty ? hostText : "\(compacted)\n\(hostText)"
        } else if currentText.isEmpty {
            performanceView.text = hostText
        } else {
            performanceView.text = "\(currentText)\n\(hostText)"
        }
    }

    @objc func captureAction() {
        capturePhoto()
    }

    private func capturePhoto() {
        guard isCapturingPhoto == false else {
            return
        }
        isCapturingPhoto = true
        let captureSession = captureSession
        let photoOutput = photoOutput
        let photoCaptureDelegate = photoCaptureDelegate
        let device = deviceInput?.device
        let flashMode = currentFlashMode
        let isHighResolutionCaptureEnabled = photoOutput.isHighResolutionCaptureEnabled
        let maxPhotoQualityPrioritization = photoOutput.maxPhotoQualityPrioritization

        UIView.animate(withDuration: 0.1, animations: {
            self.previewRenderView.alpha = 0.5
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.previewRenderView.alpha = 1.0
            }
        }

        sessionQueue.async {
            guard captureSession.isRunning else {
                DispatchQueue.main.async {
                    self.isCapturingPhoto = false
                    self.showAlert(title: "拍照失败", message: "相机会话未运行")
                }
                return
            }

            let photoSettings = AVCapturePhotoSettings()
            photoSettings.flashMode = Self.safeFlashMode(for: photoSettings, device: device, mode: flashMode)
            if isHighResolutionCaptureEnabled {
                photoSettings.isHighResolutionPhotoEnabled = true
            }
            photoSettings.photoQualityPrioritization = Self.safePhotoQualityPrioritization(maximum: maxPhotoQualityPrioritization)
            photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureDelegate)
        }
    }

    private func handlePhotoCaptureResult(_ result: CameraPhotoCaptureResult) {
        isCapturingPhoto = false
        switch result {
        case .failure(let message):
            showAlert(title: "拍照失败", message: message)
        case .success(let imageData):
            guard let image = UIImage(data: imageData) else {
                showAlert(title: "拍照失败", message: "无法解析照片数据")
                return
            }
            renderAndSavePhoto(image)
        }
    }

    private func renderAndSavePhoto(_ image: UIImage) {
        let filters = activeFilters()
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let frame = try ImageNode
                    .image(image)
                    .applying(filters: filters)
                    .makeFrame(profile: .exportQuality, metadata: [
                        "previewRoute": "RenderView",
                        "source": "camera.photo"
                    ])
                guard let outputImage = try frame.makeImage() else {
                    throw HarbethError.texture2Image
                }
                DispatchQueue.main.async {
                    UIImageWriteToSavedPhotosAlbum(outputImage, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(title: "拍照失败", message: error.localizedDescription)
                }
            }
        }
    }

    private static func safeFlashMode(for settings: AVCapturePhotoSettings, device: AVCaptureDevice?, mode: FlashMode) -> AVCaptureDevice.FlashMode {
        guard let device, device.hasFlash else {
            return .off
        }
        switch mode {
        case .off:
            return .off
        case .on:
            return settings.flashMode == .on ? .on : .off
        case .auto:
            return .auto
        case .torch:
            return .off
        }
    }

    private static func safePhotoQualityPrioritization(maximum: AVCapturePhotoOutput.QualityPrioritization) -> AVCapturePhotoOutput.QualityPrioritization {
        switch maximum {
        case .quality:
            return .quality
        case .balanced:
            return .balanced
        case .speed:
            return .speed
        @unknown default:
            return .balanced
        }
    }

    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error {
            showAlert(title: "保存失败", message: error.localizedDescription)
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
            let restartNeeded = self.captureSession.isRunning
            if restartNeeded {
                self.captureSession.stopRunning()
            }
            self.captureSession.beginConfiguration()
            defer {
                self.captureSession.commitConfiguration()
                if restartNeeded {
                    self.captureSession.startRunning()
                }
            }

            let targetPosition: AVCaptureDevice.Position = self.currentCameraPosition() == .back ? .front : .back
            self.configureInputsIfNeeded(position: targetPosition)
            self.configureConnection(for: targetPosition)
        }
    }

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
        let iconName: String
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
        guard let device = deviceInput?.device else {
            return
        }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            switch mode {
            case .off, .on, .auto:
                if device.isTorchModeSupported(.off) {
                    device.torchMode = .off
                }
            case .torch:
                if device.hasTorch, device.isTorchModeSupported(.on) {
                    try device.setTorchModeOn(level: 1.0)
                }
            }
        } catch {
            print("Error setting flash mode: \(error)")
        }
    }

    @objc func filterSelected(_ sender: UIButton) {
        updateFilterButtonSelection(selectedButton: sender)
        if let filter = filter(for: sender.tag) {
            setActiveFilters([filter])
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

    private func setupFilterOptions() {
        let titles = filterTitles()
        var previousButton: UIButton?
        var firstButton: UIButton?

        for (index, filterName) in titles.enumerated() {
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
                filterButton.widthAnchor.constraint(equalToConstant: 80)
            ])

            if index == 0 {
                filterButton.leadingAnchor.constraint(equalTo: filterScrollView.leadingAnchor, constant: 15).isActive = true
                firstButton = filterButton
            } else if let prevButton = previousButton {
                filterButton.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor, constant: 10).isActive = true
            }

            if index == titles.count - 1 {
                filterButton.trailingAnchor.constraint(equalTo: filterScrollView.trailingAnchor, constant: -15).isActive = true
            }

            previousButton = filterButton
        }

        if let firstButton {
            updateFilterButtonSelection(selectedButton: firstButton)
        }
    }
}

private final class CameraVideoOutputDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let pipeline: RealtimeFramePipeline

    init(pipeline: RealtimeFramePipeline) {
        self.pipeline = pipeline
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        pipeline.enqueue(sampleBuffer)
    }
}

private enum CameraPhotoCaptureResult {
    case success(Data)
    case failure(String)
}

private final class CameraPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let handler: (CameraPhotoCaptureResult) -> Void

    init(handler: @escaping (CameraPhotoCaptureResult) -> Void) {
        self.handler = handler
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let result: CameraPhotoCaptureResult
        if let error {
            result = .failure(error.localizedDescription)
        } else if let imageData = photo.fileDataRepresentation() {
            result = .success(imageData)
        } else {
            result = .failure("无法解析照片数据")
        }
        DispatchQueue.main.async { [handler] in
            handler(result)
        }
    }
}

enum RealtimeFrameDropReason {
    case staleOrDuplicatePTS
    case supersededWhileBusy
}

struct RealtimeFramePipelineMetrics {
    let renderedFrames: Int
    let droppedFrames: Int
    let averageRenderDuration: TimeInterval
    let lastRenderDuration: TimeInterval
    let lastFrameAgeMs: Double
    let queueDepth: Int
}

struct RealtimeFramePipelineFailureContext {
    let sampleBufferPTSSeconds: TimeInterval
    let sourcePixelFormat: OSType
    let sourceWidth: Int
    let sourceHeight: Int
    let renderRoute: String
}

final class RealtimeFramePipeline {
    typealias RenderedFrameHandler = (RenderedFrame, RealtimeFramePipelineMetrics) -> Void
    typealias DropHandler = (RealtimeFrameDropReason, RealtimeFramePipelineMetrics) -> Void
    typealias FailureHandler = (Error, RealtimeFramePipelineMetrics, RealtimeFramePipelineFailureContext) -> Void

    var onFrameRendered: RenderedFrameHandler?
    var onFrameDropped: DropHandler?
    var onRenderFailure: FailureHandler?

    private(set) var latestRenderRoute = "ImageNode+RenderView(sampleBuffer)"

    private struct TimedFrame {
        let sampleBuffer: CMSampleBuffer
        let enqueuedAt: TimeInterval
        let presentationTime: CMTime
    }

    private let queue = DispatchQueue(label: "harbeth.demo.camera.preview.pipeline", qos: .userInitiated)
    private var pendingFrame: TimedFrame?
    private var isRendering = false
    private var filters: [C7FilterProtocol] = []
    private var renderDurationSamples: [TimeInterval] = []
    private var averageRenderDuration: TimeInterval = 0
    private var renderedFrames = 0
    private var droppedFrames = 0
    private var lastRenderedPTS: CMTime?
    private var lastFailureContext: RealtimeFramePipelineFailureContext?
    private let renderDurationWindow = 45

    func setFilters(_ filters: [C7FilterProtocol]) {
        queue.sync {
            self.filters = filters
        }
    }

    func currentFilters() -> [C7FilterProtocol] {
        queue.sync { filters }
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        queue.async { [weak self] in
            self?.enqueueOnPipeline(sampleBuffer)
        }
    }

    func resetMetrics() {
        queue.async { [weak self] in
            guard let self else { return }
            self.renderDurationSamples.removeAll(keepingCapacity: true)
            self.averageRenderDuration = 0
            self.renderedFrames = 0
            self.droppedFrames = 0
            self.pendingFrame = nil
            self.lastRenderedPTS = nil
            self.lastFailureContext = nil
            self.isRendering = false
        }
    }

    func discardPendingFrame() {
        queue.async { [weak self] in
            self?.pendingFrame = nil
        }
    }

    func metrics() -> RealtimeFramePipelineMetrics {
        return queue.sync {
            let frameAgeMs = pendingFrame.map { max(0, (CACurrentMediaTime() - $0.enqueuedAt) * 1000) } ?? 0
            return RealtimeFramePipelineMetrics(
                renderedFrames: renderedFrames,
                droppedFrames: droppedFrames,
                averageRenderDuration: averageRenderDuration,
                lastRenderDuration: renderDurationSamples.last ?? 0,
                lastFrameAgeMs: frameAgeMs,
                queueDepth: pendingFrame == nil ? 0 : 1
            )
        }
    }

    private func enqueueOnPipeline(_ sampleBuffer: CMSampleBuffer) {
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if let lastRenderedPTS,
           presentationTime.isValid,
           lastRenderedPTS.isValid,
           CMTimeCompare(presentationTime, lastRenderedPTS) <= 0 {
            droppedFrames += 1
            notifyDropped(pendingFrame: nil, reason: .staleOrDuplicatePTS)
            return
        }

        if pendingFrame != nil {
            droppedFrames += 1
            notifyDropped(reason: .supersededWhileBusy)
        }

        pendingFrame = TimedFrame(
            sampleBuffer: sampleBuffer,
            enqueuedAt: CACurrentMediaTime(),
            presentationTime: presentationTime
        )
        if isRendering == false {
            drainIfNeeded()
        }
    }

    private func drainIfNeeded() {
        guard isRendering == false, let frame = pendingFrame else {
            return
        }
        isRendering = true
        pendingFrame = nil
        render(frame)
    }

    private func render(_ frame: TimedFrame) {
        let activeFilters = filters
        let renderStart = CACurrentMediaTime()
        let frameAgeMs = max(0, (CACurrentMediaTime() - frame.enqueuedAt) * 1000)
        do {
            let output = try ImageNode
                .sampleBuffer(frame.sampleBuffer)
                .applying(filters: activeFilters)
                .makeFrame(profile: .interactiveLatency, metadata: [
                    "previewRoute": latestRenderRoute,
                    "source": "camera.preview"
                ])
            let renderDuration = CACurrentMediaTime() - renderStart
            renderedFrames += 1
            updateRenderDuration(renderDuration)
            if frame.presentationTime.isValid {
                lastRenderedPTS = frame.presentationTime
            }
            lastFailureContext = nil
            let metrics = RealtimeFramePipelineMetrics(
                renderedFrames: renderedFrames,
                droppedFrames: droppedFrames,
                averageRenderDuration: averageRenderDuration,
                lastRenderDuration: renderDuration,
                lastFrameAgeMs: frameAgeMs,
                queueDepth: pendingFrame == nil ? 0 : 1
            )
            DispatchQueue.main.async { [weak self] in
                self?.onFrameRendered?(output, metrics)
            }
        } catch {
            let renderDuration = CACurrentMediaTime() - renderStart
            let metrics = RealtimeFramePipelineMetrics(
                renderedFrames: renderedFrames,
                droppedFrames: droppedFrames,
                averageRenderDuration: averageRenderDuration,
                lastRenderDuration: renderDuration,
                lastFrameAgeMs: frameAgeMs,
                queueDepth: pendingFrame == nil ? 0 : 1
            )
            let failureContext = makeFailureContext(for: frame)
            lastFailureContext = failureContext
            DispatchQueue.main.async { [weak self] in
                self?.onRenderFailure?(error, metrics, failureContext)
            }
        }

        queue.async { [weak self] in
            guard let self else { return }
            self.isRendering = false
            if let next = self.pendingFrame {
                if next.presentationTime.isValid,
                   self.lastRenderedPTS?.isValid == true,
                   CMTimeCompare(next.presentationTime, self.lastRenderedPTS!) <= 0 {
                    self.pendingFrame = nil
                    self.droppedFrames += 1
                    self.notifyDropped(reason: .staleOrDuplicatePTS)
                    return
                }
                self.drainIfNeeded()
            }
        }
    }

    private func notifyDropped(pendingFrame: TimedFrame? = nil, reason: RealtimeFrameDropReason) {
        let metrics = RealtimeFramePipelineMetrics(
            renderedFrames: renderedFrames,
            droppedFrames: droppedFrames,
            averageRenderDuration: averageRenderDuration,
            lastRenderDuration: renderDurationSamples.last ?? 0,
            lastFrameAgeMs: pendingFrame.map { max(0, (CACurrentMediaTime() - $0.enqueuedAt) * 1000) } ?? 0,
            queueDepth: pendingFrame == nil ? 0 : 1
        )
        DispatchQueue.main.async { [weak self] in
            self?.onFrameDropped?(reason, metrics)
        }
    }

    private func updateRenderDuration(_ duration: TimeInterval) {
        renderDurationSamples.append(duration)
        if renderDurationSamples.count > renderDurationWindow {
            renderDurationSamples.removeFirst(renderDurationSamples.count - renderDurationWindow)
        }
        let total = renderDurationSamples.reduce(0) { $0 + $1 }
        averageRenderDuration = renderDurationSamples.isEmpty ? 0 : total / Double(renderDurationSamples.count)
    }

    private func makeFailureContext(for frame: TimedFrame) -> RealtimeFramePipelineFailureContext {
        let imageBuffer = CMSampleBufferGetImageBuffer(frame.sampleBuffer)
        let sourcePixelFormat = imageBuffer.map { CVPixelBufferGetPixelFormatType($0) } ?? 0
        let sourceWidth = imageBuffer.map { CVPixelBufferGetWidth($0) } ?? 0
        let sourceHeight = imageBuffer.map { CVPixelBufferGetHeight($0) } ?? 0
        return RealtimeFramePipelineFailureContext(
            sampleBufferPTSSeconds: CMTimeGetSeconds(frame.presentationTime),
            sourcePixelFormat: sourcePixelFormat,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight,
            renderRoute: latestRenderRoute
        )
    }
}
