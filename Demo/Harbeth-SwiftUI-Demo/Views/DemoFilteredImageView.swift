import Harbeth
import SwiftUI

struct DemoFilteredImage<Content>: View where Content: View {
    @State private var renderedImage: C7Image?
    @State private var renderGeneration: Int = 0
    @State private var renderHandle: RenderSubmissionHandle?
    @State private var submissionScopeIdentifier = "DemoFilteredImage.\(UUID().uuidString)"

    private let inputImage: C7Image
    private let filters: [C7FilterProtocol]
    private let content: (Image) -> Content

    init(
        image: C7Image,
        filters: [C7FilterProtocol],
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.inputImage = image
        self.filters = filters
        self.content = content
    }

    var body: some View {
        content(Image(c7Image: renderedImage ?? inputImage))
            .onAppear(perform: render)
            .onDisappear(perform: cancelRender)
            .onChange(of: renderSignature) { _ in
                render()
            }
    }

    private var renderSignature: String {
        let filterSignature = filters.map(\.identifier).joined(separator: "||")
        return "\(ObjectIdentifier(inputImage).hashValue)|\(filterSignature)"
    }

    private func render() {
        renderHandle?.cancel()
        renderGeneration += 1
        let generation = renderGeneration

        var io = HarbethIO(element: inputImage, filters: filters)
        io.submissionPolicy = .latestOnly(scopeIdentifier: submissionScopeIdentifier)

        renderHandle = io.transmitOutput(
            success: { output in
                DispatchQueue.main.async {
                    guard generation == renderGeneration else { return }
                    renderedImage = output
                }
            },
            failed: { _ in }
        )
    }

    private func cancelRender() {
        renderHandle?.cancel()
        renderHandle = nil
        renderGeneration += 1
    }
}
