//
//  UITextField+KJCustomView.h
//  KJEmitterView
//
//  Created by 77。 on 2019/12/4.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class KJTextFieldLeftMaker;

/// Quickly set account password box
@interface UITextField (KJCustomView)

/// Set the color of the bottom border line
@property (nonatomic, strong) IBInspectable UIColor *bottomLineColor;

/// Set the left view, similar to the title of account password
- (UIView *)kj_leftView:(void(^)(KJTextFieldLeftMaker * make))withBlock;

/// Set the right view, similar to a small round fork
/// @param withBlock click event response
/// @param imageName icon name
/// @param width width
/// @param height height
/// @param padding Distance to the right
- (UIButton *)kj_rightViewTapBlock:(nullable void(^)(UIButton * button))withBlock
                         imageName:(nullable NSString *)imageName
                             width:(CGFloat)width
                            height:(CGFloat)height
                           padding:(CGFloat)padding;

@end

typedef NS_ENUM(NSInteger, KJTextAndImageStyle) {
    KJTextAndImageStyleNormal = 0,// Picture on the left and text on the right
    KJTextAndImageStyleImageRight,// Picture on the right and text on the left
};
/// Related parameter settings of the left view
@interface KJTextFieldLeftMaker: NSObject
/// text
@property (nonatomic, strong) NSString *text;
/// Picture name
@property (nonatomic, strong) NSString *imageName;
/// Text color, default control font color
@property (nonatomic, strong) UIColor *textColor;
/// Text font, default control font
@property (nonatomic, strong) UIFont *font;
/// The maximum height of the picture, the default control height is half
@property (nonatomic, assign) CGFloat maxImageHeight;
/// Margin, default 0px
@property (nonatomic, assign) CGFloat periphery;
/// Minimum width, default actual width
@property (nonatomic, assign) CGFloat minWidth;
/// Picture and text style, default picture left and text right
@property (nonatomic, assign) KJTextAndImageStyle style;
/// Picture and text spacing, the default is 5px
@property (nonatomic, assign) CGFloat padding;

@end

NS_ASSUME_NONNULL_END
