//
//  NSObject+KJRuntime.h
//  KJEmitterView
//
//  Created by 77。 on 2019/12/15.
//  https://github.com/YangKJ/KJCategories
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (KJRuntime)

/// Get all the attributes of the object
@property (nonatomic, strong, readonly) NSArray<NSString *> *propertyTemps;
/// List of instance variables
@property (nonatomic, strong, readonly) NSArray<NSString *> *ivarTemps;
/// Method list
@property (nonatomic, strong, readonly) NSArray<NSString *> *methodTemps;
/// List of protocols followed
@property (nonatomic, strong, readonly) NSArray<NSString *> *protocolTemps;
/// Get all the attributes of the object, whether it contains the attributes of the parent class
@property (nonatomic, strong, readonly) NSArray<NSString *> *(^objectProperties)(BOOL containSuper);

/// Archive package
- (void)kj_runtimeEncode:(NSCoder *)encoder;
/// Unarchive and package
- (void)kj_runtimeInitCoder:(NSCoder *)decoder;
/// NSCopying protocol quick setting
- (id)kj_setCopyingWithZone:(NSZone *)zone;
/// Copy attributes
- (void)kj_copyingObject:(id)obj;

/// Copy specified class attributes, used in NSCopying protocol
- (instancetype)kj_appointCopyPropertyClass:(Class)clazz Zone:(NSZone *)zone;
/// Copy all attributes (including parent class)
- (instancetype)kj_copyPropertyWithZone:(NSZone *)zone;

/// Exchange instance method, this method needs to be executed in dispatch_once
FOUNDATION_EXPORT void kRuntimeMethodSwizzling(Class clazz, SEL original, SEL swizzled);
/// Exchange class method
FOUNDATION_EXPORT void kRuntimeClassMethodSwizzling(Class clazz, SEL original, SEL swizzled);

/// Dynamic inheritance, use it with caution (Once you modify it, you will use this subclass)
- (void)kj_dynamicInheritChildClass:(Class)clazz;

/// Get the object class name
- (NSString *)kj_runtimeClassName;

/// Determine whether the object has this attribute
- (void)kj_runtimeHaveProperty:(void(^)(NSString * property, BOOL * stop))traversal;

@end

NS_ASSUME_NONNULL_END
