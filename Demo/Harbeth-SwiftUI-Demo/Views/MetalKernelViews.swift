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
            NavigationLink(destination: CustomViews(value: C7TiltShift.range.value, filtering: {
                C7TiltShift.init(blurRadius: $0)
            }, min: C7TiltShift.range.min, max: C7TiltShift.range.max, inputImage: R.image("yuan002"))) {
                Text("C7 Tilt Shift Test")
            }
            NavigationLink(destination: CustomViews(value: 0.5, filtering: {
                var filter = C7Clarity()
                filter.intensity = $0
                return filter
            }, min: 0.0, max: 1.0, inputImage: R.image("yuan002"))) {
                Text("C7 Clarity Test")
            }
            NavigationLink(destination: ToneAdjustmentView()) {
                Text("C7 Tone Adjustment Test")
            }
            NavigationLink(destination: SharpenDetailView()) {
                Text("C7 Sharpen Detail Test")
            }
            NavigationLink(destination: ColorCorrectionView()) {
                Text("C7 Color Correction Test")
            }
            NavigationLink(destination: ChannelControlView()) {
                Text("C7 Channel Control Test")
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

struct ToneAdjustmentView: View {
    @State private var shadows: Float = 0.0
    @State private var highlights: Float = 0.0
    @State private var midtones: Float = 0.0
    @State private var contrast: Float = 0.0
    @State private var inputImage = R.image("Bear")!
    
    var body: some View {
        VStack(spacing: 20) {
            Text("C7 Tone Adjustment Test")
                .font(.title)
                .bold()
            
            HarbethView(image: inputImage, filters: [C7ToneAdjustment(
                shadows: shadows,
                highlights: highlights,
                midtones: midtones,
                contrast: contrast
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
                        Text("Shadows: \(String(format: "%.2f", shadows))")
                        Spacer()
                        Text("-1")
                        Spacer()
                        Text("1")
                    }
                    Slider(value: $shadows, in: -1.0...1.0)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Highlights: \(String(format: "%.2f", highlights))")
                        Spacer()
                        Text("-1")
                        Spacer()
                        Text("1")
                    }
                    Slider(value: $highlights, in: -1.0...1.0)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Midtones: \(String(format: "%.2f", midtones))")
                        Spacer()
                        Text("-1")
                        Spacer()
                        Text("1")
                    }
                    Slider(value: $midtones, in: -1.0...1.0)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Contrast: \(String(format: "%.2f", contrast))")
                        Spacer()
                        Text("-1")
                        Spacer()
                        Text("1")
                    }
                    Slider(value: $contrast, in: -1.0...1.0)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
        .navigationTitle("Tone Adjustment")
    }
}

struct ToneAdjustmentView_Previews: PreviewProvider {
    static var previews: some View {
        ToneAdjustmentView()
    }
}

struct SharpenDetailView: View {
    @State private var sharpen: Float = 0.0
    @State private var clarity: Float = 0.0
    @State private var detail: Float = 0.0
    @State private var inputImage = R.image("Bear")!
    
    var body: some View {
        VStack(spacing: 20) {
            Text("C7 Sharpen Detail Test")
                .font(.title)
                .bold()
            
            HarbethView(image: inputImage, filters: [C7SharpenDetail(
                sharpen: sharpen,
                clarity: clarity,
                detail: detail
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
                        Text("Sharpen: \(String(format: "%.2f", sharpen))")
                        Spacer()
                        Text("Low")
                        Spacer()
                        Text("High")
                    }
                    Slider(value: $sharpen, in: 0.0...1.0)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Clarity: \(String(format: "%.2f", clarity))")
                        Spacer()
                        Text("Low")
                        Spacer()
                        Text("High")
                    }
                    Slider(value: $clarity, in: 0.0...1.0)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Detail: \(String(format: "%.2f", detail))")
                        Spacer()
                        Text("Low")
                        Spacer()
                        Text("High")
                    }
                    Slider(value: $detail, in: 0.0...1.0)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
        .navigationTitle("Sharpen Detail")
    }
}

struct SharpenDetailView_Previews: PreviewProvider {
    static var previews: some View {
        SharpenDetailView()
    }
}

struct ColorCorrectionView: View {
    @State private var levels: Float = 0.0
    @State private var curves: Float = 0.0
    @State private var colorBalance: Float = 0.0
    @State private var inputImage = R.image("Bear")!
    
    var body: some View {
        VStack(spacing: 20) {
            Text("C7 Color Correction Test")
                .font(.title)
                .bold()
            
            HarbethView(image: inputImage, filters: [C7ColorCorrection(
                levels: levels,
                curves: curves,
                colorBalance: colorBalance
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
                        Text("Levels: \(String(format: "%.2f", levels))")
                        Spacer()
                        Text("-1")
                        Spacer()
                        Text("1")
                    }
                    Slider(value: $levels, in: -1.0...1.0)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Curves: \(String(format: "%.2f", curves))")
                        Spacer()
                        Text("-1")
                        Spacer()
                        Text("1")
                    }
                    Slider(value: $curves, in: -1.0...1.0)
                }
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Color Balance: \(String(format: "%.2f", colorBalance))")
                        Spacer()
                        Text("-1")
                        Spacer()
                        Text("1")
                    }
                    Slider(value: $colorBalance, in: -1.0...1.0)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
        .navigationTitle("Color Correction")
    }
}

struct ColorCorrectionView_Previews: PreviewProvider {
    static var previews: some View {
        ColorCorrectionView()
    }
}

struct ChannelControlView: View {
    @State private var red: Float = 0.0
    @State private var green: Float = 0.0
    @State private var blue: Float = 0.0
    @State private var alpha: Float = 1.0
    @State private var blend: Float = 0.0
    @State private var inputImage = R.image("Bear")!
    
    var body: some View {
        VStack(spacing: 20) {
            Text("C7 Channel Control Test")
                .font(.title)
                .bold()
            
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
                        Text("-1")
                        Spacer()
                        Text("1")
                    }
                    Slider(value: $blend, in: -1.0...1.0)
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
