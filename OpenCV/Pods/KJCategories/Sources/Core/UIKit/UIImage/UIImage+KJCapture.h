//
//  UIImage+KJCapture.h
//  KJEmitterView
//
//  Created by yangkejun on 2020/8/10.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Screenshot processing
@interface UIImage (KJCapture)

/// Screenshot of current view
+ (UIImage *)kj_captureScreen:(UIView *)view;

/// Screen shot of specified location
/// @param view screenshot control
/// @param rect intercept size
+ (UIImage *)kj_captureScreen:(UIView *)view Rect:(CGRect)rect;

/// Screenshot of custom quality
/// @param view is intercepted view
/// @param rect intercept size
/// @param quality quality multiple
/// @return return screenshot
+ (UIImage *)kj_captureScreen:(UIView *)view Rect:(CGRect)rect Quality:(NSInteger)quality;

/// Take a screenshot of the current screen (window screenshot)
+ (UIImage *)kj_captureScreenWindow;

/// Capture the current screen (rotate according to the direction of the phone)
+ (UIImage *)kj_captureScreenWindowForInterfaceOrientation;

/// Take a screenshot of the scroll view
/// @param scroll intercept view
/// @param contentOffset start to intercept position
/// @return return screenshot
+ (UIImage *)kj_captureScreenWithScrollView:(UIScrollView *)scroll
                              contentOffset:(CGPoint)contentOffset;

@end

NS_ASSUME_NONNULL_END
