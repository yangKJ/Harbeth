//
//  UIImage+KJURLSize.h
//  KJEmitterView
//
//  Created by yangkejun on 2020/8/10.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (KJURLSize)

/// Get network picture size
/// @param URL image link
+ (CGSize)kj_imageSizeWithURL:(NSURL *)URL;

/// Obtain the network picture size and semaphore synchronously
/// @param URL image link
+ (CGSize)kj_imageAsyncGetSizeWithURL:(NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
