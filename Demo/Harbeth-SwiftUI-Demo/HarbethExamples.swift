//
//  HarbethExamples.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/3/21.
//

import SwiftUI

@main
struct HarbethExamples: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(width: 888, height: 600)
                #endif
        }
    }
}
