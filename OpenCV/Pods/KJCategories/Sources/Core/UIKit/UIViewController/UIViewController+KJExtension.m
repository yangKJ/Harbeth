//
//  UIViewController+KJExtension.m
//  KJEmitterView
//
//  Created by 77。 on 2021/5/28.
//  https://github.com/YangKJ/KJCategories

#import "UIViewController+KJExtension.h"

@implementation UIViewController (KJExtension)

/// 跳转回指定控制器
- (BOOL)kj_popTargetViewController:(Class)clazz complete:(void(^)(UIViewController *vc))complete{
    UIViewController *vc = nil;
    for (UIViewController *__vc in self.navigationController.viewControllers) {
        if ([__vc isKindOfClass:clazz]) {
            vc = __vc;
            break;
        }
    }
    if (vc == nil) return NO;
    [self.navigationController popToViewController:vc animated:YES];
    if (complete) complete(vc);
    return YES;
}

/// 切换根视图控制器
- (void)kj_changeRootViewController:(void(^)(BOOL success))complete{
    UIWindow *window = ({
        UIWindow *window;
        if (@available(iOS 13.0, *)) {
            window = [UIApplication sharedApplication].windows.firstObject;
        } else {
            window = [UIApplication sharedApplication].keyWindow;
        }
        window;
    });
    [UIView transitionWithView:window
                      duration:0.5f
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        BOOL oldState = [UIView areAnimationsEnabled];
        [UIView setAnimationsEnabled:NO];
        window.rootViewController = self;
        [UIView setAnimationsEnabled:oldState];
    } completion:^(BOOL finished) {
        if (complete) complete(finished);
    }];
}


@end
