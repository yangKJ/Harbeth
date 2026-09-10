//
//  C7ColorCube.swift
//  Harbeth
//
//  Created by Condy on 2026/2/10.
//

import Foundation
import MetalKit
import Compression
import CryptoKit

/// 3D LUT颜色立方体滤镜
/// 使用Metal实现的CUBE文件格式LUT滤镜
public struct C7ColorCube: C7FilterProtocol {

    public enum Interpolation: Float, Sendable, Codable, Equatable, Hashable {
        case trilinear = 0
        case tetrahedral = 1
    }
    
    public struct Resource: Sendable {
        public let dimension: Int
        public let data: Data
        public let domainMinimum: SIMD3<Float>
        public let domainMaximum: SIMD3<Float>
        public let identity: String

        public init(dimension: Int, data: Data, domainMinimum: SIMD3<Float> = .zero, domainMaximum: SIMD3<Float> = SIMD3<Float>(repeating: 1)) {
            self.dimension = dimension
            self.data = data
            self.domainMinimum = domainMinimum
            self.domainMaximum = domainMaximum
            self.identity = Self.makeIdentity(dimension: dimension, data: data, domainMinimum: domainMinimum, domainMaximum: domainMaximum)
        }
    }
    
    /// Intensity range, used to adjust the mixing ratio of filters and sources.
    @ZeroOneRange public var intensity: Float = R.intensityRange.value
    public private(set) var resourceName: String?
    public private(set) var resourceBundleName: String?
    public private(set) var interpolation: Interpolation
    public private(set) var resourceIdentity: String?
    public private(set) var resourceLoadError: HarbethError?
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ColorCube")
    }
    
    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(name: "intensity", index: 0, stage: .compute, value: .float(intensity)),
            KernelParameterBinding(name: "interpolation", index: 1, stage: .compute, value: .float(interpolation.rawValue)),
            KernelParameterBinding(name: "domainMinimum", index: 2, stage: .compute, value: .float3(domainMinimum)),
            KernelParameterBinding(name: "domainMaximum", index: 3, stage: .compute, value: .float3(domainMaximum))
        ]
    }
    
    public var otherInputTextures: C7InputTextures {
        return lutTexture == nil ? [] : [lutTexture!]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .dualTexture
    }

    public var kernelResourceIdentity: String? { resourceIdentity }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(precision: .float32, dynamicRangeBehavior: .unspecified, samplingFootprint: .point)
    }
    
    private var lutTexture: MTLTexture?
    private var dimension: Int
    private var domainMinimum: SIMD3<Float>
    private var domainMaximum: SIMD3<Float>
    
    public init(cubeName: String, bundle: Bundle = .main, intensity: Float = 1.0, interpolation: Interpolation = .tetrahedral) {
        let resolution = C7ColorCube.Resource.resolveNamedResource(cubeName, bundle: bundle)
        self.init(cubeResource: resolution.resource, intensity: intensity, interpolation: interpolation)
        self.resourceName = cubeName
        self.resourceBundleName = bundle.bundleURL.deletingPathExtension().lastPathComponent
        self.resourceLoadError = resolution.error
    }

    public init(cubeName: String, forResource resource: String, intensity: Float = 1.0, interpolation: Interpolation = .tetrahedral) {
        let bundle = R.readFrameworkBundle(with: resource) ?? .main
        self.init(cubeName: cubeName, bundle: bundle, intensity: intensity, interpolation: interpolation)
        self.resourceName = cubeName
        self.resourceBundleName = resource
    }
    
    public init(cubeURL: URL, intensity: Float = 1.0, interpolation: Interpolation = .tetrahedral) {
        let resource = C7ColorCube.Resource.readCubeResource(from: cubeURL)
        self.init(cubeResource: resource, intensity: intensity, interpolation: interpolation)
        self.resourceName = nil
        self.resourceBundleName = nil
    }
    
    public init(cubeData: Data, dimension: Int, intensity: Float = 1.0, interpolation: Interpolation = .tetrahedral) {
        let resource = C7ColorCube.Resource(dimension: dimension, data: cubeData)
        self.init(cubeResource: resource, intensity: intensity, interpolation: interpolation)
        self.resourceName = nil
        self.resourceBundleName = nil
    }
    
    public init(cubeResource: C7ColorCube.Resource?, intensity: Float = 1.0, interpolation: Interpolation = .tetrahedral) {
        self.intensity = intensity
        self.interpolation = interpolation
        self.resourceIdentity = cubeResource?.identity
        self.resourceName = nil
        self.resourceBundleName = nil
        self.resourceLoadError = nil
        if let resource = cubeResource {
            self.dimension = resource.dimension
            self.domainMinimum = resource.domainMinimum
            self.domainMaximum = resource.domainMaximum
            self.lutTexture = C7ColorCube.Resource.createLUTTexture(from: resource)
        } else {
            self.dimension = 0
            self.domainMinimum = .zero
            self.domainMaximum = SIMD3<Float>(repeating: 1)
            self.lutTexture = nil
        }
    }
    
    public func updateIntensity(_ intensity: CGFloat) -> Self {
        var copy = self
        copy.intensity = Float(intensity)
        return copy
    }
    
    public func updateCubeResource(_ cubeResource: C7ColorCube.Resource?) -> Self {
        var copy = self
        copy.resourceLoadError = nil
        if let resource = cubeResource {
            copy.dimension = resource.dimension
            copy.resourceIdentity = resource.identity
            copy.domainMinimum = resource.domainMinimum
            copy.domainMaximum = resource.domainMaximum
            copy.lutTexture = C7ColorCube.Resource.createLUTTexture(from: resource)
        } else {
            copy.dimension = 0
            copy.resourceIdentity = nil
            copy.domainMinimum = .zero
            copy.domainMaximum = SIMD3<Float>(repeating: 1)
            copy.lutTexture = nil
        }
        return copy
    }

    public func updateInterpolation(_ interpolation: Interpolation) -> Self {
        var copy = self
        copy.interpolation = interpolation
        return copy
    }
}

extension C7ColorCube.Resource {
    struct NamedResourceResolution {
        let resource: C7ColorCube.Resource?
        let error: HarbethError?
    }

    static func readCubeResource(from url: URL) -> C7ColorCube.Resource? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return try? parse(contents: contents)
    }
    
    static func createLUTTexture(from resource: C7ColorCube.Resource) -> MTLTexture? {
        guard resource.hasValidStorage else { return nil }
        let context = HarbethContext.shared
        let cacheIdentity = context.makeDerivedResourceIdentity(
            domain: .lookupTable,
            namespace: "harbeth.lookup-table",
            fingerprint: resource.identity
        )
        if let cached = context.cachedDerivedTexture(for: cacheIdentity) {
            return cached
        }
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = .type3D
        textureDescriptor.pixelFormat = .rgba32Float
        textureDescriptor.width = resource.dimension
        textureDescriptor.height = resource.dimension
        textureDescriptor.depth = resource.dimension
        textureDescriptor.mipmapLevelCount = 1
        textureDescriptor.usage = [.shaderRead]
        textureDescriptor.storageMode = .shared
        textureDescriptor.cpuCacheMode = .writeCombined
        guard let texture = HarbethContext.shared.device.makeTexture(descriptor: textureDescriptor) else { return nil }

        let bytesPerPixel = 4 * MemoryLayout<Float>.size
        let bytesPerRow = resource.dimension * bytesPerPixel
        let bytesPerImage = resource.dimension * bytesPerRow
        resource.data.withUnsafeBytes { buffer in
            let floatBuffer = buffer.bindMemory(to: Float.self)
            guard let baseAddress = floatBuffer.baseAddress else { return }
            texture.replace(
                region: MTLRegionMake3D(0, 0, 0, resource.dimension, resource.dimension, resource.dimension),
                mipmapLevel: 0,
                slice: 0,
                withBytes: baseAddress,
                bytesPerRow: bytesPerRow,
                bytesPerImage: bytesPerImage
            )
        }
        context.storeDerivedTexture(texture, for: cacheIdentity)
        return texture
    }
    
    /// Read Cube file resources.
    /// - Parameters:
    ///   - name: File name.
    ///   - bundle: Bundle that contains the cube resource.
    /// - Returns: Cube resource
    public static func readCubeResource(_ name: String, bundle: Bundle = .main) -> C7ColorCube.Resource? {
        resolveNamedResource(name, bundle: bundle).resource
    }

    static func resolveNamedResource(_ name: String, bundle: Bundle) -> NamedResourceResolution {
        let compactPaths = ["hlut", "HLUT"].compactMap { bundle.url(forResource: name, withExtension: $0) }
        if let compactURL = compactPaths.first {
            switch loadCompactResource(from: compactURL) {
            case .success(let resource):
                return NamedResourceResolution(resource: resource, error: nil)
            case .failure(let error):
                return NamedResourceResolution(resource: nil, error: error)
            }
        }
        let paths = ["cube", "CUBE"].compactMap {
            bundle.path(forResource: name, ofType: $0)
        }
        guard let path = paths.first, let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return NamedResourceResolution(resource: nil, error: nil)
        }
        return NamedResourceResolution(resource: try? parse(contents: contents), error: nil)
    }

    /// 读取 Harbeth 紧凑 3D LUT 资源。格式包含版本、维度、domain、LZFSE 压缩的 RGBA Float32 样本与 SHA-256 校验值。
    public static func readCompactResource(from url: URL) -> C7ColorCube.Resource? {
        try? readCompactResourceStrict(from: url)
    }

    /// 严格读取紧凑 LUT。损坏、篡改或不符合格式时返回明确错误，调用方不得回退到另一份滤镜资源。
    public static func readCompactResourceStrict(from url: URL) throws -> C7ColorCube.Resource {
        switch loadCompactResource(from: url) {
        case .success(let resource):
            return resource
        case .failure(let error):
            throw error
        }
    }

    static func loadCompactResource(from url: URL) -> Result<C7ColorCube.Resource, HarbethError> {
        guard let encoded = try? Data(contentsOf: url) else {
            return .failure(.cubeCompactResourceFailed(reason: "unreadable"))
        }
        do {
            return .success(try decodeCompactResource(encoded))
        } catch let error as HarbethError {
            return .failure(error)
        } catch {
            return .failure(.cubeCompactResourceFailed(reason: "invalidPayload"))
        }
    }

    /// 严格解析 `.cube` 3D LUT；尺寸、domain、样本数量或非有限值不合法时直接失败。
    public static func parse(contents: String) throws -> C7ColorCube.Resource {
        var dimension: Int?
        var domainMinimum = SIMD3<Float>(repeating: 0)
        var domainMaximum = SIMD3<Float>(repeating: 1)
        var samples = [Float]()

        for rawLine in contents.replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n") {
            let line = rawLine
                .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
                .first
                .map(String.init) ?? ""
            let fields = line.split(whereSeparator: { $0.isWhitespace })
            guard fields.isEmpty == false else { continue }
            switch fields[0].uppercased() {
            case "TITLE":
                continue
            case "LUT_1D_SIZE":
                throw HarbethError.cubeResource
            case "LUT_3D_SIZE":
                guard fields.count == 2, let value = Int(fields[1]), (2...65).contains(value) else {
                    throw HarbethError.cubeResource
                }
                dimension = value
            case "DOMAIN_MIN":
                domainMinimum = try parseDomain(fields)
            case "DOMAIN_MAX":
                domainMaximum = try parseDomain(fields)
            default:
                guard fields.count == 3 else { throw HarbethError.cubeResource }
                let values = fields.compactMap { Float($0) }
                guard values.count == 3, values.allSatisfy(\.isFinite) else { throw HarbethError.cubeResource }
                samples.append(contentsOf: [values[0], values[1], values[2], 1])
            }
        }

        guard let dimension,
              samples.count == dimension * dimension * dimension * 4,
              domainMinimum.x < domainMaximum.x,
              domainMinimum.y < domainMaximum.y,
              domainMinimum.z < domainMaximum.z else {
            throw HarbethError.cubeResource
        }
        return C7ColorCube.Resource(
            dimension: dimension,
            data: samples.withUnsafeBufferPointer { Data(buffer: $0) },
            domainMinimum: domainMinimum,
            domainMaximum: domainMaximum
        )
    }
}

private extension C7ColorCube.Resource {
    static let compactMagic = [UInt8]([0x48, 0x4C, 0x55, 0x54]) // HLUT
    static let compactVersion: UInt8 = 2
    static let compactHeaderLength = 72
    static let compactChecksumOffset = 40
    static let compactChecksumLength = 32

    var hasValidStorage: Bool {
        dimension >= 2
        && dimension <= 65
        && data.count == dimension * dimension * dimension * 4 * MemoryLayout<Float>.size
    }

    static func parseDomain(_ fields: [Substring]) throws -> SIMD3<Float> {
        guard fields.count == 4 else { throw HarbethError.cubeResource }
        let values = fields.dropFirst().compactMap { Float($0) }
        guard values.count == 3, values.allSatisfy(\.isFinite) else { throw HarbethError.cubeResource }
        return SIMD3<Float>(values[0], values[1], values[2])
    }

    static func makeIdentity(dimension: Int, data: Data, domainMinimum: SIMD3<Float>, domainMaximum: SIMD3<Float>) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return "cube|\(dimension)|\(domainMinimum)|\(domainMaximum)|\(String(hash, radix: 16))"
    }

    static func decodeCompactResource(_ encoded: Data) throws -> C7ColorCube.Resource {
        guard encoded.count >= compactHeaderLength else {
            throw HarbethError.cubeCompactResourceFailed(reason: "invalidHeader")
        }
        let bytes = [UInt8](encoded)
        guard Array(bytes[0..<4]) == compactMagic,
              bytes[4] == compactVersion, bytes[5] == 1,
              let encodedDimension = integer(UInt16.self, bytes: bytes, at: 6),
              let encodedPayloadLength = integer(UInt32.self, bytes: bytes, at: 32),
              let encodedCompressedLength = integer(UInt32.self, bytes: bytes, at: 36) else {
            throw HarbethError.cubeCompactResourceFailed(reason: "invalidHeader")
        }
        let dimension = Int(encodedDimension)
        let payloadLength = Int(encodedPayloadLength)
        let compressedLength = Int(encodedCompressedLength)
        let expectedPayloadLength = dimension * dimension * dimension * 4 * MemoryLayout<Float>.size
        guard (2...65).contains(dimension),
              payloadLength == expectedPayloadLength,
              compressedLength > 0,
              encoded.count == compactHeaderLength + compressedLength,
              let domainMinimum = vector(bytes: bytes, at: 8),
              let domainMaximum = vector(bytes: bytes, at: 20),
              domainMinimum.x < domainMaximum.x,
              domainMinimum.y < domainMaximum.y,
              domainMinimum.z < domainMaximum.z else {
            throw HarbethError.cubeCompactResourceFailed(reason: "invalidHeader")
        }
        var decoded = Data(count: payloadLength)
        let decodedLength = decoded.withUnsafeMutableBytes { destination in
            encoded.withUnsafeBytes { source in
                guard let destinationAddress = destination.bindMemory(to: UInt8.self).baseAddress,
                      let sourceAddress = source.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }
                return compression_decode_buffer(
                    destinationAddress,
                    payloadLength,
                    sourceAddress.advanced(by: compactHeaderLength),
                    compressedLength,
                    nil,
                    COMPRESSION_LZFSE
                )
            }
        }
        guard decodedLength == payloadLength else {
            throw HarbethError.cubeCompactResourceFailed(reason: "invalidPayload")
        }
        let expectedChecksum = Data(bytes[compactChecksumOffset..<(compactChecksumOffset + compactChecksumLength)])
        guard Data(SHA256.hash(data: decoded)) == expectedChecksum else {
            throw HarbethError.cubeCompactResourceFailed(reason: "checksumMismatch")
        }
        let values = decoded.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
        guard values.allSatisfy(\.isFinite) else {
            throw HarbethError.cubeCompactResourceFailed(reason: "invalidPayload")
        }
        return C7ColorCube.Resource(dimension: dimension, data: decoded, domainMinimum: domainMinimum, domainMaximum: domainMaximum)
    }

    static func vector(bytes: [UInt8], at offset: Int) -> SIMD3<Float>? {
        guard let x = floating(bytes: bytes, at: offset),
              let y = floating(bytes: bytes, at: offset + 4),
              let z = floating(bytes: bytes, at: offset + 8),
              x.isFinite, y.isFinite, z.isFinite else {
            return nil
        }
        return SIMD3<Float>(x, y, z)
    }

    static func floating(bytes: [UInt8], at offset: Int) -> Float? {
        integer(UInt32.self, bytes: bytes, at: offset).map { Float(bitPattern: $0) }
    }

    static func integer<T: FixedWidthInteger>(_ type: T.Type, bytes: [UInt8], at offset: Int) -> T? {
        let length = MemoryLayout<T>.size
        guard offset >= 0, offset + length <= bytes.count else { return nil }
        return bytes[offset..<(offset + length)].enumerated().reduce(T.zero) { value, element in
            value | (T(element.element) << (element.offset * 8))
        }
    }
}
