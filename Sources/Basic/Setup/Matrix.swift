//
//  Matrix.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/18.
//

import Foundation
import QuartzCore

public protocol Matrix {
    associatedtype MatrixType
    
    static var size: Int { get }
    
    var values: [Float] { get set }
    
    init(values: [Float])
    
    func to_factor() -> MatrixType
}

extension Matrix {
    public static var size: Int {
        MemoryLayout<MatrixType>.size
    }
}
