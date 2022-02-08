//
//  NSDictionary+KJExtension.h
//  KJEmitterView
//
//  Created by 77。 on 2019/11/6.
//  https://github.com/YangKJ/KJCategories

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary (KJExtension)

/// Is it empty
@property (nonatomic, assign, readonly) BOOL isEmpty;

/// Convert to Josn string
@property (nonatomic, strong, readonly) NSString * jsonString;

/// Does it contain a key
- (BOOL)kj_containsKey:(NSString *)key;

/// Sort by dictionary key name, in ascending order
- (NSArray<NSString *> *)kj_keysSorted;

/// Sort by dictionary key name, sort in descending order
- (NSArray<NSString *> *)kj_keySortDescending;

/// Quickly traverse the dictionary
/// @param apply traverse the event, return yes to need the value
/// @return returns the key that satisfies the condition
- (NSArray<NSString *> *)kj_applyDictionaryValue:(BOOL(^)(id value, BOOL * stop))apply;

/// mapping dictionary
- (NSDictionary *)kj_mapDictionary:(BOOL(^)(NSString * key, id value))map;

/// merge dictionary
- (NSDictionary *)kj_mergeDictionary:(NSDictionary *)dictionary;

/// Dictionary selector
- (NSDictionary *)kj_pickForKeys:(NSArray<NSString *> *)keys;

/// Dictionary remover
- (NSDictionary *)kj_omitForKeys:(NSArray<NSString *> *)keys;

@end

NS_ASSUME_NONNULL_END
