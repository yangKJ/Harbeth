//
//  UINavigationBar+KJExtension.m
//  KJEmitterView
//
//  Created by 77。 on 2018/12/1.
//  Copyright © 2018 77。. All rights reserved.
//  https://github.com/YangKJ/KJCategories

#import "UINavigationBar+KJExtension.h"
#import <objc/runtime.h>

@interface KJCustomNavigationView : UIView
@property (nonatomic, strong) UIImage *backImage;
@property (nonatomic, strong) UIColor *backColor;
@property (nonatomic, assign) CGFloat alpha;
@property (nonatomic, assign) BOOL hiddenBottomLine;

@end

@interface UINavigationBar (KJExtension)
@property (nonatomic, strong) KJCustomNavigationView *customNavigationView;
@property (nonatomic, strong) UIImage *backClearImage, *lineClearImage;

@end

@implementation UINavigationBar (KJExtension)

- (UINavigationBar * (^)(UIColor *, UIFont *))kChangeNavigationBarTitle{
    return ^(UIColor * color, UIFont * font){
        if (@available(iOS 13.0, *)) {
            [self.standardAppearance setTitleTextAttributes:@{
                NSFontAttributeName: font,
                NSForegroundColorAttributeName: color
            }];
        } else {
            [self setTitleTextAttributes:@{
                NSFontAttributeName: font,
                NSForegroundColorAttributeName: color
            }];
        }
        return self;
    };
}
/// 设置导航条标题颜色和字号
/// @param color 导航条标题颜色
/// @param font 导航条标题字号
- (instancetype)setNavigationBarTitleColor:(UIColor *)color font:(UIFont *)font{
    return self.kChangeNavigationBarTitle(color, font);
}
- (UIColor *)navgationBackground{
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setNavgationBackground:(UIColor *)navgationBackground{
    objc_setAssociatedObject(self, @selector(navgationBackground), navgationBackground, OBJC_ASSOCIATION_COPY_NONATOMIC);
    if (navgationBackground == UIColor.clearColor || CGColorGetAlpha(navgationBackground.CGColor) <= 0.0001) {
        if (@available(iOS 13.0, *)) {
            [self.standardAppearance configureWithTransparentBackground];
            self.standardAppearance.shadowColor = [UIColor clearColor];
        } else {
            [self setBackgroundImage:[UIImage new] forBarMetrics:UIBarMetricsDefault];
            if (@available(iOS 10.0, *)){
                [self kj_hiddenLine:YES];
            } else {
                self.shadowImage = [UIImage new];
            }
        }
    } else {
        if (@available(iOS 13.0, *)) {
            [self.standardAppearance configureWithOpaqueBackground];
            [self.standardAppearance setBackgroundColor:navgationBackground];
            [self.standardAppearance setBackgroundImage:nil];
        } else {
            [self setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
            [self setBarTintColor:navgationBackground];
        }
    }
}
/// 设置图片背景导航栏
- (UIImage *)navgationImage{
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setNavgationImage:(UIImage *)navgationImage{
    objc_setAssociatedObject(self, @selector(navgationImage), navgationImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIColor *color = [UIColor colorWithPatternImage:navgationImage];
    [self setNavgationBackground:color];
}
- (NSString *)navgationCustomBackImageName{
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setNavgationCustomBackImageName:(NSString *)navgationCustomBackImageName{
    objc_setAssociatedObject(self, @selector(navgationCustomBackImageName), navgationCustomBackImageName, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIImage *image = [UIImage imageNamed:navgationCustomBackImageName];
    image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    if (@available(iOS 13.0, *)){
        [self.standardAppearance setBackIndicatorImage:image transitionMaskImage:image];
    } else {
        self.backIndicatorTransitionMaskImage = self.backIndicatorImage = image;
    }
}
@dynamic navgationBarBottomLine;
- (UIImageView *)navgationBarBottomLine{
    @autoreleasepool {
        /// 利用哈西算法解决多层嵌套
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        for (int i = 0; i < self.subviews.count; i++) {
            [dict setObject:self.subviews[i] forKey:[NSString stringWithFormat:@"%d",i]];
        }
        for (int i = 0; i < dict.allKeys.count; i++) {
            UIView *view = [dict objectForKey:[NSString stringWithFormat:@"%d",i]];
            if ([view isKindOfClass:[UIImageView class]]) {
                return (UIImageView *)view;
            }
        }
        return nil;
    }
}
- (UINavigationBar *)kj_hiddenNavigationBarBottomLine{
    if (@available(iOS 13.0, *)) {
        self.standardAppearance.shadowColor = [UIColor clearColor];
    } else {
        if (@available(iOS 10.0, *)){
            [self kj_hiddenLine:YES];
        } else {
            self.shadowImage = [UIImage new];
        }
    }
    return self;
}
- (void)kj_resetNavigationBarSystem{
    if (@available(iOS 13.0, *)){
        [self.standardAppearance configureWithDefaultBackground];
        self.standardAppearance.shadowImage = nil;
    } else {
        [self setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        if (@available(iOS 10.0, *)){
            [self kj_hiddenLine:NO];
        } else {
            self.shadowImage = nil;
        }
    }
}
/// 隐藏线条
- (void)kj_hiddenLine:(BOOL)hidden{
    if ([self respondsToSelector:@selector(setBackgroundImage:forBarMetrics:)]) {
        self.navgationBarBottomLine.hidden = hidden;
    }
}

#pragma mark - 自定义导航栏相关

// 更改导航栏颜色和图片
- (instancetype)kj_customNavgationBackImage:(UIImage *_Nullable)image background:(UIColor *_Nullable)color{
    [self clearSystemNavigation];
    if (self.customNavigationView == nil) {
        CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        CGFloat barHeight = self.bounds.size.height;
        CGRect barBounds = self.bounds;
        barBounds.size.height = statusHeight + barHeight;
        self.customNavigationView = [[KJCustomNavigationView alloc]initWithFrame:barBounds];
        [self kj_customNavgationHiddenBottomLine:self.hiddenBottomLine];
    }
    if (color) {
        self.customNavigationView.backColor = color;
    }
    if (image) {
        self.customNavigationView.backImage = image;
    }
    [[self valueForKey:@"backgroundView"] addSubview:self.customNavigationView];
    return self;
}
// 更改透明度
- (instancetype)kj_customNavgationAlpha:(CGFloat)alpha{
    [self clearSystemNavigation];
    if (self.customNavigationView == nil) {
        CGFloat statusHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
        CGFloat barHeight = self.bounds.size.height;
        CGRect barBounds = self.bounds;
        barBounds.size.height = statusHeight + barHeight;
        self.customNavigationView = [[KJCustomNavigationView alloc]initWithFrame:barBounds];
        [self kj_customNavgationHiddenBottomLine:self.hiddenBottomLine];
    }
    self.customNavigationView.alpha = alpha;
    [[self valueForKey:@"backgroundView"] addSubview:self.customNavigationView];
    return self;
}
// 导航栏背景高度，备注：这里并没有改导航栏高度，只是改了自定义背景高度
- (instancetype)kj_customNavgationHeight:(CGFloat)height{
    height = height < 0 ? 0 : height;
    [self clearSystemNavigation];
    if (self.customNavigationView == nil) {
        self.customNavigationView = [[KJCustomNavigationView alloc]init];
        [self kj_customNavgationHiddenBottomLine:self.hiddenBottomLine];
    }
    [self.customNavigationView setFrame:CGRectMake(0, 0, self.bounds.size.width, height)];
    [[self valueForKey:@"backgroundView"] addSubview:self.customNavigationView];
    return self;
}
// 隐藏底线
- (instancetype)kj_customNavgationHiddenBottomLine:(BOOL)hidden{
    self.hiddenBottomLine = hidden;
    if (self.customNavigationView && self.customNavigationView.hiddenBottomLine != hidden) {
        self.customNavigationView.hiddenBottomLine = hidden;
    } else {
        if (hidden) {
            if (self.lineClearImage == nil) {
                self.lineClearImage = [[UIImage alloc]init];
                [self setShadowImage:self.lineClearImage];
            }
        } else {
            if (self.lineClearImage) {
                self.lineClearImage = nil;
                [self setShadowImage:self.lineClearImage];
            }
        }
    }
    return self;
}
/// 更改自定义底部线条颜色
//- (instancetype)kj_customNavgationChangeBottomLineColor:(UIColor *)color{
//    if (self.lineClearImage == nil) {
//        self.lineClearImage = [[UIImage alloc] init];
//        self.lineClearImage = [self changeImage:self.lineClearImage color:color];
//        [self setShadowImage:self.lineClearImage];
//    }
//    return self;
//}
//- (UIImage *)changeImage:(UIImage *)image color:(UIColor *)color{
//    CGSize size = CGSizeMake(image.size.width * 2, image.size.height * 2);
//    UIGraphicsBeginImageContext(size);
//    CGContextRef ctx = UIGraphicsGetCurrentContext();
//    CGRect area = CGRectMake(0, 0, size.width, size.height);
//    CGContextScaleCTM(ctx, 1, -1);
//    CGContextTranslateCTM(ctx, 0, -area.size.height);
//    CGContextSaveGState(ctx);
//    CGContextClipToMask(ctx, area, image.CGImage);
//    [color set];
//    CGContextFillRect(ctx, area);
//    CGContextRestoreGState(ctx);
//    CGContextSetBlendMode(ctx, kCGBlendModeMultiply);
//    CGContextDrawImage(ctx, area, image.CGImage);
//    UIImage *destImage = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//    return destImage;
//}
// 还原到系统初始状态
- (void)kj_customNavigationRestoreSystemNavigation {
    if (self.customNavigationView) {
        [self.customNavigationView removeFromSuperview];
        self.customNavigationView = nil;
    }
    if (self.lineClearImage) {
        self.lineClearImage = nil;
    }
    if (self.backClearImage) {
        self.backClearImage = nil;
    }
    [self setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
    [self setShadowImage:nil];
//    self.barStyle = UIBarStyleDefault;
}
//去掉系统导航栏特征
- (void)clearSystemNavigation{
    if (self.backClearImage == nil) {
        self.backClearImage = [[UIImage alloc]init];
        [self setBackgroundImage:self.backClearImage forBarMetrics:UIBarMetricsDefault];
    }
    //去掉系统底线，使用自定义底线
    if (self.lineClearImage == nil) {
        self.lineClearImage = [[UIImage alloc]init];
        [self setShadowImage:self.lineClearImage];
    }
}

#pragma mark - Associated

- (KJCustomNavigationView *)customNavigationView{
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setCustomNavigationView:(KJCustomNavigationView *)customNavigationView{
    objc_setAssociatedObject(self, @selector(customNavigationView), customNavigationView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)hiddenBottomLine{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}
- (void)setHiddenBottomLine:(BOOL)hiddenBottomLine{
    objc_setAssociatedObject(self, @selector(hiddenBottomLine), @(hiddenBottomLine), OBJC_ASSOCIATION_ASSIGN);
}
- (UIImage *)backClearImage{
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setBackClearImage:(UIImage *)backClearImage{
    objc_setAssociatedObject(self, @selector(backClearImage), backClearImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIImage *)lineClearImage{
    return objc_getAssociatedObject(self, _cmd);
}
- (void)setLineClearImage:(UIImage *)lineClearImage{
    objc_setAssociatedObject(self, @selector(lineClearImage), lineClearImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@interface KJCustomNavigationView()
@property (nonatomic, strong) UIImageView *backImageView;
@property (nonatomic, strong) UIView *bottomLine;

@end

@implementation KJCustomNavigationView
- (void)setFrame:(CGRect)frame{
    [super setFrame:frame];
    if (CGRectEqualToRect(CGRectZero, frame)) {
        return;
    }
    CGFloat height = frame.size.height;
    CGFloat width = frame.size.width;
    [self.backImageView setFrame:CGRectMake(0, 0, width, height)];
    [self addSubview:self.backImageView];
    
    [self.bottomLine setFrame:CGRectMake(0, height-0.5, width, 0.5)];
    [self addSubview:self.bottomLine];
}

#pragma mark - getter/setter

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    [super setBackgroundColor:[UIColor clearColor]];
}

- (void)setBackColor:(UIColor *)backColor {
    _backColor = backColor;
    self.backImageView.backgroundColor = backColor;
}

- (void)setAlpha:(CGFloat)alpha {
    _alpha = alpha;
    self.backImageView.alpha = alpha;
}

- (void)setBackImage:(UIImage *)backImage {
    _backImage = backImage;
    self.backImageView.image = backImage;
}

- (void)setHiddenBottomLine:(BOOL)hiddenBottomLine {
    _hiddenBottomLine = hiddenBottomLine;
    self.bottomLine.hidden = hiddenBottomLine;
}

#pragma mark - lazy

- (UIImageView *)backImageView {
    if (!_backImageView) {
        _backImageView = [UIImageView new];
        _backImageView.clipsToBounds = YES;
        _backImageView.contentMode = UIViewContentModeTop;
    }
    return _backImageView;
}
- (UIView *)bottomLine {
    if (!_bottomLine) {
        _bottomLine = [UIView new];
        [_bottomLine setBackgroundColor:[UIColor grayColor]];
    }
    return _bottomLine;
}

@end
