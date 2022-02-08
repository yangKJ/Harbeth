//
//  UINavigationBar+KJExtension.h
//  KJEmitterView
//
//  Created by 77。 on 2018/12/1.
//  Copyright © 2018 77。. All rights reserved.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UINavigationBar (KJExtension)

/// Set the background color of the navigation bar
@property (nonatomic, strong) UIColor *navgationBackground;
/// Set the picture background navigation bar
@property (nonatomic, strong) UIImage *navgationImage;
/// Set a custom back button
@property (nonatomic, strong) NSString *navgationCustomBackImageName;
/// System navigation bar dividing line
@property (nonatomic, strong, readonly) UIImageView *navgationBarBottomLine;
/// Set the color and font size of the navigation bar title
@property (nonatomic, copy, readonly) UINavigationBar * (^kChangeNavigationBarTitle)(UIColor *, UIFont *);

/// Set the title color and font size of the navigation bar, compatible with Swift and easy to use
/// @param color Navigation bar title color
/// @param font Font size of navigation bar title
- (instancetype)setNavigationBarTitleColor:(UIColor *)color font:(UIFont *)font;
/// Hide the underline at the bottom of the navigation bar
- (UINavigationBar *)kj_hiddenNavigationBarBottomLine;
/// Restore to the system color and underline by default
- (void)kj_resetNavigationBarSystem;

//************************ Custom navigation bar related ****************** *****

/// Change the navigation bar
/// @param image Navigation bar image
/// @param color Navigation bar background color
- (instancetype)kj_customNavgationBackImage:(UIImage *_Nullable)image background:(UIColor *_Nullable)color;

/// Change transparency
- (instancetype)kj_customNavgationAlpha:(CGFloat)alpha;

/// The height of the background of the navigation bar,
/// Note: The height of the navigation bar is not changed here, but the height of the custom background is changed
- (instancetype)kj_customNavgationHeight:(CGFloat)height;

/// Hide bottom line
- (instancetype)kj_customNavgationHiddenBottomLine:(BOOL)hidden;

/// Change the color of the custom bottom line
//- (instancetype)kj_customNavgationChangeBottomLineColor:(UIColor *)color;
/// Restore back to the system navigation bar
- (void)kj_customNavigationRestoreSystemNavigation;

@end

NS_ASSUME_NONNULL_END
