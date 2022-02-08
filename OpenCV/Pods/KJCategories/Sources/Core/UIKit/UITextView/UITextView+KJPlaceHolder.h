//
//  UITextView+KJPlaceHolder.h
//  CategoryDemo
//
//  Created by 77。 on 2018/7/12.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
IB_DESIGNABLE
@interface UITextView (KJPlaceHolder)

/// placeholder text
@property (nonatomic, strong) IBInspectable NSString *placeHolder;

/// Placeholder Label
@property (nonatomic, strong, readonly) UILabel *placeHolderLabel;

@end

NS_ASSUME_NONNULL_END
