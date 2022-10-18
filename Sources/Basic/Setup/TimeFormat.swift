//
//  TimeFormat.swift
//  Harbeth
//
//  Created by Condy on 2022/10/18.
//

import Foundation

public enum TimeFormat: String {
    case YYYYMMDD = "YYYY-MM-dd"
    case YYYYMMDDHH = "YYYY-MM-dd HH"
    case YYYYMMDDHHMM = "YYYY-MM-dd HH:mm"
    case YYYYMMDDHHMMSS = "YYYY-MM-dd HH:mm:ss"
    case YYYYMMDDHHMMSSsss = "YYYY-MM-dd HH:mm:ss.SSS"
}

extension TimeFormat {
    
    /// Get the current time
    /// - Parameter region: A time zone initialized with a given identifier.
    /// - Returns: Region time string
    public func currentTime(region: String = "Asia/Beijing") -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.medium
        formatter.timeStyle = DateFormatter.Style.short
        formatter.dateFormat = self.rawValue
        let timezone = TimeZone.init(identifier: region)
        formatter.timeZone = timezone
        let dateTime = formatter.string(from: Date.init())
        return dateTime
    }
}
