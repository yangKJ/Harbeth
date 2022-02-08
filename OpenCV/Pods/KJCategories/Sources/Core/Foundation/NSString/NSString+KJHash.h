//
//  NSString+KJHash.h
//  KJEmitterView
//
//  Created by 77。 on 2021/5/28.
//  https://github.com/YangKJ/KJCategories

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (KJHash)

/// Determine whether it is a SHA512 encrypted string
@property (nonatomic, assign, readonly) BOOL verifySHA512;

/// Hash encryption
- (NSString *)SHA512String;

- (NSString *)SHA256String;

- (NSString *)MD5String;

/// base64 decoding
- (nullable NSString *)Base64DecodeString;
/// base64 encoding
- (nullable NSString *)Base64EncodeString;

/// AES256 encryption
/// @param key key
- (NSString *)AES256EncryptWithKey:(NSString *)key;
+ (nullable NSData *)AES256EncryptData:(NSData *)data key:(NSString *)key;

/// AES256 decryption
/// @param key key
- (NSString *)AES256DecryptWithKey:(NSString *)key;
+ (nullable NSData *)AES256DecryptData:(NSData *)data key:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
