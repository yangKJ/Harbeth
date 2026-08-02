//
//  RenderExecutionProgram.swift
//  Harbeth
//
//  Created by Condy on 2026/8/2.
//

import Foundation

/// HarbethIO 与 ImageNode 共享的内部执行快照。
///
/// 它不是第三条公开使用路线，只负责把 sampler adaptation、pointwise fusion、
/// render plan 与 diagnostics 固化为同一份执行事实，避免执行与诊断各自重新推导。
struct RenderExecutionProgram: @unchecked Sendable {
    let sourceFilterFingerprint: String
    let filters: [C7FilterProtocol]
    let plan: RenderPlan
    let steps: [RenderExecutionStep]
    let fingerprint: String
    let reusedCachedPlan: Bool

    var diagnostics: RenderPlanDiagnostics { plan.diagnostics }
}

/// 编译后可直接执行的单步调度信息。
struct RenderExecutionStep: @unchecked Sendable {
    let nodeIndex: Int
    let stageIndex: Int
    let filter: C7FilterProtocol
    let outputSize: C7Size
    let lifecycleAction: RenderTextureLifecycleAction
    let breaksFusion: Bool
}

enum RenderExecutionCompiler {
    static func compile(
        filters: [C7FilterProtocol],
        inputSize: C7Size,
        profile: RenderProfile = .stablePreview,
        derivative: ImageDerivativeSpec? = nil,
        compilationSource: RenderCompilationSource = .filtersPrimitive,
        outputContract: RenderOutputContract = .preserveInput,
        imageCachePolicy: ImageCachePolicy = .transient,
        samplerDescriptor: ImageSamplerDescriptor = .default,
        sourceDescriptor: ImageSourceDescriptor? = nil,
        auxiliaryInputDescriptor: ImageSourceDescriptor? = nil,
        imageGraph: ImageGraph? = nil,
        graphOptimizationDecisions: [String] = [],
        planCacheKey: String? = nil,
        preparedPlan: RenderPlan? = nil
    ) -> RenderExecutionProgram {
        let samplerPlan = SamplerExecutionAdapter.makePlan(
            filters: filters,
            samplerDescriptor: samplerDescriptor
        )
        let executionFilters = PointwiseFusionPlanner.makeExecutionFilters(samplerPlan.filters)

        func compilePlan() -> RenderPlan {
            GraphCompiler.compile(
                filters: executionFilters,
                inputSize: inputSize,
                profile: profile,
                derivative: derivative,
                compilationSource: compilationSource,
                outputContract: outputContract,
                imageCachePolicy: imageCachePolicy,
                samplerDescriptor: samplerDescriptor,
                samplerExecutionCoverage: samplerPlan.coverage,
                sourceDescriptor: sourceDescriptor,
                auxiliaryInputDescriptor: auxiliaryInputDescriptor,
                imageGraph: imageGraph,
                graphOptimizationDecisions: graphOptimizationDecisions
            )
        }

        let cachedPlan = preparedPlan == nil
            ? planCacheKey.flatMap { HarbethContext.shared.cachedRenderPlan(for: $0) }
            : nil
        var plan = preparedPlan ?? cachedPlan ?? compilePlan()
        var reusedCachedPlan = cachedPlan != nil
        if isStructurallyCompatible(
            plan: plan,
            executionFilters: executionFilters,
            inputSize: inputSize,
            derivative: derivative ?? profile.defaultDerivativeSpec
        ) == false {
            plan = compilePlan()
            reusedCachedPlan = false
        }
        if reusedCachedPlan == false, let planCacheKey {
            HarbethContext.shared.storeRenderPlan(plan, for: planCacheKey)
        }
        let steps = makeExecutionSteps(filters: executionFilters, plan: plan)
        let executableFilters = steps.map(\.filter)

        return RenderExecutionProgram(
            sourceFilterFingerprint: filters.chainRecipe.fingerprint,
            filters: executableFilters,
            plan: plan,
            steps: steps,
            fingerprint: [
                executableFilters.chainRecipe.fingerprint,
                plan.diagnostics.graphFingerprint,
                "sampler=\(samplerDescriptor.fingerprint)",
                "derivative=\(plan.diagnostics.derivative.fingerprint)",
            ].joined(separator: "|"),
            reusedCachedPlan: reusedCachedPlan
        )
    }

    private static func isStructurallyCompatible(
        plan: RenderPlan,
        executionFilters: [C7FilterProtocol],
        inputSize: C7Size,
        derivative: ImageDerivativeSpec
    ) -> Bool {
        let filterNodes = plan.graph.nodes.filter { $0.filter != nil }
        guard plan.diagnostics.inputSize == inputSize,
              plan.diagnostics.derivative.fingerprint == derivative.fingerprint,
              filterNodes.count == executionFilters.count,
              filterNodes.compactMap(\.filter).chainRecipe.fingerprint == executionFilters.chainRecipe.fingerprint else {
            return false
        }

        var currentSize = inputSize
        for (node, filter) in zip(filterNodes, executionFilters) {
            let outputSize = filter.resize(input: currentSize)
            let expectedBreaksFusion = outputSize != currentSize || node.kind == .combination
            guard node.outputSize == outputSize, node.breaksFusion == expectedBreaksFusion else {
                return false
            }
            currentSize = outputSize
        }

        let expectedOutputSize = derivative.resolvedOutputSize(for: currentSize)
        let derivativeNodes = plan.diagnostics.nodes.filter { $0.name == "DerivativeResize" }
        guard derivativeNodes.count == (expectedOutputSize == currentSize ? 0 : 1) else {
            return false
        }
        return plan.diagnostics.outputSize == expectedOutputSize
    }

    private static func makeExecutionSteps(filters: [C7FilterProtocol], plan: RenderPlan) -> [RenderExecutionStep] {
        func isExecutableNode(at index: Int) -> Bool {
            guard plan.graph.nodes.indices.contains(index) else { return false }
            return plan.graph.nodes[index].filter != nil
                || plan.diagnostics.nodes.first(where: { $0.index == index })?.name == "DerivativeResize"
        }

        let lifecycleByStage = Dictionary(
            uniqueKeysWithValues: plan.diagnostics.optimizationPlan.lifecycleDecisions.map {
                ($0.stageIndex, $0.action)
            }
        )
        var filterIndex = 0
        return plan.graph.nodes.enumerated().compactMap { nodeIndex, node in
            let filter: C7FilterProtocol
            if node.filter != nil, filters.indices.contains(filterIndex) {
                filter = filters[filterIndex]
                filterIndex += 1
            } else if plan.diagnostics.nodes.first(where: { $0.index == nodeIndex })?.name == "DerivativeResize" {
                let outputSize = node.outputSize
                    ?? plan.diagnostics.nodes.first(where: { $0.index == nodeIndex })?.outputSize
                    ?? plan.diagnostics.inputSize
                filter = C7Resize(width: Float(outputSize.width), height: Float(outputSize.height))
            } else {
                return nil
            }
            let stage = plan.optimizedStages.first(where: { $0.nodeIndices.contains(nodeIndex) })
            let stageIndex = stage?.index ?? 0
            let isLastExecutableNodeInStage = stage?.nodeIndices.last(where: isExecutableNode(at:)) == nodeIndex
            let lifecycleAction: RenderTextureLifecycleAction
            if isLastExecutableNodeInStage {
                lifecycleAction = lifecycleByStage[stageIndex] ?? .allocateTransient
            } else {
                lifecycleAction = .reuseTransient
            }
            return RenderExecutionStep(
                nodeIndex: nodeIndex,
                stageIndex: stageIndex,
                filter: filter,
                outputSize: node.outputSize
                    ?? plan.diagnostics.nodes.first(where: { $0.index == nodeIndex })?.outputSize
                    ?? plan.diagnostics.inputSize,
                lifecycleAction: lifecycleAction,
                breaksFusion: node.breaksFusion
            )
        }
    }
}
