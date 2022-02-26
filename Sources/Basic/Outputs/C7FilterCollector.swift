//
//  C7FilterCollector.swift
//  Harbeth
//
//  Created by Condy on 2022/2/25.
//

import Foundation
import AVFoundation
import CoreVideo
import MetalKit

/// 相机数据采集器，在主线程返回图片
/// The camera data collector returns pictures in the main thread.
public final class C7FilterCollector: CALayer {
    
    public typealias CollectorImageCallback = (_ image: UIImage) -> Void

    public var groupFilters: [C7FilterProtocol]
    public lazy var captureSession: AVCaptureSession = AVCaptureSession()
    
    private var textureCache: CVMetalTextureCache?
    private let callback: CollectorImageCallback
    
    public init(callback: @escaping CollectorImageCallback) {
        self.callback = callback
        self.groupFilters = []
        super.init()
        setupCaptureSession()
        // 生成全局纹理缓存，Generate a global texture cache.
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, Device.device(), nil, &textureCache)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCaptureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
        guard let camera = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: camera) else {
                  return
              }
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        // video output
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.collector.metal"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        if let connection = videoOutput.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!
        }
        captureSession.commitConfiguration()
    }
}

extension C7FilterCollector: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        guard let inputTexture = processNext(pixelBuffer: pixelBuffer, textureCache: textureCache) else {
            return
        }
        var destTexture: MTLTexture = inputTexture
        for filter in groupFilters {
            if let outTexture = try? Processed.generateOutTexture(inTexture: destTexture, filter: filter) {
                destTexture = outTexture
            }
        }
        guard let image = destTexture.toImage() else {
            return
        }
        if let textureCache = textureCache {
            CVMetalTextureCacheFlush(textureCache, 0);
        }
        DispatchQueue.main.sync { callback(image) }
    }
}

extension C7FilterCollector {
    
    func processNext(pixelBuffer: CVPixelBuffer, textureCache: CVMetalTextureCache?) -> MTLTexture? {
        guard let textureCache = textureCache else {
            return nil
        }
        var cvmTexture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                  textureCache,
                                                  pixelBuffer,
                                                  nil,
                                                  MTLPixelFormat.bgra8Unorm,
                                                  CVPixelBufferGetWidth(pixelBuffer),
                                                  CVPixelBufferGetHeight(pixelBuffer),
                                                  0,
                                                  &cvmTexture)
        if let cvmTexture = cvmTexture, let texture = CVMetalTextureGetTexture(cvmTexture) {
            return texture
        }
        return nil
    }
}
