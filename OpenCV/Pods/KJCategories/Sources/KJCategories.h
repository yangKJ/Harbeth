// KJCategories.h
//
// Copyright (c) 2021 Zz <ykj310@126.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

// Like Doraemon’s pocket, has endless and unexpected props for us to use

// This library is independently disassembled from the previous `KJEmitterView` for use,
// And will be added later if relevant..
// You think it’s helpful, please give me a star ⭐..
// Portal: https://github.com/YangKJ/KJCategories
// Note: Open the browser command quickly, command + left mouse button

#import <Foundation/Foundation.h>

#import "KJCategories.h"

//! Project version number for KJCategories.
FOUNDATION_EXPORT double KJCategoriesVersionNumber;

//! Project version string for KJCategories.
FOUNDATION_EXPORT const unsigned char KJCategoriesVersionString[];

// In this header, you should import all the public headers of your framework
// using statements like #import <KJCategories/KJCategories.h>
// or @import KJCategories;

//**!  pod 'KJCategories'
#if __has_include(<KJCategories/KJCoreHeader.h>)
#import <KJCategories/KJCoreHeader.h>
#elif __has_include("KJCoreHeader.h")
#import "KJCoreHeader.h"
#else
#endif

//**!  pod 'KJCategories/C7'
#if __has_include(<KJCategories/KJUIKitHeader.h>)
#import <KJCategories/KJUIKitHeader.h>
#elif __has_include("KJUIKitHeader.h")
#import "KJUIKitHeader.h"
#else
#endif

//**!  pod 'KJCategories/Foundation'
#if __has_include(<KJCategories/KJFoundationHeader.h>)
#import <KJCategories/KJFoundationHeader.h>
#elif __has_include("KJFoundationHeader.h")
#import "KJFoundationHeader.h"
#else
#endif
