//
//  UIImage+KJResize.h
//  KJEmitterView
//
//  Created by yangkejun on 2020/8/10.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (KJResize)

/// Scale the picture by proportion
/// @param scale zoom scale
- (UIImage *)kj_scaleImage:(CGFloat)scale;

/// Scale the image with a fixed width
/// @param width fixed width
- (UIImage *)kj_scaleWithFixedWidth:(CGFloat)width;

/// Scale the image with a fixed height
/// @param height fixed height
- (UIImage *)kj_scaleWithFixedHeight:(CGFloat)height;

/// Change the picture size proportionally
/// @param size size box
- (UIImage *)kj_cropImageWithAnySize:(CGSize)size;

/// Reduce the size of the picture proportionally
/// @param size Reduce size
- (UIImage *)kj_zoomImageWithMaxSize:(CGSize)size;

/// Do not pull up and fill the picture
/// @param size fill size
- (UIImage *)kj_fitImageWithSize:(CGSize)size;

/// Rotate pictures and mirror image processing
/// @param orientation rotation direction
- (UIImage *)kj_rotationImageWithOrientation:(UIImageOrientation)orientation;

/// Oval picture, the picture will appear cut out ellipse when the picture is different in length and width
- (UIImage *)kj_ellipseImage;

/// round picture
- (UIImage *)kj_circleImage;

/// Border circle picture
/// @param borderWidth border width
/// @param borderColor border color
/// @return returns the picture with border added
- (UIImage *)kj_squareCircleImageWithBorderWidth:(CGFloat)borderWidth
                                     borderColor:(UIColor *)borderColor;

@end

NS_ASSUME_NONNULL_END
