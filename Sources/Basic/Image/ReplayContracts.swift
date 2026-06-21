//
//  ReplayContracts.swift
//  Harbeth
//
//  Created by Condy on 2026/6/20.
//
import Foundation

public extension ImageSourceTier {
    var rank: Int {
        switch self {
        case .thumbnail:
            return 0
        case .deliveryReusable:
            return 1
        case .stableReusable:
            return 2
        case .fullResolutionReusable:
            return 3
        case .original:
            return 4
        }
    }

    func satisfies(_ requiredTier: ImageSourceTier) -> Bool {
        rank >= requiredTier.rank
    }
}

/// 描述某个渲染结果允许从哪一级资源重放。
public struct ReplayBaseContract: Sendable, Hashable, Codable {
    public let preferredSourceTier: ImageSourceTier
    public let requiresOriginalSource: Bool
    public let allowsDerivedReuse: Bool

    public init(preferredSourceTier: ImageSourceTier, requiresOriginalSource: Bool, allowsDerivedReuse: Bool) {
        self.preferredSourceTier = preferredSourceTier
        self.requiresOriginalSource = requiresOriginalSource
        self.allowsDerivedReuse = allowsDerivedReuse
    }

    public var fingerprint: String {
        [
            "preferredTier=\(preferredSourceTier.rawValue)",
            "requiresOriginal=\(requiresOriginalSource ? 1 : 0)",
            "allowsDerivedReuse=\(allowsDerivedReuse ? 1 : 0)"
        ].joined(separator: "|")
    }
}

public extension ImageDerivativeSpec {
    var replayBaseContract: ReplayBaseContract {
        switch renderIntent {
        case .export, .readback:
            return ReplayBaseContract(
                preferredSourceTier: .original,
                requiresOriginalSource: true,
                allowsDerivedReuse: false
            )
        case .inspection:
            return ReplayBaseContract(
                preferredSourceTier: .fullResolutionReusable,
                requiresOriginalSource: false,
                allowsDerivedReuse: true
            )
        case .delivery:
            let preferred: ImageSourceTier = sourceTier == .thumbnail ? .thumbnail : .deliveryReusable
            return ReplayBaseContract(
                preferredSourceTier: preferred,
                requiresOriginalSource: false,
                allowsDerivedReuse: true
            )
        case .interactive, .responsive, .stable:
            return ReplayBaseContract(
                preferredSourceTier: .stableReusable,
                requiresOriginalSource: false,
                allowsDerivedReuse: true
            )
        }
    }
}

public extension ImageSourceDescriptor {
    func satisfies(_ contract: ReplayBaseContract) -> Bool {
        if contract.requiresOriginalSource {
            return sourceTier == .original
        }
        if contract.allowsDerivedReuse {
            return sourceTier.satisfies(contract.preferredSourceTier)
        }
        return sourceTier == contract.preferredSourceTier
    }
}

/// 供上层缓存系统使用的稳定身份。
public struct RenderCacheIdentity: Sendable, Hashable, Codable {
    public let sourceFingerprint: String
    public let renderIntent: RenderIntent
    public let derivativeFingerprint: String
    public let replayBaseFingerprint: String
    public let filterChainFingerprint: String

    public init(sourceFingerprint: String,
                renderIntent: RenderIntent,
                derivativeFingerprint: String,
                replayBaseFingerprint: String,
                filterChainFingerprint: String) {
        self.sourceFingerprint = sourceFingerprint
        self.renderIntent = renderIntent
        self.derivativeFingerprint = derivativeFingerprint
        self.replayBaseFingerprint = replayBaseFingerprint
        self.filterChainFingerprint = filterChainFingerprint
    }

    public var fingerprint: String {
        [
            sourceFingerprint,
            "intent=\(renderIntent.rawValue)",
            derivativeFingerprint,
            replayBaseFingerprint,
            filterChainFingerprint
        ].joined(separator: " || ")
    }
}

public extension RenderRecipe {
    var replayBaseContract: ReplayBaseContract {
        outputDerivative.replayBaseContract
    }

    var cacheIdentity: RenderCacheIdentity {
        RenderCacheIdentity(
            sourceFingerprint: source.fingerprint,
            renderIntent: renderIntent,
            derivativeFingerprint: outputDerivative.fingerprint,
            replayBaseFingerprint: replayBaseContract.fingerprint,
            filterChainFingerprint: FilterChainRecipe(filters: filters).fingerprint
        )
    }
}

/// 单个可用 replay base 候选。由上层资源表、磁盘缓存或内存缓存提供。
public struct ReplaySourceCandidate: Sendable, Hashable, Codable {
    public let identifier: String
    public let descriptor: ImageSourceDescriptor
    public let pixelSize: C7Size?

    public init(identifier: String, descriptor: ImageSourceDescriptor, pixelSize: C7Size? = nil) {
        self.identifier = identifier
        self.descriptor = descriptor
        self.pixelSize = pixelSize
    }
}

/// replay base 选择结果。
public struct ReplaySourceSelection: Sendable, Hashable, Codable {
    public enum Strategy: String, Sendable, Hashable, Codable {
        /// 选中了和 contract 偏好层级一致的资源。
        case exactPreferredTier
        /// 没有更低成本资源时，回退到更高层级的可复用资源。
        case higherTierFallback
        /// 当前请求必须从 original 真相源重放。
        case requiresOriginalReplay
        /// 没有满足 contract 的可复用资源。
        case noReusableSource
    }

    public let contract: ReplayBaseContract
    public let requestedDerivative: ImageDerivativeSpec
    public let selectedCandidate: ReplaySourceCandidate?
    public let strategy: Strategy

    public init(contract: ReplayBaseContract,
                requestedDerivative: ImageDerivativeSpec,
                selectedCandidate: ReplaySourceCandidate?,
                strategy: Strategy) {
        self.contract = contract
        self.requestedDerivative = requestedDerivative
        self.selectedCandidate = selectedCandidate
        self.strategy = strategy
    }

    public var requiresOriginalReplay: Bool {
        strategy == .requiresOriginalReplay || contract.requiresOriginalSource
    }

    public var reusesExistingDerivedSource: Bool {
        guard let candidate = selectedCandidate else { return false }
        return candidate.descriptor.sourceTier != .original
    }
}

public extension ImageSourceDescriptor {
    func replayReuseScore(for derivative: ImageDerivativeSpec, contract: ReplayBaseContract) -> Int? {
        guard satisfies(contract) else {
            return nil
        }

        let preferredRank = contract.preferredSourceTier.rank
        let tierDistance = sourceTier.rank - preferredRank
        var score = 1_000 - max(tierDistance, 0) * 100

        if sourceTier == contract.preferredSourceTier {
            score += 80
        }
        if semantic.purpose == derivative.semantic.purpose {
            score += 40
        }
        if semantic.fidelity == derivative.semantic.fidelity {
            score += 20
        }
        if semantic.role == .source && sourceTier == .original {
            score += 10
        }

        return score
    }
}

public extension ImageDerivativeSpec {
    func selectReplaySource(from candidates: [ReplaySourceCandidate]) -> ReplaySourceSelection {
        let contract = replayBaseContract

        if contract.requiresOriginalSource {
            let originalCandidate = candidates
                .filter { $0.descriptor.sourceTier == .original }
                .sorted {
                    let leftScore = $0.descriptor.replayReuseScore(for: self, contract: contract) ?? Int.min
                    let rightScore = $1.descriptor.replayReuseScore(for: self, contract: contract) ?? Int.min
                    if leftScore == rightScore {
                        return $0.identifier < $1.identifier
                    }
                    return leftScore > rightScore
                }
                .first
            return ReplaySourceSelection(
                contract: contract,
                requestedDerivative: self,
                selectedCandidate: originalCandidate,
                strategy: .requiresOriginalReplay
            )
        }

        let selected = candidates
            .compactMap { candidate -> (candidate: ReplaySourceCandidate, score: Int)? in
                guard let score = candidate.descriptor.replayReuseScore(for: self, contract: contract) else {
                    return nil
                }
                return (candidate, score)
            }
            .sorted {
                if $0.score == $1.score {
                    return $0.candidate.identifier < $1.candidate.identifier
                }
                return $0.score > $1.score
            }
            .first?
            .candidate

        guard let selected else {
            return ReplaySourceSelection(
                contract: contract,
                requestedDerivative: self,
                selectedCandidate: nil,
                strategy: .noReusableSource
            )
        }

        return ReplaySourceSelection(
            contract: contract,
            requestedDerivative: self,
            selectedCandidate: selected,
            strategy: selected.descriptor.sourceTier == contract.preferredSourceTier ? .exactPreferredTier : .higherTierFallback
        )
    }
}

public extension RenderRecipe {
    func selectReplaySource(from candidates: [ReplaySourceCandidate]) -> ReplaySourceSelection {
        outputDerivative.selectReplaySource(from: candidates)
    }
}

/// 由 derivative + replay selection 推导出的 source 请求计划。
public struct ReplaySourceRequestPlan: Sendable, Hashable, Codable {
    public let derivative: ImageDerivativeSpec
    public let selection: ReplaySourceSelection
    public let requestedSourceTier: ImageSourceTier
    public let loadingOptions: ImageLoadingOptions
    public let canReuseSelectedCandidateDirectly: Bool
    public let requiresPostLoadResize: Bool

    public init(derivative: ImageDerivativeSpec,
                selection: ReplaySourceSelection,
                requestedSourceTier: ImageSourceTier,
                loadingOptions: ImageLoadingOptions,
                canReuseSelectedCandidateDirectly: Bool,
                requiresPostLoadResize: Bool) {
        self.derivative = derivative
        self.selection = selection
        self.requestedSourceTier = requestedSourceTier
        self.loadingOptions = loadingOptions
        self.canReuseSelectedCandidateDirectly = canReuseSelectedCandidateDirectly
        self.requiresPostLoadResize = requiresPostLoadResize
    }

    public var shouldDecodeFromUnderlyingSource: Bool {
        !canReuseSelectedCandidateDirectly
    }
}

public extension ImageDerivativeSpec {
    func makeReplaySourceRequestPlan(from selection: ReplaySourceSelection) -> ReplaySourceRequestPlan {
        let requestedTier: ImageSourceTier
        switch selection.strategy {
        case .exactPreferredTier, .higherTierFallback:
            requestedTier = selection.selectedCandidate?.descriptor.sourceTier ?? sourceTier
        case .requiresOriginalReplay:
            requestedTier = .original
        case .noReusableSource:
            requestedTier = replayBaseContract.preferredSourceTier
        }

        let canReuseDirectly: Bool
        if let candidate = selection.selectedCandidate,
           selection.strategy == .exactPreferredTier,
           outputSizePolicy == .source,
           candidate.descriptor.semantic == semantic {
            canReuseDirectly = true
        } else {
            canReuseDirectly = false
        }

        let loadingOptions: ImageLoadingOptions
        if canReuseDirectly {
            loadingOptions = selection.selectedCandidate?.descriptor.loadingOptions ?? .default
        } else {
            switch outputSizePolicy {
            case .source:
                loadingOptions = .default
            case .maxPixelSize(let value):
                loadingOptions = ImageLoadingOptions(sizePolicy: .maxPixelSize(value))
            case .fit(let size), .exact(let size):
                loadingOptions = ImageLoadingOptions(sizePolicy: .fit(width: size.width, height: size.height))
            }
        }

        return ReplaySourceRequestPlan(
            derivative: self,
            selection: selection,
            requestedSourceTier: requestedTier,
            loadingOptions: loadingOptions,
            canReuseSelectedCandidateDirectly: canReuseDirectly,
            requiresPostLoadResize: outputSizePolicy != .source
        )
    }
}

public extension RenderRecipe {
    func makeReplaySourceRequestPlan(from selection: ReplaySourceSelection) -> ReplaySourceRequestPlan {
        outputDerivative.makeReplaySourceRequestPlan(from: selection)
    }
}

/// replay/source 请求完成后，该结果在上层资源体系中的落点策略。
public struct SourceProvisionPolicy: Sendable, Hashable, Codable {
    public enum DeliveryMode: String, Sendable, Hashable, Codable {
        /// 直接复用已存在候选，不触发新的 decode / replay。
        case reuseExistingCandidate
        /// 从底层 source 解码后继续生成目标 derivative。
        case decodeUnderlyingSource
        /// 必须从 original 真相源重放。
        case replayFromOriginal
    }

    public let requestPlan: ReplaySourceRequestPlan
    public let deliveryMode: DeliveryMode
    public let producedCachePolicy: ImageCachePolicy
    public let shouldPersistProducedDerivative: Bool
    public let shouldStoreAsReusableReplayBase: Bool

    public init(requestPlan: ReplaySourceRequestPlan,
                deliveryMode: DeliveryMode,
                producedCachePolicy: ImageCachePolicy,
                shouldPersistProducedDerivative: Bool,
                shouldStoreAsReusableReplayBase: Bool) {
        self.requestPlan = requestPlan
        self.deliveryMode = deliveryMode
        self.producedCachePolicy = producedCachePolicy
        self.shouldPersistProducedDerivative = shouldPersistProducedDerivative
        self.shouldStoreAsReusableReplayBase = shouldStoreAsReusableReplayBase
    }
}

public extension ImageDerivativeSpec {
    func makeSourceProvisionPolicy(from requestPlan: ReplaySourceRequestPlan) -> SourceProvisionPolicy {
        let deliveryMode: SourceProvisionPolicy.DeliveryMode
        if requestPlan.canReuseSelectedCandidateDirectly {
            deliveryMode = .reuseExistingCandidate
        } else if requestPlan.selection.requiresOriginalReplay {
            deliveryMode = .replayFromOriginal
        } else {
            deliveryMode = .decodeUnderlyingSource
        }

        let producedCachePolicy: ImageCachePolicy
        let shouldPersistProducedDerivative: Bool
        let shouldStoreAsReusableReplayBase: Bool

        switch renderIntent {
        case .interactive, .responsive:
            producedCachePolicy = .transient
            shouldPersistProducedDerivative = false
            shouldStoreAsReusableReplayBase = false
        case .stable, .inspection, .delivery:
            producedCachePolicy = .persistent
            shouldPersistProducedDerivative = !requestPlan.canReuseSelectedCandidateDirectly
            shouldStoreAsReusableReplayBase = true
        case .export, .readback:
            producedCachePolicy = .transient
            shouldPersistProducedDerivative = false
            shouldStoreAsReusableReplayBase = false
        }

        return SourceProvisionPolicy(
            requestPlan: requestPlan,
            deliveryMode: deliveryMode,
            producedCachePolicy: producedCachePolicy,
            shouldPersistProducedDerivative: shouldPersistProducedDerivative,
            shouldStoreAsReusableReplayBase: shouldStoreAsReusableReplayBase
        )
    }
}

public extension RenderRecipe {
    func makeSourceProvisionPolicy(from requestPlan: ReplaySourceRequestPlan) -> SourceProvisionPolicy {
        outputDerivative.makeSourceProvisionPolicy(from: requestPlan)
    }
}
