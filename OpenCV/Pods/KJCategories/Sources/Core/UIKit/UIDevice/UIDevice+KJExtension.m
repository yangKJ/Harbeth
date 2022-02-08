//
//  UIDevice+KJExtension.m
//  KJEmitterView
//
//  Created by 77。 on 2019/3/17.
//  https://github.com/YangKJ/KJCategories

#import "UIDevice+KJExtension.h"
#import <MobileCoreServices/MobileCoreServices.h>

@implementation UIDevice (KJExtension)

@dynamic appCurrentVersion,appName,appIcon,deviceID;
+ (NSString *)appCurrentVersion{
    static NSString * version;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    });
    return version;
}
+ (NSString *)appName{
    static NSString * name;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        name = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
    });
    return name;
}
+ (NSString *)deviceID{
    static NSString * identifier;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        identifier = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    });
    return identifier;
}
+ (UIImage *)appIcon{
    static UIImage * image;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *iconFilename = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIconFile"];
        NSString *name = [iconFilename stringByDeletingPathExtension];
        image = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:name ofType:[iconFilename pathExtension]]];
    });
    return image;
}
@dynamic launchImage;
+ (UIImage *)launchImage{
    UIImage *lauchImage = nil;
    NSString *viewOrientation = nil;
    CGSize viewSize = [UIScreen mainScreen].bounds.size;
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (orientation == UIInterfaceOrientationLandscapeLeft ||
        orientation == UIInterfaceOrientationLandscapeRight){
        viewOrientation = @"Landscape";
    } else {
        viewOrientation = @"Portrait";
    }
    NSArray *imagesDictionary = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"UILaunchImages"];
    for (NSDictionary *dict in imagesDictionary){
        CGSize imageSize = CGSizeFromString(dict[@"UILaunchImageSize"]);
        if (CGSizeEqualToSize(imageSize, viewSize) &&
            [viewOrientation isEqualToString:dict[@"UILaunchImageOrientation"]]) {
            lauchImage = [UIImage imageNamed:dict[@"UILaunchImageName"]];
        }
    }
    return lauchImage;
}
@dynamic cameraAvailable;
+ (BOOL)cameraAvailable{
    NSArray *temps = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
    BOOL canTakeVideo = NO;
    for (NSString *mediaType in temps) {
        if ([mediaType isEqualToString:(NSString *)kUTTypeImage]) {
            canTakeVideo = YES;
            break;
        }
    }
    return canTakeVideo;
}

@end
