//
//  Files.swift
//  Harbeth
//
//  Created by Condy on 2023/8/8.
//

import Foundation

public struct Files {
    
    public enum Extensions {
        case image
        case video
        case customization([String])
    }
    
    /// Loading URLs from the local filesystem.
    /// - Parameters:
    ///   - directoryURL: Catalogue URL
    ///   - fileExtensions: File extension to be found.
    ///   - filteringSubdirectories: Subdirectories that need to be filtered.
    /// - Returns: Images URLs.
    public static func loadedURLs(at directoryURL: URL,
                                  fileExtensions: Files.Extensions = .image,
                                  filteringSubdirectories: ((URL) -> Bool)? = nil) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(atPath: directoryURL.path) else {
            return []
        }
        return enumerator.compactMap({
            guard let relativePath = $0 as? String else {
                return nil
            }
            let url = directoryURL.appendingPathComponent(relativePath).absoluteURL
            if let attributes = enumerator.fileAttributes {
                let type = attributes[.type] as! FileAttributeType
                if type == .typeDirectory {
                    if let filter = filteringSubdirectories, !filter(url) {
                        enumerator.skipDescendants()
                    }
                } else if type == .typeRegular {
                    if fileExtensions.fileExtensions.contains(url.pathExtension.lowercased()) {
                        return url
                    }
                }
            }
            return nil
        })
    }
}

extension Files.Extensions {
    var fileExtensions: [String] {
        switch self {
        case .image:
            return ["jpg", "jpeg", "png", "tiff", "tif", "gif", "heic", "heif"]
        case .video:
            return ["mp4", "mov"]
        case .customization(let array):
            return array
        }
    }
}
