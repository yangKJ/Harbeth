//
//  Harbeth.h
//
//  Copyright (c) 2022 Condy https://github.com/YangKJ
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

// 该组件基于GPU快速实现图片or视频注入滤镜特效，代码零侵入实现图像显示and视频导出功能，支持iOS系统和macOS系统。

// 支持多种模式数据源，简单直接使用！！！
// 如果觉得好用，希望您能STAR支持，你的 ⭐️ 是我持续更新的动力!
// 传送门：https://github.com/yangKJ/Harbeth/blob/master/README_CN.md <备注：快捷打开浏览器命令，command + 鼠标左键>


// This component is a tiny set of utils and extensions
// over Apple's Metal framework dedicated to make your Swift GPU code much cleaner
// and let you prototype your pipelines faster.

// Support multiple mode data sources, simple and direct use!!!
// And it is easy to use when summarizing it, so let's add it slowly.
// If you find it easy to use, I hope you can support STAR. Your ⭐️ is my motivation for updating!
// Portal: https://github.com/YangKJ/Harbeth <Note: Open the browser command quickly, command + left mouse button>

// 关于加载和缓存网络图像orGIF，你也可以使用另外的库[ImageX](https://github.com/YangKJ/ImageX)

// If you need downloading and caching images or gif from the web.
// You can also use another library [ImageX](https://github.com/YangKJ/ImageX)

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT double HarbethVersionNumber;

FOUNDATION_EXPORT const unsigned char HarbethVersionString[];
