//
//  UIView+KJGestureBlock.h
//  KJEmitterView
//
//  Created by 77。 on 2019/6/4.
//  https://github.com/YangKJ/KJCategories

/* 使用示例 */
// [self.view kj_AddTapGestureRecognizerBlock:^(UIView *view, UIGestureRecognizer *gesture) {
//     [view removeGestureRecognizer:gesture];
// }];

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^KJGestureRecognizerBlock)(UIView * view, UIGestureRecognizer * gesture);
typedef NS_ENUM(NSUInteger, KJGestureType) {
    KJGestureTypeTap,       // click
    KJGestureTypeDouble,    // double click
    KJGestureTypeLongPress, // long press
    KJGestureTypeSwipe,     // swipe
    KJGestureTypePan,       // move
    KJGestureTypeRotate,    // rotate
    KJGestureTypePinch,     // zoom
};
@interface UIView (KJGestureBlock)

/// Click gesture
/// @param block gesture response callback
/// @return returns the corresponding gesture
- (UIGestureRecognizer *)kj_AddTapGestureRecognizerBlock:(KJGestureRecognizerBlock)block;

/// Gesture processing
/// @param type gesture type
/// @param block gesture response callback
/// @return returns the corresponding gesture
- (UIGestureRecognizer *)kj_AddGestureRecognizer:(KJGestureType)type block:(KJGestureRecognizerBlock)block;

@end

NS_ASSUME_NONNULL_END
