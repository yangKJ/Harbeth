//
//  UITextField+KJExtension.h
//  KJEmitterView
//
//  Created by 77。 on 2019/12/4.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

IB_DESIGNABLE
@interface UITextField (KJExtension)

/// placeholder color
@property (nonatomic, strong) IBInspectable UIColor *placeholderColor;
/// Font size of placeholder text
@property (nonatomic, assign) IBInspectable CGFloat placeholderFontSize;
/// The maximum length
@property (nonatomic, assign) IBInspectable NSInteger maxLength;
/// Switch between plaintext and darktext
@property (nonatomic, assign) BOOL securePasswords;
/// Whether to display the operation bar above the keyboard and the top finish button
@property (nonatomic, assign) BOOL displayInputAccessoryView;

/// Maximum character length reached
- (void)maxLengthWithBlock:(void(^)(NSString * text))withBlock;

/// Text editing moment
- (void)textEditingChangedWithBolck:(void(^)(NSString * text))withBlock;

@end

NS_ASSUME_NONNULL_END
