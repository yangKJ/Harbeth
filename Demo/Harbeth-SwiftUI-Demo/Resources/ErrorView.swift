//
//  ErrorView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/8/25.
//

import Foundation
import SwiftUI
import Harbeth

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
                    RetryButton()
                }
            }
            .padding()
            .background(.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
}

class RefreshActionPerformer: ObservableObject {
    @Published private(set) var isPerforming = false
    
    func perform(_ action: RefreshAction) async {
        guard !isPerforming else { return }
        isPerforming = true
        await action()
        isPerforming = false
    }
}

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
