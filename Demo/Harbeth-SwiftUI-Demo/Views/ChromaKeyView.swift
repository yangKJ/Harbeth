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
            HarbethView(image: inputImage, filters: [
                C7ChromaKey(
                    thresholdSensitivity: thresholdSensitivity,
                    smoothing: smoothing,
                    chroma: C7Color(chromaColor),
                    replace: C7Color(replaceColor)
                )
            ], content: { image in
                image.resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
            }, async: true)
            
            VStack(alignment: .leading, spacing: 20) {
                // Threshold Sensitivity
                VStack(alignment: .leading) {
                    Text("Threshold Sensitivity: \(thresholdSensitivity, specifier: "%.2f")")
                    Slider(value: $thresholdSensitivity, in: 0.0...1.0)
                }
                
                // Smoothing
                VStack(alignment: .leading) {
                    Text("Smoothing: \(smoothing, specifier: "%.2f")")
                    Slider(value: $smoothing, in: 0.0...1.0)
                }
                
                // Chroma Color
                HStack {
                    Text("Chroma Color")
                    Spacer()
                    ZStack {
                        ColorPicker("", selection: $chromaColor)
                            .labelsHidden()
                        Rectangle()
                            .fill(chromaColor)
                            .frame(width: 30, height: 30)
                            .cornerRadius(8)
                            .allowsHitTesting(false)
                    }
                }
                
                // Replace Color
                HStack {
                    Text("Replace Color")
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
            .background(RoundedRectangle(cornerRadius: 10).foregroundColor(Color.background))
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
