//
//  ExporterError.swift
//  Harbeth
//
//  Created by Condy on 2023/2/20.
//

import Foundation
import AVFoundation

extension Exporter {
    /// Exporter error definition.
    public enum Error: Swift.Error {
        case unknown
        case error(Swift.Error)
        case videoTrackEmpty
        case addVideoTrack
        case exportSessionEmpty
        case exportAsynchronously(AVAssetExportSession.Status)
    }
}

extension Exporter.Error: CustomStringConvertible {
    
    /// For each error type return the appropriate description.
    public var description: String {
        localizedDescription
    }
    
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
            return "Export asynchronously other is \(status)."
        default:
            return "Unknown error occurred."
        }
    }
}
