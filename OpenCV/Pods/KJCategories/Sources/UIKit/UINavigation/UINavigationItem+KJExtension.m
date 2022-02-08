//
//  UINavigationItem+KJExtension.m
//  KJEmitterView
//
//  Created by 77。 on 2018/12/1.
//  Copyright © 2018 77。. All rights reserved.
//  https://github.com/YangKJ/KJCategories

#import "UINavigationItem+KJExtension.h"
#import <objc/runtime.h>

@interface UIButton (UINavigationItemButtonExtension)

- (void)navigationAddAction:(void(^)(UIButton * kButton))block;

@end

@implementation UIButton (UINavigationItemButtonExtension)

- (void)navigationAddAction:(void(^)(UIButton * kButton))block{
    SEL selector = NSSelectorFromString(@"kNavigationItemButtonAction");
    objc_setAssociatedObject(self, selector, block, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
}
- (void)kNavigationItemButtonAction{
    void (^withBlock)(UIButton *) = objc_getAssociatedObject(self, _cmd);
    if (withBlock) withBlock(self);
}

@end

@implementation UINavigationItem (KJExtension)
/// 链式生成
- (instancetype)kj_makeNavigationItem:(void(^)(UINavigationItem *make))block{
    if (block) block(self);
    return self;
}
- (UIBarButtonItem *)kj_barButtonItemWithTitle:(NSString *)title
                                    titleColor:(UIColor *)color
                                         image:(UIImage *)image
                                     tintColor:(UIColor *)tintColor
                                   buttonBlock:(void(^)(UIButton *))block
                                barButtonBlock:(void(^)(UIButton *))withBlock{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    if (image) {
        if (tintColor) {
            image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [button.imageView setTintColor:tintColor];
        } else {
            image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
        }
        [button setImage:image forState:UIControlStateNormal];
    }
    if (title) {
        [button setTitle:title forState:UIControlStateNormal];
        [button setTitleColor:color forState:UIControlStateNormal];
    }
    [button sizeToFit];
    [button navigationAddAction:block];
    if (withBlock) withBlock(button);
    return [[UIBarButtonItem alloc] initWithCustomView:button];
}

#pragma mark - chain parameter

- (UINavigationItem * (^)(void(^)(KJNavigationItemInfo *),void(^)(UIButton *)))kAddBarButtonItemInfo{
    return ^ UINavigationItem * (void(^xblock)(KJNavigationItemInfo *), void(^block)(UIButton *)){
        KJNavigationItemInfo *info = [KJNavigationItemInfo new];
        if (xblock) xblock(info);
        UIBarButtonItem * barButtonItem = [self kj_barButtonItemWithTitle:info.title
                                                               titleColor:info.color
                                                                    image:[UIImage imageNamed:info.imageName]
                                                                tintColor:info.tintColor
                                                              buttonBlock:block
                                                           barButtonBlock:info.barButton];
        if (info.isLeft) {
            return self.kAddLeftBarButtonItem(barButtonItem);
        } else {
            return self.kAddRightBarButtonItem(barButtonItem);
        }
    };
}
- (UINavigationItem * (^)(UIBarButtonItem *))kAddLeftBarButtonItem{
    return ^ UINavigationItem * (UIBarButtonItem * barButtonItem){
        if (self.leftBarButtonItem == nil) {
            self.leftBarButtonItem = barButtonItem;
        } else {
            if (self.leftBarButtonItems.count == 0) {
                self.leftBarButtonItems = @[self.leftBarButtonItem,barButtonItem];
            } else {
                NSMutableArray * items = [NSMutableArray arrayWithArray:self.leftBarButtonItems];
                [items addObject:barButtonItem];
                self.leftBarButtonItems = items;
            }
        }
        return self;
    };
}
- (UINavigationItem * (^)(UIBarButtonItem *))kAddRightBarButtonItem{
    return ^ UINavigationItem * (UIBarButtonItem * barButtonItem){
        if (self.rightBarButtonItem == nil) {
            self.rightBarButtonItem = barButtonItem;
        } else {
            if (self.rightBarButtonItems.count == 0) {
                self.rightBarButtonItems = @[self.rightBarButtonItem,barButtonItem];
            } else {
                NSMutableArray * items = [NSMutableArray arrayWithArray:self.rightBarButtonItems];
                [items addObject:barButtonItem];
                self.rightBarButtonItems = items;
            }
        }
        return self;
    };
}

@end

@implementation KJNavigationItemInfo

- (instancetype)init{
    if (self = [super init]) {
        self.color = UIColor.whiteColor;
        self.isLeft = YES;
    }
    return self;
}

@end
