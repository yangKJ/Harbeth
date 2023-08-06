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
        NavigationView {
            List {
                NavigationLink(destination: AsyncImageView()) {
                    Text("Async Load Image")
                }
                NavigationLink(destination: SwiftUIView()) {
                    Text("Supports use of SwiftUI")
                }
                Section {
                    NavigationLink(destination: BlendView()) {
                        Text("Blend Modes")
                    }
                    NavigationLink(destination: CustomViews(value: C7SoulOut.range.value, filtering: {
                        C7SoulOut.init(soul: $0)
                    }, min: C7SoulOut.range.min, max: C7SoulOut.range.max)) {
                        Text("Soul out")
                    }
                } header: {
                    Text("Metal kernel").bold().textCase(.none)
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
                Section {
                    NavigationLink(destination: CubeView()) {
                        Text("CI Color Cube")
                    }
                    NavigationLink(destination: CustomViews(value: CILookupTable.range.value, filtering: {
                        CILookupTable(cubeName: "violet", amount: $0)
                    }, min: CILookupTable.range.min, max: CILookupTable.range.max)) {
                        Text("CI Lookup Talbe")
                    }
                    NavigationLink(destination: CustomViews(value: CIGaussianBlur.range.value, filtering: {
                        CIGaussianBlur.init(radius: $0)
                    }, min: CIGaussianBlur.range.min, max: CIGaussianBlur.range.max)) {
                        Text("CI Gaussian Blur filter")
                    }
                    NavigationLink(destination: CustomViews(value: CIBrightness.range.value, filtering: {
                        CIBrightness.init(brightness: $0)
                    }, min: CIBrightness.range.min, max: CIBrightness.range.max)) {
                        Text("CI Brightness filter")
                    }
                    NavigationLink(destination: CustomViews(value: CISaturation.range.value, filtering: {
                        CISaturation.init(saturation: $0)
                    }, min: CISaturation.range.min, max: CISaturation.range.max)) {
                        Text("CI Saturation filter")
                    }
                    NavigationLink(destination: CustomViews(value: CIContrast.range.value, filtering: {
                        CIContrast.init(contrast: $0)
                    }, min: CIContrast.range.min, max: CIContrast.range.max)) {
                        Text("CI Contrast filter")
                    }
                    NavigationLink(destination: CustomViews(value: CIFade.range.value, filtering: {
                        CIFade.init(intensity: $0)
                    }, min: CIFade.range.min, max: CIFade.range.max)) {
                        Text("CI Fade filter")
                    }
                    NavigationLink(destination: CustomViews(value: CITemperature.range.value, filtering: {
                        CITemperature.init(temperature: $0)
                    }, min: CITemperature.range.min, max: CITemperature.range.max)) {
                        Text("CI Temperature filter")
                    }
                    NavigationLink(destination: CustomViews(value: CISharpen.range.value, filtering: {
                        CISharpen.init(sharpness: $0, radius: 10)
                    }, min: CISharpen.range.min, max: CISharpen.range.max)) {
                        Text("CI Sharpen filter")
                    }
                    NavigationLink(destination: CustomViews(value: CIVignette.range.value, filtering: {
                        CIVignette.init(vignette: $0)
                    }, min: CIVignette.range.min, max: CIVignette.range.max)) {
                        Text("CI Vignette filter")
                    }
                } header: {
                    Text("CoreImage").bold().textCase(.none)
                }
            }
            .padding(.bottom)
            .listStyle(.sidebar)
            .textCase(.none)
            .groupedListStyle()
            .inlineNavigationBarTitle("Harbeth Examples")
            
            VStack(spacing: 6) {
                Text("Welcome to Harbeth examples.")
                Text("Select a topic to begin.").font(Font.caption).foregroundColor(.secondary)
            }.toolbar(content: { Spacer() })
        }
        .stackNavigationViewStyle()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewDevice("iPad (8th generation)")
    }
}
