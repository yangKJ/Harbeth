//
//  Extensions.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/7/29.
//

import Foundation
import SwiftUI

extension View {
    func roundedRectangleButtonStyle() -> some View {
        #if os(iOS)
        return self.padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            .background(RoundedRectangle(cornerRadius: 10).foregroundColor(Color.background))
        #else
        return self
        #endif
    }
    
    func stackNavigationViewStyle() -> some View {
        #if os(iOS)
        return self.navigationViewStyle(StackNavigationViewStyle())
        #else
        return self
        #endif
    }
    
    func groupedListStyle() -> some View {
        #if os(iOS)
        return self.listStyle(GroupedListStyle())
        #else
        return self
        #endif
    }
    
    func inlineNavigationBarTitle<T>(_ title: T) -> some View where T: StringProtocol {
        #if os(iOS)
        return self.navigationBarTitle(title, displayMode: .inline)
        #else
        return self.navigationTitle(title)
        #endif
    }
    
    func largeControlSize() -> some View {
        #if os(macOS)
        return self.controlSize(.large)
        #else
        return self
        #endif
    }
    
    func smallControlSize() -> some View {
        #if os(macOS)
        return self.controlSize(.small)
        #else
        return self
        #endif
    }
    
    func toolbarMenu<T>(_ menu: T) -> some View where T: View {
        #if os(iOS)
        return self.navigationBarItems(trailing: menu)
        #else
        return self.toolbar(content: { menu })
        #endif
    }
    
    func pickerWidthLimit(_ width: CGFloat) -> some View {
        #if os(macOS)
        return self.frame(maxWidth: width)
        #else
        return self
        #endif
    }
    func macOSWindowFrame(width: CGFloat, height: CGFloat) -> some View {
        #if os(macOS)
        return self.frame(width: width, height: height)
        #else
        return self
        #endif
    }
    func macOSLabsPresentation(minWidth: CGFloat, minHeight: CGFloat) -> some View {
        #if os(macOS)
        return self.navigationViewStyle(.automatic).frame(minWidth: minWidth, minHeight: minHeight)
        #else
        return self
        #endif
    }
    func inlineNavigationDisplayMode() -> some View {
        #if os(iOS)
        return self.navigationBarTitleDisplayMode(.inline)
        #else
        return self
        #endif
    }
    func iOSFont(_ font: Font) -> some View {
        #if os(iOS)
        return self.font(font)
        #else
        return self
        #endif
    }
}

extension Color {
    static var background: Color {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        #error("Unsupported Platform")
        #endif
    }
}
