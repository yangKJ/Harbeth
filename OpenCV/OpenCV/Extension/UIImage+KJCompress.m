//
//  UIImage+KJCompress.m
//  KJEmitterView
//
//  Created by yangkejun on 2020/8/10.
//  https://github.com/YangKJ/KJCategories


#import "UIImage+KJCompress.h"

@import ImageIO;
@import QuartzCore;

@implementation UIImage (KJCompress)

/// 压缩图片到指定大小
- (UIImage *)kj_compressTargetByte:(NSUInteger)maxLength{
    return [UIImage kj_compressImage:self TargetByte:maxLength];
}
+ (UIImage *)kj_compressImage:(UIImage *)image TargetByte:(NSUInteger)maxLength{
    CGFloat compression = 1.;
    NSData *data = UIImageJPEGRepresentation(image, compression);
    if (data.length < maxLength) return image;
    CGFloat max = 1,min = 0;
    for (int i = 0; i < 6; ++i) {
        compression = (max + min) / 2;
        data = UIImageJPEGRepresentation(image, compression);
        if (data.length < maxLength * 0.9) {
            min = compression;
        } else if (data.length > maxLength) {
            max = compression;
        }else {
            break;
        }
    }
    UIImage *resultImage = [UIImage imageWithData:data];
    if (data.length < maxLength) return resultImage;
    NSUInteger lastDataLength = 0;
    while (data.length > maxLength && data.length != lastDataLength) {
        lastDataLength = data.length;
        CGFloat ratio = (CGFloat)maxLength / data.length;
        CGSize size = CGSizeMake((NSUInteger)(resultImage.size.width * sqrtf(ratio)), (NSUInteger)(resultImage.size.height * sqrtf(ratio)));
        UIGraphicsBeginImageContext(size);
        [resultImage drawInRect:CGRectMake(0, 0, size.width, size.height)];
        resultImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        data = UIImageJPEGRepresentation(resultImage, compression);
    }
    return resultImage;
}
#pragma mark - UIKit方式
- (UIImage *)kj_UIKitChangeImageSize:(CGSize)size{
    UIGraphicsBeginImageContext(size);
    [self drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

#pragma mark - Quartz 2D
- (UIImage *)kj_QuartzChangeImageSize:(CGSize)size{
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0.0, size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height), self.CGImage);
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

#pragma mark - ImageIO
- (UIImage *)kj_ImageIOChangeImageSize:(CGSize)size{
    NSData *date = UIImagePNGRepresentation(self);
    int max = (int)MAX(size.width, size.height);
    CFDictionaryRef dictionaryRef = (__bridge CFDictionaryRef) @{(id)kCGImageSourceCreateThumbnailFromImageIfAbsent : @(YES),
                                                                 (id)kCGImageSourceThumbnailMaxPixelSize : @(max),
                                                                 (id)kCGImageSourceShouldCache : @(YES)};
    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)date, nil);
    CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(src, 0, dictionaryRef);
    UIImage *newImage = [UIImage imageWithCGImage:imageRef];
    if (imageRef != nil) CFRelease(imageRef);
    CFRelease(src);
    return newImage;
}

#pragma mark - CoreGraphics

/// 图片压缩
- (UIImage *)kj_BitmapChangeImageSize:(CGSize)size{
    const size_t width = size.width, height = size.height;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 width,
                                                 height,
                                                 8,
                                                 width * 4,
                                                 space,
                                                 kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (!context) return nil;
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), self.CGImage);
    UInt8 * data = (UInt8*)CGBitmapContextGetData(context);
    if (!data){
        CGContextRelease(context);
        return nil;
    }
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    UIImage *newImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGContextRelease(context);
    return newImage;
}

/// 自定义质量的截图，quality质量倍数
+ (UIImage *)kj_captureScreen:(UIView *)view Rect:(CGRect)rect Quality:(NSInteger)quality{
    return ({
        CGSize size = view.bounds.size;
        size.width  = floorf(size.width  * quality) / quality;
        size.height = floorf(size.height * quality) / quality;
        rect = CGRectMake(rect.origin.x*quality, rect.origin.y*quality, rect.size.width*quality, rect.size.height*quality);
        UIGraphicsBeginImageContextWithOptions(size, NO, quality);
        [view.layer renderInContext:UIGraphicsGetCurrentContext()];
        UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        CGImageRef imageRef = CGImageCreateWithImageInRect([viewImage CGImage], rect);
        UIImage *newImage = [UIImage imageWithCGImage:imageRef];
        CGImageRelease(imageRef);
        newImage;
    });
}

@end
