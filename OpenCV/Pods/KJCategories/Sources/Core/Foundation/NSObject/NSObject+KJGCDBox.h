//
//  NSObject+KJGCDBox.h
//  KJEmitterView
//
//  Created by 77。 on 2019/3/17.
//  https://github.com/YangKJ/KJCategories
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// GCD box package, resident thread package
@interface NSObject (KJGCDBox)

/// Create an asynchronous timer, which is more accurate than NSTimer and CADisplayLink (both are based on runloop processing)
/// @param async is asynchronous
/// @param task event handling
/// @param start start time
/// @param interval interval time
/// @param repeats whether to repeat
/// @return returns the timer
- (dispatch_source_t)kj_createGCDAsyncTimer:(BOOL)async
                                       task:(dispatch_block_t)task
                                      start:(NSTimeInterval)start
                                   interval:(NSTimeInterval)interval
                                    repeats:(BOOL)repeats;
/// Cancel the timer
- (void)kj_gcdStopTimer:(dispatch_source_t)timer;

/// Pause the timer
- (void)kj_gcdPauseTimer:(dispatch_source_t)timer;

/// Continue timer
- (void)kj_gcdResumeTimer:(dispatch_source_t)timer;

/// Delayed execution
/// @param task event handling
/// @param time delay time
/// @param async is asynchronous
- (void)kj_gcdAfterTask:(dispatch_block_t)task
                   time:(NSTimeInterval)time
                  asyne:(BOOL)async;

/// Asynchronous fast iteration
/// @param task event handling
/// @param count total number of iterations
- (void)kj_gcdApplyTask:(BOOL(^)(size_t index))task
                  count:(NSUInteger)count;

#pragma mark - GCD threading

/// Create a queue
FOUNDATION_EXPORT dispatch_queue_t kGCD_queue(void);
/// Main thread
FOUNDATION_EXPORT void kGCD_main(dispatch_block_t block);
/// child thread
FOUNDATION_EXPORT void kGCD_async(dispatch_block_t block);
/// Asynchronous parallel queue, carrying variable parameters (need to end with nil)
FOUNDATION_EXPORT void kGCD_group_notify(dispatch_block_t notify, dispatch_block_t block,...);
/// Fence
FOUNDATION_EXPORT dispatch_queue_t kGCD_barrier(dispatch_block_t block, dispatch_block_t barrier);
/// The barrier implements multiple read and single write operations,
/// the write operation is completed in the barrier, and the variable parameters are carried (need to end with nil)
FOUNDATION_EXPORT void kGCD_barrier_read_write(dispatch_block_t barrier, dispatch_block_t block,...);
/// One-time
FOUNDATION_EXPORT void kGCD_once(dispatch_block_t block);
/// Delayed execution
FOUNDATION_EXPORT void kGCD_after(int64_t delayInSeconds, dispatch_block_t block);
/// Delayed execution in the main thread
FOUNDATION_EXPORT void kGCD_after_main(int64_t delayInSeconds, dispatch_block_t block);
/// Fast iteration
FOUNDATION_EXPORT void kGCD_apply(int iterations, void(^block)(size_t idx));
/// Quickly traverse the array
FOUNDATION_EXPORT void kGCD_apply_array(NSArray * temp, void(^block)(id obj, size_t index));

@end

#define _weakself __weak __typeof(self) weakself = self
#define _strongself __strong __typeof(weakself) strongself = weakself
#ifndef kWeakObject
#if DEBUG
#if __has_feature(objc_arc)
#define kWeakObject(object) autoreleasepool{} __weak __typeof__(object) weak##_##object = object;
#else
#define kWeakObject(object) autoreleasepool{} __block __typeof__(object) block##_##object = object;
#endif
#else
#if __has_feature(objc_arc)
#define kWeakObject(object) try{} @finally{} {} __weak __typeof__(object) weak##_##object = object;
#else
#define kWeakObject(object) try{} @finally{} {} __block __typeof__(object) block##_##object = object;
#endif
#endif
#endif

#ifndef kStrongObject
#if DEBUG
#if __has_feature(objc_arc)
#define kStrongObject(object) autoreleasepool{} __typeof__(object) object = weak##_##object;
#else
#define kStrongObject(object) autoreleasepool{} __typeof__(object) object = block##_##object;
#endif
#else
#if __has_feature(objc_arc)
#define kStrongObject(object) try{} @finally{} __typeof__(object) object = weak##_##object;
#else
#define kStrongObject(object) try{} @finally{} __typeof__(object) object = block##_##object;
#endif
#endif
#endif

NS_ASSUME_NONNULL_END
