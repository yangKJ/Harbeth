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
                        ShowcaseRow(title: "Video / LUT / HDR Pipeline", subtitle: "Metal kernels for frame-oriented effects")
                    }
                } header: {
                    Text("Showcase").bold().textCase(.none)
                }

                Section {
                    NavigationLink(destination: DoubleBufferView()) {
                        Text("Double Buffer")
                    }
                    NavigationLink(destination: CurvesView()) {
                        Text("Curves")
                    }
                    NavigationLink(destination: HSLView()) {
                        Text("HSL")
                    }
                    NavigationLink(destination: ColorRGBAView()) {
                        Text("Color")
                    }
                    NavigationLink(destination: CubeView()) {
                        Text("Cube")
                    }
                    NavigationLink(destination: BlendView()) {
                        Text("Blend")
                    }
                    NavigationLink(destination: HighlightShadowToneView()) {
                        Text("Highlight Shadow")
                    }
                    NavigationLink(destination: ChromaKeyView()) {
                        Text("Chroma Key")
                    }
                    NavigationLink(destination: ChannelControlView()) {
                        Text("Channel Control")
                    }
                } header: {
                    Text("Examples").bold().textCase(.none)
                }
                
                Section {
                    NavigationLink(destination: MetalKernelViews()) {
                        Text("Metal filters")
                    }
                }
                
                Section {
                    NavigationLink(destination: CustomViews(value: MPSGaussianBlur.range.value, filtering: {
                        MPSGaussianBlur.init(radius: $0)
                    }, min: MPSGaussianBlur.range.min, max: MPSGaussianBlur.range.max)) {
                        Text("MPS gaussian blur")
                    }
                } header: {
                    Text("MPS").bold().textCase(.none)
                }
            }
            .padding(.bottom)
            .listStyle(.sidebar)
            .textCase(.none)
            .groupedListStyle()
            .inlineNavigationBarTitle("Harbeth Examples")
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
