import Harbeth
import AVFoundation
import QuartzCore

class PlayerViewController: UIViewController {
    
    var tuple: FilterResult?
    
    lazy var originImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = .black
        return imageView
    }()
    
    lazy var video: C7CollectorVideo = {
        let path = Bundle.main.path(forResource: "Skateboarding", ofType: "mp4")!
        let videoURL = NSURL.init(fileURLWithPath: path) as URL
        let asset = AVURLAsset.init(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer.init(playerItem: playerItem)
        let video = C7CollectorVideo.init(player: player, delegate: self)
        video.filters = [self.tuple!.filter]
        return video
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
    
    private let times: [Float] = (0...50).map { 0.1 + Float($0) * 0.03 }
    private var current = 0
    var nextTime: Float {
        let time = times[current]
        current = (current + 1) % times.count
        return time
    }
    
    private var timeObserver: Any?
    
    deinit {
        print("PlayerViewController is Deinit.")
        if let observer = timeObserver {
            video.player.removeTimeObserver(observer)
        }
        Shared.shared.deinitDevice()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPlayer()
        setupTimeObserver()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        video.pause()
    }
    
    func setupUI() {
        view.backgroundColor = .black
        
        view.addSubview(originImageView)
        view.addSubview(controlView)
        controlView.addSubview(playPauseButton)
        controlView.addSubview(progressSlider)
        controlView.addSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            originImageView.topAnchor.constraint(equalTo: view.topAnchor),
            originImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            originImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            originImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
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
            timeLabel.widthAnchor.constraint(equalToConstant: 80),
        ])
    }
    
    func setupPlayer() {
        video.play()
    }
    
    func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 60)
        timeObserver = video.player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            let currentTime = CMTimeGetSeconds(time)
            let duration = CMTimeGetSeconds(self.video.player.currentItem?.duration ?? CMTime.zero)
            
            if duration > 0 {
                let progress = Float(currentTime / duration)
                self.progressSlider.value = progress
                
                let currentTimeString = self.formatTime(currentTime)
                let durationString = self.formatTime(duration)
                self.timeLabel.text = "\(currentTimeString) / \(durationString)"
            }
        }
    }
    
    func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    @objc func togglePlayPause() {
        if video.player.rate > 0 {
            video.pause()
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        } else {
            video.play()
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        }
    }
    
    @objc func progressSliderChanged() {
        guard let duration = video.player.currentItem?.duration else { return }
        let totalSeconds = CMTimeGetSeconds(duration)
        let seekTime = CMTime(seconds: Double(progressSlider.value) * totalSeconds, preferredTimescale: 60)
        video.player.seek(to: seekTime)
    }
}

extension PlayerViewController: C7CollectorImageDelegate {
    func preview(_ collector: C7Collector, fliter image: C7Image) {
        self.originImageView.image = image
        if let filter = self.tuple?.callback?(self.nextTime) {
            self.video.filters = [filter]
        }
    }
    
    func captureOutput(_ collector: C7Collector, pixelBuffer: CVPixelBuffer) {
    }
    
    func captureOutput(_ collector: C7Collector, texture: MTLTexture) {
    }
}
