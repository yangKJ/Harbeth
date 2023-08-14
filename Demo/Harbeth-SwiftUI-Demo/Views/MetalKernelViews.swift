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
            }, min: C7SoulOut.range.min, max: C7SoulOut.range.max)) {
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
                var filter = C7ColorConvert(with: .gray)
                filter.intensity = $0
                return filter
            }, min: R.iRange.min, max: R.iRange.max)) {
                Text("Gray image")
            }
        }
        .padding(.bottom)
        .listStyle(.sidebar)
        .textCase(.none)
        .groupedListStyle()
        .inlineNavigationBarTitle("Metal kernel")
    }
}
