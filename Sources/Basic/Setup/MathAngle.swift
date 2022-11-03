//
//  AngleAssist.swift
//  Harbeth
//
//  Created by Condy on 2022/10/30.
//

import Foundation

public protocol AngleAssist {
    
    /// Standardized correction Angle, `0-360`
    /// - Parameter angle: Current Angle
    /// - Returns: The normalized Angle
    func standardizeAngle(_ angle: CGFloat) -> CGFloat
    
    /// Automatic horizontal or vertical Angle.
    /// - Parameter angle: Current Angle
    /// - Returns: The Angle after the treatment
    func autoHorizontalOrVerticalAngle(_ angle: CGFloat) -> CGFloat
}

extension AngleAssist {
    
    public func standardizeAngle(_ angle: CGFloat) -> CGFloat {
        var angle = angle
        if angle >= 0, angle <= 2 * CGFloat.pi {
            return angle
        } else if angle < 0 {
            angle += 2 * CGFloat.pi
            return standardizeAngle(angle)
        } else {
            angle -= 2 * CGFloat.pi
            return standardizeAngle(angle)
        }
    }
    
    public func autoHorizontalOrVerticalAngle(_ angle: CGFloat) -> CGFloat {
        var angle = angle
        angle = standardizeAngle(angle)
        let deviation: CGFloat = 0.017444444 // 1 * 3.14 / 180, sync with AngleRuler
        if abs(angle - 0) < deviation {
            angle = 0
        } else if abs(angle - CGFloat.pi / 2.0) < deviation {
            angle = CGFloat.pi / 2.0
        } else if abs(angle - CGFloat.pi) < deviation {
            angle = CGFloat.pi - 0.001 // Handling a iOS bug that causes problems with rotation animations
        } else if abs(angle - CGFloat.pi / 2.0 * 3) < deviation {
            angle = CGFloat.pi / 2.0 * 3
        } else if abs(angle - CGFloat.pi * 2) < deviation {
            angle = CGFloat.pi * 2
        }
        return angle
    }
}

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
