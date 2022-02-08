//
//  UILabel+KJExtension.m
//  KJEmitterView
//
//  Created by 77。 on 2019/9/24.
//  https://github.com/YangKJ/KJCategories

#import "UILabel+KJExtension.h"

@implementation UILabel (KJExtension)

/// 获取宽度
- (CGFloat)kj_calculateWidth{
    self.lineBreakMode = NSLineBreakByCharWrapping;
    CGSize size = [UILabel kj_calculateLabelSizeWithTitle:self.text
                                                     font:self.font
                                        constrainedToSize:CGSizeMake(MAXFLOAT, self.frame.size.height)
                                            lineBreakMode:NSLineBreakByCharWrapping];
    return ceil(size.width);
}
/// 获取高度
- (CGFloat)kj_calculateHeightWithWidth:(CGFloat)width{
    self.numberOfLines = 0;
    self.lineBreakMode = NSLineBreakByCharWrapping;
    CGSize size = [UILabel kj_calculateLabelSizeWithTitle:self.text
                                                     font:self.font
                                        constrainedToSize:CGSizeMake(width, MAXFLOAT)
                                            lineBreakMode:NSLineBreakByCharWrapping];
    return ceil(size.height);
}
/// 获取高度，指定行高
- (CGFloat)kj_calculateHeightWithWidth:(CGFloat)width oneLineHeight:(CGFloat)height{
    CGFloat newHeight = [self kj_calculateHeightWithWidth:width];
    return newHeight * height / self.font.lineHeight;
}
/// 获取文字尺寸
+ (CGSize)kj_calculateLabelSizeWithTitle:(NSString *)title
                                    font:(UIFont *)font
                       constrainedToSize:(CGSize)size
                           lineBreakMode:(NSLineBreakMode)lineBreakMode{
    if (title.length == 0) return CGSizeZero;
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = lineBreakMode;
    NSDictionary *attributes = @{NSFontAttributeName:font,NSParagraphStyleAttributeName:paragraph};
    CGRect frame = [title boundingRectWithSize:size options:NSStringDrawingUsesLineFragmentOrigin
                                    attributes:attributes
                                       context:nil];
    return frame.size;
}
- (void)kj_changeLineSpace:(float)space {
    NSString *labelText = self.text;
    if (!labelText) return;
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:labelText];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineSpacing:space];
    [attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle
                             range:NSMakeRange(0, [labelText length])];
    self.attributedText = attributedString;
    [self sizeToFit];
}
- (void)kj_changeLineSpace:(float)space paragraphSpace:(float)paragraphSpace{
    NSString *labelText = self.text;
    if (!labelText) return;
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:labelText];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineSpacing:space];
    [paragraphStyle setParagraphSpacing:paragraphSpace];
    [attributedString addAttribute:NSParagraphStyleAttributeName
                             value:paragraphStyle
                             range:NSMakeRange(0, [labelText length])];
    self.attributedText = attributedString;
    [self sizeToFit];
}
- (void)kj_changeWordSpace:(float)space {
    NSString *labelText = self.text;
    if (!labelText) return;
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc]
                                                   initWithString:labelText
                                                   attributes:@{NSKernAttributeName:@(space)}];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [attributedString addAttribute:NSParagraphStyleAttributeName
                             value:paragraphStyle
                             range:NSMakeRange(0, [labelText length])];
    self.attributedText = attributedString;
    [self sizeToFit];
}
- (void)kj_changeLineSpace:(float)lineSpace wordSpace:(float)wordSpace {
    NSString *labelText = self.text;
    if (!labelText) return;
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc]
                                                   initWithString:labelText
                                                   attributes:@{NSKernAttributeName:@(wordSpace)}];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineSpacing:lineSpace];
    [attributedString addAttribute:NSParagraphStyleAttributeName
                             value:paragraphStyle
                             range:NSMakeRange(0, [labelText length])];
    self.attributedText = attributedString;
    [self sizeToFit];
}

@end
