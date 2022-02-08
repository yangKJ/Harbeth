//
//  NSString+KJMath.h
//  KJEmitterView
//
//  Created by yangkejun on 2020/8/10.
//  https://github.com/YangKJ/KJCategories

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Mathematical operators
@interface NSString (KJMath)

/// Is it empty
@property (nonatomic, assign, readonly) BOOL isEmpty;
/// Non-empty safe handling
@property (nonatomic, assign, readonly) NSString *safeString;

/// Comparison of size
- (NSComparisonResult)kj_compare:(NSString *)string;
/// addition operation
- (NSString *)kj_adding:(NSString *)string;
/// Subtraction operation
- (NSString *)kj_subtract:(NSString *)string;
/// The amount of multiplication
- (NSString *)kj_multiply:(NSString *)string;
/// Division operation
- (NSString *)kj_divide:(NSString *)string;
/// Exponential calculation
- (NSString *)kj_multiplyingByPowerOf10:(NSInteger)oxff;
/// Power operation
- (NSString *)kj_raisingToPower:(NSInteger)oxff;

/// Convert to decimal
- (double)kj_calculateDoubleValue;

/// Keep the integer part, 100.0130 => 100
- (NSString *)kj_retainInteger;

/// Remove the digits whose tail is `0` or `.`
/// 10.000 => 10 or 10.100 => 10.1
- (NSString *)kj_removeTailZero;

/// Keep a few decimal places, rounding to two digits is as follows
/// 10.00001245 => 10.00 or 120.026 => 120.03
extern NSString * kStringFractionDigits(NSDecimalNumber * number, NSUInteger digits);
+ (NSString *)kj_fractionDigits:(double)value digits:(NSUInteger)digits;

/// Keep the decimal, directly remove the excess part of the decimal
+ (NSString *)kj_retainDigits:(double)value digits:(int)digits;

/// Keep a few valid decimal places, keep two digits as follows
/// 10.00001245 => 10.000012 or 120.02 => 120.02 or 10.000 => 10
extern NSString * kStringReservedValidDigit(NSDecimalNumber * value, NSInteger digit);
+ (NSString *)kj_reservedValidDigit:(double)value digit:(int)digit;

/// Double precision loss repair
- (NSString *)kj_doublePrecisionRevise;
+ (NSString *)kj_doublePrecisionReviseWithDouble:(double)conversionValue;

@property (nonatomic, assign, readonly) BOOL isNumber;
@property (nonatomic, assign, readonly) BOOL isInt;
@property (nonatomic, assign, readonly) BOOL isFloat;

/// Convert large units to small units
/// [@"1.1" kj_parseToUInt64WithDecimals: 5] => @"110000"
- (NSString *)kj_parseToIntStringWithDecimals:(int)decimals;

/// Add `0` after the decimal
/// [@"1.2" kj_decimalAddZeroToLength:5] => @"1.20000"
- (NSString *)kj_decimalAddZeroToLength:(int)length;

/// Convert small units to large units
/// [@"200" kj_formatToDecimalWithDecimals:5] => @"0.002"
/// [@"1.2" kj_decimalAddZeroToLength:5] => @"0.000012"
- (NSString *)kj_formatToDecimalWithDecimals:(int)decimals;

@end

NS_ASSUME_NONNULL_END
