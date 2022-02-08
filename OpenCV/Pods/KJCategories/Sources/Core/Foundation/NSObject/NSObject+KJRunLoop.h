//
//  NSObject+KJRunLoop.h
//  KJEmitterView
//
//  Created by 77。 on 2019/12/15.
//  https://github.com/YangKJ/KJCategories

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (KJRunLoop)

/// Resident thread, thread keep alive
- (void)kj_residentThread:(dispatch_block_t)withBlock;

/// Stop the resident thread
- (void)kj_stopResidentThread;

/// Execute at idle time
/// @param withBlock execute callback
/// @param queue thread, the default main thread
- (void)kj_performOnLeisure:(dispatch_block_t)withBlock
                      queue:(nullable dispatch_queue_t)queue;

@end

NS_ASSUME_NONNULL_END
