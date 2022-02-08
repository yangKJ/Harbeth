//
//  KJCoreHeader.h
//  KJCategories
//
//  Created by 77。 on 2021/11/7.
//  https://github.com/YangKJ/KJCategories
//

#ifndef KJCoreHeader_h
#define KJCoreHeader_h

/// Commonly used core categories of projects.

#if __has_include(<KJCategories/UIButton+KJBlock.h>)
#import <KJCategories/UIButton+KJBlock.h>
#import <KJCategories/UIButton+KJContentLayout.h>
#import <KJCategories/UIColor+KJExtension.h>
#import <KJCategories/UIColor+KJGradient.h>
#import <KJCategories/UIDevice+KJExtension.h>
#import <KJCategories/UIImage+KJCapture.h>
#import <KJCategories/UIImage+KJCut.h>
#import <KJCategories/UIImage+KJExtension.h>
#import <KJCategories/UIImage+KJResize.h>
#import <KJCategories/UIImage+KJURLSize.h>
#import <KJCategories/UILabel+KJExtension.h>
#import <KJCategories/UITextField+KJExtension.h>
#import <KJCategories/UITextField+KJCustomView.h>
#import <KJCategories/UITextView+KJPlaceHolder.h>
#import <KJCategories/UIView+KJXib.h>
#import <KJCategories/UIView+KJFrame.h>
#import <KJCategories/UIView+KJGestureBlock.h>
#import <KJCategories/UIViewController+KJExtension.h>
#elif __has_include("UIButton+KJBlock.h")
#import "UIButton+KJBlock.h"
#import "UIButton+KJContentLayout.h"
#import "UIColor+KJExtension.h"
#import "UIColor+KJGradient.h"
#import "UIDevice+KJExtension.h"
#import "UIImage+KJCapture.h"
#import "UIImage+KJCut.h"
#import "UIImage+KJExtension.h"
#import "UIImage+KJResize.h"
#import "UIImage+KJURLSize.h"
#import "UILabel+KJExtension.h"
#import "UITextField+KJExtension.h"
#import "UITextField+KJCustomView.h"
#import "UITextView+KJPlaceHolder.h"
#import "UIView+KJXib.h"
#import "UIView+KJFrame.h"
#import "UIView+KJGestureBlock.h"
#import "UIViewController+KJExtension.h"
#else
#endif

#if __has_include(<KJCategories/NSArray+KJExtension.h>)
#import <KJCategories/NSArray+KJExtension.h>
#import <KJCategories/NSDate+KJFormat.h>
#import <KJCategories/NSDictionary+KJExtension.h>
#import <KJCategories/NSObject+KJExtension.h>
#import <KJCategories/NSObject+KJGCDBox.h>
#import <KJCategories/NSObject+KJRunLoop.h>
#import <KJCategories/NSObject+KJRuntime.h>
#import <KJCategories/NSString+KJHash.h>
#import <KJCategories/NSString+KJMath.h>
#elif __has_include("NSArray+KJExtension.h")
#import "NSArray+KJExtension.h"
#import "NSDate+KJFormat.h"
#import "NSDictionary+KJExtension.h"
#import "NSObject+KJExtension.h"
#import "NSObject+KJGCDBox.h"
#import "NSObject+KJRunLoop.h"
#import "NSObject+KJRuntime.h"
#import "NSString+KJHash.h"
#import "NSString+KJMath.h"
#else
#endif

#endif /* KJCoreHeader_h */
