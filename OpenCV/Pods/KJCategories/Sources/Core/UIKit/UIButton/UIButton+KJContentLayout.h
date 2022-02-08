//
//  UIButton+KJContentLayout.h
//  CategoryDemo
//
//  Created by 77。 on 2018/7/7.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, KJButtonContentLayoutStyle) {
    KJButtonContentLayoutStyleNormal = 0,       // 内容居中-图左文右
    KJButtonContentLayoutStyleCenterImageRight, // 内容居中-图右文左
    KJButtonContentLayoutStyleCenterImageTop,   // 内容居中-图上文下
    KJButtonContentLayoutStyleCenterImageBottom,// 内容居中-图下文上
    KJButtonContentLayoutStyleLeftImageLeft,    // 内容居左-图左文右
    KJButtonContentLayoutStyleLeftImageRight,   // 内容居左-图右文左
    KJButtonContentLayoutStyleRightImageLeft,   // 内容居右-图左文右
    KJButtonContentLayoutStyleRightImageRight,  // 内容居右-图右文左
};
IB_DESIGNABLE
@interface UIButton (KJContentLayout)

/// Graphic style
@property (nonatomic, assign) IBInspectable NSInteger layoutType;
/// Picture and text spacing, the default is 0px
@property (nonatomic, assign) IBInspectable CGFloat padding;
/// The spacing between the graphic and text borders, the default is 5px
@property (nonatomic, assign) IBInspectable CGFloat periphery;

/// Set graphics and text mixing, the default border spacing between graphics and text is 5px
/// @param layoutStyle Graphic and text mixed style
/// @param padding Image and text spacing
- (void)kj_contentLayout:(KJButtonContentLayoutStyle)layoutStyle
                 padding:(CGFloat)padding;

/// Set image and text mixing
/// FIXME: There is a problem with this writing that it will break the automatic layout of the button
/// @param layoutStyle Graphic and text mixed style
/// @param padding Image and text spacing
/// @param periphery The distance between the graphic borders
- (void)kj_contentLayout:(KJButtonContentLayoutStyle)layoutStyle
                 padding:(CGFloat)padding
               periphery:(CGFloat)periphery;

@end

NS_ASSUME_NONNULL_END
