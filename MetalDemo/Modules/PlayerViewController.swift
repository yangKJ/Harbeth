//
//  PlayerViewController.swift
//  MetalDemo
//
//  Created by Condy on 2022/2/28.
//

import Harbeth
import AVFoundation

class PlayerViewController: UIViewController {
    
    var tuple: FilterResult?
    lazy var originImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = UIColor.background2?.withAlphaComponent(0.3)
        return imageView
    }()
    
    var player: AVPlayer!
    
    lazy var video: C7CollectorVideo = {
        let video = C7CollectorVideo.init(player: player) { [unowned self] in
            self.originImageView.image = $0
            if let callback = self.tuple?.callback {
                self.video.filters = [callback(self.nextTime)]
            }
        }
        video.filters = [self.tuple!.filter]
        return video
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
        print("PlayerViewController is Deinit.")
        Shared.shared.deinitDevice()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPlayer()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        video.pause()
    }
    
    func setupUI() {
        view.backgroundColor = UIColor.background
        view.addSubview(originImageView)
        NSLayoutConstraint.activate([
            originImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
            originImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            originImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            originImageView.heightAnchor.constraint(equalTo: originImageView.widthAnchor, multiplier: 1),
        ])
    }
    
    func setupPlayer() {
        let videoURL = NSURL.init(string: "https://mp4.vjshi.com/2017-06-03/076f1b8201773231ca2f65e38c34033c.mp4")!
        //let videoURL = NSURL.init(string: "https://mp4.vjshi.com/2018-03-30/1f36dd9819eeef0bc508414494d34ad9.mp4")!
        let asset = AVURLAsset.init(url: videoURL as URL)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer.init(playerItem: playerItem)
        
        video.play()
    }
}
