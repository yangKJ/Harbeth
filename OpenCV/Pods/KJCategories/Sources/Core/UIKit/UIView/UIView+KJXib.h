//
//  UIView+KJXib.h
//  KJEmitterView
//
//  Created by yangkejun on 2020/8/10.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Show attributes in Xib IBInspectable can visually display related attributes
@interface UIView (KJXib)

/// Image attribute, note that this will overwrite the image set on UIImageView
@property (nonatomic, strong) IBInspectable UIImage *viewImage;

/// Rounded border
@property (nonatomic, strong) IBInspectable UIColor *borderColor;
@property (nonatomic, assign) IBInspectable CGFloat borderWidth;
@property (nonatomic, assign) IBInspectable CGFloat cornerRadius;

/// Shadow, note that the shadow will not take effect when the default color of View is ClearColor
@property (nonatomic, strong) UIColor *shadowColor;
@property (nonatomic, assign) CGFloat shadowRadius;
@property (nonatomic, assign) CGFloat shadowWidth;
@property (nonatomic, assign) CGFloat shadowOpacity;
@property (nonatomic, assign) CGSize shadowOffset;

/// Bezier round corners, a faster and more efficient way to round corners
@property (nonatomic, assign) CGFloat bezierRadius;

/// Set Bézier color border, more efficient
/// @param radius radius
/// @param borderWidth border size
/// @param borderColor border color
- (void)bezierBorderWithRadius:(CGFloat)radius
                   borderWidth:(CGFloat)borderWidth
                   borderColor:(UIColor *)borderColor;

/// set shadow
/// @param color shadow color
/// @param offset shadow displacement
/// @param radius shadow radius
- (void)shadowColor:(UIColor *)color offset:(CGSize)offset radius:(CGFloat)radius;

/// Set the specified corner fillet
/// @param rectCorner specifies the corner
/// @param cornerRadius round corner radius
- (void)cornerWithRectCorner:(UIRectCorner)rectCorner cornerRadius:(CGFloat)cornerRadius;

@end

NS_ASSUME_NONNULL_END
