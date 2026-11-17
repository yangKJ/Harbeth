// 由 Condy 创建于 2026/11/17。
import Metal
import XCTest
@testable import Harbeth

final class LocalToneStatisticsRegressionTests: XCTestCase {
    func testGroupedHistogramExactlyMatchesDirectAndConservesTileCounts() throws {
        let w = 67, h = 65
        for format in ColorMathPixels.formats { for grid in [C7CLAHE.TileGridSize(columns:1,rows:1), .init(columns:5,rows:3), .init(columns:16,rows:16)] {
            let source = try fixture(w, h, format)
            let stats = try LocalToneStatistics(device: source.device, width: w, height: h, clipLimit: 2, grid: grid)
            let command = try buffer()
            try stats.encodeClear(commandBuffer: command)
            try stats.encodeAccumulate(source: source, origin: .zero, commandBuffer: command)
            let reference = try directHistogram(source, width: w, height: h, grid: grid, command: command)
            command.commit(); command.waitUntilCompleted()
            XCTAssertEqual(command.status, .completed)
            let actual = try uints(stats.histogram), count = try uints(stats.sampleCounts)
            XCTAssertEqual(actual, try uints(reference.0))
            XCTAssertEqual(count, try uints(reference.1))
            let p = try ColorMathPixels.read(source).map { Float(Float16($0)) }
            var expected = Array(repeating: UInt32(0), count: grid.columns * grid.rows)
            for y in 0..<h { for x in 0..<w {
                let i = (y*w+x)*4, a = p[i+3]
                if a > 0 && (0..<3).allSatisfy({ (p[i+$0]/a).isFinite && (0...1).contains(p[i+$0]/a) }) {
                    expected[(y*grid.rows/h)*grid.columns+x*grid.columns/w] += 1
                }
            } }
            XCTAssertEqual(count, expected)
            for tile in count.indices { XCTAssertEqual(actual[tile*256..<tile*256+256].reduce(0,+), count[tile]) }
        } }
    }

    func testRegionAccumulationKeepsFullCanvasTileCoordinates() throws {
        let w = 67, h = 65, grid = C7CLAHE.TileGridSize(columns:5,rows:3)
        let source = try fixture(w, h, .rgba16Float), p = try ColorMathPixels.read(source)
        let full = try LocalToneStatistics(device: source.device, width: w, height: h, clipLimit: 2, grid: grid)
        let parts = try LocalToneStatistics(device: source.device, width: w, height: h, clipLimit: 2, grid: grid)
        let command = try buffer(); try full.encodeClear(commandBuffer: command); try parts.encodeClear(commandBuffer: command)
        try full.encodeAccumulate(source: source, origin: .zero, commandBuffer: command)
        for (origin, width) in [(0,31),(31,36)] {
            var values: [Float] = []
            for y in 0..<h { for x in origin..<origin+width { values += p[(y*w+x)*4..<(y*w+x)*4+4] } }
            let tile = try ColorMathPixels.make(width:width,height:h,values:values,format:.rgba16Float)
            try parts.encodeAccumulate(source: tile, origin: .init(UInt32(origin),0), commandBuffer: command)
        }
        command.commit(); command.waitUntilCompleted()
        XCTAssertEqual(try uints(parts.histogram), try uints(full.histogram))
        XCTAssertEqual(try uints(parts.sampleCounts), try uints(full.sampleCounts))
    }

    func testSignedNativePathMatchesPublicFullPreparationAcrossStorage() throws {
        for format in ColorMathPixels.formats { for (w,h) in [(1,1),(17,13),(67,65)] {
            let source = try ColorMathPixels.fixture(width:w,height:h,format:format), grid = C7CLAHE.TileGridSize(columns:4,rows:3)
            for amount: Float in [-0.7,0.7] {
                let native: MTLTexture = try HarbethIO(element: source, filter: C7LocalTone(amount:amount,tileGridSize:grid)).output()
                let prepared = try LocalToneStatistics(device: source.device, width:w,height:h,clipLimit:2,grid:grid)
                let out = try outputLike(source), command = try buffer()
                try prepared.encodeClear(commandBuffer: command)
                try prepared.encodeAccumulate(source: source, origin: .zero, commandBuffer: command)
                try prepared.encodePrepare(commandBuffer: command)
                try prepared.encodeApply(source: source, destination: out, origin: .zero, amount: amount, commandBuffer: command)
                command.commit(); command.waitUntilCompleted()
                XCTAssertEqual(out.c7.rawBytes(maximumBytes:w*h*16), native.c7.rawBytes(maximumBytes:w*h*16))
            }
        } }
    }

    func testPublicPreparationSupportsBothSignsWithoutLosingLookup() throws {
        let source = try ColorMathPixels.fixture(width:67,height:65,format:.rgba16Float), grid = C7CLAHE.TileGridSize(columns:4,rows:3)
        let stats = try LocalToneStatistics(device:source.device,width:67,height:65,clipLimit:2,grid:grid), command = try buffer()
        try stats.encodeClear(commandBuffer: command); try stats.encodeAccumulate(source: source, origin:.zero,commandBuffer:command); try stats.encodePrepare(commandBuffer:command)
        let minus = try outputLike(source), plus = try outputLike(source)
        try stats.encodeApply(source:source,destination:minus,origin:.zero,amount:-0.7,commandBuffer:command)
        try stats.encodeApply(source:source,destination:plus,origin:.zero,amount:0.7,commandBuffer:command)
        command.commit(); command.waitUntilCompleted()
        for (amount,result): (Float,MTLTexture) in [(-0.7,minus),(0.7,plus)] {
            let reference: MTLTexture = try HarbethIO(element: source, filter:C7LocalTone(amount:amount,tileGridSize:grid)).output()
            XCTAssertEqual(result.c7.rawBytes(maximumBytes:67*65*8), reference.c7.rawBytes(maximumBytes:67*65*8))
        }
    }

    func testLocalToneAsyncAndZeroKeepSourceAndMatchCompletedPixels() async throws {
        let source = try ColorMathPixels.fixture(width:67,height:65,format:.rgba16Float), before = source.c7.rawBytes(maximumBytes:67*65*8)
        for amount: Float in [-0.7,0,0.7] {
            let f = C7LocalTone(amount:amount)
            let a: MTLTexture = try HarbethIO(element: source,filter:f).output(), b: MTLTexture = try await HarbethIO(element:source,filter:f).transmitOutput()
            XCTAssertEqual(a.c7.rawBytes(maximumBytes:67*65*8), b.c7.rawBytes(maximumBytes:67*65*8))
            if amount == 0 { XCTAssertEqual(a.c7.rawBytes(maximumBytes:67*65*8), before) }
        }
        XCTAssertEqual(source.c7.rawBytes(maximumBytes:67*65*8), before)
    }

    private func fixture(_ w: Int, _ h: Int, _ format: MTLPixelFormat) throws -> MTLTexture {
        var p: [Float] = []
        for y in 0..<h { for x in 0..<w {
            let a: Float = [0,0.25,0.5,1][(x+y)%4]
            p += [Float(x%17)/16*a,Float(y%13)/12*a,0.5*a,a]
        } }
        for (pixel,v) in [[Float](arrayLiteral:0,0,0,0),[1,1,1,1],[0.5,0.5,0.5,1],[2,0.5,0.25,1],[-0.1,0.2,0.3,1]].enumerated() { p.replaceSubrange(pixel*4..<pixel*4+4,with:v) }
        if format == .rgba16Float || format == .rgba32Float { p.replaceSubrange(20..<24,with:[.nan,0.5,0.5,1]) }
        let tiny = Float(Float16.leastNonzeroMagnitude)
        p.replaceSubrange(24..<28,with:[tiny,tiny,tiny,tiny])
        return try ColorMathPixels.make(width:w,height:h,values:p,format:format)
    }

    private func directHistogram(_ source: MTLTexture, width: Int, height: Int, grid: C7CLAHE.TileGridSize, command: MTLCommandBuffer) throws -> (MTLBuffer,MTLBuffer) {
        let device = source.device, count = grid.columns*grid.rows
        let hist = try XCTUnwrap(device.makeBuffer(length:count*256*4,options:.storageModePrivate)), totals = try XCTUnwrap(device.makeBuffer(length:count*4,options:.storageModePrivate))
        let blit = try XCTUnwrap(command.makeBlitCommandEncoder()); for b in [hist,totals] { blit.fill(buffer:b,range:0..<b.length,value:0) }; blit.endEncoding()
        let pso = try MetalCommandEnvironment(device:device).makeComputePipelineState(.init(kind:.compute,primaryName:"localToneAccumulate",librarySource:.harbethFramework))
        let encoder = try XCTUnwrap(command.makeComputeCommandEncoder()); encoder.setComputePipelineState(pso); encoder.setTexture(source,index:0); encoder.setBuffer(hist,offset:0,index:0); encoder.setBuffer(totals,offset:0,index:1)
        let values: [UInt32] = [UInt32(width),UInt32(height),0,0,UInt32(grid.columns),UInt32(grid.rows)]
        values.withUnsafeBytes { encoder.setBytes($0.baseAddress!,length:$0.count,index:2) }
        encoder.dispatchThreadgroups(.init(width:(source.width+15)/16,height:(source.height+15)/16,depth:1),threadsPerThreadgroup:.init(width:16,height:16,depth:1)); encoder.endEncoding()
        return (hist,totals)
    }
    private func buffer() throws -> MTLCommandBuffer { try XCTUnwrap(HarbethContext.shared.device.makeCommandQueue()?.makeCommandBuffer()) }
    private func outputLike(_ source: MTLTexture) throws -> MTLTexture { try ColorMathPixels.make(width:source.width,height:source.height,values:Array(repeating:0,count:source.width*source.height*4),format:source.pixelFormat) }
    private func uints(_ source: MTLBuffer) throws -> [UInt32] {
        let copy = try XCTUnwrap(source.device.makeBuffer(length:source.length,options:.storageModeShared)), command = try buffer(), blit = try XCTUnwrap(command.makeBlitCommandEncoder())
        blit.copy(from:source,sourceOffset:0,to:copy,destinationOffset:0,size:source.length); blit.endEncoding(); command.commit(); command.waitUntilCompleted()
        return Array(UnsafeBufferPointer(start:copy.contents().bindMemory(to:UInt32.self,capacity:source.length/4),count:source.length/4))
    }
}
