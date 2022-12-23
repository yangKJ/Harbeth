//
//  FileHelper.swift
//  Harbeth
//
//  Created by Condy on 2022/12/20.
//

import Foundation

public struct FileHelper {
    
    public static let cachesPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first
    public static let documentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
    
    public static func fileExists(at path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
    
    public static func removeFile(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
    
    public static func createDirectory(at path: String) throws {
        if fileExists(at: path) {
            return
        }
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        } catch {
            throw error
        }
    }
    
    /// Empty the specified directory, but do not delete it.
    /// - Parameter path: The path of the directory.
    public static func cleanDirectory(at path: String) {
        if let dirEnumerator = FileManager.default.enumerator(atPath: path) {
            for name in dirEnumerator where name is String {
                removeFile(at: path + (name as! String))
            }
        }
    }
}
