//
//  UIImage+Queen.h
//  MetalQueen
//
//  Created by 77。 on 2021/3/20.
//

/* **************** Need to introduce OpenCV library, pod 'OpenCV','~> 4.1.0' *******************/

#import <UIKit/UIKit.h>
#import "KJOpencvType.h"

#if __has_include(<opencv2/imgcodecs/ios.h>)

NS_ASSUME_NONNULL_BEGIN

/// https://docs.opencv.org/4.5.1/modules.html
@interface UIImage (Queen)

/// The picture is tiled
/// @param row row
/// @param col column
- (UIImage *)kj_opencvTiledRows:(int)row cols:(int)col;

/// Four-point perspective picture based on perspective
/// @param points Four points of perspective
/// @param size size
- (UIImage *)kj_opencvWarpPerspectiveWithKnownPoints:(KJKnownPoints)points size:(CGSize)size;

/// Eliminate image highlights
/// @param beta ambiguity, 0-2
/// @param alpha transparency, 0-2
- (UIImage *)kj_opencvIlluminationChangeBeta:(double)beta alpha:(double)alpha;

/// Picture mix
/// @param image mixed pictures, the prerequisite for the two pictures must be the same size and type
/// @param alpha transparency, 0-1
- (UIImage *)kj_opencvBlendImage:(UIImage *)image alpha:(double)alpha;

/// Adjust picture brightness and contrast
/// @param contrast brightness, 0-100
/// @param luminance contrast, 0-2
- (UIImage *)kj_opencvChangeContrast:(int)contrast luminance:(double)luminance;

/// Modify the color of the picture channel value, if you need to keep it unchanged, please pass -1
/// @param r red, 0-255
/// @param g green, 0-255
/// @param b blue, 0-255
- (UIImage *)kj_opencvChangeR:(int)r g:(int)g b:(int)b;

#pragma mark - filter blur block

/// Blur processing
- (UIImage *)kj_opencvBlurX:(int)x y:(int)y;

/// Gaussian blur, xy is positive and odd
- (UIImage *)kj_opencvGaussianBlurX:(int)x y:(int)y;

/// The median value is blurred, white particles can be removed, ksize must be positive and odd
- (UIImage *)kj_opencvMedianBlurksize:(int)ksize;

/// Gaussian bilateral blur, can be used for skin whitening effect
/// @param radio radius
/// @param sigma filter degree, 10-155
- (UIImage *)kj_opencvBilateralFilterBlurRadio:(int)radio sigma:(int)sigma;

/// Custom linear blur
- (UIImage *)kj_opencvCustomBlurksize:(int)ksize;

#pragma mark - Image morphology related

/// Morphological operation
/// @param type morphology style
/// @param element Corrosion and expansion degree
- (UIImage *)kj_opencvMorphology:(KJOpencvMorphologyStyle)type element:(int)element;

#pragma mark - Comprehensive effect processing

/// Repair the picture, you can remove the watermark
- (UIImage *)kj_opencvInpaintImage:(int)radius;

/// Picture repair, effect enhancement processing
- (UIImage *)kj_opencvRepairImage;

/// Image cropping algorithm, crop out the largest inner rectangular area
- (UIImage *)kj_opencvCutMaxRegionImage;

/// Picture stitching technology, combining multiple similar pictures into one
- (UIImage *)kj_opencvCompoundMoreImage:(UIImage *)image,...;

/// Feature extraction, based on Sobel operator
- (UIImage *)kj_opencvFeatureExtractionFromSobel;

/// Text type picture correction, straight line detection based on Hough line judgment correction
- (UIImage *)kj_opencvHoughLinesCorrectTextImageFillColor:(UIColor *)color;

@end

NS_ASSUME_NONNULL_END

#endif
