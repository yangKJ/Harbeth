//
//  UIColor+KJGradient.h
//  KJCategories
//
//  Created by 77。 on 2021/11/7.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIColor (KJGradient)

/// Picture generated color
+ (UIColor *)kj_colorWithImage:(UIImage *)image;

/// Variable parameter gradient color
/// @param size Gradient color size box
/// @param color Indefinite number of gradient colors, need to end with nil
- (UIColor *)kj_gradientSize:(CGSize)size color:(UIColor *)color,... NS_REFINED_FOR_SWIFT;

/// Vertical gradient color
/// @param color end color
/// @param height gradient height
/// @return returns the vertical gradient color
- (UIColor *)kj_gradientVerticalToColor:(UIColor *)color height:(CGFloat)height;

/// Horizontal gradient color
/// @param color end color
/// @param width gradient color width
/// @return returns the horizontal gradient color
- (UIColor *)kj_gradientAcrossToColor:(UIColor *)color width:(CGFloat)width;

/// Generate gradient color pictures with borders
/// @param colors gradient color array
/// @param locations The proportion of each group of gradient colors
/// @param size size
/// @param borderWidth border width
/// @param borderColor border color
+ (UIImage *)kj_colorImageWithColors:(NSArray<UIColor *> *)colors
                           locations:(NSArray<NSNumber *> *)locations
                                size:(CGSize)size
                         borderWidth:(CGFloat)borderWidth
                         borderColor:(UIColor *)borderColor;

@end

NS_ASSUME_NONNULL_END
