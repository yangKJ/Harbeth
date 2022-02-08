//
//  UIImage+KJResize.m
//  KJEmitterView
//
//  Created by yangkejun on 2020/8/10.
//  https://github.com/YangKJ/KJCategories

#import "UIImage+KJResize.h"

@implementation UIImage (KJResize)

/// 等比改变图片尺寸
- (UIImage *)kj_cropImageWithAnySize:(CGSize)size{
    float scale = self.size.width/self.size.height;
    CGRect rect = CGRectZero;
    if (scale > size.width/size.height){
        rect.origin.x = (self.size.width - self.size.height * size.width/size.height)/2;
        rect.size.width  = self.size.height * size.width/size.height;
        rect.size.height = self.size.height;
    } else {
        rect.origin.y = (self.size.height - self.size.width/size.width * size.height)/2;
        rect.size.width  = self.size.width;
        rect.size.height = self.size.width/size.width * size.height;
    }
    CGImageRef imageRef = CGImageCreateWithImageInRect(self.CGImage, rect);
    UIImage *croppedImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    return croppedImage;
}
/// 等比缩小图片尺寸
- (UIImage *)kj_zoomImageWithMaxSize:(CGSize)size{
    float imgHeight = self.size.height;
    float imgWidth  = self.size.width;
    float maxHeight = size.width;
    float maxWidth = size.height;
    float imgRatio = imgWidth/imgHeight;
    float maxRatio = maxWidth/maxHeight;
    if (imgHeight <= maxHeight && imgWidth <= maxWidth) return self;
    if (imgHeight > maxHeight || imgWidth > maxWidth) {
        if (imgRatio < maxRatio) {
            imgRatio = maxHeight / imgHeight;
            imgWidth = imgRatio * imgWidth;
            imgHeight = maxHeight;
        } else if (imgRatio > maxRatio) {
            imgRatio = maxWidth / imgWidth;
            imgHeight = imgRatio * imgHeight;
            imgWidth = maxWidth;
        }else {
            imgHeight = maxHeight;
            imgWidth = maxWidth;
        }
    }
    CGRect rect = CGRectMake(0.0, 0.0, imgWidth, imgHeight);
    UIGraphicsBeginImageContext(rect.size);
    [self drawInRect:rect];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}
- (UIImage *)kj_scaleWithFixedWidth:(CGFloat)width {
    float newHeight = self.size.height * (width / self.size.width);
    CGSize size = CGSizeMake(width, newHeight);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0.0, size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, size.width, size.height), self.CGImage);
    UIImage *imageOut = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return imageOut;
}
- (UIImage *)kj_scaleWithFixedHeight:(CGFloat)height {
    float newWidth = self.size.width * (height / self.size.height);
    CGSize size = CGSizeMake(newWidth, height);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0.0, size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, size.width, size.height), self.CGImage);
    UIImage *imageOut = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return imageOut;
}
/// 通过比例来缩放图片
- (UIImage *)kj_scaleImage:(CGFloat)scale{
    UIGraphicsBeginImageContext(CGSizeMake(self.size.width * scale, self.size.height * scale));
    [self drawInRect:CGRectMake(0, 0, self.size.width * scale, self.size.height * scale)];
    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return scaledImage;
}
/// 不拉升填充图片
- (UIImage *)kj_fitImageWithSize:(CGSize)size{
    CGFloat x,y,w,h;
    if ((self.size.width/self.size.height)<(size.width/size.height)) {
        y = 0.;
        h = size.height;
        w = self.size.width * h / self.size.height;
        x = (size.width - w) / 2.;
    }else {
        x = 0.;
        w = size.width;
        h = self.size.height * w / self.size.width;
        y = -(size.height - h) / 2.;
    }
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0.0, h);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextDrawImage(context, CGRectMake(x, y, w, h), self.CGImage);
    UIImage *imageOut = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return imageOut;
}

/// 旋转图片和镜像处理
- (UIImage *)kj_rotationImageWithOrientation:(UIImageOrientation)orientation{
    CGRect rect = CGRectMake(0, 0, CGImageGetWidth(self.CGImage), CGImageGetHeight(self.CGImage));
    CGRect bounds = rect;
    CGRect (^kSwapWidthAndHeight)(CGRect) = ^CGRect(CGRect rect) {
        CGFloat swap = rect.size.width;
        rect.size.width  = rect.size.height;
        rect.size.height = swap;
        return rect;
    };
    CGAffineTransform transform = CGAffineTransformIdentity;
    switch (orientation) {
        case UIImageOrientationUp:
            break;
        case UIImageOrientationUpMirrored:
            transform = CGAffineTransformMakeTranslation(rect.size.width, 0.0);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            break;
        case UIImageOrientationDown:
            transform = CGAffineTransformMakeTranslation(rect.size.width,rect.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformMakeTranslation(0.0, rect.size.height);
            transform = CGAffineTransformScale(transform, 1.0, -1.0);
            break;
        case UIImageOrientationLeft:
            bounds = kSwapWidthAndHeight(bounds);
            transform = CGAffineTransformMakeTranslation(0.0, rect.size.width);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
        case UIImageOrientationLeftMirrored:
            bounds = kSwapWidthAndHeight(bounds);
            transform = CGAffineTransformMakeTranslation(rect.size.height,rect.size.width);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
        case UIImageOrientationRight:
            bounds = kSwapWidthAndHeight(bounds);
            transform = CGAffineTransformMakeTranslation(rect.size.height, 0.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
        case UIImageOrientationRightMirrored:
            bounds = kSwapWidthAndHeight(bounds);
            transform = CGAffineTransformMakeScale(-1.0, 1.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
    }
    UIGraphicsBeginImageContext(bounds.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    switch (orientation){
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            CGContextScaleCTM(context, -1.0, 1.0);
            CGContextTranslateCTM(context, -rect.size.height, 0.0);
            break;
        default:
            CGContextScaleCTM(context, 1.0, -1.0);
            CGContextTranslateCTM(context, 0.0, -rect.size.height);
            break;
    }
    CGContextConcatCTM(context, transform);
    CGContextDrawImage(UIGraphicsGetCurrentContext(), rect, self.CGImage);
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}
/// 椭圆形图片
- (UIImage *)kj_ellipseImage{
    UIGraphicsBeginImageContextWithOptions(self.size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect rect = CGRectMake(0, 0, self.size.width, self.size.height);
    CGContextAddEllipseInRect(ctx, rect);
    CGContextClip(ctx);
    [self drawInRect:rect];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
/// 圆形图片
- (UIImage *)kj_circleImage{
    CGFloat width = MIN(self.size.width, self.size.height);
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, width), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextAddEllipseInRect(ctx, CGRectMake(0, 0, width, width));
    CGContextClip(ctx);
    [self drawInRect:CGRectMake(0, 0, self.size.width, self.size.height)];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
/// 边框圆形图片
- (UIImage *)kj_squareCircleImageWithBorderWidth:(CGFloat)borderWidth borderColor:(UIColor *)borderColor{
    CGFloat width = self.size.width + 2 * borderWidth;
    CGFloat height = width;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [borderColor set];
    CGFloat bigRadius = width * 0.5;
    CGFloat centerX = bigRadius;
    CGFloat centerY = bigRadius;
    CGContextAddArc(context, centerX, centerY, bigRadius, 0, M_PI * 2, 0);
    CGContextFillPath(context);
    CGFloat smallRadius = bigRadius - borderWidth;
    CGContextAddArc(context, centerX, centerY, smallRadius, 0, M_PI * 2, 0);
    CGContextClip(context);
    [self drawInRect:CGRectMake(borderWidth, borderWidth, width, height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

@end
