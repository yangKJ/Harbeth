//
//  HalfFloatConversion.swift
//  Harbeth
//
//  Created by Condy on 2026/11/1.
//

import Accelerate

/// Converts half-precision texture scalars without resampling or mixing channels.
public enum HalfFloatConversion {
    public static func decode(_ values: [UInt16]) throws -> [Float] {
        guard !values.isEmpty else { return [] }
        var output = [Float](repeating: 0, count: values.count)
        let error = values.withUnsafeBytes { source in
            output.withUnsafeMutableBytes { destination in
                var input = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: source.baseAddress!), height: 1, width: vImagePixelCount(values.count), rowBytes: source.count)
                var result = vImage_Buffer(data: destination.baseAddress!, height: 1, width: vImagePixelCount(values.count), rowBytes: destination.count)
                return vImageConvert_Planar16FtoPlanarF(&input, &result, vImage_Flags(kvImageNoFlags))
            }
        }
        guard error == kvImageNoError else { throw HalfFloatConversionFailure.failed }
        return output
    }

    public static func encode(_ values: [Float]) throws -> [UInt16] {
        guard !values.isEmpty else { return [] }
        var output = [UInt16](repeating: 0, count: values.count)
        let error = values.withUnsafeBytes { source in
            output.withUnsafeMutableBytes { destination in
                var input = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: source.baseAddress!), height: 1, width: vImagePixelCount(values.count), rowBytes: source.count)
                var result = vImage_Buffer(data: destination.baseAddress!, height: 1, width: vImagePixelCount(values.count), rowBytes: destination.count)
                return vImageConvert_PlanarFtoPlanar16F(&input, &result, vImage_Flags(kvImageNoFlags))
            }
        }
        guard error == kvImageNoError else { throw HalfFloatConversionFailure.failed }
        return output
    }
}

private enum HalfFloatConversionFailure: Error { case failed }
