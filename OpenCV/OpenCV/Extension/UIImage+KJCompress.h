//
//  UIImage+KJCompress.h
//  KJEmitterView
//
//  Created by yangkejun on 2020/8/10.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (KJCompress)

/// Compress the picture to the specified size
/// @param maxLength specifies the size
- (UIImage *)kj_compressTargetByte:(NSUInteger)maxLength;
+ (UIImage *)kj_compressImage:(UIImage *)image TargetByte:(NSUInteger)maxLength;

/// UIKit way
- (UIImage *)kj_UIKitChangeImageSize:(CGSize)size;

/// Quartz 2D
- (UIImage *)kj_QuartzChangeImageSize:(CGSize)size;

/// ImageIO, the best performance
- (UIImage *)kj_ImageIOChangeImageSize:(CGSize)size;

/// CoreGraphics
- (UIImage *)kj_BitmapChangeImageSize:(CGSize)size;

/// Screenshot of custom quality
/// @param view is intercepted view
/// @param rect intercept size
/// @param quality quality multiple
/// @return return screenshot
+ (UIImage *)kj_captureScreen:(UIView *)view Rect:(CGRect)rect Quality:(NSInteger)quality;

@end

NS_ASSUME_NONNULL_END
