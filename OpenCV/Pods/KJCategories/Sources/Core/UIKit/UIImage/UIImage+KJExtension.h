//
//  UIImage+KJExtension.h
//  KJEmitterView
//
//  Created by yangkejun on 2020/8/10.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (KJExtension)

/// Generate color picture
/// @param color Generate image color, support gradient color
/// @param size image size
+ (UIImage *)kj_imageWithColor:(UIColor *)color size:(CGSize)size;

/// Change the background color of the picture
/// @param color target color
- (UIImage *)kj_changeImageColor:(UIColor *)color;

/// Change the pixel color inside the picture
/// @param color pixel color
- (UIImage *)kj_changeImagePixelColor:(UIColor *)color;

/// Change picture transparency
/// @param alpha transparency, 0-1
- (UIImage *)kj_changeImageAlpha:(CGFloat)alpha;

/// Change picture brightness
/// @param luminance brightness, 0-1
- (UIImage *)kj_changeImageLuminance:(CGFloat)luminance;

/// Modify the line color of the picture
/// @param color modify color
- (UIImage *)kj_imageLinellaeColor:(UIColor *)color;

/// Layer mixing, https://blog.csdn.net/yignorant/article/details/77864887
/// @param blendMode blend type
/// @param tintColor color
/// @return returns the picture after mixing
- (UIImage *)kj_imageBlendMode:(CGBlendMode)blendMode tineColor:(UIColor *)tintColor;

@end

NS_ASSUME_NONNULL_END
