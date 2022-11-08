//
//  AppDelegate.swift
//  Dancing
//
//  Created by Condy on 2022/11/6.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    lazy var window: NSWindow = {
        let rect = NSMakeRect(0, 0, 700, 700)
        let mask = [.titled, .resizable, .miniaturizable, .closable, .fullSizeContentView] as NSWindow.StyleMask
        let window = NSWindow(contentRect: rect, styleMask: mask, backing: .buffered, defer: false)
        window.minSize = window.frame.size
        window.maxSize = window.frame.size
        window.center()
        return window
    }()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.mainWindow?.title = "Unit testing"
        let vc = ViewController()
        window.contentViewController = vc
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
