//
//  ChannelControlView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2026/3/14.
//

import Foundation
import SwiftUI
import Harbeth

struct ChannelControlView: View {
    @State private var red: Float = 0.0
    @State private var green: Float = 0.0
    @State private var blue: Float = 1.0
    @State private var alpha: Float = 1.0
    @State private var blend: Float = 0.5
    @State private var inputImage = R.image("Bear")!
    
    var body: some View {
        VStack(spacing: 20) {
            HarbethView(image: inputImage, filters: [C7ChannelControl(
                red: red,
                green: green,
                blue: blue,
                alpha: alpha,
                blend: blend
            )]) {
                $0.resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 400)
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
            
            VStack(spacing: 15) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Red: \(String(format: "%.2f", red))")
                        Spacer()
                        Text("-1")
                        Spacer()
                        Text("1")
                    }
                    Slider(value: $red, in: -1.0...1.0)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Green: \(String(format: "%.2f", green))")
                        Spacer()
                        Text("-1")
                        Spacer()
                        Text("1")
                    }
                    Slider(value: $green, in: -1.0...1.0)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Blue: \(String(format: "%.2f", blue))")
                        Spacer()
                        Text("-1")
                        Spacer()
                        Text("1")
                    }
                    Slider(value: $blue, in: -1.0...1.0)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Alpha: \(String(format: "%.2f", alpha))")
                        Spacer()
                        Text("0")
                        Spacer()
                        Text("1")
                    }
                    Slider(value: $alpha, in: 0.0...1.0)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Blend: \(String(format: "%.2f", blend))")
                        Spacer()
                        Text("0")
                        Spacer()
                        Text("1")
                    }
                    Slider(value: $blend, in: 0.0...1.0)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
        .navigationTitle("Channel Control")
    }
}

struct ChannelControlView_Previews: PreviewProvider {
    static var previews: some View {
        ChannelControlView()
    }
}

