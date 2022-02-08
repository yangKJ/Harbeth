//
//  UIImage+KJCut.m
//  KJEmitterView
//
//  Created by yangkejun on 2020/8/10.
//  https://github.com/YangKJ/KJCategories

#import "UIImage+KJCut.h"

@implementation UIImage (KJCut)

/// 不规则图形切图
+ (UIImage *)kj_cutAnomalyImage:(UIView *)view bezierPath:(UIBezierPath *)path{
    CAShapeLayer *maskLayer = [CAShapeLayer layer];
    maskLayer.path = path.CGPath;
    maskLayer.fillColor = [UIColor blackColor].CGColor;
    maskLayer.strokeColor = [UIColor darkGrayColor].CGColor;
    maskLayer.frame = view.bounds;
    maskLayer.contentsCenter = CGRectMake(0.5, 0.5, 0.1, 0.1);
    maskLayer.contentsScale = [UIScreen mainScreen].scale;
    
    CALayer * contentLayer = [CALayer layer];
    contentLayer.mask = maskLayer;
    contentLayer.frame = view.bounds;
    view.layer.mask = maskLayer;
    UIImage *image = ({
        CGSize size = view.bounds.size;
        NSInteger quality = UIScreen.mainScreen.scale;
        CGRect rect = view.frame;
        size.width  = floorf(size.width  * quality) / quality;
        size.height = floorf(size.height * quality) / quality;
        rect = CGRectMake(rect.origin.x * quality, rect.origin.y * quality, rect.size.width * quality, rect.size.height * quality);
        UIGraphicsBeginImageContextWithOptions(size, NO, quality);
        [view.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        CGImageRef imageRef = CGImageCreateWithImageInRect([viewImage CGImage], rect);
        UIImage *newImage = [UIImage imageWithCGImage:imageRef];
        CGImageRelease(imageRef);
        newImage;
    });
    return image;
}
/// 多边形切图
+ (UIImage *)kj_cutPolygonImage:(UIImageView *)view pointArray:(NSArray *)points{
    CGRect rect = CGRectZero;
    rect.size = view.image.size;
    UIGraphicsBeginImageContextWithOptions(rect.size, YES, 0.0);
    [[UIColor blackColor] setFill];
    UIRectFill(rect);
    [[UIColor whiteColor] setFill];
    UIBezierPath *aPath = [UIBezierPath bezierPath];
    CGPoint p1 = [self convertCGPoint:[points[0] CGPointValue]
                            fromRect1:view.frame.size
                              toRect2:view.frame.size];
    [aPath moveToPoint:p1];
    for (int i = 1; i < points.count; i++) {
        CGPoint point = [self convertCGPoint:[points[i] CGPointValue]
                                   fromRect1:view.frame.size
                                     toRect2:view.frame.size];
        [aPath addLineToPoint:point];
    }
    [aPath closePath];
    [aPath fill];
    
    UIImage *mask = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0);
    CGContextClipToMask(UIGraphicsGetCurrentContext(), rect, mask.CGImage);
    [view.image drawAtPoint:CGPointZero];
    UIImage *maskedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return maskedImage;
}
+ (CGPoint)convertCGPoint:(CGPoint)point1 fromRect1:(CGSize)rect1 toRect2:(CGSize)rect2 {
    point1.y = rect1.height - point1.y;
    return CGPointMake((point1.x*rect2.width)/rect1.width, (point1.y*rect2.height)/rect1.height);
}
/// 根据特定的区域对图片进行裁剪
- (UIImage *)kj_cutImageWithCropRect:(CGRect)cropRect{
    return ({
        CGImageRef tmp = CGImageCreateWithImageInRect([self CGImage], cropRect);
        UIImage *newImage = [UIImage imageWithCGImage:tmp
                                                scale:self.scale
                                          orientation:self.imageOrientation];
        CGImageRelease(tmp);
        newImage;
    });
}
/// quartz 2d 实现裁剪
- (UIImage *)kj_quartzCutImageWithCropRect:(CGRect)cropRect{
    CGFloat scale = self.scale;
    if (scale != 1) {
        cropRect.origin.x *= scale;
        cropRect.origin.y *= scale;
        cropRect.size.width *= scale;
        cropRect.size.height *= scale;
    }
    UIGraphicsBeginImageContext(cropRect.size);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGImageRef imageRef = CGImageCreateWithImageInRect(self.CGImage, cropRect);
    CGContextDrawImage(ctx, cropRect, imageRef);
    UIImage * resultImage = [UIImage imageWithCGImage:imageRef];
    UIGraphicsEndImageContext();
    CGImageRelease(imageRef);
    return resultImage;
}
/// 图片路径裁剪，裁剪路径 "以外" 部分
- (UIImage *)kj_cutOuterImageBezierPath:(UIBezierPath *)path rect:(CGRect)rect{
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, self.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGMutablePathRef outer = CGPathCreateMutable();
    CGPathAddRect(outer, NULL, rect);
    CGPathAddPath(outer, NULL, path.CGPath);
    CGContextAddPath(context, outer);
    CGPathRelease(outer);
    CGContextSetBlendMode(context, kCGBlendModeClear);
    [self drawInRect:rect];
    CGContextDrawPath(context, kCGPathEOFill);
    UIImage *newimage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newimage;
}
/// 图片路径裁剪，裁剪路径 "以内" 部分
- (UIImage *)kj_cutInnerImageBezierPath:(UIBezierPath *)path rect:(CGRect)rect{
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, self.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetBlendMode(context, kCGBlendModeClear);/// kCGBlendModeClear 裁剪部分透明
    [self drawInRect:rect];
    CGContextAddPath(context, path.CGPath);
    CGContextDrawPath(context, kCGPathEOFill);
    UIImage *newimage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newimage;
}

/// 裁剪图片处理，以图片中心位置开始裁剪
- (UIImage *)kj_cutCenterClipImageWithSize:(CGSize)size{
    UIImage * aImage = self;
    CGFloat scale = MIN(aImage.size.width / [[UIScreen mainScreen] bounds].size.width,
                        aImage.size.height / [[UIScreen mainScreen] bounds].size.height);
    CGFloat x = 0.0;
    CGFloat y = 0.0;
    CGFloat w = size.width * scale;
    CGFloat h = size.height * scale;
    // 正面
    if (aImage.imageOrientation == UIImageOrientationUp) {
        x = (aImage.size.width - w) / 2.0;
        y = (aImage.size.height - h) / 2.0;
    } else if (aImage.imageOrientation == UIImageOrientationRight) {// 相机拍出来的照片是 right
        x = (aImage.size.height - w) / 2.0;
        y = (aImage.size.width - h) / 2.0;
    }
    // 裁剪
    CGImageRef cgRef = CGImageCreateWithImageInRect(aImage.CGImage, CGRectMake(x, y, w, h));
    UIImage * image = [UIImage imageWithCGImage:cgRef];
    CGImageRelease(cgRef);
    return image;
}

/// 裁剪掉图片周围的透明部分
- (UIImage *)kj_cutRoundAlphaZero{
    UIImage *image = self;
    CGImageRef cgimage = [image CGImage];
    size_t width  = CGImageGetWidth(cgimage);
    size_t height = CGImageGetHeight(cgimage);
    unsigned char *data = calloc(width * height * 4, sizeof(unsigned char));
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data,
                                                 width,
                                                 height,
                                                 8,
                                                 width * 4,
                                                 space,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgimage);
    int top = 0,left = 0,right = 0,bottom = 0;
    for (size_t row = 0; row < height; row++) {
        BOOL find = false;
        for (size_t col = 0; col < width; col++) {
            size_t pixelIndex = (row * width + col) * 4;
            int alpha = data[pixelIndex + 3];
            if (alpha != 0) {
                find = YES;
                break;
            }
        }
        if (find) break;
        top ++;
    }
    for (size_t col = 0; col < width; col++) {
        BOOL find = false;
        for (size_t row = 0; row < height; row++) {
            size_t pixelIndex = (row * width + col) * 4;
            int alpha = data[pixelIndex + 3];
            if (alpha != 0) {
                find = YES;
                break;
            }
        }
        if (find) break;
        left ++;
    }
    for (size_t col = width - 1; col > 0; col--) {
        BOOL find = false;
        for (size_t row = 0; row < height; row++) {
            size_t pixelIndex = (row * width + col) * 4;
            int alpha = data[pixelIndex + 3];
            if (alpha != 0) {
                find = YES;
                break;
            }
        }
        if (find) break;
        right ++;
    }
    
    for (size_t row = height - 1; row > 0; row--) {
        BOOL find = false;
        for (size_t col = 0; col < width; col++) {
            size_t pixelIndex = (row * width + col) * 4;
            int alpha = data[pixelIndex + 3];
            if (alpha != 0) {
                find = YES;
                break;
            }
        }
        if (find) break;
        bottom ++;
    }
    
    CGFloat scale = image.scale;
    CGImageRef newImageRef = CGImageCreateWithImageInRect(cgimage, CGRectMake(left*scale,
                                                                              top*scale,
                                                                              (image.size.width-left-right)*scale,
                                                                              (image.size.height-top-bottom)*scale));
    UIImage *newImage = [UIImage imageWithCGImage:newImageRef];
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    CGImageRelease(newImageRef);
    free(data);
    return newImage;
}

@end
