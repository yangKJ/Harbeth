//
//  UIView+KJXib.m
//  KJEmitterView
//
//  Created by yangkejun on 2020/8/10.
//  https://github.com/YangKJ/KJCategories

#import "UIView+KJXib.h"

@implementation UIView (KJXib)

#pragma mark - Xib中显示的属性
@dynamic viewImage;
- (void)setViewImage:(UIImage *)viewImage{
    if (viewImage) {
        CALayer *topLayer = [[CALayer alloc]init];
        [topLayer setBounds:self.bounds];
        [topLayer setPosition:CGPointMake(self.bounds.size.width*.5, self.bounds.size.height*.5)];
        [topLayer setContents:(id)viewImage.CGImage];
        [self.layer addSublayer:topLayer];
    }
}

@dynamic borderColor,borderWidth,cornerRadius;
- (void)setBorderColor:(UIColor *)borderColor {
    [self.layer setBorderColor:borderColor.CGColor];
}
- (void)setBorderWidth:(CGFloat)borderWidth {
    if (borderWidth <= 0) return;
    [self.layer setBorderWidth:borderWidth];
}
- (void)setCornerRadius:(CGFloat)cornerRadius {
    if (cornerRadius <= 0) return;
    [self.layer setCornerRadius:cornerRadius];
    self.layer.masksToBounds = YES;
    self.layer.shouldRasterize = YES;
    self.layer.rasterizationScale = [UIScreen mainScreen].scale;
}

@dynamic shadowColor,shadowRadius,shadowWidth,shadowOffset,shadowOpacity;
- (void)setShadowColor:(UIColor *)shadowColor{
    [self.layer setShadowColor:shadowColor.CGColor];
}
- (void)setShadowRadius:(CGFloat)shadowRadius{
    if (shadowRadius <= 0) return;
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:shadowRadius];
    [self.layer setShadowPath:path.CGPath];
}
- (void)setShadowWidth:(CGFloat)shadowWidth{
    if (shadowWidth <= 0) return;
    [self.layer setShadowRadius:shadowWidth];
}
- (void)setShadowOpacity:(CGFloat)shadowOpacity{
    [self.layer setShadowOpacity:shadowOpacity];
}
- (void)setShadowOffset:(CGSize)shadowOffset{
    [self.layer setShadowOffset:shadowOffset];
}
@dynamic bezierRadius;
- (void)setBezierRadius:(CGFloat)bezierRadius {
    if (bezierRadius <= 0) return;
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = self.bounds;
    maskLayer.path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:bezierRadius].CGPath;
    self.layer.mask = maskLayer;
}

/// 设置贝塞尔颜色边框，更高效
/// @param radius 半径
/// @param borderWidth 边框尺寸
/// @param borderColor 边框颜色
- (void)bezierBorderWithRadius:(CGFloat)radius borderWidth:(CGFloat)borderWidth borderColor:(UIColor *)borderColor{
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = self.bounds;
    
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:radius];
    maskLayer.path = path.CGPath;
    
    CAShapeLayer *borderLayer = [[CAShapeLayer alloc] init];
    borderLayer.frame = self.bounds;
    borderLayer.lineWidth = borderWidth;
    borderLayer.strokeColor = borderColor.CGColor;
    borderLayer.fillColor = [UIColor clearColor].CGColor;
    borderLayer.path = path.CGPath;
    
    [self.layer insertSublayer:borderLayer atIndex:0];
    self.layer.mask = maskLayer;
}

/// 设置阴影
/// @param color 阴影颜色
/// @param offset 阴影位移
/// @param radius 阴影半径
- (void)shadowColor:(UIColor *)color offset:(CGSize)offset radius:(CGFloat)radius{
    self.layer.shadowColor = color.CGColor;
    self.layer.shadowOffset = offset;
    self.layer.shadowRadius = radius;
    self.layer.shadowOpacity = 1;
    self.layer.shouldRasterize = YES;
    self.layer.rasterizationScale = [UIScreen mainScreen].scale;
}

/// 设置指定角落圆角
/// @param rectCorner 指定角落
/// @param cornerRadius 圆角半径
- (void)cornerWithRectCorner:(UIRectCorner)rectCorner cornerRadius:(CGFloat)cornerRadius{
    CGSize cornerSize = CGSizeMake(cornerRadius, cornerRadius);
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                   byRoundingCorners:rectCorner
                                                         cornerRadii:cornerSize];
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.frame = self.bounds;
    maskLayer.path = maskPath.CGPath;
    self.layer.mask = maskLayer;
    self.layer.masksToBounds = YES;
}

@end
