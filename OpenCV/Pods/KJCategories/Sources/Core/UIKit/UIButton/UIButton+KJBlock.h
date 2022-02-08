//
//  UIButton+KJBlock.h
//  KJEmitterView
//
//  Created by 77。 on 2019/4/4.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
typedef void(^KJButtonBlock)(UIButton * kButton);
IB_DESIGNABLE
@interface UIButton (KJBlock)

/// Add click event, default UIControlEventTouchUpInside
- (void)kj_addAction:(void(^)(UIButton * kButton))block;

/// Add event, does not support multiple enumeration forms
- (void)kj_addAction:(KJButtonBlock)block forControlEvents:(UIControlEvents)controlEvents;

/// Click the event interval, set a non-zero cancellation interval
@property (nonatomic, assign) IBInspectable CGFloat timeInterval;

#pragma mark - Expand the click field

/// Expand the unified click domain, support Xib quick setting
@property (nonatomic, assign) IBInspectable CGFloat enlargeClick;
/// Set button extra hot zone
@property (nonatomic, assign) UIEdgeInsets touchAreaInsets;

/// Expand the click domain
/// @param top Top
/// @param left Left
/// @param bottom Bottom
/// @param right Right
- (void)EnlargeEdgeTop:(CGFloat)top left:(CGFloat)left bottom:(CGFloat)bottom right:(CGFloat)right;

@end

NS_ASSUME_NONNULL_END
