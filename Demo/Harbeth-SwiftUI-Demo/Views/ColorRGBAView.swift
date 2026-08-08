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
    @State private var selectedColor: Color = .yellow
    @State private var inputImage: C7Image = R.image("Bear")!
    
    let colors: [Color] = [
        .red, .green, .blue, .yellow, .purple, .orange, .pink, .teal
    ]
    
    var body: some View {
        VStack {
            DemoFilteredImage(image: inputImage, filters: [createFilter()]) {
                $0.resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 400)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
            .padding(.horizontal, 16)
            
            VStack(spacing: 20) {
                // 强度调整滑块
                VStack(alignment: .leading) {
                    Text("Intensity: \(String(format: "%.2f", intensity))")
                    Slider(value: $intensity, in: 0...1).accentColor(Color(hex: "#5E9EFF"))
                        .padding(.horizontal)
                }
                
                // 颜色选择器
                VStack(alignment: .leading) {
                    Text("Select Color:").foregroundColor(.white.opacity(0.94))
                    HStack(spacing: 10) {
                        ForEach(colors, id: \.self) {
                            color in
                            Circle()
                                .fill(color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    selectedColor == color ?
                                        Circle().stroke(Color(hex: "#5E9EFF"), lineWidth: 3)
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
                    Text("Current Color:").foregroundColor(.white.opacity(0.94))
                    ZStack {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 50, height: 30)
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        ColorPicker("", selection: $selectedColor)
                            .labelsHidden()
                        Rectangle()
                            .fill(selectedColor)
                            .frame(width: 50, height: 30)
                            .cornerRadius(5)
                            .allowsHitTesting(false)
                    }
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



// MARK: - Design System Colors (synced with ContentView)
private extension View {
    var dsSurfaceGlass: Color { Color.white.opacity(0.06) }
    var dsSurfaceCard: Color { Color(hex: "#141418") }
    var dsBackground: Color { Color(hex: "#0A0A0C") }
    var dsBorderSubtle: Color { Color.white.opacity(0.06) }
    var dsBorderActive: Color { Color.white.opacity(0.14) }
    var dsTextPrimary: Color { Color.white.opacity(0.94) }
    var dsTextSecondary: Color { Color.white.opacity(0.62) }
    var dsTextTertiary: Color { Color.white.opacity(0.38) }
}

private let dsAccentPrimary = Color(hex: "#5E9EFF")
private let dsAccentSecondary = Color(hex: "#A78BFA")
private let dsAccentSuccess = Color(hex: "#34D399")
