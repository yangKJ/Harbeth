import Harbeth
import AVFoundation
import QuartzCore

class PlayerViewController: UIViewController {

    var tuple: FilterResult?

    private let renderQueue = DispatchQueue(label: "player.render.queue", qos: .userInitiated)
    private var currentFilter: C7FilterProtocol?
    private var timeObserver: Any?
    private var videoOutput: AVPlayerItemVideoOutput!
    private lazy var displayLink: CADisplayLink = {
        let link = CADisplayLink(target: self, selector: #selector(readBuffer(_:)))
        link.add(to: .current, forMode: .default)
        link.isPaused = true
        return link
    }()
    private var pendingFrame: TimedPixelBufferFrame?
    private var isRendering = false
    private var formatDescription: CMVideoFormatDescription?
    private let renderProfile: RenderProfile = .interactiveLatency
    private var pipelineGeneration: UInt64 = 0
    private var renderedFrames = 0
    private var droppedFrames = 0

    lazy var previewRenderView: RenderView = {
        let view = RenderView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .black
        view.resizingMode = .aspectFit
        return view
    }()

    lazy var controlView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        return view
    }()

    lazy var playPauseButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)
        return button
    }()

    lazy var progressSlider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumTrackTintColor = UIColor(hex: "#5C48FA")
        slider.maximumTrackTintColor = .white
        slider.thumbTintColor = UIColor(hex: "#5C48FA")
        slider.addTarget(self, action: #selector(progressSliderChanged), for: .valueChanged)
        return slider
    }()

    lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 12)
        label.text = "00:00 / 00:00"
        return label
    }()

    private lazy var pipelineLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor.white.withAlphaComponent(0.7)
        label.font = UIFont.systemFont(ofSize: 10)
        label.text = "render: 0 / drop: 0"
        return label
    }()

    private let player: AVPlayer = {
        let path = Bundle.main.path(forResource: "Skateboarding", ofType: "mp4")!
        let videoURL = URL(fileURLWithPath: path)
        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        return AVPlayer(playerItem: playerItem)
    }()

    deinit {
        print("PlayerViewController is Deinit.")
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        displayLink.invalidate()
        Shared.shared.deinitDevice()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupVideoOutput()
        setupPlayer()
        setupTimeObserver()
        syncCurrentFilter()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pause()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if player.rate <= 0 {
            player.play()
            displayLink.isPaused = false
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }

    private func setupUI() {
        title = ""
        view.backgroundColor = .black

        view.addSubview(previewRenderView)
        view.addSubview(controlView)
        view.addSubview(pipelineLabel)
        controlView.addSubview(playPauseButton)
        controlView.addSubview(progressSlider)
        controlView.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            previewRenderView.topAnchor.constraint(equalTo: view.topAnchor),
            previewRenderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewRenderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewRenderView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            pipelineLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            pipelineLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),

            controlView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            controlView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlView.heightAnchor.constraint(equalToConstant: 60),

            playPauseButton.leadingAnchor.constraint(equalTo: controlView.leadingAnchor, constant: 15),
            playPauseButton.centerYAnchor.constraint(equalTo: controlView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 40),
            playPauseButton.heightAnchor.constraint(equalToConstant: 40),

            progressSlider.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 15),
            progressSlider.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -15),
            progressSlider.centerYAnchor.constraint(equalTo: controlView.centerYAnchor),

            timeLabel.trailingAnchor.constraint(equalTo: controlView.trailingAnchor, constant: -15),
            timeLabel.centerYAnchor.constraint(equalTo: controlView.centerYAnchor),
            timeLabel.widthAnchor.constraint(equalToConstant: 80)
        ])
    }

    private func setupVideoOutput() {
        let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        videoOutput = output
    }

    private func setupPlayer() {
        if let currentItem = player.currentItem {
            currentItem.add(videoOutput)
        }
        player.play()
        displayLink.isPaused = false
    }

    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 60)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }

            let currentTime = CMTimeGetSeconds(time)
            let duration = CMTimeGetSeconds(self.player.currentItem?.duration ?? .zero)

            if duration > 0 {
                let progress = Float(currentTime / duration)
                self.progressSlider.value = progress

                let currentTimeString = self.formatTime(currentTime)
                let durationString = self.formatTime(duration)
                self.timeLabel.text = "\(currentTimeString) / \(durationString)"
            }
        }
    }

    private func syncCurrentFilter() {
        currentFilter = tuple?.filter
    }

    private func currentFilters(for time: CMTime) -> [C7FilterProtocol] {
        if let callback = tuple?.callback {
            currentFilter = callback(Float(CMTimeGetSeconds(time)))
        } else if currentFilter == nil {
            currentFilter = tuple?.filter
        }
        return [currentFilter].compactMap { $0 }
    }

    private func enqueueRender(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        renderQueue.async {
            let frame = TimedPixelBufferFrame(
                pixelBuffer: pixelBuffer,
                presentationTime: presentationTime,
                generation: self.pipelineGeneration
            )
            self.enqueueFrame(frame)
            self.drainIfNeeded()
        }
    }

    private func enqueueFrame(_ frame: TimedPixelBufferFrame) {
        if let pending = pendingFrame,
           CMTimeCompare(frame.presentationTime, pending.presentationTime) <= 0 {
            droppedFrames += 1
            return
        }
        pendingFrame = frame
    }

    private func drainIfNeeded() {
        guard isRendering == false, let frame = pendingFrame else {
            return
        }
        isRendering = true
        pendingFrame = nil
        render(frame)
    }

    private func render(_ frame: TimedPixelBufferFrame) {
        if frame.generation != pipelineGeneration {
            renderQueue.async {
                self.isRendering = false
                self.drainIfNeeded()
            }
            return
        }
        let filters = currentFilters(for: frame.presentationTime)
        let metadata = [
            "previewRoute": "RenderView",
            "source": "player"
        ]
        do {
            let sampleBuffer = makeSampleBuffer(from: frame.pixelBuffer, presentationTime: frame.presentationTime)
            let output: RenderedFrame
            if let sampleBuffer {
                output = try ImageNode
                    .sampleBuffer(sampleBuffer)
                    .applying(filters: filters)
                    .makeFrame(profile: renderProfile, metadata: metadata)
            } else {
                output = try HarbethIO(element: frame.pixelBuffer, filters: filters)
                    .makeFrame(profile: renderProfile, metadata: metadata)
            }
            renderedFrames += 1
            DispatchQueue.main.async {
                self.previewRenderView.display(output)
                self.pipelineLabel.text = "render: \(self.renderedFrames) / drop: \(self.droppedFrames)"
            }
        } catch {
            droppedFrames += 1
            // Keep the render loop alive even if a frame fails.
        }
        renderQueue.async {
            self.isRendering = false
            if self.pendingFrame != nil {
                self.drainIfNeeded()
            }
        }
    }

    private func makeSampleBuffer(from pixelBuffer: CVPixelBuffer, presentationTime: CMTime) -> CMSampleBuffer? {
        if formatDescription == nil {
            var newDesc: CMVideoFormatDescription?
            let status = CMVideoFormatDescriptionCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: pixelBuffer,
                formatDescriptionOut: &newDesc
            )
            guard status == noErr, let desc = newDesc else {
                return nil
            }
            formatDescription = desc
        }
        guard let description = formatDescription else {
            return nil
        }
        var timing = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: CMTime.invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: description,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr else {
            return nil
        }
        return sampleBuffer
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func pause() {
        player.pause()
        displayLink.isPaused = true
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
    }

    @objc func togglePlayPause() {
        if player.rate > 0 {
            pause()
        } else {
            player.play()
            displayLink.isPaused = false
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }

    @objc func progressSliderChanged() {
        guard let duration = player.currentItem?.duration else { return }
        let totalSeconds = CMTimeGetSeconds(duration)
        resetPipelineState()
        let seekTime = CMTime(seconds: Double(progressSlider.value) * totalSeconds, preferredTimescale: 60)
        player.seek(to: seekTime)
    }

    private func resetPipelineState() {
        renderQueue.async {
            self.pipelineGeneration &+= 1
            self.pendingFrame = nil
            self.isRendering = false
            DispatchQueue.main.async {
                self.pipelineLabel.text = "render: \(self.renderedFrames) / drop: \(self.droppedFrames)"
            }
        }
    }
}

private struct TimedPixelBufferFrame {
    let pixelBuffer: CVPixelBuffer
    let presentationTime: CMTime
    let generation: UInt64
}

extension PlayerViewController {
    @objc func readBuffer(_ sender: CADisplayLink) {
        guard let videoOutput else { return }
        let time = videoOutput.itemTime(forHostTime: sender.timestamp + sender.duration)
        guard videoOutput.hasNewPixelBuffer(forItemTime: time) else {
            return
        }
        if let pixelBuffer = videoOutput.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) {
            enqueueRender(pixelBuffer, presentationTime: time)
        }
    }
}
