//
//  NSObject+KJExtension.h
//  KJEmitterView
//
//  Created by 77。 on 2019/12/15.
//  https://github.com/YangKJ/KJCategories

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (KJExtension)

/// Code execution time processing, code execution in the block
FOUNDATION_EXPORT CFTimeInterval kDoraemonBoxExecuteTimeBlock(void(^block)(void));
/// Delay clicks to avoid quick clicks
FOUNDATION_EXPORT void kDoraemonBoxAvoidQuickClick(float time);

/// Save to album
/// @param image save the picture
/// @param complete The callback of whether the save is successful or not
- (void)kj_saveImageToPhotosAlbum:(UIImage *)image complete:(void(^)(BOOL success))complete;

@end

NS_ASSUME_NONNULL_END
