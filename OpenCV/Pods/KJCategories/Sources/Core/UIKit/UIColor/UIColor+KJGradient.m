//
//  UIColor+KJGradient.m
//  KJCategories
//
//  Created by 77。 on 2021/11/7.
//  https://github.com/YangKJ/KJCategories

#import "UIColor+KJGradient.h"

@implementation UIColor (KJGradient)
/// 图片生成颜色
+ (UIColor *)kj_colorWithImage:(UIImage *)image{
    return [UIColor colorWithPatternImage:image];
}
/// 兼容Swift版本，可变参数渐变色
- (UIColor *)kj_gradientSize:(CGSize)size color:(UIColor *)color,...{
    NSMutableArray * colors = [NSMutableArray arrayWithObjects:(id)self.CGColor,(id)color.CGColor,nil];
    va_list args;UIColor * arg;
    va_start(args, color);
    while ((arg = va_arg(args, UIColor *))) {
        [colors addObject:(id)arg.CGColor];
    }
    va_end(args);
    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColors(colorspace, (__bridge CFArrayRef)colors, NULL);
    CGContextDrawLinearGradient(context, gradient, CGPointZero, CGPointMake(size.width, size.height), 0);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorspace);
    UIGraphicsEndImageContext();
    return [UIColor colorWithPatternImage:image];
}
/// 渐变色
- (UIColor *)kj_gradientVerticalToColor:(UIColor *)color height:(CGFloat)height{
    CGSize size = CGSizeMake(1, height);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    NSArray * colors = [NSArray arrayWithObjects:(id)self.CGColor, (id)color.CGColor, nil];
    CGGradientRef gradient = CGGradientCreateWithColors(colorspace, (__bridge CFArrayRef)colors, NULL);
    CGContextDrawLinearGradient(context, gradient, CGPointMake(0, 0), CGPointMake(0, size.height), 0);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorspace);
    UIGraphicsEndImageContext();
    return [UIColor colorWithPatternImage:image];
}
- (UIColor *)kj_gradientAcrossToColor:(UIColor *)color width:(CGFloat)width{
    CGSize size = CGSizeMake(width, 1);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    NSArray * colors = [NSArray arrayWithObjects:(id)self.CGColor, (id)color.CGColor, nil];
    CGGradientRef gradient = CGGradientCreateWithColors(colorspace, (__bridge CFArrayRef)colors, NULL);
    CGContextDrawLinearGradient(context, gradient, CGPointMake(0, 0), CGPointMake(size.width, size.height), 0);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorspace);
    UIGraphicsEndImageContext();
    return [UIColor colorWithPatternImage:image];
}

/// 生成渐变色图片
+ (UIImage *)kj_colorImageWithColors:(NSArray<UIColor*>*)colors
                           locations:(NSArray<NSNumber*>*)locations
                                size:(CGSize)size
                         borderWidth:(CGFloat)borderWidth
                         borderColor:(UIColor *)borderColor{
    NSAssert(colors || locations, @"colors and locations must has value");
    NSAssert(colors.count == locations.count, @"Please make sure colors and locations count is equal");
    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (borderWidth > 0 && borderColor) {
        CGRect rect = CGRectMake(size.width * 0.01, 0, size.width * 0.98, size.height);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:size.height*0.5];
        [borderColor setFill];
        [path fill];
    }
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(size.width * 0.01 + borderWidth,
                                                                            borderWidth,
                                                                            size.width * 0.98 - borderWidth * 2,
                                                                            size.height - borderWidth * 2)
                                                    cornerRadius:size.height * 0.5];
    [self kj_drawLinearGradient:context path:path.CGPath colors:colors locations:locations];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}
+ (void)kj_drawLinearGradient:(CGContextRef)context
                         path:(CGPathRef)path
                       colors:(NSArray<UIColor*>*)colors
                    locations:(NSArray<NSNumber*>*)locations{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSMutableArray *colorefs = [@[] mutableCopy];
    [colors enumerateObjectsUsingBlock:^(UIColor *obj, NSUInteger idx, BOOL *stop) {
        [colorefs addObject:(__bridge id)obj.CGColor];
    }];
    CGFloat locs[locations.count];
    for (int i = 0; i < locations.count; i++) {
        locs[i] = locations[i].floatValue;
    }
    CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colorefs, locs);
    CGRect pathRect = CGPathGetBoundingBox(path);
    CGPoint startPoint = CGPointMake(CGRectGetMinX(pathRect), CGRectGetMidY(pathRect));
    CGPoint endPoint = CGPointMake(CGRectGetMaxX(pathRect), CGRectGetMidY(pathRect));
    CGContextSaveGState(context);
    CGContextAddPath(context, path);
    CGContextClip(context);
    CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, 0);
    CGContextRestoreGState(context);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(colorSpace);
}

@end
