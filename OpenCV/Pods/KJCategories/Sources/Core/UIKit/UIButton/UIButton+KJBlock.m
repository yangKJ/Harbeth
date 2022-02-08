//
//  UIButton+KJBlock.m
//  KJEmitterView
//
//  Created by 77。 on 2019/4/4.
//  https://github.com/YangKJ/KJCategories

#import "UIButton+KJBlock.h"
#import <objc/runtime.h>

@implementation UIButton (KJBlock)

static NSString * const _Nonnull DoraemonBoxEventsStringMap[] = {
    [UIControlEventTouchDown]        = @"kDoraemonBoxUIControlEventTouchDown",
    [UIControlEventTouchDownRepeat]  = @"kDoraemonBoxUIControlEventTouchDownRepeat",
    [UIControlEventTouchDragInside]  = @"kDoraemonBoxUIControlEventTouchDragInside",
    [UIControlEventTouchDragOutside] = @"kDoraemonBoxUIControlEventTouchDragOutside",
    [UIControlEventTouchDragEnter]   = @"kDoraemonBoxUIControlEventTouchDragEnter",
    [UIControlEventTouchDragExit]    = @"kDoraemonBoxUIControlEventTouchDragExit",
    [UIControlEventTouchUpInside]    = @"kDoraemonBoxUIControlEventTouchUpInside",
    [UIControlEventTouchUpOutside]   = @"kDoraemonBoxUIControlEventTouchUpOutside",
    [UIControlEventTouchCancel]      = @"kDoraemonBoxUIControlEventTouchCancel",
};
#define kDoraemonBoxButtonAction(name) \
- (void)kj_action##name{ \
KJButtonBlock block = objc_getAssociatedObject(self, _cmd);\
if (block) block(self);\
}
/// 事件响应方法
kDoraemonBoxButtonAction(kDoraemonBoxUIControlEventTouchDown);
kDoraemonBoxButtonAction(kDoraemonBoxUIControlEventTouchDownRepeat);
kDoraemonBoxButtonAction(kDoraemonBoxUIControlEventTouchDragInside);
kDoraemonBoxButtonAction(kDoraemonBoxUIControlEventTouchDragOutside);
kDoraemonBoxButtonAction(kDoraemonBoxUIControlEventTouchDragEnter);
kDoraemonBoxButtonAction(kDoraemonBoxUIControlEventTouchDragExit);
kDoraemonBoxButtonAction(kDoraemonBoxUIControlEventTouchUpInside);
kDoraemonBoxButtonAction(kDoraemonBoxUIControlEventTouchUpOutside);
kDoraemonBoxButtonAction(kDoraemonBoxUIControlEventTouchCancel);

/// 添加点击事件，默认UIControlEventTouchUpInside
- (void)kj_addAction:(void(^)(UIButton * kButton))block{
    [self kj_addAction:block forControlEvents:UIControlEventTouchUpInside];
}
/// 添加事件
- (void)kj_addAction:(KJButtonBlock)block forControlEvents:(UIControlEvents)controlEvents{
    if (block == nil || controlEvents > (1<<8)) return;
    if (controlEvents != UIControlEventTouchDown && (controlEvents&1)) return;
    NSString *actionName = [@"kj_action" stringByAppendingFormat:@"%@",DoraemonBoxEventsStringMap[controlEvents]];
    SEL selector = NSSelectorFromString(actionName);
    objc_setAssociatedObject(self, selector, block, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self addTarget:self action:selector forControlEvents:controlEvents];
}

#pragma mark - 时间相关方法交换

/// 交换方法后实现
- (void)kj_sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event{
    if (self.timeInterval <= 0) {
        [self kj_sendAction:action to:target forEvent:event];
        return;
    }
    NSTimeInterval time = CFAbsoluteTimeGetCurrent();
    if ((time - self.lastTime >= self.timeInterval)) {
        self.lastTime = time;
        [self kj_sendAction:action to:target forEvent:event];
    }
}

#pragma mark - associated

- (CGFloat)timeInterval{
    return [objc_getAssociatedObject(self, @selector(timeInterval)) doubleValue];
}
- (void)setTimeInterval:(CGFloat)timeInterval{
    objc_setAssociatedObject(self, @selector(timeInterval), @(timeInterval), OBJC_ASSOCIATION_ASSIGN);
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        kExceptionMethodSwizzling([self class],
                                  @selector(sendAction:to:forEvent:),
                                  @selector(kj_sendAction:to:forEvent:));
    });
}
- (NSTimeInterval)lastTime{
    return [objc_getAssociatedObject(self, @selector(lastTime)) doubleValue];
}
- (void)setLastTime:(NSTimeInterval)lastTime{
    objc_setAssociatedObject(self, @selector(lastTime), @(lastTime), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
/// 交换实例方法的实现
static void kExceptionMethodSwizzling(Class clazz, SEL original, SEL swizzled){
    Method originalMethod = class_getInstanceMethod(clazz, original);
    Method swizzledMethod = class_getInstanceMethod(clazz, swizzled);
    if (class_addMethod(clazz, original, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
        class_replaceMethod(clazz, swizzled, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

#pragma mark - 扩大点击域

- (CGFloat)enlargeClick{
    return [objc_getAssociatedObject(self, @selector(enlargeClick)) floatValue];;
}
- (void)setEnlargeClick:(CGFloat)enlargeClick{
    objc_setAssociatedObject(self, @selector(enlargeClick), @(enlargeClick), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &topNameKey, [NSNumber numberWithFloat:enlargeClick], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, &rightNameKey, [NSNumber numberWithFloat:enlargeClick], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, &bottomNameKey, [NSNumber numberWithFloat:enlargeClick], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, &leftNameKey, [NSNumber numberWithFloat:enlargeClick], OBJC_ASSOCIATION_COPY_NONATOMIC);
}
static char topNameKey,bottomNameKey,leftNameKey,rightNameKey;
- (void)EnlargeEdgeTop:(CGFloat)top left:(CGFloat)left bottom:(CGFloat)bottom right:(CGFloat)right{
    objc_setAssociatedObject(self, &topNameKey, [NSNumber numberWithFloat:top], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, &rightNameKey, [NSNumber numberWithFloat:right], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, &bottomNameKey, [NSNumber numberWithFloat:bottom], OBJC_ASSOCIATION_COPY_NONATOMIC);
    objc_setAssociatedObject(self, &leftNameKey, [NSNumber numberWithFloat:left], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (CGRect)enlargedRect{
    NSNumber *top = objc_getAssociatedObject(self, &topNameKey);
    NSNumber *right = objc_getAssociatedObject(self, &rightNameKey);
    NSNumber *bottom = objc_getAssociatedObject(self, &bottomNameKey);
    NSNumber *left = objc_getAssociatedObject(self, &leftNameKey);
    if (top && right && bottom && left) {
        return CGRectMake(self.bounds.origin.x - left.floatValue,
                          self.bounds.origin.y - top.floatValue,
                          self.bounds.size.width + left.floatValue + right.floatValue,
                          self.bounds.size.height + top.floatValue + bottom.floatValue);
    } else {
        return self.bounds;
    }
}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event{
    CGRect rect = [self enlargedRect];
    if (CGRectEqualToRect(rect, self.bounds)) {
        return [super hitTest:point withEvent:event];
    }
    return CGRectContainsPoint(rect, point) ? self : nil;
}
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event{
    UIEdgeInsets insets = self.touchAreaInsets;
    CGRect bounds = self.bounds;
    bounds = CGRectMake(bounds.origin.x - insets.left,
                        bounds.origin.y - insets.top,
                        bounds.size.width + insets.left + insets.right,
                        bounds.size.height + insets.top + insets.bottom);
    return CGRectContainsPoint(bounds, point);
}

#pragma mark - associated

- (UIEdgeInsets)touchAreaInsets{
    return [objc_getAssociatedObject(self, _cmd) UIEdgeInsetsValue];
}
- (void)setTouchAreaInsets:(UIEdgeInsets)touchAreaInsets{
    NSValue *value = [NSValue valueWithUIEdgeInsets:touchAreaInsets];
    objc_setAssociatedObject(self, @selector(touchAreaInsets), value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
