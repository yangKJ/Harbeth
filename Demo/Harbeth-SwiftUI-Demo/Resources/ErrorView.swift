//
//  ErrorView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/8/25.
//

import Foundation
import SwiftUI
import Harbeth

@available(iOS 15.0, *)
struct ErrorView: View {
    @Binding var error: HarbethError?
    
    var body: some View {
        if let error = error {
            VStack {
                Text(error.localizedDescription)
                    .bold()
                HStack {
                    Button("Dismiss") {
                        self.error = nil
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    .foregroundColor(.white.opacity(0.94))
                    RetryButton()
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(hex: "#141418")))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.red.opacity(0.5), lineWidth: 1)
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .padding(.leading, 0)
            }
            .foregroundColor(.white.opacity(0.94))
        }
    }
}

@available(iOS 15.0, *)
class RefreshActionPerformer: ObservableObject {
    @Published private(set) var isPerforming = false
    
    func perform(_ action: RefreshAction) async {
        guard !isPerforming else { return }
        isPerforming = true
        await action()
        isPerforming = false
    }
}

@available(iOS 15.0, *)
struct RetryButton: View {
    var title: LocalizedStringKey = "Retry"
    
    @Environment(\.refresh) private var action
    @StateObject private var actionPerformer = RefreshActionPerformer()
    
    var body: some View {
        if let action = action {
            Button {
                Task {
                    await actionPerformer.perform(action)
                }
            } label: {
                ZStack {
                    if actionPerformer.isPerforming {
                        Text(title).hidden()
                        ProgressView()
                    } else {
                        Text(title)
                    }
                }
            }
            .disabled(actionPerformer.isPerforming)
        }
    }
}



// MARK: - Design System Colors (synced with ContentView)
private extension View {
    var dsSurfaceGlass: Color { Color.white.opacity(0.06) }
    var dsSurfaceCard: Color { Color(hex: "#141418") }
    var dsBackground: Color { Color(hex: "#0A0A0C") }
    var dsBorderSubtle: Color { Color.white.opacity(0.06) }
    var dsBorderActive: Color { Color.white.opacity(0.14) }
    var dsTextPrimary: Color { Color.white.opacity(0.94) }
    var dsTextSecondary: Color { Color.white.opacity(0.62) }
    var dsTextTertiary: Color { Color.white.opacity(0.38) }
}

private let dsAccentPrimary = Color(hex: "#5E9EFF")
private let dsAccentSecondary = Color(hex: "#A78BFA")
private let dsAccentSuccess = Color(hex: "#34D399")
