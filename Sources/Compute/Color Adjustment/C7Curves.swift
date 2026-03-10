//
//  C7Curves.swift
//  Harbeth
//
//  Created by Condy on 2026/3/10.
//

import Foundation

/// 曲线调整滤镜
/// Curves adjustment filter
public struct C7Curves: C7FilterProtocol {
    
    /// RGB曲线控制点，使用C7Point2D（归一化坐标）
    public var rgbPoints: [C7Point2D] = [
        C7Point2D(x: 0.0, y: 0.0),
        C7Point2D(x: 0.5, y: 0.5),
        C7Point2D(x: 1.0, y: 1.0)
    ]
    
    /// 红色通道曲线控制点
    public var redPoints: [C7Point2D] = [
        C7Point2D(x: 0.0, y: 0.0),
        C7Point2D(x: 0.5, y: 0.5),
        C7Point2D(x: 1.0, y: 1.0)
    ]
    
    /// 绿色通道曲线控制点
    public var greenPoints: [C7Point2D] = [
        C7Point2D(x: 0.0, y: 0.0),
        C7Point2D(x: 0.5, y: 0.5),
        C7Point2D(x: 1.0, y: 1.0)
    ]
    
    /// 蓝色通道曲线控制点
    public var bluePoints: [C7Point2D] = [
        C7Point2D(x: 0.0, y: 0.0),
        C7Point2D(x: 0.5, y: 0.5),
        C7Point2D(x: 1.0, y: 1.0)
    ]
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Curves")
    }
    
    public var factors: [Float] {
        return [
            Float(rgbPoints.count), Float(redPoints.count), Float(greenPoints.count), Float(bluePoints.count)
        ]
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        // 传递RGB曲线点数据
        var rgbData: [Float] = []
        rgbData.reserveCapacity(rgbPoints.count * 2)
        for point in rgbPoints {
            rgbData.append(point.x)
            rgbData.append(point.y)
        }
        computeEncoder.setBytes(&rgbData, length: rgbData.count * MemoryLayout<Float>.size, index: index)
        
        // 传递红色曲线点数据
        var redData: [Float] = []
        redData.reserveCapacity(redPoints.count * 2)
        for point in redPoints {
            redData.append(point.x)
            redData.append(point.y)
        }
        computeEncoder.setBytes(&redData, length: redData.count * MemoryLayout<Float>.size, index: index + 1)
        
        // 传递绿色曲线点数据
        var greenData: [Float] = []
        greenData.reserveCapacity(greenPoints.count * 2)
        for point in greenPoints {
            greenData.append(point.x)
            greenData.append(point.y)
        }
        computeEncoder.setBytes(&greenData, length: greenData.count * MemoryLayout<Float>.size, index: index + 2)
        
        // 传递蓝色曲线点数据
        var blueData: [Float] = []
        blueData.reserveCapacity(bluePoints.count * 2)
        for point in bluePoints {
            blueData.append(point.x)
            blueData.append(point.y)
        }
        computeEncoder.setBytes(&blueData, length: blueData.count * MemoryLayout<Float>.size, index: index + 3)
    }
    
    public init() { }
    
    public init(rgbPoints: [C7Point2D]? = nil, redPoints: [C7Point2D]? = nil, greenPoints: [C7Point2D]? = nil, bluePoints: [C7Point2D]? = nil) {
        if let points = rgbPoints {
            self.rgbPoints = points
        }
        if let points = redPoints {
            self.redPoints = points
        }
        if let points = greenPoints {
            self.greenPoints = points
        }
        if let points = bluePoints {
            self.bluePoints = points
        }
    }
}
