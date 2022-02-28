//
//  PlayerViewConteroller.swift
//  MetalDemo
//
//  Created by Condy on 2022/2/28.
//

import Harbeth
import AVFoundation

class PlayerViewConteroller: UIViewController {
    
    var tuple: FilterResult?
    lazy var originImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.backgroundColor = UIColor.background2?.withAlphaComponent(0.3)
        return imageView
    }()
    
    var player: AVPlayer!
    
    lazy var video: C7FilterVideo = {
        let video = C7FilterVideo.init(player: player) {
            self.originImageView.image = $0
        }
        video.groupFilters = [self.tuple!.filter]
        return video
    }()
    
    deinit {
        print("🎨 is Deinit.")
        Shared.shared.deinitDevice()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPlayer()
    }
    
    func setupUI() {
        view.backgroundColor = UIColor.background
        view.addSubview(originImageView)
        NSLayoutConstraint.activate([
            originImageView.topAnchor.constraint(equalTo: view.topAnchor, constant: 100),
            originImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 15),
            originImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -15),
            originImageView.heightAnchor.constraint(equalTo: originImageView.widthAnchor, multiplier: 9/16),
        ])
    }
    
    func setupPlayer() {
        let videoURL = NSURL.init(string: "https://mp4.vjshi.com/2017-11-21/7c2b143eeb27d9f2bf98c4ab03360cfe.mp4")!
        let asset = AVURLAsset.init(url: videoURL as URL)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer.init(playerItem: playerItem)
        
        video.play()
    }
}
