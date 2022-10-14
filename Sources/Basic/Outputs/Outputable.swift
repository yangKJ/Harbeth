//
//  Outputable.swift
//  Harbeth
//
//  Created by Condy on 2022/2/13.
//

import Foundation

public protocol Outputable {
    
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
