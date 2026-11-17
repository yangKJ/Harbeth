// 由 Condy 创建于 2026/11/17。仅在已知来源关联类型时准备显式转换。
import Foundation

struct FilterAlphaPlan {
    let filters: [C7FilterProtocol]
    let outputType: AlphaType

    init(filters: [C7FilterProtocol], inputType: AlphaType) {
        var current = inputType
        var result: [C7FilterProtocol] = []
        result.reserveCapacity(filters.count + 1)
        for filter in filters {
            let contract = filter.kernelOutputContract
            let expected = contract.inputAlphaExpectation == .preserveInput
                ? filter.kernelPixelContract.inputAlphaExpectation : contract.inputAlphaExpectation
            if expected == .premultiplied && current == .nonPremultiplied {
                result.append(C7PremultiplyAlpha()); current = .premultiplied
            } else if expected == .nonPremultiplied && current == .premultiplied {
                result.append(C7UnpremultiplyAlpha()); current = .nonPremultiplied
            }
            result.append(filter)
            let declared = contract.alpha == .preserveInput ? filter.kernelPixelContract.outputAlpha : contract.alpha
            if declared == .preserveInput && filter.defaultAlphaBehavior == .modifiesAlpha && current == .alphaIsOne {
                // 原始RGBA矩阵不改变关联域，但改变覆盖后不能继续宣称不透明。
                current = .premultiplied
            } else {
                current = declared.expectedAlphaType ?? filter.defaultAlphaBehavior.renderAlphaContract.expectedAlphaType ?? current
            }
        }
        self.filters = result
        self.outputType = current
    }
}

// 共享不可变合同，避免每次查询都重新构造附件数组。
extension RenderOutputContract {
    static let premultipliedColorInput = RenderOutputContract(inputAlphaExpectation: .premultiplied)
    static let premultipliedColorOutput = RenderOutputContract(inputAlphaExpectation: .premultiplied, alpha: .premultiplied)
}
