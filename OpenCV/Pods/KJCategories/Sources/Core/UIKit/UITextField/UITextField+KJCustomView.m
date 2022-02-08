//
//  UITextField+KJCustomView.m
//  KJEmitterView
//
//  Created by 77。 on 2019/12/4.
//  https://github.com/YangKJ/KJCategories

#import "UITextField+KJCustomView.h"
#import <objc/runtime.h>

@implementation UITextField (KJCustomView)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        method_exchangeImplementations(class_getInstanceMethod(self.class, NSSelectorFromString(@"layoutSubviews")),
                                       class_getInstanceMethod(self.class, @selector(kj_custom_layoutSubviews)));
    });
}

- (void)kj_custom_layoutSubviews{
    [self kj_custom_layoutSubviews];
    CALayer *bottomLayer = objc_getAssociatedObject(self, @selector(bottomLayer));
    if (bottomLayer) {
        bottomLayer.frame = CGRectMake(0, self.frame.size.height - 1, CGRectGetWidth(self.bounds), 1);
    }
    KJTextFieldLeftMaker *maker = objc_getAssociatedObject(self, &leftViewMakerKey);
    if (maker) {
        [self setupLeftViewFrameWithMaker:maker leftView:self.leftView];
    }
    UIButton * rightButton = objc_getAssociatedObject(self, &rightButtonKey);
    if (rightButton) {
        CGRect frame = self.rightView.frame;
        frame.size.height = self.frame.size.height;
        self.rightView.frame = frame;
        CGPoint center = rightButton.center;
        center.y = self.rightView.center.y;
        rightButton.center = center;
    }
}

@dynamic bottomLineColor;
- (void)setBottomLineColor:(UIColor *)bottomLineColor{
    self.bottomLayer.backgroundColor = bottomLineColor.CGColor;
}
- (CALayer *)bottomLayer{
    CALayer *bottomLayer = objc_getAssociatedObject(self, @selector(bottomLayer));
    if (bottomLayer == nil) {
        bottomLayer = [[CALayer alloc] init];
        bottomLayer.frame = CGRectMake(0, self.frame.size.height - 1, CGRectGetWidth(self.bounds), 1);
        bottomLayer.contentsScale = [UIScreen mainScreen].scale;
        objc_setAssociatedObject(self, @selector(bottomLayer), bottomLayer, OBJC_ASSOCIATION_RETAIN);
        [self.layer addSublayer:bottomLayer];
    }
    return bottomLayer;
}

/// 设置左边视图，类似账号密码标题
static char leftViewMakerKey;
- (UIView *)kj_leftView:(void(^)(KJTextFieldLeftMaker *))withBlock{
    KJTextFieldLeftMaker * maker = [[KJTextFieldLeftMaker alloc] init];
    objc_setAssociatedObject(self, &leftViewMakerKey, maker, OBJC_ASSOCIATION_RETAIN);
    if (withBlock) withBlock(maker);
    UIView * view = [[UIView alloc] init];
    if (maker.text && maker.imageName) {
        UIImageView *imageView = [[UIImageView alloc]init];
        imageView.tag = 520;
        imageView.image = [UIImage imageNamed:maker.imageName];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        [view addSubview:imageView];
        
        UILabel *label = [[UILabel alloc] init];
        label.tag = 521;
        label.font = maker.font ?: self.font;
        label.text = maker.text;
        label.textColor = maker.textColor ?: self.textColor;
        [view addSubview:label];
        [self setupLeftViewFrameWithMaker:maker leftView:view];
    } else if (maker.imageName) {
        UIImageView *imageView = [[UIImageView alloc]init];
        imageView.tag = 520;
        imageView.image = [UIImage imageNamed:maker.imageName];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        [view addSubview:imageView];
        [self setupLeftViewFrameWithMaker:maker leftView:view];
    } else if (maker.text) {
        UILabel *label = [[UILabel alloc] init];
        label.tag = 521;
        label.font = maker.font?:self.font;
        label.text = maker.text;
        label.textColor = maker.textColor?:self.textColor;
        [view addSubview:label];
        [self setupLeftViewFrameWithMaker:maker leftView:view];
    } else {
        return view;
    }
    self.leftView = view;
    self.leftViewMode = UITextFieldViewModeAlways;
    return view;
}

/// 配置左边控件相关尺寸信息
- (void)setupLeftViewFrameWithMaker:(KJTextFieldLeftMaker *)maker leftView:(UIView *)view{
    CGFloat width = self.frame.size.width;
    CGFloat height = self.frame.size.height;
    if (width == 0 || height == 0) return;
    UILabel * label = [view viewWithTag:521];
    UIImageView * imageView = [view viewWithTag:520];
    if (maker.text && maker.imageName) {
        CGFloat tw = [self kj_calculateRectWithText:maker.text
                                               Size:CGSizeMake(CGFLOAT_MAX, height)
                                               font:label.font
                                          alignment:NSTextAlignmentLeft
                                      linebreakMode:NSLineBreakByWordWrapping
                                          lineSpace:0.0].width + 2.;
        CGFloat ih = maker.maxImageHeight ?: height / 2;
        CGFloat iw = imageView.image.size.width * ih / imageView.image.size.height;
        if (maker.minWidth > 0 && tw < maker.minWidth) tw = maker.minWidth;
        if (maker.style == KJTextAndImageStyleNormal) {
            imageView.frame = CGRectMake(maker.periphery, (height - ih)/2., iw, ih);
            label.frame = CGRectMake(maker.periphery + iw+maker.padding, 0.0, tw, height);
        } else {
            label.frame = CGRectMake(maker.periphery, 0.0, tw, height);
            imageView.frame = CGRectMake(maker.periphery + tw + maker.padding, (height - ih) / 2., iw, ih);
        }
        CGFloat vw = maker.periphery + label.frame.size.width + maker.padding + imageView.frame.size.width;
        view.frame = CGRectMake(0, 0, vw, height);
    } else if (maker.imageName) {
        CGFloat ih = maker.maxImageHeight ?: height / 2;
        CGFloat iw = imageView.image.size.width * ih / imageView.image.size.height;
        if (maker.minWidth > 0 && iw < maker.minWidth) iw = maker.minWidth;
        imageView.frame = CGRectMake(maker.periphery, (height - ih)/2., iw, ih);
        view.frame = CGRectMake(0, 0, iw + maker.periphery, height);
    } else if (maker.text) {
        CGFloat tw = [self kj_calculateRectWithText:maker.text
                                               Size:CGSizeMake(CGFLOAT_MAX, height)
                                               font:label.font
                                          alignment:NSTextAlignmentLeft
                                      linebreakMode:NSLineBreakByWordWrapping
                                          lineSpace:0.0].width + 2.;
        if (maker.minWidth > 0 && tw < maker.minWidth) tw = maker.minWidth;
        label.frame = CGRectMake(maker.periphery, 0.0, tw, height);
        view.frame = CGRectMake(0, 0, tw+maker.periphery, height);
    }
}

/// 设置右边视图，类似小圆叉
static char tapActionKey;
static char rightButtonKey;
- (UIButton *)kj_rightViewTapBlock:(nullable void(^)(UIButton * button))withBlock
                         imageName:(nullable NSString *)imageName
                             width:(CGFloat)width
                            height:(CGFloat)height
                           padding:(CGFloat)padding{
    UIButton *button = [UIButton buttonWithType:(UIButtonTypeCustom)];
    objc_setAssociatedObject(self, &rightButtonKey, button, OBJC_ASSOCIATION_RETAIN);
    button.frame = CGRectMake(0, 0, width, height);
    UIImage *image = [UIImage imageNamed:imageName];
    if (image) {
        [button setImage:image forState:(UIControlStateNormal)];
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    if (withBlock) {
        objc_setAssociatedObject(self, &tapActionKey, withBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
        [button addTarget:self action:@selector(tapAction:) forControlEvents:(UIControlEventTouchUpInside)];
    }
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width + padding, self.frame.size.height)];
    [view addSubview:button];
    self.rightView = view;
    self.rightViewMode = UITextFieldViewModeAlways;
    return button;
}
- (void)tapAction:(UIButton *)sender{
    void(^withBlock)(UIButton * button) = objc_getAssociatedObject(self, &tapActionKey);
    sender.selected = !sender.selected;
    if (withBlock) withBlock(sender);
}

#pragma mark - private Method
/// 获取文本尺寸
- (CGSize)kj_calculateRectWithText:(NSString *)string
                              Size:(CGSize)size
                              font:(UIFont *)font
                         alignment:(NSTextAlignment)alignment
                     linebreakMode:(NSLineBreakMode)linebreakMode
                         lineSpace:(CGFloat)lineSpace{
    if (string.length == 0) return CGSizeZero;
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineBreakMode = linebreakMode;
    paragraphStyle.alignment = alignment;
    if (lineSpace > 0) paragraphStyle.lineSpacing = lineSpace;
    NSDictionary *attributes = @{NSFontAttributeName:font,NSParagraphStyleAttributeName:paragraphStyle};
    CGSize newSize = [string boundingRectWithSize:size
                                          options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine
                                       attributes:attributes
                                          context:NULL].size;
    return CGSizeMake(ceil(newSize.width), ceil(newSize.height));
}

@end

@implementation KJTextFieldLeftMaker

- (instancetype)init{
    if (self = [super init]) {
        self.padding = 5;
    }
    return self;
}

@end
