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
    
    lazy var video: C7CollectorVideo = {
        //let videoURL = URL.init(string: "https://mp4.vjshi.com/2017-06-03/076f1b8201773231ca2f65e38c34033c.mp4")!
        let videoURL = URL.init(string: "https://mp4.vjshi.com/2018-03-30/1f36dd9819eeef0bc508414494d34ad9.mp4")!
        let asset = AVURLAsset.init(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer.init(playerItem: playerItem)
        let video = C7CollectorVideo.init(player: player, delegate: self)
        video.filters = [self.tuple!.filter]
        return video
    }()
    
    // random time(actually NOT random)
    private let times: [Float] = (0...50).map { 0.1 + Float($0) * 0.03 }
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
            originImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            originImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            originImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            originImageView.heightAnchor.constraint(equalTo: originImageView.widthAnchor, multiplier: 1),
        ])
    }
    
    func setupPlayer() {
        self.video.play()
    }
}

extension PlayerViewController: C7CollectorImageDelegate {
    func preview(_ collector: C7Collector, fliter image: C7Image) {
        self.originImageView.image = image
        // Simulated dynamic effect.
        if let filter = self.tuple?.callback?(self.nextTime) {
            self.video.filters = [filter]
        }
    }
}
