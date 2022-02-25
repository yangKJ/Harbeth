//
//  C7FilterDestProtocol.swift
//  Harbeth
//
//  Created by Condy on 2022/2/13.
//

import Foundation

public protocol C7FilterDestProtocol {
    
    /// Filter processing
    /// - Parameters:
    ///   - filter: It must be an object implementing C7FilterProtocol
    /// - Returns: C7FilterSerializer
    mutating func make<T: C7FilterDestProtocol>(filter: C7FilterProtocol) throws -> T
    
    /// Multiple filter combinations
    /// Please note that the order in which filters are added may affect the result of image generation.
    ///
    /// - Parameters:
    ///   - filters: Filter group, It must be an object implementing C7FilterProtocol
    /// - Returns: C7FilterDestProtocol
    mutating func makeGroup<T: C7FilterDestProtocol>(filters: [C7FilterProtocol]) throws -> T
}
