//
//  UIButton+KJContentLayout.m
//  CategoryDemo
//
//  Created by 77。 on 2018/7/7.
//  https://github.com/YangKJ/KJCategories

#import "UIButton+KJContentLayout.h"
#import <objc/runtime.h>

@implementation UIButton (KJContentLayout)

/// 设置图文混排，默认图文边界间距5px
/// @param layoutStyle 图文混排样式
/// @param padding 图文间距
- (void)kj_contentLayout:(KJButtonContentLayoutStyle)layoutStyle padding:(CGFloat)padding{
    [self kj_contentLayout:layoutStyle padding:padding periphery:5];
}

/// 设置图文混排
/// @param layoutStyle 图文混排样式
/// @param padding 图文间距
/// @param periphery 图文边界的间距
- (void)kj_contentLayout:(KJButtonContentLayoutStyle)layoutStyle
                 padding:(CGFloat)padding
               periphery:(CGFloat)periphery{
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    CGFloat imageWith   = self.imageView.image.size.width;
    CGFloat imageHeight = self.imageView.image.size.height;
//    CGSize size = [self.titleLabel.text sizeWithAttributes:@{NSFontAttributeName:self.titleLabel.font}];
    CGFloat labelWidth = 0, labelHeight = 0;
    if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0) {
        labelWidth  = self.titleLabel.intrinsicContentSize.width;
        labelHeight = self.titleLabel.intrinsicContentSize.height;
    } else {
        labelWidth  = self.titleLabel.frame.size.width;
        labelHeight = self.titleLabel.frame.size.height;
    }
    UIEdgeInsets imageEdge = UIEdgeInsetsZero;
    UIEdgeInsets titleEdge = UIEdgeInsetsZero;
    switch (layoutStyle) {
        case KJButtonContentLayoutStyleNormal:{
            titleEdge = UIEdgeInsetsMake(0, padding, 0, 0);
            imageEdge = UIEdgeInsetsMake(0, 0, 0, padding);
            self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        } break;
        case KJButtonContentLayoutStyleCenterImageRight:{
            titleEdge = UIEdgeInsetsMake(0, -imageWith - padding, 0, imageWith);
            imageEdge = UIEdgeInsetsMake(0, labelWidth + padding, 0, -labelWidth);
            self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        } break;
        case KJButtonContentLayoutStyleCenterImageTop:{
            titleEdge = UIEdgeInsetsMake(0, -imageWith, -imageHeight - padding, 0);
            imageEdge = UIEdgeInsetsMake(-labelHeight - padding, 0, 0, -labelWidth);
            self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        } break;
        case KJButtonContentLayoutStyleCenterImageBottom:{
            titleEdge = UIEdgeInsetsMake(-imageHeight - padding, -imageWith, 0, 0);
            imageEdge = UIEdgeInsetsMake(0, 0, -labelHeight - padding, -labelWidth);
            self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
        } break;
        case KJButtonContentLayoutStyleLeftImageLeft:{
            titleEdge = UIEdgeInsetsMake(0, padding + periphery, 0, 0);
            imageEdge = UIEdgeInsetsMake(0, periphery, 0, 0);
            self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        } break;
        case KJButtonContentLayoutStyleLeftImageRight:{
            titleEdge = UIEdgeInsetsMake(0, -imageWith + periphery, 0, 0);
            imageEdge = UIEdgeInsetsMake(0, labelWidth + padding + periphery, 0, 0);
            self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        } break;
        case KJButtonContentLayoutStyleRightImageLeft:{
            imageEdge = UIEdgeInsetsMake(0, 0, 0, padding + periphery);
            titleEdge = UIEdgeInsetsMake(0, 0, 0, periphery);
            self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        } break;
        case KJButtonContentLayoutStyleRightImageRight:{
            titleEdge = UIEdgeInsetsMake(0, -self.frame.size.width / 2, 0, imageWith + padding + periphery);
            imageEdge = UIEdgeInsetsMake(0, 0, 0, -labelWidth + periphery);
            self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        } break;
        default:break;
    }
    self.imageEdgeInsets = imageEdge;
    self.titleEdgeInsets = titleEdge;
    [self setNeedsDisplay];
}

#pragma mark - associated

- (NSInteger)layoutType{
    return [objc_getAssociatedObject(self, @selector(layoutType)) integerValue];;
}
- (void)setLayoutType:(NSInteger)layoutType{
    objc_setAssociatedObject(self, @selector(layoutType), @(layoutType), OBJC_ASSOCIATION_ASSIGN);
    [self kj_contentLayout:layoutType padding:self.padding periphery:self.periphery];
}
- (CGFloat)padding{
    return [objc_getAssociatedObject(self, @selector(padding)) floatValue];
}
- (void)setPadding:(CGFloat)padding{
    objc_setAssociatedObject(self, @selector(padding), @(padding), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self kj_contentLayout:self.layoutType padding:padding periphery:self.periphery];
}
- (CGFloat)periphery{
    return [objc_getAssociatedObject(self, @selector(periphery)) floatValue];
}
- (void)setPeriphery:(CGFloat)periphery{
    objc_setAssociatedObject(self, @selector(periphery), @(periphery), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self kj_contentLayout:self.layoutType padding:self.padding periphery:periphery];
}

@end
