//
//  CIPhotoEffect.swift
//  Harbeth
//
//  Created by Condy on 2024/3/20.
//

import Foundation
import CoreImage

public struct CIPhotoEffect: CoreImageProtocol {
    public enum EffectType {
        /// Imitate vintage photography film with exaggerated color.
        case chrome
        /// Imitate vintage photography film with diminished color.
        case fade
        /// Imitate vintage photography film with distorted colors.
        case instant
        /// Imitate black-and-white photography film with low contrast.
        case mono
        /// Imitate black-and-white photography film with exaggerated contrast.
        case noir
        /// Imitate vintage photography film with emphasized cool colors.
        case process
        /// Imitate black-and-white photography film without significantly altering contrast.
        case tonal
        /// Imitate vintage photography film with emphasized warm colors.
        case transfer
    }
    
    public var modifier: Modifier {
        return .coreimage(CIName: effectType.kernel)
    }
    
    private let effectType: EffectType
    
    public init(with type: EffectType) {
        self.effectType = type
    }
}

extension CIPhotoEffect.EffectType: Hashable, Identifiable {
    
    public var id: String {
        kernel
    }
    
    var kernel: String {
        switch self {
        case .chrome:
            return "CIPhotoEffectChrome"
        case .fade:
            return "CIPhotoEffectFade"
        case .instant:
            return "CIPhotoEffectInstant"
        case .mono:
            return "CIPhotoEffectMono"
        case .noir:
            return "CIPhotoEffectNoir"
        case .process:
            return "CIPhotoEffectProcess"
        case .tonal:
            return "CIPhotoEffectTonal"
        case .transfer:
            return "CIPhotoEffectTransfer"
        }
    }
}
