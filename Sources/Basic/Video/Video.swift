//
//  Video.swift
//  Harbeth
//
//  Created by Condy on 2023/2/20.
//

import Foundation
import AVFoundation

/// 该功能我也单独封装成库使用，``Kakapos``是一个视频添加过滤器工具，支持网络和本地网址以及专辑视频。
/// 支持所有能转换`Buffer`的滤镜库，例如`GPUImage、Harbeth、CoreImage`等。
/// See: https://github.com/yangKJ/Kakapos

/// Video addition filter tool, support for network and local URLs and album videos.
public class Video: NSObject {
    
    public typealias VideoCompleted = (_ videoURL: URL) -> Void
    public typealias VideoFailed = (_ error: Exporter.Error) -> Void
    
    private let asset: AVAsset
    private let completed: VideoCompleted
    private let failed: VideoFailed
    private lazy var exporter: Exporter = {
        let exporter = Exporter(asset: asset, delegate: self)
        return exporter
    }()
    
    public convenience init(videoURL: URL, outputURL: URL? = nil, filters: [C7FilterProtocol], completed: @escaping VideoCompleted, failed: @escaping VideoFailed) {
        self.init(asset: AVAsset(url: videoURL), outputURL: outputURL, filters: filters, completed: completed, failed: failed)
    }
    
    public init(asset: AVAsset, outputURL: URL? = nil, filters: [C7FilterProtocol], completed: @escaping VideoCompleted, failed: @escaping VideoFailed) {
        self.asset = asset
        self.completed = completed
        self.failed = failed
        super.init()
        self.export(filters: filters, outputURL: outputURL)
    }
}

extension Video {
    private func export(filters: [C7FilterProtocol], outputURL: URL?) {
        let outputURL: URL = outputURL ?? {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let outputURL = documents.appendingPathComponent("condy_exporter_video.mp4")
            
            // Check if the file already exists then remove the previous file
            if FileManager.default.fileExists(atPath: outputURL.path) {
                do {
                    try FileManager.default.removeItem(at: outputURL)
                } catch {
                    //completionHandler(nil, error)
                }
            }
            return outputURL
        }()
        exporter.export(outputURL: outputURL) {
            let dest = BoxxIO(element: $0, filters: filters)
            return try? dest.output()
        }
    }
}

extension Video: ExporterDelegate {
    public func export(_ exporter: Exporter, success videoURL: URL) {
        completed(videoURL)
    }
    
    public func export(_ exporter: Exporter, failed error: Exporter.Error) {
        failed(error)
    }
}
