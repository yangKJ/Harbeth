//
//  CoreImageViews.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/8/6.
//

import SwiftUI
import Harbeth

struct CoreImageViews: View {
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
        }
        .padding(.bottom)
        .listStyle(.sidebar)
        .textCase(.none)
        .groupedListStyle()
        .inlineNavigationBarTitle("CoreImage")
    }
}

struct CoreImageViews_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CoreImageViews()
        }
    }
}
