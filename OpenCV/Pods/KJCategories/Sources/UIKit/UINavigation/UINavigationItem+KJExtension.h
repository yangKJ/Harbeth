//
//  UINavigationItem+KJExtension.h
//  KJEmitterView
//
//  Created by 77。 on 2018/12/1.
//  Copyright © 2018 77。. All rights reserved.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class KJNavigationItemInfo;
@interface UINavigationItem (KJExtension)

/// Chained generation
- (instancetype)kj_makeNavigationItem:(void(^)(UINavigationItem *make))block;

/// Shortcut generation method
/// @param title title
/// @param color title text color
/// @param image image
/// @param tintColor can modify the color of the picture
/// @param block click callback
/// @param withBlock return to the internal button
- (UIBarButtonItem *)kj_barButtonItemWithTitle:(NSString *)title
                                    titleColor:(UIColor *)color
                                         image:(UIImage *)image
                                     tintColor:(UIColor *)tintColor
                                   buttonBlock:(void(^)(UIButton * kButton))block
                                barButtonBlock:(void(^)(UIButton * kButton))withBlock;

#pragma mark - chain parameter

@property (nonatomic, strong, readonly) UINavigationItem *(^kAddBarButtonItemInfo)
(void(^)(KJNavigationItemInfo *info), void(^)(UIButton * kButton));
@property (nonatomic, strong, readonly) UINavigationItem *(^kAddLeftBarButtonItem)(UIBarButtonItem *);
@property (nonatomic, strong, readonly) UINavigationItem *(^kAddRightBarButtonItem)(UIBarButtonItem *);

@end

/// Configuration parameters
@interface KJNavigationItemInfo: NSObject
@property (nonatomic, strong) NSString *imageName;
@property (nonatomic, strong) NSString *title;
/// Picture color, default white
@property (nonatomic, strong) UIColor *tintColor;
/// Text color, default white
@property (nonatomic, strong) UIColor *color;
/// Whether it is the left item, the default yes
@property (nonatomic, assign) BOOL isLeft;
/// Internal button for external modification of parameters
@property (nonatomic, copy, readwrite) void(^barButton)(UIButton * barButton);

@end

NS_ASSUME_NONNULL_END
