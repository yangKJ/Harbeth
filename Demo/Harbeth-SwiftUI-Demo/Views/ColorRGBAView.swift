//
//  ColorRGBAView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2026/3/10.
//

import SwiftUI
import Harbeth

struct ColorRGBAView: View {
    @State private var intensity: Float = R.intensityRange.value
    @State private var selectedColor: Color = .red
    @State private var inputImage: UIImage = R.image("yuan002")!
    
    let colors: [Color] = [
        .red, .green, .blue, .yellow, .purple, .orange, .pink, .teal
    ]
    
    var body: some View {
        VStack {
            HarbethView(image: inputImage, filters: [createFilter()]) {
                $0.resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 400)
            }
            
            VStack(spacing: 20) {
                // 强度调整滑块
                VStack(alignment: .leading) {
                    Text("Intensity: \(String(format: "%.2f", intensity))")
                    Slider(value: $intensity, in: 0...1)
                        .padding(.horizontal)
                }
                
                // 颜色选择器
                VStack(alignment: .leading) {
                    Text("Select Color:")
                    HStack(spacing: 10) {
                        ForEach(colors, id: \.self) {
                            color in
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    selectedColor == color ?
                                        Circle().stroke(Color.white, lineWidth: 3)
                                        : nil
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                }
                
                // 颜色预览
                HStack {
                    Text("Current Color:")
                    Rectangle()
                        .fill(selectedColor)
                        .frame(width: 50, height: 30)
                        .cornerRadius(5)
                }
            }
            .padding()
        }
        .padding()
        .navigationTitle("C7 ColorRGBA Test")
    }
    
    func createFilter() -> C7FilterProtocol {
        let c7Color = C7Color(selectedColor)
        var filter = C7ColorRGBA(color: c7Color)
        filter.intensity = intensity
        return filter
    }
}

struct C7ColorRGBAView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ColorRGBAView()
        }
    }
}
