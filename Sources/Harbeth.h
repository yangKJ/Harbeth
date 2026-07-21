//
//  Harbeth.h
//
//  Copyright (c) 2022 Condy https://github.com/YangKJ
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// Harbeth 是面向 Apple 平台、以 texture-first 为核心的 Metal 图像与帧处理引擎。
// 它负责 image / texture / pixelBuffer / sampleBuffer 的逐帧 GPU 处理与预览宿主支撑，
// 不接管相机、播放器、时间线、录制、导出或持久化等媒体产品流程。

// Harbeth is a texture-first Metal render engine for Apple image and frame pipelines.
// It owns per-frame GPU processing and preview-host support for image, texture,
// pixel-buffer, and sample-buffer sources without owning the host media workflow.

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT double HarbethVersionNumber;

FOUNDATION_EXPORT const unsigned char HarbethVersionString[];

/// Quickly add filters to sources.
/// Support use `UIImage/NSImage, CGImage, MTLTexture, CMSampleBuffer, CVPixelBuffer/CVImageBuffer`
///
/// For example:
///
///     let filter = C7Storyboard(ranks: 2)
///     let dest = HarbethIO.init(element: originImage, filter: filter)
///     ImageView.image = try? dest.output()
///
///     // Asynchronous add filters to sources.
///     dest.transmitOutput(success: { [weak self] image in
///         // do somthing..
///     })
///
