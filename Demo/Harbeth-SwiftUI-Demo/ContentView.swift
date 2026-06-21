//
//  ContentView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/3/21.
//

import SwiftUI
import Harbeth

struct ContentView: View {
    var body: some View {
        setupContentView()
    }
    
    func setupContentView() -> some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(destination: CubeView()) {
                        ShowcaseRow(title: "Cinematic Color Grading", subtitle: "CUBE LUT with native Metal processing")
                    }
                    NavigationLink(destination: DoubleBufferView()) {
                        ShowcaseRow(title: "Real-time Frame Processing", subtitle: "Filter chains, texture reuse, and double buffering")
                    }
                    NavigationLink(destination: MetalKernelViews()) {
                        ShowcaseRow(title: "Metal Runtime and Custom Kernels", subtitle: "Frame-oriented kernels, custom effects, and reusable runtime surfaces")
                    }
                } header: {
                    Text("Capability Showcase").bold().textCase(.none)
                }

                Section {
                    NavigationLink(destination: DoubleBufferView()) {
                        Text("Frame Runtime")
                    }
                    NavigationLink(destination: CurvesView()) {
                        Text("Curves and Tone")
                    }
                    NavigationLink(destination: HSLView()) {
                        Text("HSL Adjustments")
                    }
                    NavigationLink(destination: ColorRGBAView()) {
                        Text("Channel and Color Controls")
                    }
                    NavigationLink(destination: CubeView()) {
                        Text("LUT Pipeline")
                    }
                    NavigationLink(destination: BlendView()) {
                        Text("Blend and Compositing")
                    }
                    NavigationLink(destination: HighlightShadowToneView()) {
                        Text("Highlight and Shadow")
                    }
                    NavigationLink(destination: ChromaKeyView()) {
                        Text("Chroma Key")
                    }
                    NavigationLink(destination: ChannelControlView()) {
                        Text("Channel Isolation")
                    }
                } header: {
                    Text("Capability Examples").bold().textCase(.none)
                }
                
                Section {
                    NavigationLink(destination: MetalKernelViews()) {
                        Text("Custom Metal Filters")
                    }
                } header: {
                    Text("Metal Runtime").bold().textCase(.none)
                }
                
                Section {
                    NavigationLink(destination: CustomViews(value: MPSGaussianBlur.range.value, filtering: {
                        MPSGaussianBlur.init(radius: $0)
                    }, min: MPSGaussianBlur.range.min, max: MPSGaussianBlur.range.max)) {
                        Text("MPS Gaussian Blur")
                    }
                } header: {
                    Text("MPS").bold().textCase(.none)
                }
            }
            .padding(.bottom)
            .listStyle(.sidebar)
            .textCase(.none)
            .groupedListStyle()
            .inlineNavigationBarTitle("Harbeth Capability Demos")
        }
        .stackNavigationViewStyle()
    }
    
    func setupWelcome() -> some View {
        VStack(spacing: 5) {
            Text("Welcome to Harbeth examples.")
            Text("Select a topic to begin.").font(Font.caption).foregroundColor(.secondary)
        }.toolbar(content: { Spacer() })
    }
}

private struct ShowcaseRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.none)
        }
        .padding(.vertical, 4)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPad (8th generation)")
    }
}
