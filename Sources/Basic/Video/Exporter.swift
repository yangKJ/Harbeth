//
//  Exporter.swift
//  Harbeth
//
//  Created by Condy on 2023/2/20.
//

import Foundation
import AVFoundation
import CoreVideo

public typealias ExporterBuffer = CVPixelBuffer

public protocol ExporterDelegate: NSObjectProtocol {
    
    /// Video export successed.
    /// - Parameters:
    ///   - exporter: VideoExporter
    ///   - videoURL: Export the successful video url, Be equivalent to outputURL.
    func export(_ exporter: Exporter, success videoURL: URL)
    
    /// Video export failure.
    /// - Parameters:
    ///   - exporter: VideoExporter
    ///   - error: Failure error message.
    func export(_ exporter: Exporter, failed error: Exporter.Error)
}

public struct Exporter {
    
    /// Exporter error definition.
    public enum Error {
        case unknown
        case error(Swift.Error)
        case videoTrackEmpty
        case addVideoTrack
        case exportSessionEmpty
        case exportAsynchronously(AVAssetExportSession.Status)
    }
    
    public typealias PixelBufferCallback = (_ buffer: ExporterBuffer) -> ExporterBuffer?
    
    let asset: AVAsset
    weak var delegate: ExporterDelegate?
    
    /// Unique identifier, distinguishing between different exporters.
    public var identifier: String = "\(Date().timeIntervalSince1970)"
    
    /// These export options can be used to produce movie files with video size appropriate to the device.
    public var presetName: String = AVAssetExportPresetHighestQuality {
        didSet {
            if !AVAssetExportSession.allExportPresets().contains(presetName) {
                presetName = AVAssetExportPresetMediumQuality
            }
        }
    }
    
    public init(videoURL: URL, delegate: ExporterDelegate) {
        self.init(asset: AVAsset(url: videoURL), delegate: delegate)
    }
    
    public init(asset: AVAsset, delegate: ExporterDelegate) {
        self.asset = asset
        self.delegate = delegate
    }
    
    /// Export the video after add the filter.
    /// - Parameters:
    ///   - outputURL: Specifies the sandbox address of the exported video.
    ///   - optimizeForNetworkUse: Indicates that the output file should be optimized for network use.
    ///   - filtering: Filters work to filter pixel buffer.
    public func export(outputURL: URL, optimizeForNetworkUse: Bool = true, filtering: @escaping PixelBufferCallback) {
        guard let track = self.asset.tracks(withMediaType: .video).first else {
            delegate?.export(self, failed: Exporter.Error.videoTrackEmpty)
            return
        }
        
        let composition = AVMutableComposition()
        composition.naturalSize = track.naturalSize
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            delegate?.export(self, failed: Exporter.Error.addVideoTrack)
            return
        }
        
        do {
            try videoTrack.insertTimeRange(CMTimeRangeMake(start: .zero, duration: self.asset.duration), of: track, at: .zero)
        } catch {
            delegate?.export(self, failed: Exporter.Error.error(error))
        }
        
        var audioTrack: AVMutableCompositionTrack? = nil
        if let audio = self.asset.tracks(withMediaType: .audio).first,
           let audioCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            audioTrack = audioCompositionTrack
            do {
                try audioTrack!.insertTimeRange(CMTimeRangeMake(start: .zero, duration: self.asset.duration), of: audio, at: .zero)
            } catch {
                delegate?.export(self, failed: Exporter.Error.error(error))
            }
        }
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.trackID = videoTrack.trackID
        
        let instruction = Exporter.CompositionInstruction(trackID: videoTrack.trackID, bufferCallback: filtering)
        instruction.timeRange = CMTimeRangeMake(start: .zero, duration: self.asset.duration)
        instruction.layerInstructions = [layerInstruction]
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.customVideoCompositorClass = Compositor.self
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        videoComposition.renderSize = videoTrack.naturalSize
        videoComposition.instructions = [instruction]
        
        guard let export = AVAssetExportSession(asset: composition, presetName: presetName) else {
            delegate?.export(self, failed: Exporter.Error.exportSessionEmpty)
            return
        }
        export.videoComposition = videoComposition
        export.outputURL = outputURL
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = optimizeForNetworkUse
        
        export.exportAsynchronously { [weak export] in
            guard let export = export else { return }
            DispatchQueue.main.async {
                switch export.status {
                case .failed:
                    if let error = export.error {
                        delegate?.export(self, failed: Exporter.Error.error(error))
                    } else {
                        delegate?.export(self, failed: Exporter.Error.unknown)
                    }
                case .completed:
                    delegate?.export(self, success: outputURL)
                default:
                    delegate?.export(self, failed: Exporter.Error.exportAsynchronously(export.status))
                    break
                }
            }
        }
    }
}

extension Exporter: Equatable {
    public static func == (lhs: Exporter, rhs: Exporter) -> Bool {
        lhs.identifier == rhs.identifier
    }
}

extension Exporter.Error {
    /// A textual representation of `self`, suitable for debugging.
    public var localizedDescription: String {
        switch self {
        case .error(let error):
            return error.localizedDescription
        case .videoTrackEmpty:
            return "Video track is nil."
        case .exportSessionEmpty:
            return "Video asset export session is nil."
        case .addVideoTrack:
            return "Add video mutable track is nil."
        case .exportAsynchronously(let status):
            return "export asynchronously other is \(status)."
        default:
            return "Unknown error occurred."
        }
    }
}
