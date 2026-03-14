//
//  C7LuminanceThreshold.swift
//  MetalQueenDemo
//
//  Created by Condy on 2021/8/8.
//

import Foundation

/// 阈值滤镜 阈值的大小是动态
/// Threshold filter threshold size is dynamic
public struct C7LuminanceThreshold: C7FilterProtocol {
    
    public var threshold: Float = 0.5
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7LuminanceThreshold")
    }
    
    public var factors: [Float] {
        return [threshold]
    }
    
    public init(threshold: Float = 0.5) {
        self.threshold = threshold
    }
}

extension C7LuminanceThreshold {
    public static func calculateThreshold(from image: C7Image) -> Float {
        guard let cgImage = image.cgImage else { return 0.5 }
        return calculateThreshold(from: cgImage)
    }
    
    /// Calculates the best threshold according to the picture's brightness distribution.
    public static func calculateThreshold(from cgImage: CGImage) -> Float {
        let width  = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = bytesPerRow * height
        
        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: Shared.shared.device?.colorSpace ?? Device.colorSpace(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var histogram = [Int](repeating: 0, count: 256)
        for i in stride(from: 0, to: totalBytes, by: 4) {
            let r = pixelData[i]
            let g = pixelData[i + 1]
            let b = pixelData[i + 2]
            let luminance = UInt8(0.2125 * Float(r) + 0.7154 * Float(g) + 0.0721 * Float(b))
            histogram[Int(luminance)] += 1
        }
        
        let threshold = otsuThreshold(histogram: histogram, totalPixels: width * height)
        return Float(threshold) / 255.0
    }
    
    /// Otsu's method to calculate the best threshold value
    private static func otsuThreshold(histogram: [Int], totalPixels: Int) -> Int {
        var sum = 0
        for i in 0..<256 {
            sum += i * histogram[i]
        }
        var sumB = 0
        var wB = 0
        var wF = 0
        var varMax = 0.0
        var threshold = 0
        
        for i in 0..<256 {
            wB += histogram[i]
            if wB == 0 { continue }
            wF = totalPixels - wB
            if wF == 0 { break }
            
            sumB += i * histogram[i]
            
            let mB = Double(sumB) / Double(wB)
            let mF = Double(sum - sumB) / Double(wF)
            
            let varBetween = Double(wB) * Double(wF) * pow(mB - mF, 2)
            
            if varBetween > varMax {
                varMax = varBetween
                threshold = i
            }
        }
        return threshold
    }
    
    /// Calculate the threshold by the triangle method
    private static func triangleThreshold(histogram: [Int]) -> Int {
        var peakIndex = 0
        var maxCount = 0
        for i in 0..<256 {
            if histogram[i] > maxCount {
                maxCount = histogram[i]
                peakIndex = i
            }
        }
        
        var startIndex = 0
        for i in 0..<256 {
            if histogram[i] > 0 {
                startIndex = i
                break
            }
        }
        
        var endIndex = 255
        for i in (0..<256).reversed() {
            if histogram[i] > 0 {
                endIndex = i
                break
            }
        }
        
        let baselineStart: (x: Int, y: Int)
        let baselineEnd: (x: Int, y: Int)
        
        if peakIndex - startIndex > endIndex - peakIndex {
            baselineStart = (endIndex, 0)
            baselineEnd = (peakIndex, maxCount)
        } else {
            baselineStart = (startIndex, 0)
            baselineEnd = (peakIndex, maxCount)
        }
        
        var maxDistance = 0.0
        var threshold = peakIndex
        
        func distanceFromPointToLine(point: (x: Int, y: Int)) -> Double {
            let lineEnd = baselineEnd, lineStart = baselineStart
            let numerator = abs(Double((lineEnd.y - lineStart.y) * point.x - (lineEnd.x - lineStart.x) * point.y + lineEnd.x * lineStart.y - lineEnd.y * lineStart.x))
            let denominator = sqrt(pow(Double(lineEnd.y - lineStart.y), 2) + pow(Double(lineEnd.x - lineStart.x), 2))
            return denominator > 0 ? numerator / denominator : 0
        }
        
        for i in min(baselineStart.x, baselineEnd.x)...max(baselineStart.x, baselineEnd.x) {
            let distance = distanceFromPointToLine(point: (i, histogram[i]))
            if distance > maxDistance {
                maxDistance = distance
                threshold = i
            }
        }
        
        return threshold
    }
}
