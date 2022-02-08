//
//  UIView+KJFrame.h
//  CategoryDemo
//
//  Created by 77。 on 2018/7/12.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#define kKeyWindow \
({UIWindow *window;\
if (@available(iOS 13.0, *)) {\
window = [UIApplication sharedApplication].windows.firstObject;\
} else {\
window = [UIApplication sharedApplication].keyWindow;\
}\
window;})
// Determine whether it is iPhone X series
#define iPhoneX \
({BOOL isPhoneX = NO;\
if (@available(iOS 13.0, *)) {\
isPhoneX = [UIApplication sharedApplication].windows.firstObject.safeAreaInsets.bottom > 0.0;\
} else if (@available(iOS 11.0, *)) {\
isPhoneX = [[UIApplication sharedApplication] delegate].window.safeAreaInsets.bottom > 0.0;\
}\
(isPhoneX);})
// tabBar height
#define kTABBAR_HEIGHT (iPhoneX ? (49.f + 34.f) : 49.f)
// statusBar height
#define kSTATUSBAR_HEIGHT (iPhoneX ? 44.0f : 20.f)
// navigationBar height
#define kNAVIGATION_HEIGHT (44.f)
// (navigationBar + statusBar) height
#define kSTATUSBAR_NAVIGATION_HEIGHT (iPhoneX ? 88.0f : 64.f)
#define kBOTTOM_SPACE_HEIGHT (iPhoneX ? 34.0f : 0.0f)
#define kScreenSize ([UIScreen mainScreen].bounds.size)
#define kScreenW    ([UIScreen mainScreen].bounds.size.width)
#define kScreenH    ([UIScreen mainScreen].bounds.size.height)
#define kScreenRect CGRectMake(0, 0, kScreenW, kScreenH)
// AutoSize
#define kAutoW(x)   (x * kScreenW / 375.0)
#define kAutoH(x)   (x * kScreenH / 667.0)
#define kOnePixel   (1.0 / [UIScreen mainScreen].scale)

@interface UIView (KJFrame)

@property (nonatomic, assign) CGSize  size;
@property (nonatomic, assign) CGPoint origin;
@property (nonatomic, assign) CGFloat x;
@property (nonatomic, assign) CGFloat y;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign) CGFloat centerX;
@property (nonatomic, assign) CGFloat centerY;
@property (nonatomic, assign) CGFloat left;
@property (nonatomic, assign) CGFloat right;
@property (nonatomic, assign) CGFloat top;
@property (nonatomic, assign) CGFloat bottom;
@property (nonatomic, assign, readonly) CGFloat maxX;
@property (nonatomic, assign, readonly) CGFloat maxY;
@property (nonatomic, assign, readonly) CGFloat subviewMaxX;
@property (nonatomic, assign, readonly) CGFloat subviewMaxY;
@property (nonatomic, assign, readonly) CGFloat masonryX;
@property (nonatomic, assign, readonly) CGFloat masonryY;
@property (nonatomic, assign, readonly) CGFloat masonryWidth;
@property (nonatomic, assign, readonly) CGFloat masonryHeight;
@property (nonatomic, strong, readonly) UIViewController *viewController;
@property (nonatomic, assign, readonly) BOOL showKeyWindow;
@property (nonatomic, strong, class, readonly)UIViewController *topViewController;

/// Place the center of the view in its parent view, support post-processing of the rotation direction
- (void)kj_centerToSuperview;

/// Distance from the right side of the parent view
- (void)kj_rightToSuperview:(CGFloat)right;

/// Distance from the bottom of the parent view
- (void)kj_bottomToSuperview:(CGFloat)bottom;

/// Hide/show all subviews
- (void)kj_hideSubviews:(BOOL)hide operation:(BOOL(^)(UIView *subview))operation;

/// Find subview
- (UIView *)kj_findSubviewRecursively:(BOOL(^)(UIView *subview, BOOL * stop))recurse;

/// Remove all subviews
- (void)kj_removeAllSubviews;

/// Update the size, when using autolayout layout, you need to refresh the constraints to get the real frame
- (void)kj_updateFrame;

@end

NS_ASSUME_NONNULL_END
