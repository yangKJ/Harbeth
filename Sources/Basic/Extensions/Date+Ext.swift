//
//  Date+Ext.swift
//  Harbeth
//
//  Created by Condy on 2022/12/20.
//

import Foundation

extension Date: C7Compatible { }

extension Queen where Base == Date {
    
    public enum FormatType {
        case yyyy, mm_p_dd, yyyy_p_mm, yyyy_p_mm_p_dd
        case yyyy_mm_dd_hh_mm, yyyy_mm_dd_hh_mm_ss
        case yyyymmddhhmmss, yyyy_virgule_mm_virgule_dd
        case custom(String)
        
        public var des: String {
            switch self {
            case .yyyy:
                return "yyyy"
            case .mm_p_dd:
                return "MM.dd"
            case .yyyy_p_mm:
                return "yyyy.MM"
            case .yyyy_p_mm_p_dd:
                return "yyyy.MM.dd"
            case .yyyy_mm_dd_hh_mm:
                return "yyyy-MM-dd HH:mm"
            case .yyyy_mm_dd_hh_mm_ss:
                return "yyyy-MM-dd HH:mm:ss"
            case .yyyymmddhhmmss:
                return "YYYYMMddHHmmss"
            case .yyyy_virgule_mm_virgule_dd:
                return "yyyy/MM/dd"
            case .custom(let string):
                return string
            }
        }
    }
    
    public func format(_ type: FormatType) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.medium
        formatter.timeStyle = DateFormatter.Style.short
        formatter.dateFormat = type.des
        return formatter.string(from: base)
    }
}
