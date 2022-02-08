//
//  UIColor+KJExtension.m
//  KJEmitterView
//
//  Created by 77。 on 2019/12/31.
//  https://github.com/YangKJ/KJCategories

#import "UIColor+KJExtension.h"

@implementation UIColor (KJExtension)
- (CGFloat)red{
    CGFloat r = 0, g, b, a;
    [self getRed:&r green:&g blue:&b alpha:&a];
    return r;
}
- (CGFloat)green{
    CGFloat r, g = 0, b, a;
    [self getRed:&r green:&g blue:&b alpha:&a];
    return g;
}
- (CGFloat)blue{
    CGFloat r, g, b = 0, a;
    [self getRed:&r green:&g blue:&b alpha:&a];
    return b;
}
- (CGFloat)alpha{
    return CGColorGetAlpha(self.CGColor);
}
- (CGFloat)hue{
    CGFloat h = 0,s,l;
    [self kj_HSL:&h :&s :&l];
    return h;
}
- (CGFloat)saturation{
    CGFloat h,s = 0,l;
    [self kj_HSL:&h :&s :&l];
    return s;
}
- (CGFloat)light{
    CGFloat h,s,l = 0;
    [self kj_HSL:&h :&s :&l];
    return l;
}
/// 获取颜色对应的RGBA
- (void)kj_rgba:(CGFloat *)r :(CGFloat *)g :(CGFloat *)b :(CGFloat *)a{
    NSString *colorString = [NSString stringWithFormat:@"%@",self];
    NSArray *temps = [colorString componentsSeparatedByString:@" "];
    if (temps.count == 3 || temps.count == 4) {
        *r = [temps[1] floatValue];
        *g = [temps[2] floatValue];
        *b = [temps[3] floatValue];
        if (temps.count == 4) {
            *a = [temps[4] floatValue];
        }
    }
}
/// 获取颜色对应的色相饱和度和透明度
- (void)kj_HSL:(CGFloat *)h :(CGFloat *)s :(CGFloat *)l{
    CGFloat red,green,blue,alpha = 0.0f;
    BOOL success = [self getRed:&red green:&green blue:&blue alpha:&alpha];
    if (success == NO) {
        *h = 0;*s = 0;*l = 0;
        return;
    }
    CGFloat hue = 0;
    CGFloat saturation = 0;
    CGFloat light = 0;
    CGFloat min = MIN(red,MIN(green,blue));
    CGFloat max = MAX(red,MAX(green,blue));
    if (min == max) {
        hue = 0;
        saturation = 0;
        light = min;
    }else {
        CGFloat d = (red==min) ? green-blue : ((blue==min) ? red-green : blue-red);
        CGFloat h = (red==min) ? 3 : ((blue==min) ? 1 : 5);
        hue = (h - d / (max - min)) / 6.0;
        saturation = (max - min) / max;
        light = max;
    }
    hue = (2 * hue - 1) * M_PI;
    *h = hue;
    *s = saturation;
    *l = light;
}
// UIColor转#ffffff格式的16进制字符串
- (NSString *)kj_hexString{
    return [UIColor hexStringFromColor:self];
}
+ (NSString *)hexStringFromColor:(UIColor *)color {
    const CGFloat *components = CGColorGetComponents(color.CGColor);
    CGFloat r = components[0];
    CGFloat g = components[1];
    CGFloat b = components[2];
    return [NSString stringWithFormat:@"#%02lX%02lX%02lX",lroundf(r*255),lroundf(g*255),lroundf(b*255)];
}
NSString *kDoraemonBoxHexStringFromColor(UIColor *color){
    return [UIColor hexStringFromColor:color];
}
UIColor * kDoraemonBoxColorHexString(NSString *hexString){
    return [UIColor colorWithHexString:hexString];
}
/// 16进制字符串转UIColor
+ (UIColor *)colorWithHexString:(NSString *)hexString {
    return [self colorWithHexString:hexString alpha:1.0];
}
/// 16进制字符串转UIColor
/// @param hexString 十六进制
/// @param alpha 透明度
+ (UIColor *)colorWithHexString:(NSString *)hexString alpha:(float)alpha{
    NSString *string = [[hexString stringByReplacingOccurrencesOfString:@"#" withString:@""] uppercaseString];
    if ([hexString hasPrefix:@"0x"]) {
        string = [hexString stringByReplacingOccurrencesOfString:@"0x" withString:@""];
    }
    CGFloat red,blue,green;
    switch ([string length]) {
        case 3: // #RGB
            alpha = 1.0f;
            red   = [self colorComponent:string start:0 length:1];
            green = [self colorComponent:string start:1 length:1];
            blue  = [self colorComponent:string start:2 length:1];
            break;
        case 4: // #ARGB
            alpha = [self colorComponent:string start:0 length:1];
            red   = [self colorComponent:string start:1 length:1];
            green = [self colorComponent:string start:2 length:1];
            blue  = [self colorComponent:string start:3 length:1];
            break;
        case 6: // #RRGGBB
            alpha = 1.0f;
            red   = [self colorComponent:string start:0 length:2];
            green = [self colorComponent:string start:2 length:2];
            blue  = [self colorComponent:string start:4 length:2];
            break;
        case 8: // #AARRGGBB
            alpha = [self colorComponent:string start:0 length:2];
            red   = [self colorComponent:string start:2 length:2];
            green = [self colorComponent:string start:4 length:2];
            blue  = [self colorComponent:string start:6 length:2];
            break;
        default:
            return nil;
    }
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}
+ (CGFloat)colorComponent:(NSString *)string start:(NSUInteger)start length:(NSUInteger)length {
    NSString *substring = [string substringWithRange:NSMakeRange(start,length)];
    NSString *fullHex = length == 2 ? substring : [NSString stringWithFormat:@"%@%@",substring,substring];
    unsigned hexComponent;
    [[NSScanner scannerWithString:fullHex] scanHexInt:&hexComponent];
    return hexComponent / 255.0;
}
/// 随机颜色
UIColor * kDoraemonBoxRandomColor(void){
    return [UIColor colorWithRed:((float)arc4random_uniform(256)/255.0)
                           green:((float)arc4random_uniform(256)/255.0)
                            blue:((float)arc4random_uniform(256)/255.0)
                           alpha:1.0];
}

@end
