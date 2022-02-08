//
//  UIViewController+KJFullScreen.h
//  Winpower
//
//  Created by 77。 on 2019/10/10.
//  Copyright © 2019 cq. All rights reserved.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIViewController (KJFullScreen) <UINavigationControllerDelegate>

/// Whether to turn on the sliding back gesture
- (void)kj_openPopGesture:(BOOL)open;

/// The system comes with sharing
/// @param items share data
/// @param complete Sharing completion callback processing
/// @return Return to share controller
- (UIActivityViewController *)kj_shareActivityWithItems:(NSArray *)items
                                               complete:(nullable void(^)(BOOL success))complete;

@end

NS_ASSUME_NONNULL_END
