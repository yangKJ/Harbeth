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
                NavigationLink(destination: CubeView()) {
                    Text("Cube")
                }
                NavigationLink(destination: BlendView()) {
                    Text("Blend Modes")
                }
                NavigationLink(destination: CustomViews<C7CombinationBeautiful>(value: 0.0, filtering: {
                    C7CombinationBeautiful.init(smoothDegree: $0)
                }, min: -0.2, max: 0.2, inputImage: R.image("SampleImage"))) {
                    Text("Combination Beauty")
                }
                NavigationLink(destination: CustomViews<C7Brightness>(value: 0.0, filtering: {
                    C7Brightness.init(brightness: $0)
                }, min: 0.0, max: 1.0, inputImage: R.image("SP"))) {
                    Text("Brightness")
                }
                NavigationLink(destination: CoreImageViews()) {
                    Text("CoreImage filters")
                }
                NavigationLink(destination: MetalKernelViews()) {
                    Text("Metal kernel filters")
                }
                NavigationLink(destination: SwiftUIView()) {
                    Text("Use of SwiftUI")
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPad (8th generation)")
    }
}
