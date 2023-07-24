//
//  VideoIO.swift
//  Harbeth
//
//  Created by Condy on 2023/2/20.
//

import Foundation
import AVFoundation

/// 该功能我也单独封装成库使用，``Kakapos``是一个视频添加过滤器工具，支持网络和本地网址以及专辑视频。
/// 支持所有能转换`Buffer`的滤镜库，例如`GPUImage、Harbeth、CoreImage`等。
/// See: https://github.com/yangKJ/Kakapos

/// VideoIO addition filter tool, support for network and local URLs and album videos.
public final class VideoIO: NSObject {
    
    public typealias VideoCompleted = (Result<URL, Exporter.Error>) -> Void
    
    private let asset: AVAsset
    private let filters: [C7FilterProtocol]
    private let completed: (Result<URL, Exporter.Error>) -> Void
    
    public private(set) lazy var exporter: Exporter = {
        let exporter = Exporter(asset: asset, delegate: self)
        return exporter
    }()
    
    public convenience init(videoURL: URL, filters: [C7FilterProtocol], completed: @escaping VideoCompleted) {
        let asset = AVAsset(url: videoURL)
        self.init(asset: asset, filters: filters, completed: completed)
    }
    
    public init(asset: AVAsset, filters: [C7FilterProtocol], completed: @escaping VideoCompleted) {
        self.asset = asset
        self.completed = completed
        self.filters = filters
        super.init()
    }
    
    /// Start export the video after add the filter.
    /// - Parameter optimizeForNetworkUse: Indicates that the output file should be optimized for network use.
    public func start(optimizeForNetworkUse: Bool = true) {
        let outputURL: URL = {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let random = Int(arc4random_uniform(89999) + 10000)
            let outputURL = documents.appendingPathComponent("condy_export_video_\(random).mp4")
            // Check if the file already exists then remove the previous file
            if FileManager.default.fileExists(atPath: outputURL.path) {
                do {
                    try FileManager.default.removeItem(at: outputURL)
                } catch {
                    self.completed(.failure(.error(error)))
                }
            }
            return outputURL
        }()
        exporter.export(outputURL: outputURL, optimizeForNetworkUse: optimizeForNetworkUse) { [weak self] in
            guard let `self` = self else {
                return $0
            }
            let dest = BoxxIO(element: $0, filters: self.filters)
            return (try? dest.output()) ?? $0
        }
    }
    
    public func cancel() {
        
    }
}

extension VideoIO: ExporterDelegate {
    
    public func export(_ exporter: Exporter, success videoURL: URL) {
        self.completed(.success(videoURL))
    }
    
    public func export(_ exporter: Exporter, failed error: Exporter.Error) {
        self.completed(.failure(error))
    }
}
