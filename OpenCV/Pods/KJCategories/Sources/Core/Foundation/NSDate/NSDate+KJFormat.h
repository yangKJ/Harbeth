//
//  NSDate+KJFormat.h
//  KJEmitterView
//
//  Created by 77。 on 2019/12/16.
//  https://github.com/YangKJ/KJCategories

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDate (KJFormat)

/// Convert date to local time
- (NSDate *)kj_localeDate;

/// Time string conversion NSDate, format @"yyyy-MM-dd HH:mm:ss"
+ (NSDate *)kj_dateFromString:(NSString *)string;

/// Time string to NSDate
/// @param string time string
/// @param format time format
+ (NSDate *)kj_dateFromString:(NSString *)string format:(NSString *)format;

/// Get the current timestamp, whether it is milliseconds
+ (NSTimeInterval)kj_currentTimetampWithMsec:(BOOL)msec;

/// Timestamp to time, internal judgment is milliseconds or seconds
/// @param timestamp timestamp
/// @param format time format
+ (NSString *)kj_timeWithTimestamp:(NSTimeInterval)timestamp format:(NSString *)format;

/// Get the UTC timestamp of the specified time
/// @param timeString specifies the time
+ (NSTimeInterval)kj_timeStampUTCWithTimeString:(NSString *)timeString;

@end

NS_ASSUME_NONNULL_END
