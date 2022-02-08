//
//  UITextView+KJPlaceHolder.m
//  CategoryDemo
//
//  Created by 77。 on 2018/7/12.
//  https://github.com/YangKJ/KJCategories

#import "UITextView+KJPlaceHolder.h"
#import <objc/runtime.h>

@implementation UITextView (KJPlaceHolder)

#pragma mark - swizzled

- (void)placeHolderSwizzled{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        method_exchangeImplementations(class_getInstanceMethod(self.class, NSSelectorFromString(@"layoutSubviews")),
                                       class_getInstanceMethod(self.class, @selector(kj_placeHolder_layoutSubviews)));
        method_exchangeImplementations(class_getInstanceMethod(self.class, NSSelectorFromString(@"dealloc")),
                                       class_getInstanceMethod(self.class, @selector(kj_placeHolder_dealloc)));
        method_exchangeImplementations(class_getInstanceMethod(self.class, NSSelectorFromString(@"setText:")),
                                       class_getInstanceMethod(self.class, @selector(kj_placeHolder_setText:)));
    });
}

- (void)kj_placeHolder_dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self kj_placeHolder_dealloc];
}
- (void)kj_placeHolder_layoutSubviews{
    [self kj_placeHolder_layoutSubviews];
    UIEdgeInsets textContainerInset = self.textContainerInset;
    CGFloat x = self.textContainer.lineFragmentPadding + textContainerInset.left + self.layer.borderWidth;
    CGFloat y = textContainerInset.top + self.layer.borderWidth;
    CGFloat width = self.bounds.size.width - x - textContainerInset.right - 2 * self.layer.borderWidth;
    CGFloat height = [self.placeHolderLabel sizeThatFits:CGSizeMake(width, 0)].height;
    self.placeHolderLabel.frame = CGRectMake(x, y, width, height);
    if (![self.subviews containsObject:self.placeHolderLabel]) {
        [self insertSubview:self.placeHolderLabel atIndex:0];
    }
}
- (void)kj_placeHolder_setText:(NSString *)text{
    [self kj_placeHolder_setText:text];
    [self updatePlaceHolder];
}

#pragma mark - private method

- (void)updatePlaceHolder{
    self.placeHolderLabel.hidden = self.text.length;
}

#pragma mark - associated

- (UILabel *)placeHolderLabel{
    UILabel *label = objc_getAssociatedObject(self, @selector(placeHolderLabel));
    if (label == nil) {
        label = [[UILabel alloc] init];
        label.numberOfLines = 0;
        label.textColor = [UIColor colorWithRed:0 green:0 blue:0.0980392 alpha:0.22];
        objc_setAssociatedObject(self, @selector(placeHolderLabel), label, OBJC_ASSOCIATION_RETAIN);
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updatePlaceHolder)
                                                     name:UITextViewTextDidChangeNotification
                                                   object:self];
        label.font = self.font;
        label.textAlignment = self.textAlignment;
        label.text = self.placeHolder;
    }
    return label;
}

- (NSString *)placeHolder{
    return objc_getAssociatedObject(self, @selector(placeHolder));
}
- (void)setPlaceHolder:(NSString *)placeHolder{
    objc_setAssociatedObject(self, @selector(placeHolder), placeHolder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self placeHolderSwizzled];
    [self updatePlaceHolder];
}

@end
