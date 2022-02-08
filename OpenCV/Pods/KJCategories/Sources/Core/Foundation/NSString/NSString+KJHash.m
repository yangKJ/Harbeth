//
//  NSString+KJHash.m
//  KJEmitterView
//
//  Created by 77。 on 2021/5/28.
//  https://github.com/YangKJ/KJCategories

#import "NSString+KJHash.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>

@implementation NSString (KJHash)

- (BOOL)verifySHA512{
    if (self.length != 128) {
        return NO;
    }
    NSData *data = [NSString kj_dataWithHexCString:[self cStringUsingEncoding:NSASCIIStringEncoding]];
    return (data != nil);
}
+ (NSData *)kj_dataWithHexCString:(const char *)hexCString{
    if (hexCString == NULL) return nil;
    const unsigned char *psz = (const unsigned char*)hexCString;
    while (isspace(*psz)) psz++;
    // Skip optional 0x prefix
    if (psz[0] == '0' && tolower(psz[1]) == 'x') psz += 2;
    while (isspace(*psz)) {
        psz++;
    }
    size_t len = strlen((const char*)psz);
    // If the string is not full number of bytes (each byte 2 hex characters), return nil.
    if (len % 2 != 0) return nil;
    unsigned char * buf = (unsigned char*)malloc(len/2);
    static const signed char digits[256] = {
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
         0,  1,  2,  3,  4,  5,  6,  7,  8,  9, -1, -1, -1, -1, -1, -1,
        -1,0xa,0xb,0xc,0xd,0xe,0xf, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1,0xa,0xb,0xc,0xd,0xe,0xf, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
    };
    unsigned char * bufpointer = buf;
    while (1) {
        unsigned char c1 = (unsigned char)*psz++;
        signed char n1 = digits[c1];
        if (n1 == (signed char)-1) break;
        unsigned char c2 = (unsigned char)*psz++;
        signed char n2 = digits[c2];
        if (n2 == (signed char)-1) break;
        *bufpointer = (unsigned char)((n1 << 4) | n2);
        bufpointer++;
    }
    
    return [[NSData alloc] initWithBytesNoCopy:buf length:len/2];
}

// SHA512加密
- (NSString *)SHA512String {
    const char *cstr = [self cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:self.length];
    uint8_t digest[CC_SHA512_DIGEST_LENGTH];
    CC_SHA512(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA512_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA512_DIGEST_LENGTH; i++)
    [output appendFormat:@"%02x", digest[i]];
    return [NSString stringWithString:output];
}

- (NSString *)SHA256String {
    const char *cstr = [self cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:self.length];
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (uint32_t)data.length, digest);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++)
    [output appendFormat:@"%02x", digest[i]];
    return [NSString stringWithString:output];
}

- (NSString *)MD5String {
    const char *str = [self UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), result);
    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        // %02意思是不足两位将用0补齐，如果多于两位则不影响
        // 小写x表示输出小写，大写X表示输出大写，可以根据需求更改
        [ret appendFormat:@"%02x",result[i]];
    }
    return ret;
}

/// base64解码
- (nullable NSString *)Base64DecodeString{
    NSData *data = [[NSData alloc]initWithBase64EncodedString:self options:0];
    if (data) {
        return [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];;
    }
    return nil;
}
/// base64编码
- (nullable NSString *)Base64EncodeString{
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
    if (data) {
        return [data base64EncodedStringWithOptions:0];
    }
    return nil;
}

/// AES256加密
/// @param key 密钥
- (NSString *)AES256EncryptWithKey:(NSString *)key{
    const char *cstr = [self cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:self.length];
    NSData *result = [NSString AES256EncryptData:data key:key];
    if (result) {
        return [result base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    } else {
        return @"";
    }
}

+ (NSData *)AES256EncryptData:(NSData *)data key:(NSString *)key{
    if (!data || !key) return nil;
    char keyPtr[kCCKeySizeAES256 + 1];
    bzero(keyPtr, sizeof(keyPtr));
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    NSUInteger dataLength = [data length];
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES,
                                          kCCOptionPKCS7Padding | kCCOptionECBMode,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL,
                                          [data bytes], dataLength,
                                          buffer, bufferSize,
                                          &numBytesEncrypted);
    NSData *result = nil;
    if (cryptStatus == kCCSuccess) {
        result = [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
    }
    free(buffer);
    return result;
}

/// AES256解密
/// @param key 密钥
- (NSString *)AES256DecryptWithKey:(NSString *)key{
    NSData *data = [[NSData alloc] initWithBase64EncodedData:[self dataUsingEncoding:NSASCIIStringEncoding]
                                                     options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSData *result = [NSString AES256DecryptData:data key:key];
    if (result) {
        return [[NSString alloc] initWithData:result encoding:NSUTF8StringEncoding];
    } else {
        return @"";
    }
}

+ (NSData *)AES256DecryptData:(NSData *)data key:(NSString *)key{
    if (!data || !key) return nil;
    char keyPtr[kCCKeySizeAES256 + 1];
    bzero(keyPtr, sizeof(keyPtr));
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    NSUInteger dataLength = [data length];
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    size_t numBytesDecrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES,
                                          kCCOptionPKCS7Padding | kCCOptionECBMode,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL,
                                          [data bytes], dataLength,
                                          buffer, bufferSize,
                                          &numBytesDecrypted);
    NSData *result = nil;
    if (cryptStatus == kCCSuccess) {
        result = [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }
    free(buffer);
    return result;
}

@end
