//
//  UIImage+KJExtension.m
//  KJEmitterView
//
//  Created by yangkejun on 2020/8/10.
//  https://github.com/YangKJ/KJCategories

#import "UIImage+KJExtension.h"

@implementation UIImage (KJExtension)

/// 生成颜色图片
/// @param color 生成图片颜色
/// @param size 图片尺寸
+ (UIImage *)kj_imageWithColor:(UIColor *)color size:(CGSize)size{
    if (!color || size.width <= 0 || size.height <= 0) return [[UIImage alloc] init];
    CGRect rect = CGRectMake(0.0f, 0.0f, size.width, size.height);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, rect);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
/// 改变图片颜色
- (UIImage *)kj_changeImageColor:(UIColor *)color{
    UIGraphicsBeginImageContext(CGSizeMake(self.size.width*2, self.size.height*2));
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect area = CGRectMake(0, 0, self.size.width * 2, self.size.height * 2);
    CGContextScaleCTM(ctx, 1, -1);
    CGContextTranslateCTM(ctx, 0, -area.size.height);
    CGContextSaveGState(ctx);
    CGContextClipToMask(ctx, area, self.CGImage);
    [color set];
    CGContextFillRect(ctx, area);
    CGContextRestoreGState(ctx);
    CGContextSetBlendMode(ctx, kCGBlendModeMultiply);
    CGContextDrawImage(ctx, area, self.CGImage);
    UIImage *destImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return destImage;
}
/// 改变图片内部像素颜色
- (UIImage *)kj_changeImagePixelColor:(UIColor *)color{
    CGFloat red = 0, green = 0, blue = 0, a;
    [color getRed:&red green:&green blue:&blue alpha:&a];
    int imageWidth = self.size.width;
    int imageHeight = self.size.height;
    size_t bytesPerRow = imageWidth * 4;
    uint32_t *rgbImageBuf = (uint32_t *)malloc(bytesPerRow * imageHeight);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(rgbImageBuf,
                                                 imageWidth,
                                                 imageHeight,
                                                 8,
                                                 bytesPerRow,
                                                 space,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipLast);
    CGContextDrawImage(context, CGRectMake(0, 0, imageWidth, imageHeight), self.CGImage);
    int pixelNum = imageWidth * imageHeight;
    uint32_t *pCurPtr = rgbImageBuf;
    for (int i = 0; i<pixelNum; i++, pCurPtr++) {
        if ((*pCurPtr & 0xFFFFFF00) < 0x99999900) {
            uint8_t *ptr = (uint8_t*)pCurPtr;
            ptr[3] = red*255;
            ptr[2] = green*255;
            ptr[1] = blue*255;
        } else {
            uint8_t *ptr = (uint8_t*)pCurPtr;
            ptr[0] = 0;
        }
    }
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, rgbImageBuf, bytesPerRow * imageHeight, kProviderReleaseData);
    CGImageRef imageRef = CGImageCreate(imageWidth,
                                        imageHeight,
                                        8,
                                        32,
                                        bytesPerRow,
                                        space,
                                        kCGImageAlphaLast | kCGBitmapByteOrder32Little,
                                        dataProvider,
                                        NULL,
                                        true,
                                        kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);
    UIImage *resultImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return resultImage;
}
/// 释放
static void kProviderReleaseData(void *info, const void * data, size_t size){
    free((void*)data);
}

/// 改变图片透明度
- (UIImage *)kj_changeImageAlpha:(CGFloat)alpha{
    UIGraphicsBeginImageContextWithOptions(self.size, NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect area = CGRectMake(0, 0, self.size.width, self.size.height);
    CGContextScaleCTM(ctx, 1, -1);
    CGContextTranslateCTM(ctx, 0, -area.size.height);
    CGContextSetBlendMode(ctx, kCGBlendModeMultiply);
    CGContextSetAlpha(ctx, alpha);
    CGContextDrawImage(ctx, area, self.CGImage);
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}
/// 改变图片亮度
- (UIImage *)kj_changeImageLuminance:(CGFloat)luminance{
    CGImageRef cgimage = self.CGImage;
    size_t width  = CGImageGetWidth(cgimage);
    size_t height = CGImageGetHeight(cgimage);
    UInt32 * data = (UInt32 *)calloc(width * height * 4, sizeof(UInt32));
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data,
                                                 width,
                                                 height,
                                                 8,
                                                 width * 4,
                                                 space,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgimage);
    for (size_t i = 0; i < height; i++){
        for (size_t j = 0; j < width; j++){
            size_t pixelIndex = i * width * 4 + j * 4;
            UInt32 red   = data[pixelIndex];
            UInt32 green = data[pixelIndex + 1];
            UInt32 blue  = data[pixelIndex + 2];
            red += luminance;
            green += luminance;
            blue += luminance;
            data[pixelIndex]     = red > 255 ? 255 : red;
            data[pixelIndex + 1] = green > 255 ? 255 : green;
            data[pixelIndex + 2] = blue > 255 ? 255 : blue;
        }
    }
    cgimage = CGBitmapContextCreateImage(context);
    UIImage *newImage = [UIImage imageWithCGImage:cgimage];
    CGColorSpaceRelease(space);
    CGContextRelease(context);
    CGImageRelease(cgimage);
    free(data);
    return newImage;
}

/// 修改图片线条颜色
- (UIImage *)kj_imageLinellaeColor:(UIColor *)color{
    return [self kj_imageBlendMode:kCGBlendModeDestinationIn tineColor:color];
}
/// 图层混合
- (UIImage *)kj_imageBlendMode:(CGBlendMode)blendMode tineColor:(UIColor *)tintColor{
    UIGraphicsBeginImageContextWithOptions(self.size, NO, 0.0f);
    [tintColor setFill];
    CGRect bounds = CGRectMake(0, 0, self.size.width, self.size.height);
    UIRectFill(bounds);
    [self drawInRect:bounds blendMode:blendMode alpha:1.0f];
    if (blendMode != kCGBlendModeDestinationIn) {
        [self drawInRect:bounds blendMode:kCGBlendModeDestinationIn alpha:1.0f];
    }
    UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return tintedImage;
}

@end
