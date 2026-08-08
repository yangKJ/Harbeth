//
//  ChromaKeyView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2026/3/14.
//

import SwiftUI
import Harbeth

struct ChromaKeyView: View {
    @State private var thresholdSensitivity: Float = 0.3
    @State private var smoothing: Float = 0.1
    @State private var chromaColor: Color = .blue
    @State private var replaceColor: Color = .green
    @State private var inputImage: C7Image = R.image("Bear")!
    
    var body: some View {
        VStack {
            DemoFilteredImage(image: inputImage, filters: [
                C7ChromaKey(
                    thresholdSensitivity: thresholdSensitivity,
                    smoothing: smoothing,
                    chroma: C7Color(chromaColor),
                    replace: C7Color(replaceColor)
                )
            ], content: { image in
                image.resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    .padding(.horizontal, 16)
            })
            
            VStack(alignment: .leading, spacing: 20) {
                // Threshold Sensitivity
                VStack(alignment: .leading) {
                    Text("Threshold Sensitivity: \(thresholdSensitivity, specifier: "%.2f")")
                    Slider(value: $thresholdSensitivity, in: 0.0...1.0).accentColor(Color(hex: "#5E9EFF"))
                }
                
                // Smoothing
                VStack(alignment: .leading) {
                    Text("Smoothing: \(smoothing, specifier: "%.2f")")
                    Slider(value: $smoothing, in: 0.0...1.0).accentColor(Color(hex: "#5E9EFF"))
                }
                
                // Chroma Color
                HStack {
                    Text("Chroma Color").foregroundColor(.white.opacity(0.94))
                    Spacer()
                    ZStack {
                        ColorPicker("", selection: $chromaColor)
                            .labelsHidden()
                        Rectangle()
                            .fill(chromaColor)
                            .frame(width: 30, height: 30)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
                            .allowsHitTesting(false)
                    }
                }
                
                // Replace Color
                HStack {
                    Text("Replace Color").foregroundColor(.white.opacity(0.94))
                    Spacer()
                    ZStack {
                        ColorPicker("", selection: $replaceColor)
                            .labelsHidden()
                        Rectangle()
                            .fill(replaceColor)
                            .frame(width: 30, height: 30)
                            .cornerRadius(8)
                            .allowsHitTesting(false)
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
            .padding()
        }
        .padding(.bottom)
        .toolbar(content: { Spacer() })
        .navigationTitle("Chroma Key")
    }
}

struct ChromaKeyView_Previews: PreviewProvider {
    static var previews: some View {
        ChromaKeyView()
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
