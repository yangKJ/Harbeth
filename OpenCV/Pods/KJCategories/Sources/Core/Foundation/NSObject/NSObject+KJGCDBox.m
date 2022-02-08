//
//  NSObject+KJGCDBox.m
//  KJEmitterView
//
//  Created by 77。 on 2019/3/17.
//  https://github.com/YangKJ/KJCategories

#import "NSObject+KJGCDBox.h"
#import <objc/runtime.h>

@implementation NSObject (KJGCDBox)

#pragma mark - Associated

- (BOOL)isHangUp{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}
- (void)setIsHangUp:(BOOL)isHangUp{
    objc_setAssociatedObject(self, @selector(isHangUp), @(isHangUp), OBJC_ASSOCIATION_ASSIGN);
}

/* 创建异步定时器 */
- (dispatch_source_t)kj_createGCDAsyncTimer:(BOOL)async
                                       task:(dispatch_block_t)task
                                      start:(NSTimeInterval)start
                                   interval:(NSTimeInterval)interval
                                    repeats:(BOOL)repeats{
    if (!task || start < 0 || (interval <= 0 && repeats)) return nil;
    self.isHangUp = NO;
    dispatch_queue_t queue = async ? dispatch_get_global_queue(0, 0) : dispatch_get_main_queue();
    __block dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, start * NSEC_PER_SEC), interval * NSEC_PER_SEC, 0);
    __weak __typeof(self) weaktarget = self;
    dispatch_source_set_event_handler(timer, ^{
        if (weaktarget == nil) {
            dispatch_source_cancel(timer);
            timer = nil;
        } else {
            if (repeats) {
                task();
            } else {
                task();
                [self kj_gcdStopTimer:timer];
            }
        }
    });
    dispatch_resume(timer);
    return timer;
}
/* 取消计时器 */
- (void)kj_gcdStopTimer:(dispatch_source_t)timer{
    self.isHangUp = NO;
    dispatch_source_t __timer = timer;
    if (__timer) {
        dispatch_source_cancel(__timer);
        __timer = nil;
    }
}
/* 暂停计时器 */
- (void)kj_gcdPauseTimer:(dispatch_source_t)timer{
    if (timer) {
        self.isHangUp = YES;
        dispatch_suspend(timer);
    }
}
/* 继续计时器 */
- (void)kj_gcdResumeTimer:(dispatch_source_t)timer{
    if (timer && self.isHangUp) {
        self.isHangUp = NO;
        //挂起的时候注意，多次暂停的操作会导致线程锁的现象
        //dispatch_suspend和dispatch_resume是一对
        dispatch_resume(timer);
    }
}

/* 延时执行 */
- (void)kj_gcdAfterTask:(dispatch_block_t)task time:(NSTimeInterval)time asyne:(BOOL)async{
    dispatch_queue_t queue = async ? dispatch_get_global_queue(0, 0) : dispatch_get_main_queue();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(time * NSEC_PER_SEC)), queue, ^{
        if (task) {        
            task();
        }
    });
}
/* 异步快速迭代 */
- (void)kj_gcdApplyTask:(BOOL(^)(size_t index))task count:(NSUInteger)count{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_apply(count, queue, ^(size_t index) {
        if (task(index)) { }
    });
}

#pragma mark - GCD 线程处理

dispatch_queue_t kGCD_queue(void) {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    return queue;
}
/// 主线程
void kGCD_main(dispatch_block_t block) {
    dispatch_queue_t queue = dispatch_get_main_queue();
    if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(queue)) == 0) {
        block();
    } else {
        if ([[NSThread currentThread] isMainThread]) {
            dispatch_async(queue, block);
        } else {
            dispatch_sync(queue, block);
        }
    }
}
/// 子线程
void kGCD_async(dispatch_block_t block) {
    dispatch_queue_t queue = kGCD_queue();
    if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(queue)) == 0) {
        block();
    } else {
        dispatch_async(queue, block);
    }
}
/// 异步并行队列，携带可变参数（需要nil结尾）
void kGCD_group_notify(dispatch_block_t notify,dispatch_block_t block,...) {
    dispatch_queue_t queue = kGCD_queue();
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, queue, block);
    va_list args;dispatch_block_t arg;
    va_start(args, block);
    while ((arg = va_arg(args, dispatch_block_t))) {
        dispatch_group_async(group, queue, arg);
    }
    va_end(args);
    dispatch_group_notify(group, queue, notify);
}
/// 栅栏
dispatch_queue_t kGCD_barrier(dispatch_block_t block,dispatch_block_t barrier) {
    dispatch_queue_t queue = kGCD_queue();
    dispatch_async(queue, block);
    dispatch_barrier_async(queue, ^{ dispatch_async(dispatch_get_main_queue(), barrier); });
    return queue;
}
/// 栅栏实现多读单写操作，barrier当中完成写操作，携带可变参数（需要nil结尾）
void kGCD_barrier_read_write(dispatch_block_t barrier, dispatch_block_t block,...){
    dispatch_queue_t queue = kGCD_queue();
    dispatch_async(queue, block);
    va_list args;dispatch_block_t arg;
    va_start(args, block);
    while ((arg = va_arg(args, dispatch_block_t))) {
        dispatch_async(queue, block);
    }
    va_end(args);
    dispatch_barrier_async(queue, ^{
        dispatch_async(dispatch_get_main_queue(), barrier);
    });
}
/// 一次性
void kGCD_once(dispatch_block_t block) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, block);
}
/// 延时执行
void kGCD_after(int64_t delayInSeconds, dispatch_block_t block) {
    dispatch_queue_t queue = kGCD_queue();
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(time, queue, block);
}
/// 主线程当中延时执行
void kGCD_after_main(int64_t delayInSeconds, dispatch_block_t block) {
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(time, dispatch_get_main_queue(), block);
}
/// 快速迭代
void kGCD_apply(int iterations, void(^block)(size_t idx)) {
    dispatch_queue_t queue = kGCD_queue();
    dispatch_apply(iterations, queue, block);
}
/// 快速遍历数组
void kGCD_apply_array(NSArray * temp, void(^block)(id obj, size_t index)) {
    void (^xxblock)(size_t) = ^(size_t index){
        block(temp[index], index);
    };
    dispatch_apply(temp.count, kGCD_queue(), xxblock);
}

@end
