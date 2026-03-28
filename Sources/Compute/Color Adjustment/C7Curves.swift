//
//  C7Curves.swift
//  Harbeth
//
//  Created by Condy on 2026/3/10.
//

import Foundation

/// 曲线调整滤镜
/// Curves adjustment filter
/// 
/// 该滤镜通过控制点定义的曲线来调整图像的色彩和对比度，
/// 支持RGB主曲线和红、绿、蓝单独通道曲线的调整。
/// 
/// 曲线控制点说明：
/// - 每个控制点是一个C7Point2D对象，使用归一化坐标(0.0-1.0)
/// - x坐标代表输入亮度值（从黑到白）
/// - y坐标代表输出亮度值（从黑到白）
/// - 默认的对角线([(0,0), (1,1)])代表无调整
public struct C7Curves: C7FilterProtocol {
    
    /// RGB曲线控制点，使用C7Point2D（归一化坐标）
    /// RGB curve control points, using C7Point2D (normalized coordinates)
    public var rgbPoints: [C7Point2D] = []
    
    /// 红色通道曲线控制点
    /// Red channel curve control points
    public var redPoints: [C7Point2D] = []
    
    /// 绿色通道曲线控制点
    /// Green channel curve control points
    public var greenPoints: [C7Point2D] = []
    
    /// 蓝色通道曲线控制点
    /// Blue channel curve control points
    public var bluePoints: [C7Point2D] = []
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7Curves")
    }
    
    public var factors: [Float] {
        return [
            Float(rgbPoints.count), Float(redPoints.count), Float(greenPoints.count), Float(bluePoints.count)
        ]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .point
    }
    
    public func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int) {
        guard let computeEncoder = encoder as? MTLComputeCommandEncoder else { return }
        var rgbData: [Float] = []
        rgbData.reserveCapacity(rgbPoints.count * 2)
        for point in rgbPoints {
            rgbData.append(point.x)
            rgbData.append(point.y)
        }
        computeEncoder.setBytes(&rgbData, length: rgbData.count * MemoryLayout<Float>.size, index: index)
        
        var redData: [Float] = []
        redData.reserveCapacity(redPoints.count * 2)
        for point in redPoints {
            redData.append(point.x)
            redData.append(point.y)
        }
        computeEncoder.setBytes(&redData, length: redData.count * MemoryLayout<Float>.size, index: index + 1)
        
        var greenData: [Float] = []
        greenData.reserveCapacity(greenPoints.count * 2)
        for point in greenPoints {
            greenData.append(point.x)
            greenData.append(point.y)
        }
        computeEncoder.setBytes(&greenData, length: greenData.count * MemoryLayout<Float>.size, index: index + 2)
        
        var blueData: [Float] = []
        blueData.reserveCapacity(bluePoints.count * 2)
        for point in bluePoints {
            blueData.append(point.x)
            blueData.append(point.y)
        }
        computeEncoder.setBytes(&blueData, length: blueData.count * MemoryLayout<Float>.size, index: index + 3)
    }
    
    public init(rgbPoints: [C7Point2D]? = nil, redPoints: [C7Point2D]? = nil, greenPoints: [C7Point2D]? = nil, bluePoints: [C7Point2D]? = nil) {
        if let points = rgbPoints {
            self.rgbPoints = points
        } else {
            self.rgbPoints = [
                C7Point2D(x: 0.0, y: 0.0),
                C7Point2D(x: 1.0, y: 1.0)
            ]
        }
        if let points = redPoints {
            self.redPoints = points
        } else {
            self.redPoints = [
                C7Point2D(x: 0.0, y: 0.0),
                C7Point2D(x: 1.0, y: 1.0)
            ]
        }
        if let points = greenPoints {
            self.greenPoints = points
        } else {
            self.greenPoints = [
                C7Point2D(x: 0.0, y: 0.0),
                C7Point2D(x: 1.0, y: 1.0)
            ]
        }
        if let points = bluePoints {
            self.bluePoints = points
        } else {
            self.bluePoints = [
                C7Point2D(x: 0.0, y: 0.0),
                C7Point2D(x: 1.0, y: 1.0)
            ]
        }
    }
}
