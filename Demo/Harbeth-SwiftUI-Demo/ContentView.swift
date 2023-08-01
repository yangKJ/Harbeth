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
                NavigationLink(destination: BlendView()) {
                    Text("Blend Modes")
                }
                NavigationLink(destination: AsyncImageView()) {
                    Text("Async Load Image")
                }
            }
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
