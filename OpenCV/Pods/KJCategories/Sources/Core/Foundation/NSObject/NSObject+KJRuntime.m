//
//  NSObject+KJRuntime.m
//  KJEmitterView
//
//  Created by 77。 on 2019/12/15.
//  https://github.com/YangKJ/KJCategories

#import "NSObject+KJRuntime.h"

@implementation NSObject (KJRuntime)
@dynamic propertyTemps;
- (NSArray<NSString *> *)propertyTemps{
    unsigned int count;
    objc_property_t *properties = class_copyPropertyList([self class], &count);
    NSMutableArray *temp = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; i++) {
        objc_property_t property = properties[i];
        const char *char_f = property_getName(property);
        NSString *propertyName = [NSString stringWithUTF8String:char_f];
        if (propertyName) [temp addObject:propertyName];
    }
    free(properties);
    return temp.mutableCopy;
}
@dynamic ivarTemps;
- (NSArray<NSString *> *)ivarTemps{
    unsigned int count;
    Ivar *ivar = class_copyIvarList([self class], &count);
    NSMutableArray *temp = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; i++) {
        const char *char_f = ivar_getName(ivar[i]);
        NSString *name = [NSString stringWithCString:char_f encoding:NSUTF8StringEncoding];
        if (name) [temp addObject:name];
    }
    return temp.mutableCopy;
}
@dynamic methodTemps;
- (NSArray<NSString *> *)methodTemps{
    unsigned int count;
    Method *method = class_copyMethodList([self class], &count);
    NSMutableArray *temp = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; i++) {
        NSString *name = NSStringFromSelector(method_getName(method[i]));
        if (name) [temp addObject:name];
    }
    return temp.mutableCopy;
}
@dynamic protocolTemps;
- (NSArray<NSString *> *)protocolTemps{
    unsigned int count;
    __unsafe_unretained Protocol **protocolList = class_copyProtocolList([self class], &count);
    NSMutableArray *temp = [NSMutableArray arrayWithCapacity:count];
    for (unsigned int i = 0; i<count; i++) {
        const char *protocolName = protocol_getName(protocolList[i]);
        NSString *name = [NSString stringWithCString:protocolName encoding:NSUTF8StringEncoding];
        if (name) [temp addObject:name];
    }
    return temp.mutableCopy;
}
@dynamic objectProperties;
- (NSArray<NSString *> * _Nonnull (^)(BOOL))objectProperties{
    return ^NSArray<NSString *> *(BOOL have){
        if (have) {
            NSMutableArray *temps = [NSMutableArray array];
            Class clazz = [self class];
            unsigned int count;
            while (clazz != [NSObject class]) {
                objc_property_t *properties = class_copyPropertyList(clazz, &count);
                for (int i = 0; i < count; i++) {
                    objc_property_t property = properties[i];
                    const char *char_f = property_getName(property);
                    NSString *propertyName = [NSString stringWithUTF8String:char_f];
                    if (propertyName) [temps addObject:propertyName];
                }
                free(properties);
                clazz = [clazz superclass];
            }
            return temps.mutableCopy;
        } else {
            return self.propertyTemps;
        }
    };
}

/// 归档封装
- (void)kj_runtimeEncode:(NSCoder *)encoder{
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList([self class], &count);
    for (int i = 0; i<count; i++) {
        const char *name = ivar_getName(ivars[i]);
        NSString *key = [NSString stringWithUTF8String:name];
        id value = [self valueForKey:key];
        [encoder encodeObject:value forKey:key];
    }
    free(ivars);
}
/// 解档封装
- (void)kj_runtimeInitCoder:(NSCoder *)decoder{
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList([self class], &count);
    for (int i = 0; i<count; i++) {
        const char *name = ivar_getName(ivars[i]);
        NSString *key = [NSString stringWithUTF8String:name];
        id value = [decoder decodeObjectForKey:key];
        [self setValue:value forKey:key];
    }
    free(ivars);
}
/// NSCopying协议快捷设置
- (id)kj_setCopyingWithZone:(NSZone *)zone{
    id obj = [[[self class] allocWithZone:zone] init];
    [self kj_copyingObject:obj];
    return obj;
}
/// 拷贝obj属性
- (void)kj_copyingObject:(id)obj{
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList([self class], &count);
    for (int i = 0; i<count; i++){
        const char *name = ivar_getName(ivars[i]);
        NSString *key = [NSString stringWithUTF8String:name];
        id value = [self valueForKey:key];
        if ([value respondsToSelector:@selector(copyWithZone:)]) {
            [obj setValue:[value copy] forKey:key];
        } else {
            [obj setValue:value forKey:key];
        }
    }
    free(ivars);
}
/// 拷贝指定类属性
- (instancetype)kj_appointCopyPropertyClass:(Class)clazz Zone:(NSZone *)zone{
    id obj = [[NSObject allocWithZone:zone] init];
    unsigned int count = 0;
    objc_property_t *properties = class_copyPropertyList(clazz, &count);
    for (int i = 0; i < count; i++) {
        objc_property_t property = properties[i];
        const char *name = property_getName(property);
        NSString *propertyName = [NSString stringWithUTF8String:name];
        id value = [self valueForKey:propertyName];
        if (value) [obj setValue:value forKey:propertyName];
    }
    free(properties);
    return obj;
}
/// 拷贝全部属性（包括父类）
- (instancetype)kj_copyPropertyWithZone:(NSZone *)zone{
    id obj = [[NSObject allocWithZone:zone] init];
    Class clazz = [self class];
    while (clazz != [NSObject class]) {
        unsigned int count;
        objc_property_t *properties = class_copyPropertyList(clazz, &count);
        for (int i = 0; i < count; i++) {
            objc_property_t property = properties[i];
            const char *char_f = property_getName(property);
            NSString *propertyName = [NSString stringWithUTF8String:char_f];
            id value = [self valueForKey:propertyName];
            if (value) [obj setValue:value forKey:propertyName];
        }
        free(properties);
        clazz = [clazz superclass];
    }
    return obj;
}

/// 交换实例方法
void kRuntimeMethodSwizzling(Class clazz, SEL original, SEL swizzled){
    Method originalMethod = class_getInstanceMethod(clazz, original);
    Method swizzledMethod = class_getInstanceMethod(clazz, swizzled);
    if (class_addMethod(clazz, original, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
        class_replaceMethod(clazz, swizzled, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}
/// 交换类方法
void kRuntimeClassMethodSwizzling(Class clazz, SEL original, SEL swizzled){
    Method originalMethod = class_getClassMethod(clazz, original);
    Method swizzledMethod = class_getClassMethod(clazz, swizzled);
    Class metaclass = objc_getMetaClass(NSStringFromClass(clazz).UTF8String);
    if (class_addMethod(metaclass, original, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
        class_replaceMethod(metaclass, swizzled, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

/// 动态继承，慎用（一旦修改后面使用的都是该子类）
- (void)kj_dynamicInheritChildClass:(Class)clazz{
    // 动态继承修改自身对象的isa指针使其指向子类，便可以调用子类的方法
    object_setClass(self, clazz);
}
/// 获取对象类名
- (NSString *)kj_runtimeClassName{
    return [NSString stringWithUTF8String:object_getClassName(self)];
}
/// 判断对象是否有该属性
- (void)kj_runtimeHaveProperty:(void(^)(NSString *, BOOL * stop))traversal{
    for (NSString * name in self.propertyTemps) {
        BOOL stop = NO;
        traversal(name, &stop);
        if (stop) return;
    }
}

@end
