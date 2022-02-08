//
//  UIImage+KJCut.h
//  KJEmitterView
//
//  Created by yangkejun on 2020/8/10.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Picture cropper
@interface UIImage (KJCut)

/// Irregular graphics cutting
/// @param view crop view
/// @param path clipping path
/// @return returns the cropped image
+ (UIImage *)kj_cutAnomalyImage:(UIView *)view bezierPath:(UIBezierPath *)path;

/// Polygon cut
/// @param view crop view
/// @param points Polygon point coordinates
/// @return returns the cropped image
+ (UIImage *)kj_cutPolygonImage:(UIImageView *)view pointArray:(NSArray *)points;

/// Specify area crop
/// @param cropRect crop area
/// @return returns the cropped image
- (UIImage *)kj_cutImageWithCropRect:(CGRect)cropRect;

/// Quartz 2d realizes clipping
/// @return returns the cropped image
- (UIImage *)kj_quartzCutImageWithCropRect:(CGRect)cropRect;

/// Image path clipping, the "outside" part of the clipping path
/// @param path clipping path
/// @param rect canvas size
/// @return returns the cropped image
- (UIImage *)kj_cutOuterImageBezierPath:(UIBezierPath *)path rect:(CGRect)rect;

/// Image path clipping, the "within" part of the clipping path
/// @param path clipping path
/// @param rect canvas size
/// @return returns the cropped image
- (UIImage *)kj_cutInnerImageBezierPath:(UIBezierPath *)path rect:(CGRect)rect;

/// Crop picture processing, start cropping from the center of the picture
/// @param size crop size
/// @return returns the cropped image
- (UIImage *)kj_cutCenterClipImageWithSize:(CGSize)size;

/// Crop out the transparent part around the picture
- (UIImage *)kj_cutRoundAlphaZero;

@end

NS_ASSUME_NONNULL_END
