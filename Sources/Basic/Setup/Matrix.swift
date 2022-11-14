//
//  Matrix.swift
//  ATMetalBand
//
//  Created by Condy on 2022/2/18.
//

import Foundation
import ObjectiveC
import QuartzCore

public protocol Matrix {
    associatedtype MatrixType
    
    static var size: Int { get }
    
    var values: [Float] { get set }
    
    init(values: [Float])
    
    func to_factor() -> MatrixType
}

fileprivate var C7ATMatrixContext: UInt8 = 0

extension Matrix {
    
    public static var size: Int {
        MemoryLayout<MatrixType>.size
    }
    
    public var values: [Float] {
        get {
            return synchronizedMatrix {
                if let object = objc_getAssociatedObject(self, &C7ATMatrixContext) {
                    return object as! [Float]
                } else {
                    let object = [Float]()
                    objc_setAssociatedObject(self, &C7ATMatrixContext, object, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    return object
                }
            }
        }
        set {
            synchronizedMatrix {
                objc_setAssociatedObject(self, &C7ATMatrixContext, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    private func synchronizedMatrix<T>( _ action: () -> T) -> T {
        objc_sync_enter(self)
        let result = action()
        objc_sync_exit(self)
        return result
    }
}
