//
//  C7FilterImage.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/13.
//

import Foundation

/// 以下模式均只支持基于并行计算编码器`compute(kernel: String)`
/// The following modes support only the encoder based on parallel computing
///
extension C7Image: Outputable {
    
    public func make<T>(filter: C7FilterProtocol) throws -> T where T : Outputable {
        let dest = C7FlexoDest.init(element: self, filters: [filter])
        do {
            return try dest.output() as! T
        } catch {
            throw error
        }
    }
    
    public func makeGroup<T>(filters: [C7FilterProtocol]) throws -> T where T : Outputable {
        let dest = C7FlexoDest.init(element: self, filters: filters)
        do {
            return try dest.output() as! T
        } catch {
            throw error
        }
    }
}
