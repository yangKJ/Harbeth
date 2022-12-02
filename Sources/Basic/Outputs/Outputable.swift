//
//  Outputable.swift
//  Harbeth
//
//  Created by Condy on 2022/2/13.
//

import Foundation
import CoreImage

public protocol Outputable {
    
    /// Filter working
    /// - Parameter filter: It must be an object implementing C7FilterProtocol
    /// - Returns: Outputable
    mutating func filtering<T: Outputable>(_ filter: C7FilterProtocol?...) -> T
    
    /// Filter processing
    /// - Parameters:
    ///   - filter: It must be an object implementing C7FilterProtocol
    /// - Returns: Outputable
    mutating func make<T: Outputable>(filter: C7FilterProtocol) throws -> T
    
    /// Multiple filter combinations
    /// Please note that the order in which filters are added may affect the result of image generation.
    ///
    /// - Parameters:
    ///   - filters: Filter group, It must be an object implementing C7FilterProtocol
    /// - Returns: Outputable
    mutating func makeGroup<T: Outputable>(filters: [C7FilterProtocol]) throws -> T
}

extension Outputable {
    
    public func filtering<T>(_ filter: C7FilterProtocol?...) -> T where T : Outputable {
        let filters = filter.compactMap { $0 }
        if filters.isEmpty { return self as! T }
        let dest = BoxxIO.init(element: self, filters: filters)
        return ((try? dest.output()) ?? self) as! T
    }
    
    public func make<T>(filter: C7FilterProtocol) throws -> T where T : Outputable {
        let dest = BoxxIO.init(element: self, filters: [filter])
        do {
            return try dest.output() as! T
        } catch {
            throw error
        }
    }
    
    public func makeGroup<T>(filters: [C7FilterProtocol]) throws -> T where T : Outputable {
        let dest = BoxxIO.init(element: self, filters: filters)
        do {
            return try dest.output() as! T
        } catch {
            throw error
        }
    }
}

extension C7Image: Outputable { }
extension CGImage: Outputable { }
extension CIImage: Outputable { }
extension CVPixelBuffer: Outputable { }
extension CMSampleBuffer: Outputable { }
