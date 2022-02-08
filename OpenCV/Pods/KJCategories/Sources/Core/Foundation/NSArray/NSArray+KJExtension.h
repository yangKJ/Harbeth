//
//  NSArray+KJExtension.h
//  KJEmitterView
//
//  Created by 77。 on 2019/11/6.
//  https://github.com/YangKJ/KJCategories
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Advanced array usage
@interface NSArray (KJExtension)

/// Is it empty
@property (nonatomic, assign, readonly) BOOL isEmpty;

/// Move the position of the object element
/// @param index move the subscript
/// @param toIndex move position
- (NSArray *)kj_moveIndex:(NSInteger)index toIndex:(NSInteger)toIndex;

/// Move element
/// @param object to move the element, it needs to be unique otherwise it will cause problems
/// @param toIndex move position
- (NSArray *)kj_moveObject:(id)object toIndex:(NSInteger)toIndex;

/// Exchange position
/// @param index exchange elements
/// @param toIndex exchange position
- (NSArray *)kj_exchangeIndex:(NSInteger)index toIndex:(NSInteger)toIndex;

/// Reverse order
- (NSArray *)kj_reverseArray;

/// Filter data
- (id)kj_detectArray:(BOOL(^)(id object, int index))block;

/// Multidimensional array filter data
- (id)kj_detectManyDimensionArray:(BOOL(^)(id object, BOOL * stop))recurse;

/// Summarize and compare choices
/// @param object Data to be compared
/// @param comparison contrast callback
/// @return returns the data after comparison
- (id)kj_reduceObject:(id)object comparison:(id(^)(id obj1, id obj2))comparison;

/// Find data, return -1 means it has not been queried
- (NSInteger)kj_searchObject:(id)object;

/// Mapping, take out some kind of data
- (NSArray *)kj_mapArray:(id(^)(id object))map;

/// Mapping, whether to reverse the order
/// @param map mapping callback
/// @param reverse Whether to reverse the order
- (NSArray *)kj_mapArray:(id(^)(id object))map reverse:(BOOL)reverse;

/// Map and filter data
/// @param map Map and filter events, return the mapped data, return nil to filter the data
/// @param repetition does it need to be repetitive
- (NSArray *)kj_mapArray:(id _Nullable(^)(id object))map repetition:(BOOL)repetition;

/// contains data
- (BOOL)kj_containsObject:(BOOL(^)(id object, NSUInteger index))contains;

/// Does it contain data
/// @param index specifies the position and returns the corresponding position of the data
/// @param contains callback event, return yes to include the data
/// @return returns whether the data is included
- (BOOL)kj_containsFromIndex:(inout NSInteger * _Nonnull)index contains:(BOOL(^)(id object))contains;

/// Replace the specified element of the array,
/// @param object replacement element
/// @param operation callback event, return yes to replace the data, stop controls whether to replace all
/// @return returns the array after replacement
- (NSArray *)kj_replaceObject:(id)object operation:(BOOL(^)(id object, NSUInteger index, BOOL * stop))operation;

/// Insert data to the destination
/// @param object The element to be inserted
/// @param aim callback event, return yes to insert the data
/// @return returns the array after insertion
- (NSArray *)kj_insertObject:(id)object aim:(BOOL(^)(id object, int index))aim;

/// Determine whether the two arrays contain the same elements
- (BOOL)kj_isEqualOtherArray:(NSArray *)otherArray;

/// Randomly scramble the array
- (NSArray *)kj_disorganizeArray;

/// Delete the same element in the array, similar to NSSet function
- (NSArray *)kj_deleteArrayEquelObject;

/// A piece of data in a random array
- (nullable id)kj_randomObject;

/// Array remover
/// @param array data to be removed
- (NSArray *)kj_pickArray:(NSArray *)array;

@end

NS_ASSUME_NONNULL_END
