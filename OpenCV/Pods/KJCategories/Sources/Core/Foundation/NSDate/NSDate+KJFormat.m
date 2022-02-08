//
//  NSDate+KJFormat.m
//  KJEmitterView
//
//  Created by 77。 on 2019/12/16.
//  https://github.com/YangKJ/KJCategories

#import "NSDate+KJFormat.h"

@implementation NSDate (KJFormat)

/// 将日期转化为本地时间
- (NSDate *)kj_localeDate{
    NSTimeZone *zone = [NSTimeZone systemTimeZone];
    NSInteger interval = [zone secondsFromGMTForDate:self];
    NSDate *localeDate = [self dateByAddingTimeInterval:interval];
    return localeDate;
}
/// 时间字符串转位NSDate
+ (NSDate *)kj_dateFromString:(NSString *)string{
    return [self kj_dateFromString:string format:@"yyyy-MM-dd HH:mm:ss"];
}
/// 时间字符串转NSDate
+ (NSDate *)kj_dateFromString:(NSString *)string format:(NSString *)format{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:format];
    return [formatter dateFromString:string];
}
/// 获取当前时间戳，是否为毫秒
+ (NSTimeInterval)kj_currentTimetampWithMsec:(BOOL)msec{
    return [[NSDate date] timeIntervalSince1970] * (msec ? 1000 : 1);
}
/// 时间戳转时间，内部判断是毫秒还是秒
+ (NSString *)kj_timeWithTimestamp:(NSTimeInterval)timestamp format:(NSString *)format{
    NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    [formatter setDateFormat:format];
    NSString * string = [NSString stringWithFormat:@"%@",[NSNumber numberWithDouble:timestamp]];
    NSDecimalNumber * decimalA = [NSDecimalNumber decimalNumberWithString:string];
    NSDecimalNumber * decimalB = [NSDecimalNumber decimalNumberWithString:@"1000000000000"];//毫秒量级
    NSDecimalNumber * decimalC = [NSDecimalNumber decimalNumberWithString:@"1000"];
    if ([decimalA compare:decimalB] == NSOrderedDescending) {// timestamp > 1000000000000，毫秒
        timestamp = [[decimalA decimalNumberByDividingBy:decimalC] doubleValue];
    }
    NSDate * date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    return [formatter stringFromDate:date];
}

+ (NSTimeInterval)kj_timeStampUTCWithTimeString:(NSString *)timeString{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateStyle:NSDateFormatterMediumStyle];
    [formatter setTimeStyle:NSDateFormatterShortStyle];
    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    [formatter setTimeZone:timeZone];
    if ([timeString containsString:@"."]) {
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS"];
    } else {
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss"];
    }
    return [[formatter dateFromString:timeString] timeIntervalSince1970];
}

@end
