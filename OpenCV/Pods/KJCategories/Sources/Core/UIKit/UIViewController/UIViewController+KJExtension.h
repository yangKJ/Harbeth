//
//  UIViewController+KJExtension.h
//  KJEmitterView
//
//  Created by 77。 on 2021/5/28.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (KJExtension)

/// Jump back to the specified controller
/// @param clazz specifies the controller class name
/// @param complete successfully callback out the controller
/// @return returns whether the jump was successful
- (BOOL)kj_popTargetViewController:(Class)clazz complete:(void(^)(UIViewController * vc))complete;

/// Switch the root view controller
- (void)kj_changeRootViewController:(void(^)(BOOL success))complete;

@end

NS_ASSUME_NONNULL_END
