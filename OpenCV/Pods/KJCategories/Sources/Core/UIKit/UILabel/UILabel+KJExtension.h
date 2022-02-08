//
//  UILabel+KJExtension.h
//  KJEmitterView
//
//  Created by 77。 on 2019/9/24.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Get text position and size
@interface UILabel (KJExtension)

/// Get width
- (CGFloat)kj_calculateWidth;
/// Get height
- (CGFloat)kj_calculateHeightWithWidth:(CGFloat)width;

/// Get the height, specify the row height
/// @param width fixed width
/// @param height The height of a line of text
/// @return returns the total height
- (CGFloat)kj_calculateHeightWithWidth:(CGFloat)width oneLineHeight:(CGFloat)height;

/// Get text size
/// @param title text
/// @param font font
/// @param size width and height size
/// @param lineBreakMode line type
/// @return returns the text size
+ (CGSize)kj_calculateLabelSizeWithTitle:(NSString *)title
                                    font:(UIFont *)font
                       constrainedToSize:(CGSize)size
                           lineBreakMode:(NSLineBreakMode)lineBreakMode;
/// Change line spacing
- (void)kj_changeLineSpace:(float)space;
/// Change the word spacing
- (void)kj_changeWordSpace:(float)space;
/// Change line spacing and paragraph spacing
- (void)kj_changeLineSpace:(float)space paragraphSpace:(float)paragraphSpace;
/// Change line spacing and word spacing
- (void)kj_changeLineSpace:(float)lineSpace wordSpace:(float)wordSpace;

@end

NS_ASSUME_NONNULL_END
