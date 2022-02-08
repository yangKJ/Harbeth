//
//  UIImage+KJCapture.m
//  KJEmitterView
//
//  Created by yangkejun on 2020/8/10.
//  https://github.com/YangKJ/KJCategories


#import "UIImage+KJCapture.h"

@implementation UIImage (KJCapture)

#pragma mark - 截图处理
/// 屏幕截图
+ (UIImage *)kj_captureScreen:(UIView *)view{
    return [UIImage kj_captureScreen:view Rect:view.frame];
}
/// 指定位置屏幕截图
+ (UIImage *)kj_captureScreen:(UIView *)view Rect:(CGRect)rect{
    return [self kj_captureScreen:view Rect:rect Quality:UIScreen.mainScreen.scale];
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
/// 截取当前屏幕
+ (UIImage *)kj_captureScreenWindow{
    CGSize imageSize = [UIScreen mainScreen].bounds.size;
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    for (UIWindow *window in [[UIApplication sharedApplication] windows]){
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, window.center.x, window.center.y);
        CGContextConcatCTM(context, window.transform);
        CGContextTranslateCTM(context, -window.bounds.size.width * window.layer.anchorPoint.x,
                              -window.bounds.size.height * window.layer.anchorPoint.y);
        if ([window respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)]){
            [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
        } else {
            [window.layer renderInContext:context];
        }
        CGContextRestoreGState(context);
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
/// 截取当前屏幕
+ (UIImage *)kj_captureScreenWindowForInterfaceOrientation{
    CGSize imageSize = CGSizeZero;
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (UIInterfaceOrientationIsPortrait(orientation)){
        imageSize = [UIScreen mainScreen].bounds.size;
    } else {
        imageSize = CGSizeMake([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width);
    }
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    for (UIWindow *window in [[UIApplication sharedApplication] windows]){
        CGContextSaveGState(context);
        CGContextTranslateCTM(context, window.center.x, window.center.y);
        CGContextConcatCTM(context, window.transform);
        CGContextTranslateCTM(context, -window.bounds.size.width * window.layer.anchorPoint.x,
                              -window.bounds.size.height * window.layer.anchorPoint.y);
        if (orientation == UIInterfaceOrientationLandscapeLeft){
            CGContextRotateCTM(context, M_PI_2);
            CGContextTranslateCTM(context, 0, -imageSize.width);
        } else if (orientation == UIInterfaceOrientationLandscapeRight){
            CGContextRotateCTM(context, -M_PI_2);
            CGContextTranslateCTM(context, -imageSize.height, 0);
        } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
            CGContextRotateCTM(context, M_PI);
            CGContextTranslateCTM(context, -imageSize.width, -imageSize.height);
        }
        if ([window respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)]){
            [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
        } else {
            [window.layer renderInContext:context];
        }
        CGContextRestoreGState(context);
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}
/// 截取滚动的长图
+ (UIImage *)kj_captureScreenWithScrollView:(UIScrollView *)scroll contentOffset:(CGPoint)offset{
    UIGraphicsBeginImageContext(scroll.bounds.size);
    CGContextTranslateCTM(UIGraphicsGetCurrentContext(), 0.0f, -offset.y);
    [scroll.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end
