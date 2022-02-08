//
//  UIDevice+KJExtension.h
//  KJEmitterView
//
//  Created by 77。 on 2019/3/17.
//  https://github.com/YangKJ/KJCategories

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIDevice (KJExtension)

/// App version number
@property (nonatomic,strong,class) NSString *appCurrentVersion;
/// App name
@property (nonatomic,strong,class) NSString *appName;
/// Mobile phone UUID
@property (nonatomic,strong,class) NSString *deviceID;
/// Get App icon
@property (nonatomic,strong,class) UIImage *appIcon;
/// Get start page picture
@property (nonatomic,strong,class) UIImage *launchImage;
/// Determine whether the camera is available
@property (nonatomic,assign,class) BOOL cameraAvailable;

@end

NS_ASSUME_NONNULL_END
