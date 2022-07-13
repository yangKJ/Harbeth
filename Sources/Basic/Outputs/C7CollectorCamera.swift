//
//  C7CollectorCamera.swift
//  Harbeth
//
//  Created by Condy on 2022/2/25.
//

import Foundation

/// 相机数据采集器，在主线程返回图片
/// The camera data collector returns pictures in the main thread.
public final class C7CollectorCamera: C7Collector {
    
    public lazy var captureSession: AVCaptureSession = AVCaptureSession()
    
    private let videoQueue = DispatchQueue(label: "camera.collector.metal")
    private lazy var sessionQueue = DispatchQueue(label: "camera.session.collector.metal")
    private lazy var videoOutput = AVCaptureVideoDataOutput()
    
    required init(callback: @escaping C7FilterImageCallback) {
        super.init(callback: callback)
        setupCaptureSession()
    }
    
    required init(view: C7View) {
        super.init(view: view)
        setupCaptureSession()
    }
    
    public var videoOrientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            guard let connection = videoOutput.connection(with: .video),
                  connection.isVideoOrientationSupported else {
                return
            }
            connection.videoOrientation = videoOrientation
        }
    }
}

extension C7CollectorCamera {
    
    public func startCollector() {
        sessionQueue.async{
            self.captureSession.startRunning()
        }
    }
    
    public func stopCollector() {
        sessionQueue.async{
            self.captureSession.stopRunning()
        }
    }
}

extension C7CollectorCamera {
    func setupCaptureSession() {
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
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        if let connection = videoOutput.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = videoOrientation
        }
        captureSession.commitConfiguration()
    }
}

extension C7CollectorCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        if let image = pixelBuffer2Image(pixelBuffer) {
            DispatchQueue.main.async { self.callback(image) }
        }
    }
}
