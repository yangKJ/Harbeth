//
//  NSObject+KJExtension.m
//  KJEmitterView
//
//  Created by 77。 on 2019/12/15.
//  https://github.com/YangKJ/KJCategories

#import "NSObject+KJExtension.h"
#import <objc/runtime.h>

@implementation NSObject (KJExtension)

/// 代码执行时间处理，block当中执行代码
CFTimeInterval kDoraemonBoxExecuteTimeBlock(void(^block)(void)){
    if (block) {
        CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
        block();
        CFAbsoluteTime linkTime = (CFAbsoluteTimeGetCurrent() - startTime);
        NSLog(@"Linked in %f ms", linkTime * 1000.0);
        return linkTime * 1000;
    }
    return 0;
}
/// 延迟点击
void kDoraemonBoxAvoidQuickClick(float time){
    static BOOL canClick;
    if (canClick) return;
    canClick = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((time) * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        canClick = NO;
    });
}

/// 保存到相册
static char kSavePhotosKey;
- (void)kj_saveImageToPhotosAlbum:(UIImage *)image complete:(void(^)(BOOL))complete{
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
    objc_setAssociatedObject(self, &kSavePhotosKey, complete, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo{
    void(^withBlock)(BOOL success) = objc_getAssociatedObject(self, &kSavePhotosKey);
    if (withBlock) withBlock(error == nil ? YES : NO);
}

@end
