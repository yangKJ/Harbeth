//
//  AppDelegate.swift
//  Harbeth-macOS-Demo
//
//  Created by Condy on 2023/2/9.
//

import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    
    var window: NSWindow!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let rect = NSMakeRect(0, 0, 1400, 900)
        let mask: NSWindow.StyleMask = [.titled, .resizable, .miniaturizable, .closable, .fullSizeContentView]
        window = NSWindow(contentRect: rect, styleMask: mask, backing: .buffered, defer: false)
        window.center()
        window.title = "Harbeth Demo"
        let vc = ViewController()
        window.contentViewController = vc
        window.makeKeyAndOrderFront(nil)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return false
    }
}
