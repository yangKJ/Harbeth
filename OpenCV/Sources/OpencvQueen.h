// OpencvQueen.h
//
// Copyright (c) 2021 Condy <ykj310@126.com>
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

//! Project version number for OpencvQueen.
FOUNDATION_EXPORT double OpencvQueenVersionNumber;

//! Project version string for OpencvQueen.
FOUNDATION_EXPORT const unsigned char OpencvQueenVersionString[];

// In this header, you should import all the public headers of your framework
// using statements like #import <OpencvQueen/OpencvQueen.h>
// or @import OpencvQueen;

#if __has_include(<OpencvQueen/UIImage+Queen.h>)
#import <OpencvQueen/UIImage+Queen.h>
#elif __has_include("UIImage+Queen.h")
#import "UIImage+Queen.h"
#else
#endif
