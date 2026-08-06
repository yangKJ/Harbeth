//
//  C7ProgrammableBlend.swift
//  Harbeth
//
//  Created by Condy on 2026/6/22.
//

import Foundation
import MetalKit

public struct C7ProgrammableBlend: C7FilterProtocol {

    @ZeroOneRange public var intensity: Float = R.intensityRange.value

    public var modifier: ModifierEnum {
        .compute(kernel: functionName)
    }

    public var kernelParameterBindings: [KernelParameterBinding] {
        [
            KernelParameterBinding(name: "intensity", index: 0, stage: .compute, value: .float(intensity))
        ]
    }

    public var otherInputTextures: C7InputTextures {
        blendTexture.map { [$0] } ?? []
    }

    public var memoryAccessPattern: MemoryAccessPattern {
        .dualTexture
    }

    public var parameterDescription: [String: Any] {
        [
            "functionName": functionName,
            "intensity": intensity,
            "librarySource": computeKernelLibrarySource.fingerprint,
            "functionConstants": computeKernelFunctionConstants.map(\.fingerprint),
            "hasBlendTexture": blendTexture == nil ? 0 : 1
        ]
    }

    public var computeKernelLibrarySource: KernelLibrarySource {
        librarySource
    }

    public var computeKernelFunctionConstants: [KernelFunctionConstantDescriptor] {
        functionConstants
    }

    private let functionName: String
    private let librarySource: KernelLibrarySource
    private let functionConstants: [KernelFunctionConstantDescriptor]
    private let blendTexture: MTLTexture?

    public init(functionName: String,
                blendTexture: MTLTexture?,
                intensity: Float = 1.0,
                librarySource: KernelLibrarySource = .automatic,
                functionConstants: [KernelFunctionConstantDescriptor] = []) {
        self.functionName = functionName
        self.blendTexture = blendTexture
        self.intensity = intensity
        self.librarySource = librarySource
        self.functionConstants = functionConstants
    }
}
