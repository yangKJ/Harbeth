//
//  NSObject+KJRunLoop.m
//  KJEmitterView
//
//  Created by 77。 on 2019/12/15.
//  https://github.com/YangKJ/KJCategories

#import "NSObject+KJRunLoop.h"
#import <objc/runtime.h>

@implementation NSObject (KJRunLoop)

- (BOOL)stopResidentThread{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}
- (void)setStopResidentThread:(BOOL)stopResidentThread{
    objc_setAssociatedObject(self, @selector(stopResidentThread), @(stopResidentThread), OBJC_ASSOCIATION_ASSIGN);
}
static char kThreadKey;
- (NSThread *)residentThread{
    NSThread *thread = objc_getAssociatedObject(self, &kThreadKey);
    if (thread == nil) {
        thread = [[NSThread alloc]initWithTarget:self selector:@selector(_residentThreadRun) object:nil];
        thread.name = @"常驻线程";
        [thread start];
        objc_setAssociatedObject(self, &kThreadKey, thread, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return thread;
}
- (void)_residentThreadRun{
    @autoreleasepool {
        [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
        [[NSRunLoop currentRunLoop] run];
    }
}
/// 常驻线程，线程保活
- (void)kj_residentThread:(dispatch_block_t)withBlock{
    if (self.stopResidentThread) return;
    [self performSelector:@selector(_residentThreadAction:)
                 onThread:self.residentThread
               withObject:withBlock
            waitUntilDone:YES];
}
- (void)_residentThreadAction:(dispatch_block_t)withBlock{
    withBlock ? withBlock() : nil;
}
/// 停止线程
- (void)kj_stopResidentThread{
    if (objc_getAssociatedObject(self, &kThreadKey)) {
        self.stopResidentThread = YES;
        CFRunLoopStop(CFRunLoopGetCurrent());
        objc_setAssociatedObject(self, &kThreadKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

/// 空闲时刻执行
/// @param withBlock 执行回调
/// @param queue 线程，默认主线程
- (void)kj_performOnLeisure:(dispatch_block_t)withBlock queue:(dispatch_queue_t)queue{
    if (queue == nil) queue = dispatch_get_main_queue();
    dispatch_async(queue, ^{
        [self performSelector:@selector(_performTask:)
                   withObject:withBlock
                   afterDelay:0.0
                      inModes:@[NSDefaultRunLoopMode]];
    });
}
- (void)_performTask:(dispatch_block_t)withBlock{
    withBlock ? withBlock() : nil;
}

@end
