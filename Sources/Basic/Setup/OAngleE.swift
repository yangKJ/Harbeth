//
//  AngleE.swift
//  Harbeth
//
//  Created by Condy on 2022/10/30.
//

import Foundation

fileprivate struct AngleE<E>: AngleAssist {
    var element: E
    init(angle: E) {
        self.element = angle
    }
    
    func standardizeAngle() -> E {
        if let element = element as? CGFloat {
            return CGFloat(self.standardizeAngle(element)) as! E
        } else if let element = element as? Float {
            return Float(self.standardizeAngle(CGFloat(element))) as! E
        } else if let element = element as? Double {
            return Double(self.standardizeAngle(CGFloat(element))) as! E
        } else if let element = element as? Int {
            return Int(self.standardizeAngle(CGFloat(element))) as! E
        }
        return element
    }
    
    func autoHorizontalOrVerticalAngle() -> E {
        if let element = element as? CGFloat {
            return CGFloat(self.autoHorizontalOrVerticalAngle(element)) as! E
        } else if let element = element as? Float {
            return Float(self.autoHorizontalOrVerticalAngle(CGFloat(element))) as! E
        } else if let element = element as? Double {
            return Double(self.autoHorizontalOrVerticalAngle(CGFloat(element))) as! E
        } else if let element = element as? Int {
            return Int(self.autoHorizontalOrVerticalAngle(CGFloat(element))) as! E
        }
        return element
    }
}

extension Queen where Base == CGFloat {
    public var standardizeAngle: CGFloat {
        return AngleE(angle: base).standardizeAngle()
    }
    
    public var autoHorizontalOrVerticalAngle: CGFloat {
        return AngleE(angle: base).autoHorizontalOrVerticalAngle()
    }
}

extension Queen where Base == Float {
    public var standardizeAngle: Float {
        return AngleE(angle: base).standardizeAngle()
    }
    
    public var autoHorizontalOrVerticalAngle: Float {
        return AngleE(angle: base).autoHorizontalOrVerticalAngle()
    }
}

extension Queen where Base == Double {
    public var standardizeAngle: Double {
        return AngleE(angle: base).standardizeAngle()
    }
    
    public var autoHorizontalOrVerticalAngle: Double {
        return AngleE(angle: base).autoHorizontalOrVerticalAngle()
    }
}

extension Queen where Base == Int {
    public var standardizeAngle: Int {
        return AngleE(angle: base).standardizeAngle()
    }
    
    public var autoHorizontalOrVerticalAngle: Int {
        return AngleE(angle: base).autoHorizontalOrVerticalAngle()
    }
}
