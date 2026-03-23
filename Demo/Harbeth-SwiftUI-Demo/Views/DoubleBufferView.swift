//
//  DoubleBufferView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2026/3/22.
//

import Foundation
import SwiftUI
import Harbeth

struct DoubleBufferView: View {
    @State private var filterCount: Int = 5
    @State private var doubleBufferTime: String = "0.000s"
    @State private var traditionalTime: String = "0.000s"
    @State private var doubleBufferMemory: String = "0.00 MB"
    @State private var traditionalMemory: String = "0.00 MB"
    @State private var doubleBufferStats: String = ""
    @State private var traditionalStats: String = ""
    @State private var inputImage = R.image("Bear")!
    @State private var doubleBufferImage: C7Image?
    @State private var traditionalImage: C7Image?
    @State private var isProcessing: Bool = false
    
    private let maxFilterCount: Int = 30
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 图像对比区域
                HStack(spacing: 16) {
                    // 左边：开启双缓冲
                    VStack(spacing: 10) {
                        Text("Double Buffer")
                            .font(.headline)
                            .foregroundColor(.blue)
                        if let doubleBufferImage = doubleBufferImage {
                            Image(c7Image: doubleBufferImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: 250)
                                .transition(.scale)
                        } else {
                            Image(c7Image: inputImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: 250)
                        }
                        Text("Time: \(doubleBufferTime)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    
                    // 右边：传统方式
                    VStack(spacing: 10) {
                        Text("Traditional")
                            .font(.headline)
                            .foregroundColor(.indigo)
                        if let traditionalImage = traditionalImage {
                            Image(c7Image: traditionalImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: 250)
                                .transition(.scale)
                        } else {
                            Image(c7Image: inputImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: 250)
                        }
                        Text("Time: \(traditionalTime)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                }
                
                // 处理按钮
                Button(action: { processImages() }, label: {
                    Text("Process Images")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(radius: 3)
                })
                .disabled(isProcessing)
                .opacity(isProcessing ? 0.7 : 1.0)
                
                // 过滤器数量滑块
                VStack(alignment: .leading) {
                    HStack {
                        Text("Filter Count: \(filterCount)")
                            .font(.headline)
                        Spacer()
                        Text("1")
                        Spacer()
                        Text("\(maxFilterCount)")
                    }
                    Slider(value: Binding(
                        get: { Double(filterCount) },
                        set: { filterCount = Int($0) }
                    ), in: 1...Double(maxFilterCount))
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // 对比结果
                VStack(spacing: 10) {
                    // 内存使用对比
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Memory Usage Comparison:")
                            .font(.headline)
                        HStack {
                            Text("Double Buffer: \(doubleBufferMemory)")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                            Spacer()
                            Text("Traditional: \(traditionalMemory)")
                                .font(.system(size: 14))
                                .foregroundColor(.indigo)
                        }
                        // 内存差异指示器
                        if !doubleBufferMemory.isEmpty && !traditionalMemory.isEmpty {
                            let doubleBufferMemoryValue = Double(doubleBufferMemory.replacingOccurrences(of: " MB", with: "")) ?? 0
                            let traditionalMemoryValue = Double(traditionalMemory.replacingOccurrences(of: " MB", with: "")) ?? 0
                            let difference = (doubleBufferMemoryValue - traditionalMemoryValue) / traditionalMemoryValue * 100
                            Text("Memory Difference: \(String(format: "%.1f%%", abs(difference))) \(difference > 0 ? "more" : "less")")
                                .font(.system(size: 12))
                                .foregroundColor(difference > 0 ? .red : .green)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // 纹理池统计对比
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Texture Pool Statistics:")
                            .font(.headline)
                        
                        Text("Double Buffer:")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        Text(doubleBufferStats)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Text("Traditional Method:")
                            .font(.subheadline)
                            .foregroundColor(.indigo)
                        Text(traditionalStats)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // 底部空间
                Spacer(minLength: 40)
            }
            .padding()
            .navigationTitle("Double Buffer Comparison")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func processImages() {
//        isProcessing = true
        var filters: [C7FilterProtocol] = []
        for i in 0..<filterCount {
            switch i % 5 {
            case 0:
                filters.append(C7Brightness(brightness: 0.1))
            case 1:
                filters.append(C7Contrast(contrast: 1.1))
            case 2:
                filters.append(C7Saturation(saturation: 1.1))
            case 3:
                filters.append(C7CombinationColorGrading())
            case 4:
                filters.append(C7Sharpen(sharpness: 0.5))
            default:
                break
            }
        }
        
        // 处理双缓冲方式
        processWithDoubleBuffer(filters: filters)
        
        // 处理传统方式
        processWithTraditionalMethod(filters: filters)
        
//        isProcessing = false
    }
    
    private func processWithDoubleBuffer(filters: [C7FilterProtocol]) {
        // 重置纹理池统计
        Shared.shared.resetTexturePoolStatistics()
        
        // 记录开始时间
        let startTime = CACurrentMediaTime()
        
        // 创建HarbethIO实例，开启双缓冲
        var io = HarbethIO(element: inputImage, filters: filters)
        io.enableDoubleBuffer = true
        
        // 处理图像
        do {
            let result = try io.output()
            doubleBufferImage = result
            
            // 计算处理时间
            let endTime = CACurrentMediaTime()
            let timeElapsed = endTime - startTime
            doubleBufferTime = String(format: "%.3fs", timeElapsed)
            
            // 获取内存使用情况
            if let stats = Shared.shared.texturePoolStatistics {
                doubleBufferMemory = String(format: "%.2f MB", Double(stats.currentMemoryUsage) / 1024 / 1024)
                doubleBufferStats = "Created: \(stats.totalTexturesCreated), Reused: \(stats.totalTexturesReused), Hit Rate: \(String(format: "%.1f%%", stats.hitRate * 100)), Saved: \(String(format: "%.2f MB", Double(stats.totalMemorySaved) / 1024 / 1024)), Peak: \(String(format: "%.2f MB", Double(stats.peakMemoryUsage) / 1024 / 1024)), Avg: \(String(format: "%.2f MB", stats.averageMemoryUsage / 1024 / 1024)), Count: \(stats.currentTextureCount)"
            }
        } catch {
            print("Error processing with double buffer: \(error)")
        }
    }
    
    private func processWithTraditionalMethod(filters: [C7FilterProtocol]) {
        // 重置纹理池统计
        Shared.shared.resetTexturePoolStatistics()
        
        // 记录开始时间
        let startTime = CACurrentMediaTime()
        
        // 创建HarbethIO实例，禁用双缓冲
        var io = HarbethIO(element: inputImage, filters: filters)
        io.enableDoubleBuffer = false
        
        // 处理图像
        do {
            let result = try io.output()
            traditionalImage = result
            
            // 计算处理时间
            let endTime = CACurrentMediaTime()
            let timeElapsed = endTime - startTime
            traditionalTime = String(format: "%.3fs", timeElapsed)
            
            // 获取内存使用情况
            if let stats = Shared.shared.texturePoolStatistics {
                traditionalMemory = String(format: "%.2f MB", Double(stats.currentMemoryUsage) / 1024 / 1024)
                traditionalStats = "Created: \(stats.totalTexturesCreated), Reused: \(stats.totalTexturesReused), Hit Rate: \(String(format: "%.1f%%", stats.hitRate * 100)), Saved: \(String(format: "%.2f MB", Double(stats.totalMemorySaved) / 1024 / 1024)), Peak: \(String(format: "%.2f MB", Double(stats.peakMemoryUsage) / 1024 / 1024)), Avg: \(String(format: "%.2f MB", stats.averageMemoryUsage / 1024 / 1024)), Count: \(stats.currentTextureCount)"
            }
        } catch {
            print("Error processing with traditional method: \(error)")
        }
    }
}

struct DoubleBufferView_Previews: PreviewProvider {
    static var previews: some View {
        DoubleBufferView()
    }
}
