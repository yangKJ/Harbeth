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
            NavigationLink(destination: ColorRGBAView()) {
                Text("C7 Color RGBA Test")
            }
            NavigationLink(destination: CurvesView()) {
                Text("C7 Curves Test")
            }
            NavigationLink(destination: HSLView()) {
                Text("C7 HSL Test")
            }
            NavigationLink(destination: CustomViews(value: 90, filtering: {
                C7Rotate.init(angle: $0)
            }, min: 0, max: 360, inputImage: R.image("yuan002"))) {
                Text("C7 Rotate")
            }
            NavigationLink(destination: CustomViews(value: C7SoulOut.range.value, filtering: {
                C7SoulOut.init(soul: $0)
            }, min: C7SoulOut.range.min, max: C7SoulOut.range.max, inputImage: R.image("yuan002"))) {
                Text("C7 Soul out")
            }
            NavigationLink(destination: CustomViews(value: C7Pixellated.range.value, filtering: {
                C7Pixellated.init(scale: $0)
            }, min: C7Pixellated.range.min, max: C7Pixellated.range.max, inputImage: R.image("yuan002"))) {
                Text("C7 Pixellated")
            }
            NavigationLink(destination: CustomViews(value: C7PolarPixellate.range.value, filtering: {
                C7PolarPixellate.init(scale: $0)
            }, min: C7PolarPixellate.range.min, max: C7PolarPixellate.range.max, inputImage: R.image("yuan002"))) {
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
            }, min: C7CircleBlur.range.min, max: C7CircleBlur.range.max, inputImage: R.image("yuan002"))) {
                Text("C7 Circle Blur")
            }
            NavigationLink(destination: CustomViews(value: 0.2, filtering: {
                C7StickerOutline(outlineColor: .red, outlineThickness: 0.015, outlineBlur: $0)
            }, min: R.iRange.min, max: R.iRange.max, inputImage: R.image("yuan002"))) {
                Text("C7 Sticker Outline Test")
            }
            NavigationLink(destination: CustomViews(value: C7Temperature.range.value, filtering: {
                var filter = C7Temperature()
                filter.temperature = $0
                filter.tint = $0
                filter.colorShift = $0
                return filter
            }, min: C7Temperature.range.min, max: C7Temperature.range.max, inputImage: R.image("yuan002"))) {
                Text("C7 Temperature Test")
            }
            NavigationLink(destination: CustomViews(value: C7Fade.range.value, filtering: {
                C7Fade.init(intensity: $0)
            }, min: C7Fade.range.min, max: C7Fade.range.max, inputImage: R.image("yuan002"))) {
                Text("C7 Fade Test")
            }
            NavigationLink(destination: CustomViews(value: C7Warmth.range.value, filtering: {
                C7Warmth.init(warmth: $0)
            }, min: C7Warmth.range.min, max: C7Warmth.range.max, inputImage: R.image("yuan002"))) {
                Text("C7 Warmth Test")
            }
        }
        .padding(.bottom)
        .listStyle(.sidebar)
        .textCase(.none)
        .groupedListStyle()
        .inlineNavigationBarTitle("Metal Filters")
    }
}

struct MetalKernelViews_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MetalKernelViews()
        }
    }
}
