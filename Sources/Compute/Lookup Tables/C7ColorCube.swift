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
import Darwin

/// 3D LUT颜色立方体滤镜
/// 使用Metal实现的CUBE文件格式LUT滤镜
public struct C7ColorCube: C7FilterPipelineProtocol {
    static let unitTetrahedralConstant = "colorCubeUnitTetrahedral"
    private static let unitTetrahedralConstants: [KernelFunctionConstantDescriptor] = [
        .init(name: unitTetrahedralConstant, index: 0, value: .bool(true))
    ]

    public enum DomainPolicy: Float, Sendable, Codable, Equatable {
        case clampToDomain = 0
        case preserveOutsideDomain = 1
    }

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
        fileprivate let isValid: Bool

        public init(dimension: Int, data: Data, domainMinimum: SIMD3<Float> = .zero, domainMaximum: SIMD3<Float> = SIMD3<Float>(repeating: 1)) {
            self.dimension = dimension
            self.data = data
            self.domainMinimum = domainMinimum
            self.domainMaximum = domainMaximum
            self.isValid = Self.validateStorage(dimension: dimension, data: data, minimum: domainMinimum, maximum: domainMaximum)
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
    public private(set) var domainPolicy: DomainPolicy
    
    public var modifier: ModifierEnum {
        return .compute(kernel: "C7ColorCube")
    }
    
    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(name: "intensity", index: 0, stage: .compute, value: .float(intensity)),
            KernelParameterBinding(name: "interpolation", index: 1, stage: .compute, value: .float(interpolation.rawValue)),
            KernelParameterBinding(name: "domainMinimum", index: 2, stage: .compute, value: .float3(domainMinimum)),
            KernelParameterBinding(name: "domainMaximum", index: 3, stage: .compute, value: .float3(domainMaximum)),
            KernelParameterBinding(name: "domainPolicy", index: 4, stage: .compute, value: .float(domainPolicy.rawValue))
        ]
    }
    
    public var otherInputTextures: C7InputTextures {
        return lutTexture == nil ? [] : [lutTexture!]
    }
    
    public var memoryAccessPattern: MemoryAccessPattern {
        .dualTexture
    }

    public var kernelResourceIdentity: String? { resourceIdentity }

    public var pipelineFilters: [C7FilterProtocol] { [] }

    public var pipelineOtherInputCount: Int { otherInputTextures.count }

    public func makeFinalFilter(otherInputTextures: C7InputTextures?) -> C7FilterProtocol? {
        if let resourceLoadError { return ColorCubeResourceFailure(error: resourceLoadError, kernelParameterBindings: kernelParameterBindings) }
        if lutTexture == nil { return ColorCubeResourceFailure(error: .cubeResource, kernelParameterBindings: kernelParameterBindings) }
        let useUnitTetrahedral = interpolation == .tetrahedral
            && domainMinimum == .zero && domainMaximum == SIMD3<Float>(repeating: 1)
        return ColorCubeKernel(bindings: kernelParameterBindings, inputs: self.otherInputTextures,
            identity: resourceIdentity, pixelContract: kernelPixelContract,
            computeKernelFunctionConstants: useUnitTetrahedral ? Self.unitTetrahedralConstants : [])
    }

    public var kernelPixelContract: KernelPixelContract {
        KernelPixelContract(precision: .float32,
            dynamicRangeBehavior: domainPolicy == .preserveOutsideDomain ? .preservesExtendedRange : .unspecified,
            samplingFootprint: .point)
    }
    
    private var lutTexture: MTLTexture?
    private var domainMinimum: SIMD3<Float> = .zero
    private var domainMaximum: SIMD3<Float> = SIMD3<Float>(repeating: 1)

    public init(cubeName: String, bundle: Bundle = .main, intensity: Float = 1.0, interpolation: Interpolation = .tetrahedral, domainPolicy: DomainPolicy = .clampToDomain) {
        self.init(cubeResource: nil, intensity: intensity, interpolation: interpolation, domainPolicy: domainPolicy)
        self.resourceName = cubeName
        self.resourceBundleName = bundle.bundleURL.deletingPathExtension().lastPathComponent
        if let file = Resource.namedFile(cubeName, bundle: bundle) {
            loadFile(at: file.url, compact: file.compact)
        }
    }

    public init(cubeName: String, forResource resource: String, intensity: Float = 1.0, interpolation: Interpolation = .tetrahedral) {
        let bundle = R.readFrameworkBundle(with: resource) ?? .main
        self.init(cubeName: cubeName, bundle: bundle, intensity: intensity, interpolation: interpolation)
        self.resourceName = cubeName
        self.resourceBundleName = resource
    }
    
    public init(cubeURL: URL, intensity: Float = 1.0, interpolation: Interpolation = .tetrahedral, domainPolicy: DomainPolicy = .clampToDomain) {
        self.init(cubeResource: nil, intensity: intensity, interpolation: interpolation, domainPolicy: domainPolicy)
        loadFile(at: cubeURL, compact: false)
    }

    public init(cubeData: Data, dimension: Int, intensity: Float = 1.0, interpolation: Interpolation = .tetrahedral, domainPolicy: DomainPolicy = .clampToDomain) {
        let resource = C7ColorCube.Resource(dimension: dimension, data: cubeData)
        self.init(cubeResource: resource, intensity: intensity, interpolation: interpolation, domainPolicy: domainPolicy)
        self.resourceName = nil
        self.resourceBundleName = nil
    }
    
    public init(cubeResource: C7ColorCube.Resource?, intensity: Float = 1.0, interpolation: Interpolation = .tetrahedral, domainPolicy: DomainPolicy = .clampToDomain) {
        self.intensity = intensity
        self.interpolation = interpolation
        self.domainPolicy = domainPolicy
        setResource(cubeResource)
    }

    private mutating func loadFile(at url: URL, compact: Bool) {
        do {
            let prepared = try PreparedColorCube.load(from: url, compact: compact)
            lutTexture = prepared.texture
            resourceIdentity = prepared.identity
            domainMinimum = prepared.domainMinimum
            domainMaximum = prepared.domainMaximum
        } catch {
            resourceLoadError = error as? HarbethError ?? .error(error)
        }
    }

    private mutating func setResource(_ resource: Resource?) {
        resourceIdentity = resource?.identity
        domainMinimum = resource?.domainMinimum ?? .zero
        domainMaximum = resource?.domainMaximum ?? SIMD3<Float>(repeating: 1)
        lutTexture = nil
        resourceLoadError = nil
        if let resource {
            do {
                lutTexture = try Resource.createLUTTexture(from: resource)
            } catch {
                resourceIdentity = nil
                resourceLoadError = error as? HarbethError ?? .error(error)
            }
        }
    }

    public func updateIntensity(_ intensity: CGFloat) -> Self {
        var copy = self
        copy.intensity = Float(intensity)
        return copy
    }
    
    public func updateCubeResource(_ cubeResource: C7ColorCube.Resource?) -> Self {
        var copy = self
        copy.setResource(cubeResource)
        return copy
    }

    public func combinationBegin(for buffer: MTLCommandBuffer, source texture: MTLTexture, dest texture2: MTLTexture) throws -> MTLTexture {
        try validateResource()
        return texture
    }

    private func validateResource() throws {
        if let resourceLoadError { throw resourceLoadError }
        guard lutTexture != nil else { throw HarbethError.cubeResource }
    }

    public func updateInterpolation(_ interpolation: Interpolation) -> Self {
        var copy = self
        copy.interpolation = interpolation
        return copy
    }

    public func updateDomainPolicy(_ policy: DomainPolicy) -> Self {
        var copy = self
        copy.domainPolicy = policy
        return copy
    }
}

/// 以单个查表内核执行，避免滤镜管线递归调度自身。
private struct ColorCubeKernel: C7FilterProtocol {
    let bindings: [KernelParameterBinding]
    let inputs: C7InputTextures
    let identity: String?
    let pixelContract: KernelPixelContract
    let computeKernelFunctionConstants: [KernelFunctionConstantDescriptor]
    var modifier: ModifierEnum { .compute(kernel: "C7ColorCube") }
    var kernelParameterBindings: [KernelParameterBinding] { bindings }
    var otherInputTextures: C7InputTextures { inputs }
    var kernelResourceIdentity: String? { identity }
    var kernelPixelContract: KernelPixelContract { pixelContract }
    var memoryAccessPattern: MemoryAccessPattern { .dualTexture }
}

private struct ColorCubeResourceFailure: BlitProtocol {
    let error: HarbethError
    let kernelParameterBindings: [KernelParameterBinding]
    var modifier: ModifierEnum { .blit }
    func encode(commandBuffer: MTLCommandBuffer, textures: [MTLTexture]) throws -> MTLTexture {
        throw error
    }
}

private final class PreparedColorCube {
    let texture: MTLTexture
    let identity: String
    let domainMinimum: SIMD3<Float>
    let domainMaximum: SIMD3<Float>

    private init(resource: C7ColorCube.Resource, device: MTLDevice) throws {
        texture = try C7ColorCube.Resource.uploadLUTTexture(from: resource, device: device)
        identity = resource.identity
        domainMinimum = resource.domainMinimum
        domainMaximum = resource.domainMaximum
    }

    static func load(from url: URL, compact: Bool) throws -> PreparedColorCube {
        let context = HarbethContext.shared
        func prepare() throws -> PreparedColorCube {
            let resource = try C7ColorCube.Resource.readFile(at: url, compact: compact)
            return try PreparedColorCube(resource: resource, device: context.device)
        }

        // 文件版本改变后，重放必须重新读取，失败结果也不能阻止后续导入。
        guard let fingerprint = fileFingerprint(url, compact: compact) else { return try prepare() }
        let identity = context.makeDerivedResourceIdentity(
            domain: .lookupTable,
            namespace: "harbeth.lookup-table",
            fingerprint: fingerprint
        )
        return try context.derivedResourceStore.object(for: identity, byteCost: { $0.texture.allocatedSize }, create: prepare)
    }

    private static func fileFingerprint(_ url: URL, compact: Bool) -> String? {
        let file = url.standardizedFileURL
        var info = stat()
        let status = file.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }
            return fstatat(AT_FDCWD, path, &info, 0)
        }
        guard status == 0 else { return nil }
        return "\(compact)|\(info.st_dev)|\(info.st_ino)|\(info.st_size)|"
            + "\(info.st_mtimespec.tv_sec).\(info.st_mtimespec.tv_nsec)|"
            + "\(info.st_ctimespec.tv_sec).\(info.st_ctimespec.tv_nsec)|\(file.path)"
    }
}

extension C7ColorCube.Resource {
    static func readCubeResource(from url: URL) -> C7ColorCube.Resource? {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return try? parse(contents: contents)
    }
    
    static func createLUTTexture(from resource: C7ColorCube.Resource) throws -> MTLTexture {
        guard resource.isValid else { throw HarbethError.cubeResource }
        let context = HarbethContext.shared
        let cacheIdentity = context.makeDerivedResourceIdentity(
            domain: .lookupTable,
            namespace: "harbeth.lookup-table",
            fingerprint: resource.identity
        )
        return try context.makeDerivedTexture(for: cacheIdentity) {
            try uploadLUTTexture(from: resource, device: context.device)
        }
    }

    fileprivate static func uploadLUTTexture(from resource: C7ColorCube.Resource, device: MTLDevice) throws -> MTLTexture {
        guard resource.isValid else { throw HarbethError.cubeResource }
        let descriptor = MTLTextureDescriptor()
        descriptor.textureType = .type3D
        descriptor.pixelFormat = .rgba32Float
        descriptor.width = resource.dimension
        descriptor.height = resource.dimension
        descriptor.depth = resource.dimension
        descriptor.mipmapLevelCount = 1
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        descriptor.cpuCacheMode = .writeCombined
        guard let texture = device.makeTexture(descriptor: descriptor) else { throw HarbethError.makeTexture }
        let bytesPerRow = resource.dimension * 4 * MemoryLayout<Float>.size
        resource.data.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake3D(0, 0, 0, resource.dimension, resource.dimension, resource.dimension),
                mipmapLevel: 0,
                slice: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: bytesPerRow,
                bytesPerImage: resource.dimension * bytesPerRow
            )
        }
        return texture
    }

    /// Read Cube file resources.
    /// - Parameters:
    ///   - name: File name.
    ///   - bundle: Bundle that contains the cube resource.
    /// - Returns: Cube resource
    public static func readCubeResource(_ name: String, bundle: Bundle = .main) -> C7ColorCube.Resource? {
        guard let file = namedFile(name, bundle: bundle) else { return nil }
        return try? readFile(at: file.url, compact: file.compact)
    }

    fileprivate static func namedFile(_ name: String, bundle: Bundle) -> (url: URL, compact: Bool)? {
        for ext in ["hlut", "HLUT", "cube", "CUBE"] {
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return (url, ext.lowercased() == "hlut")
            }
        }
        return nil
    }

    fileprivate static func readFile(at url: URL, compact: Bool) throws -> C7ColorCube.Resource {
        if compact { return try readCompactResourceStrict(from: url) }
        guard let resource = readCubeResource(from: url) else { throw HarbethError.cubeResource }
        return resource
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

    static func validateStorage(dimension: Int, data: Data, minimum: SIMD3<Float>, maximum: SIMD3<Float>) -> Bool {
        guard (2...65).contains(dimension),
              data.count == dimension * dimension * dimension * 4 * MemoryLayout<Float>.size,
              (0..<3).allSatisfy({ minimum[$0].isFinite && maximum[$0].isFinite && minimum[$0] < maximum[$0] }) else {
            return false
        }
        return data.withUnsafeBytes { bytes in
            // Data 的切片不保证 Float 对齐，验证只在不可变资源构造时执行一次。
            stride(from: 0, to: bytes.count, by: MemoryLayout<Float>.size).allSatisfy {
                bytes.loadUnaligned(fromByteOffset: $0, as: Float.self).isFinite
            }
        }
    }

    static func parseDomain(_ fields: [Substring]) throws -> SIMD3<Float> {
        guard fields.count == 4 else { throw HarbethError.cubeResource }
        let values = fields.dropFirst().compactMap { Float($0) }
        guard values.count == 3, values.allSatisfy(\.isFinite) else { throw HarbethError.cubeResource }
        return SIMD3<Float>(values[0], values[1], values[2])
    }

    static func makeIdentity(dimension: Int, data: Data, domainMinimum: SIMD3<Float>, domainMaximum: SIMD3<Float>) -> String {
        let hash = data.withUnsafeBytes { buffer in
            var value: UInt64 = 14_695_981_039_346_656_037
            for byte in buffer {
                value ^= UInt64(byte)
                value &*= 1_099_511_628_211
            }
            return value
        }
        return "cube|\(dimension)|\(domainMinimum)|\(domainMaximum)|\(String(hash, radix: 16))"
    }

    static func decodeCompactResource(_ encoded: Data) throws -> C7ColorCube.Resource {
        guard encoded.count >= compactHeaderLength else {
            throw HarbethError.cubeCompactResourceFailed(reason: "invalidHeader")
        }
        let bytes = [UInt8](encoded.prefix(compactHeaderLength))
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
        let resource = C7ColorCube.Resource(dimension: dimension, data: decoded, domainMinimum: domainMinimum, domainMaximum: domainMaximum)
        guard resource.isValid else { throw HarbethError.cubeCompactResourceFailed(reason: "invalidPayload") }
        return resource
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
