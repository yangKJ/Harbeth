//
//  main.swift
//  Harbeth-macOS-Demo
//
//  Created by Condy on 2023/2/9.
//

import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
