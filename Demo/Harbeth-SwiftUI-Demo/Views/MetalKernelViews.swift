//
//  MetalKernelViews.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/8/6.
//

import SwiftUI
import Harbeth

struct MetalKernelViews: View {
    var body: some View {
        #if os(macOS)
        NavigationView {
            setupContentView()
            setupWelcome()
        }.stackNavigationViewStyle()
        #else
        setupContentView()
        setupWelcome()
        #endif
    }
    
    func setupWelcome() -> some View {
        VStack(spacing: 6) {
            Text("Welcome to Harbeth examples.")
            Text("Select a topic to begin.").font(Font.caption).foregroundColor(.secondary)
        }.toolbar(content: { Spacer() })
    }
    
    func setupContentView() -> some View {
        List {
            NavigationLink(destination: CustomViews(value: C7SoulOut.range.value, filtering: {
                C7SoulOut.init(soul: $0)
            }, min: C7SoulOut.range.min, max: C7SoulOut.range.max, inputImage: R.image("yuan002"))) {
                Text("C7 Soul out")
            }
            NavigationLink(destination: CustomViews(value: C7Pixellated.range.value, filtering: {
                C7Pixellated.init(scale: $0)
            }, min: C7Pixellated.range.min, max: C7Pixellated.range.max)) {
                Text("C7 Pixellated")
            }
            NavigationLink(destination: CustomViews(value: C7PolarPixellate.range.value, filtering: {
                C7PolarPixellate.init(scale: $0)
            }, min: C7PolarPixellate.range.min, max: C7PolarPixellate.range.max)) {
                Text("C7 Polar Pixellate")
            }
            NavigationLink(destination: CustomViews<C7ColorConvert>(value: R.iRange.value, filtering: {
                var filter = C7ColorConvert(with: .bgra)
                filter.intensity = $0
                return filter
            }, min: R.iRange.min, max: R.iRange.max, inputImage: R.image("yuan002"))) {
                Text("C7 Color Convert to bgra image")
            }
            NavigationLink(destination: CustomViews<C7ComicStrip>(value: 0.5, filtering: {
                var filter = C7ComicStrip()
                filter.intensity = $0
                return filter
            }, min: R.iRange.min, max: R.iRange.max, inputImage: R.image("yuan002"))) {
                Text("C7 Comic Strip")
            }
            NavigationLink(destination: CustomViews<C7ColorMatrix4x4>(value: R.iRange.value, filtering: {
                var filter = C7ColorMatrix4x4(matrix: Matrix4x4.Color.greenDouble)
                filter.intensity = $0
                return filter
            }, min: R.iRange.min, max: R.iRange.max, inputImage: R.image("yuan002"))) {
                Text("C7 Matrix4x4 Green double")
            }
            NavigationLink(destination: CustomViews<C7LookupTable>(value: R.iRange.value, filtering: {
                var filter = C7LookupTable(name: "lut")
                filter.intensity = $0
                return filter
            }, min: R.iRange.min, max: R.iRange.max, inputImage: R.image("yuan002"))) {
                Text("C7 Lookup Table")
            }
            NavigationLink(destination: CustomViews(value: C7CircleBlur.range.value, filtering: {
                C7CircleBlur.init(radius: $0)
            }, min: C7CircleBlur.range.min, max: C7CircleBlur.range.max)) {
                Text("C7 Circle Blur")
            }
            NavigationLink(destination: CustomViews(value: C7ChromaKey.range.value, filtering: {
                C7ChromaKey.init(smoothing: $0, chroma: .red, replace: .purple)
            }, min: C7ChromaKey.range.min, max: C7ChromaKey.range.max, inputImage: R.image("IMG_2606"))) {
                Text("C7 Chroma Key red to purple")
            }
        }
        .padding(.bottom)
        .listStyle(.sidebar)
        .textCase(.none)
        .groupedListStyle()
        .inlineNavigationBarTitle("Metal kernel")
    }
}

struct MetalKernelViews_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MetalKernelViews()
        }
    }
}
