//
//  NSDictionary+KJExtension.m
//  KJEmitterView
//
//  Created by 77。 on 2019/11/6.
//  https://github.com/YangKJ/KJCategories

#import "NSDictionary+KJExtension.h"

@implementation NSDictionary (KJExtension)

- (BOOL)isEmpty{
    return (self == nil || [self isKindOfClass:[NSNull class]] || self.allKeys == 0);
}
- (NSString *)jsonString{
    NSError *error;
#ifdef DEBUG
    NSJSONWritingOptions options = NSJSONWritingPrettyPrinted;
#else
    NSJSONWritingOptions options = 0;
#endif
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self options:options error:&error];
    if (jsonData) {
        return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    } else {
        return @"";
    }
}
/// 是否包含某个key
- (BOOL)kj_containsKey:(NSString *)key{
    if (self.allKeys.count == 0 || ![self.allKeys containsObject:key]) {
        return NO;
    }
    if ([self[key] isEqual:[NSNull null]]) {
        return NO;
    }
    if ([self[key] isKindOfClass:[NSString class]] && [self[key] isEqualToString:@""]) {
        return NO;
    }
    if ([self[key] isEqual:[NSNull null]]) {
        return NO;
    }
    return YES;
}
/// 字典键名排序
- (NSArray<NSString *> *)kj_keysSorted{
    return [[self allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}
- (NSArray<NSString *> *)kj_keySortDescending{
    @autoreleasepool {
        // "self"，表示字符串本身
        NSSortDescriptor * des = [NSSortDescriptor sortDescriptorWithKey:@"self" ascending:NO];
        NSMutableArray * array = [NSMutableArray arrayWithArray:[self allKeys]];
        [array sortUsingDescriptors:@[des]];
        return array.mutableCopy;
    }
}
/// 快速遍历字典，返回满足条件所有key
- (NSArray<NSString *> *)kj_applyDictionaryValue:(BOOL(^)(id value, BOOL * stop))apply{
    @autoreleasepool {
        id value;
        NSMutableSet * set = [NSMutableSet set];
        NSEnumerator * enumtor = [self objectEnumerator];
        while (value = [enumtor nextObject]) {
            BOOL stop = NO;
            if (apply(value, &stop)) {
                NSArray * array = [self allKeysForObject:value];
                [set addObjectsFromArray:array];
            }
            if (stop) break;
        }
        return set.allObjects;
    }
}
/// 映射字典
- (NSDictionary *)kj_mapDictionary:(BOOL(^)(NSString * key, id value))map{
    @autoreleasepool {
        NSMutableDictionary * dict = [NSMutableDictionary dictionary];
        NSEnumerator * enumtor = [self keyEnumerator];
        NSString * key = nil;
        while (key = [enumtor nextObject]) {
            id value = self[key];
            if (map(key, value)) {
                [dict setValue:value forKey:key];
            }
        }
        return dict.mutableCopy;
    }
}
/// 合并字典
- (NSDictionary *)kj_mergeDictionary:(NSDictionary *)dictionary{
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:self];
    NSMutableDictionary *temp = [NSMutableDictionary dictionaryWithDictionary:self];
    [temp addEntriesFromDictionary:dictionary];
    [temp enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
        if ([self objectForKey:key]) {
            if ([obj isKindOfClass:[NSDictionary class]]) {
                NSDictionary * dict = [[self objectForKey:key] kj_mergeDictionary:obj];
                [result setObject:dict forKey:key];
            } else {
                [result setObject:obj forKey:key];
            }
        } else if ([dictionary objectForKey:key]) {
            if ([obj isKindOfClass:[NSDictionary class]]) {
                NSDictionary * dict = [[dictionary objectForKey:key] kj_mergeDictionary:obj];
                [result setObject:dict forKey:key];
            } else {
                [result setObject:obj forKey:key];
            }
        }
    }];
    return (NSDictionary *) [result mutableCopy];
}

- (NSDictionary *)kj_pickForKeys:(NSArray *)keys{
    @autoreleasepool {
        NSMutableDictionary *picked = [[NSMutableDictionary alloc] initWithCapacity:keys.count];
        [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if ([keys containsObject:key]) {
                picked[key] = obj;
            }
        }];
        return picked.mutableCopy;
    }
}

- (NSDictionary *)kj_omitForKeys:(NSArray *)keys{
    @autoreleasepool {
        NSMutableDictionary *result = [self mutableCopy];
        [result removeObjectsForKeys:keys];
        return result.mutableCopy;
    }
}

@end
