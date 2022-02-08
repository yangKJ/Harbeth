//
//  UIView+KJGestureBlock.m
//  KJEmitterView
//
//  Created by 77。 on 2019/6/4.
//  https://github.com/YangKJ/KJCategories

#import "UIView+KJGestureBlock.h"
#import <objc/runtime.h>

@implementation UIView (KJGestureBlock)
static NSString * const _Nonnull KJGestureTypeStringMap[] = {
    [KJGestureTypeTap]       = @"UITapGestureRecognizer",
    [KJGestureTypeDouble]    = @"UITapGestureRecognizer",
    [KJGestureTypeLongPress] = @"UILongPressGestureRecognizer",
    [KJGestureTypeSwipe]     = @"UISwipeGestureRecognizer",
    [KJGestureTypePan]       = @"UIPanGestureRecognizer",
    [KJGestureTypeRotate]    = @"UIRotationGestureRecognizer",
    [KJGestureTypePinch]     = @"UIPinchGestureRecognizer",
};

/// 单击手势
- (UIGestureRecognizer *)kj_AddTapGestureRecognizerBlock:(KJGestureRecognizerBlock)block{
    return [self kj_AddGestureRecognizer:KJGestureTypeTap block:block];
}

- (UIGestureRecognizer *)kj_AddGestureRecognizer:(KJGestureType)type block:(KJGestureRecognizerBlock)block{
    self.userInteractionEnabled = YES;
    if (block) {
        NSString *string = KJGestureTypeStringMap[type];
        UIGestureRecognizer *gesture = [[NSClassFromString(string) alloc] initWithTarget:self action:@selector(category_gestureAction:)];
        [gesture setDelaysTouchesBegan:YES];
        [self addGestureRecognizer:gesture];
        if (type == KJGestureTypeTap) {
            [self.gestureRecognizers enumerateObjectsUsingBlock:^(__kindof UIGestureRecognizer *recognizer, NSUInteger idx, BOOL *stop) {
                if ([recognizer isKindOfClass:[UITapGestureRecognizer class]] && ((UITapGestureRecognizer*)recognizer).numberOfTapsRequired == 2) {
                    [gesture requireGestureRecognizerToFail:recognizer];
                    *stop = YES;
                }
            }];
            string = [string stringByAppendingString:@"Tap"];
        } else if (type == KJGestureTypeDouble) {
            [(UITapGestureRecognizer *)gesture setNumberOfTapsRequired:2];
            [self.gestureRecognizers enumerateObjectsUsingBlock:^(__kindof UIGestureRecognizer *recognizer, NSUInteger idx, BOOL *stop) {
                if ([recognizer isKindOfClass:[UITapGestureRecognizer class]] && ((UITapGestureRecognizer*)recognizer).numberOfTapsRequired == 1) {
                    [recognizer requireGestureRecognizerToFail:gesture];
                    *stop = YES;
                }
            }];
            string = [string stringByAppendingString:@"Double"];
        }
        self.selectorString = string;
        self.gesrureblock = block;
        return gesture;
    }
    return nil;
}

- (void)category_gestureAction:(UIGestureRecognizer *)gesture{
    NSString *string = NSStringFromClass([gesture class]);
    if ([gesture isKindOfClass:[UITapGestureRecognizer class]]) {
        if (((UITapGestureRecognizer *)gesture).numberOfTapsRequired == 1) {
            string = [string stringByAppendingString:@"Tap"];
        } else {
            string = [string stringByAppendingString:@"Double"];
        }
    }
    self.selectorString = string;
    self.gesrureblock(gesture.view, gesture);
}

#pragma mark - associated

- (NSString *)selectorString{
    return objc_getAssociatedObject(self, @selector(selectorString));
}
- (void)setSelectorString:(NSString *)selectorString{
    objc_setAssociatedObject(self, @selector(selectorString), selectorString, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
- (KJGestureRecognizerBlock)gesrureblock{
    return (KJGestureRecognizerBlock)objc_getAssociatedObject(self, NSSelectorFromString(self.selectorString));
}
- (void)setGesrureblock:(KJGestureRecognizerBlock)gesrureblock{
    objc_setAssociatedObject(self, NSSelectorFromString(self.selectorString), gesrureblock, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end
