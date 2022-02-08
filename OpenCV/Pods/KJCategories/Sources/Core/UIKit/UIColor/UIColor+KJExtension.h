//
//  UIColor+KJExtension.h
//  KJEmitterView
//
//  Created by 77。 on 2019/12/31.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#define UIColorFromHEXA(hex,a)    [UIColor colorWithRed:((hex&0xFF0000)>>16)/255.0f \
green:((hex&0xFF00)>>8)/255.0f blue:(hex&0xFF)/255.0f alpha:a]
#define UIColorFromRGBA(r,g,b,a)  [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:a]
#define UIColorHexFromRGB(hex)    UIColorFromHEXA(hex,1.0)
#define kRGBA(r,g,b,a)            [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:a]
#define kRGB(r,g,b)               kRGBA(r,g,b,1.0f)

@interface UIColor (KJExtension)

@property (nonatomic, assign, readonly) CGFloat red;
@property (nonatomic, assign, readonly) CGFloat green;
@property (nonatomic, assign, readonly) CGFloat blue;
@property (nonatomic, assign, readonly) CGFloat alpha;
@property (nonatomic, assign, readonly) CGFloat hue;
@property (nonatomic, assign, readonly) CGFloat saturation;
@property (nonatomic, assign, readonly) CGFloat light;

/// Get the RGBA corresponding to the color
- (void)kj_rgba:(CGFloat *)r :(CGFloat *)g :(CGFloat *)b :(CGFloat *)a;

/// Get the hue saturation and transparency corresponding to the color
- (void)kj_HSL:(CGFloat *)hue :(CGFloat *)saturation :(CGFloat *)light;

/// UIColor to hexadecimal string
- (NSString *)kj_hexString;
/// UIColor to hexadecimal string
+ (NSString *)hexStringFromColor:(UIColor *)color;
FOUNDATION_EXPORT NSString * kDoraemonBoxHexStringFromColor(UIColor *color);

/// Convert hexadecimal string to UIColor
/// @param hexString hexadecimal, the beginning of `0x` or `#` are also supported
+ (UIColor *)colorWithHexString:(NSString *)hexString;
FOUNDATION_EXPORT UIColor * kDoraemonBoxColorHexString(NSString *hexString);

/// Convert hexadecimal string to UIColor
/// @param hexString hexadecimal, the beginning of `0x` or `#` are also supported
/// @param alpha transparency
+ (UIColor *)colorWithHexString:(NSString *)hexString alpha:(float)alpha;

/// random color
FOUNDATION_EXPORT UIColor * kDoraemonBoxRandomColor(void);

@end

NS_ASSUME_NONNULL_END
