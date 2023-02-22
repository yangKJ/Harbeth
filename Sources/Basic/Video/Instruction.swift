//
//  Instruction.swift
//  Harbeth
//
//  Created by Condy on 2023/2/20.
//

import Foundation
import AVFoundation

extension Exporter {
    class CompositionInstruction: AVMutableVideoCompositionInstruction {
        
        let trackID: CMPersistentTrackID
        let bufferCallback: Exporter.PixelBufferCallback
        
        override var requiredSourceTrackIDs: [NSValue] {
            get {
                return [NSNumber(value: Int(self.trackID))]
            }
        }
        
        override var containsTweening: Bool {
            get {
                return false
            }
        }
        
        init(trackID: CMPersistentTrackID, bufferCallback: @escaping Exporter.PixelBufferCallback) {
            self.trackID = trackID
            self.bufferCallback = bufferCallback
            super.init()
            self.enablePostProcessing = true
        }
        
        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
