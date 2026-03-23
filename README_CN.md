# Harbeth

![Harbeth](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/3eaa018dedb9433bb51f408f5bb73faf~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=600&h=234&s=31350&e=jpg&b=f5f4f4)

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-brightgreen.svg?style=flat&colorA=28a745&&colorB=4E4E4E)](https://github.com/yangKJ/Harbeth)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/Harbeth.svg?style=flat&label=Harbeth&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/Harbeth)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/OpencvQueen.svg?style=flat&label=OpenCV&colorA=28a745&&colorB=4E4E4E)](https://cocoapods.org/pods/OpencvQueen)
![Platform](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20watchOS-4E4E4E.svg?colorA=28a745)

## 📖 项目简介

**Harbeth** 是一款基于 GPU 加速的高性能图像处理框架，专为 iOS 和 macOS 平台设计，通过 Metal 着色器技术实现实时图像和视频滤镜效果。

## 🚀 核心特性

Harbeth 提供了一系列强大的特性，旨在使图像和视频处理变得快速、高效且易于实现：

- **跨平台支持**：在 iOS、macOS、tvOS 和 watchOS 上无缝运行，支持 UIKit/AppKit 和 SwiftUI 框架。
- **多数据源支持**：应用滤镜到多种图像和视频源，包括 MTLTexture、UIImage、NSImage、CIImage、CGImage、CMSampleBuffer 和 CVPixelBuffer。
- **丰富的滤镜生态系统**：超过 200+ 内置滤镜，组织成直观的类别，涵盖从基本颜色调整到高级艺术效果的各种功能。
- **高级集成**：利用 Metal Performance Shaders (MPS) 实现高性能过滤，同时保持与 CoreImage 滤镜的兼容性，以获得最大的灵活性。
- **Metal 驱动渲染**：所有预览和渲染操作都由 Metal 加速，确保即使使用复杂的滤镜链也能实现流畅的实时性能。
- **自定义滤镜支持**：使用查找表 LUT、Cube 文件或自定义 Metal 着色器轻松创建和集成自定义滤镜。通过继承 `C7CombinationBase` 创建高级组合滤镜，实现复杂的多步骤效果。
- **实时处理**：实现流畅的实时相机捕获和视频播放，带有实时滤镜应用。
- **视频处理**：使用集成的 [Kakapos](https://github.com/yangKJ/Kakapos) 库无缝处理本地和网络视频文件。
- **直观的 API**：享受干净、Swift 友好的 API，具有可链接的滤镜操作和运算符重载，以实现简洁、富有表现力的代码。
- **SwiftUI 集成**：原生支持 SwiftUI 框架。
- **性能优化**：受益于自动纹理池、内存管理和多编码器支持，以在各种设备上获得最佳性能。
- **广泛的文档**：全面的文档和演示项目，帮助您快速入门并充分利用 Harbeth 的功能。

### 🎨 丰富的滤镜效果

Harbeth 提供了全面的滤镜类别，满足各种图像处理需求：

#### 🎨 颜色调整
- **C7Brightness**（亮度）- 调整图像亮度
- **C7ColorConvert**（颜色转换）- 在不同颜色空间之间转换颜色，如RGB到YUV等
- **C7ColorRGBA**（RGBA调整）- 单独调整红、绿、蓝和透明度通道
- **C7ColorSpace**（色彩空间）- 转换图像色彩空间
- **C7Contrast**（对比度）- 增强或降低图像对比度
- **C7Curves**（曲线调整）- 允许精确调整图像的色调曲线，提供对不同色调范围的亮度和对比度的详细控制
- **C7Exposure**（曝光）- 模拟相机曝光效果
- **C7FalseColor**（伪色）- 创建特殊色彩效果
- **C7Gamma**（伽马校正）- 调整图像灰度曲线
- **C7Grayed**（灰度化）- 将图像转换为灰度，移除所有颜色信息同时保留亮度
- **C7Haze**（雾霾）- 应用雾霾效果，降低对比度并添加朦胧或雾气外观
- **C7HSL**（色相饱和度亮度）- 独立调整图像的色相、饱和度和亮度，提供全面的色彩控制
- **C7Hue**（色调）- 改变图像整体色调
- **C7LuminanceAdaptiveContrast**（亮度自适应对比度）- 根据局部像素亮度动态调整对比度，增强暗部和亮部细节
- **C7Monochrome**（单色）- 转换为单色调效果
- **C7Nostalgic**（怀旧色调）- 创建复古照片效果
- **C7Opacity**（不透明度）- 调整图像透明度，使其或多或少透明
- **C7Posterize**（色调分离）- 减少色彩数量，创建艺术效果
- **C7Saturation**（饱和度）- 调整色彩鲜艳程度
- **C7Sepia**（棕褐色调）- 创建老照片效果
- **C7Vibrance**（自然饱和度）- 智能增强色彩饱和度
- **C7Temperature**（色温调整）- 调整图像的色温、色调和色彩偏移
- **C7Warmth**（色温）- 调整图像的色温，从冷色调到暖色调
- **C7WhiteBalance**（白平衡）- 校正图像色温
- **C7ColorCorrection**（色彩校正）- 综合色彩校正滤镜，包含色阶、曲线、色彩平衡三个参数调节
- **C7AppleLogDecode**（Apple Log解码）- 将Apple Log编码的图像转换为线性空间，用于处理HDR内容

#### 🌫️ 模糊效果
- **C7BilateralBlur**（双边模糊）- 保持边缘清晰的同时模糊图像
- **C7CircleBlur**（圆形模糊）- 从中心向外模糊
- **C7DetailPreservingBlur**（细节保留模糊）- 模糊的同时保留细节
- **C7GaussianBlur**（高斯模糊）- 经典平滑模糊效果
- **C7MeanBlur**（均值模糊）- 简单平均模糊
- **C7MotionBlur**（运动模糊）- 模拟物体运动轨迹
- **C7RedMonochromeBlur**（红色单色模糊）- 仅模糊红色通道
- **C7TiltShift**（移轴模糊）- 创建选择性聚焦区域，模拟移轴镜头的浅景深效果
- **C7ZoomBlur**（缩放模糊）- 模拟相机缩放效果

#### 🔍 边缘与细节
- **C7Canny**（边缘检测）- 检测图像边缘
- **C7Clarity**（清晰度）- 通过增加中间调对比度来增强图像清晰度，使细节更加突出
- **C7ComicStrip**（漫画效果）- 创建漫画风格图像
- **C7Crosshatch**（交叉线）- 添加交叉线条效果
- **C7DetailEnhancer**（细节增强）- 增强图像细节而不放大噪声，使图像更清晰
- **C7EdgeAwareSharpen**（边缘感知锐化）- 仅锐化图像的边缘区域，同时保留平滑区域，避免放大噪声
- **C7Granularity**（颗粒感）- 添加胶片颗粒效果
- **C7Sharpen**（锐化）- 增强图像细节
- **C7SharpenDetail**（锐化细节）- 综合锐化滤镜，结合锐化、清晰度和细节增强，实现专业图像锐化
- **C7Sketch**（素描）- 将图像转换为素描效果
- **C7Sobel**（索贝尔边缘检测）- 高级边缘检测算法
- **C7ThresholdSketch**（阈值素描）- 基于阈值的素描效果

#### 🌀 扭曲与变形
- **C7Bulge**（凸起）- 创建中心凸起效果
- **C7ColorCGASpace**（CGA色彩空间）- 应用CGA（Color Graphics Adapter）色彩空间效果，将颜色限制为16色的复古计算机外观
- **C7ColorPacking**（颜色打包）- 特殊色彩处理效果
- **C7Fluctuate**（波动）- 创建波动效果，以波浪状图案扭曲图像，类似于热雾或水扭曲
- **C7GlassSphere**（玻璃球）- 模拟通过玻璃球观察的效果
- **C7Halftone**（半色调）- 模拟印刷半色调效果
- **C7Morphology**（形态学）- 应用形态学操作，如腐蚀和膨胀，对边缘检测和噪声减少很有用
- **C7Pinch**（收缩）- 收缩图像中心
- **C7Pixellated**（像素化）- 创建低分辨率像素效果
- **C7PolarPixellate**（极坐标像素化）- 从中心向外像素化
- **C7PolkaDot**（圆点花纹）- 添加圆点图案效果
- **C7SphereRefraction**（球面折射）- 模拟光线折射效果
- **C7Swirl**（漩涡）- 创建漩涡扭曲效果
- **C7WaterRipple**（水波纹）- 模拟水面波纹效果

#### 🎭 风格化效果
- **C7OilPainting**（油画）- 模拟油画笔触效果
- **C7Toon**（卡通）- 创建卡通风格图像
- **C7Kuwahara**（桑原滤波）- 艺术风格模糊效果
- **C7Glitch**（故障效果）- 模拟数字故障艺术效果
- **C7ShiftGlitch**（移位故障）- 水平移位故障效果
- **C7Fluctuate**（波动）- 创建图像波动效果
- **C7SoulOut**（灵魂出窍）- 双重曝光效果
- **C7SplitScreen**（分屏）- 将图像分为多个部分
- **C7Storyboard**（故事板）- 模拟电影故事板效果
- **C7VoronoiOverlay**（维诺图叠加）- 添加几何图案叠加
- **C7ColorCGASpace**（CGA色彩空间）- 模拟早期计算机色彩效果

##### 📷 相机风格滤镜
- **C7FujiNC**（富士NC滤镜）- 模拟富士胶片NC风格，色彩自然，适合人像和日常拍摄
- **C7FujiNN**（富士NN滤镜）- 模拟富士胶片NN风格，高对比度黑白效果，适合纪实和艺术摄影
- **C7FujiFlash**（闪光富士滤镜）- 模拟富士胶片闪光模式，明亮通透，适合晴天和户外场景
- **C7FujiX100V**（富士X100V滤镜）- 模拟富士X100V相机风格，经典复古色调，适合街拍和人文摄影
- **C7FujiCC**（富士CC滤镜）- 模拟富士Classic Chrome风格，低饱和度高质感，适合风景和建筑摄影
- **C7RicohPositive**（理光正片滤镜）- 模拟理光正片风格，色彩鲜艳，层次丰富
- **C7RicohNegative**（理光负片滤镜）- 模拟理光负片风格，对比度高，暗部细节丰富
- **C7Universal400**（全能400滤镜）- 模拟通用400胶片风格，适应性强，适合各种场景
- **C7CPM35**（CPM35滤镜）- 模拟CPM35胶片风格，温暖复古，适合人像和街拍
- **C7Polaroid**（拍立得滤镜）- 模拟拍立得相机风格，带有边框效果，复古可爱

##### 🌅 场景风格滤镜
- **C7DarkToneEnhance**（暗调增彩滤镜）- 增强暗部色彩，提升画面层次感，适合低光环境拍摄
- **C7Sunset**（日暮滤镜）- 模拟日落时分的暖色调效果，适合黄昏和日出场景
- **C7GrayRemoval**（去灰增白滤镜）- 去除画面灰雾感，提亮增白，适合阴天和雾霾天气拍摄

##### 🎨 艺术风格滤镜
- **C7PastelDream**（粉彩梦幻）- 创建柔和的粉彩梦幻效果，带有温柔的色彩、微妙的模糊和温暖的光晕，非常适合创造空灵、梦幻的图像
- **C7NeonPunk**（霓虹朋克）- 应用霓虹朋克效果，带有鲜艳的色彩、发光的边缘和高对比度，捕捉朋克文化的活力和叛逆美学
- **C7PaperCut**（剪纸艺术）- 创建剪纸艺术效果，带有锐利的边缘、分层的外观和微妙的阴影，模拟复杂的剪纸设计

##### 🚀 科幻与未来主义滤镜
- **C7Hologram**（全息图）- 创建全息效果，带有青色色调、扫描线和微妙的故障元素，模拟未来派全息显示
- **C7DigitalGlitch**（数字故障）- 应用数字故障效果，带有随机的行偏移、RGB通道分离和噪声，创建数字数据损坏的外观
- **C7QuantumDistortion**（量子扭曲）- 创建量子扭曲效果，带有波浪状像素偏移、色差和光晕，模拟时空扭曲

##### 🌿 自然与有机滤镜
- **C7Watercolor**（水彩画）- 应用水彩画效果，带有柔和的边缘、颜色渗透和纸张纹理，捕捉水彩艺术的流畅和透明特质
- **C7OrganicGrowth**（有机生长）- 创建有机生长效果，带有基于噪声的图案、自然色彩变化和边缘增强，模拟有机形式和纹理的外观
- **C7LensFlare**（镜头光晕）- 应用镜头光晕效果，带有光斑、六边形伪影和颜色分散，模拟相机镜头创建的光学光晕

##### 📼 复古与怀旧滤镜
- **C7VintageFilmGrain**（复古胶片颗粒）- 应用复古胶片颗粒效果，带有温暖的色调、微妙的颗粒噪声、去饱和度和暗角，模拟旧胶片的外观
- **C7ComicBook**（漫画书）- 创建漫画书风格效果，带有大胆的黑色轮廓、颜色量化和高对比度，类似于手绘漫画艺术
- **C780sSynthwave**（80年代合成波）- 应用80年代合成波效果，带有霓虹色彩、紫蓝色调、高对比度和微妙的光晕，捕捉1980年代合成波文化的怀旧美学

#### 📊 矩阵处理
- **C7ColorMatrix4x4**（4x4颜色矩阵）- 通过矩阵变换调整颜色
- **C7ColorMatrix4x5**（4x5颜色矩阵）- 更复杂的颜色变换
- **C7ColorVector4**（4维颜色向量）- 基于向量的颜色调整
- **C7ConvolutionMatrix3x3**（3x3卷积矩阵）- 应用卷积滤镜效果
- **C7EdgeGlow**（边缘发光）- 增强并照亮图像边缘
- **C7RGBADilation**（RGBA扩张）- 扩展颜色通道范围

#### 🔗 混合模式
- **C7Blend**（混合模式基类）- 所有混合模式的基类，为混合操作提供通用功能
- **C7BlendChromaKey**（色度键控）- 实现色度键（绿幕）功能，允许用另一个图像或透明度替换特定颜色
- **C7BlendColorAdd**（颜色添加）- 将混合层的颜色值添加到基础层，产生更亮的图像
- **C7BlendColorAlpha**（颜色透明度）- 基于透明度值混合图层，创建半透明效果
- **C7BlendColorBurn**（颜色加深）- 通过增加对比度使基础层变暗，创建丰富的深色混合效果
- **C7BlendColorDodge**（颜色减淡）- 通过降低对比度使基础层变亮，创建提亮效果
- **C7BlendDarken**（变暗）- 保留两个图层中较暗的像素值，产生整体较暗的图像
- **C7BlendDifference**（差值）- 从较亮的颜色中减去较暗的颜色，创建高对比度效果
- **C7BlendDissolve**（溶解）- 随机用混合层的像素替换基础层的像素，创建溶解效果
- **C7BlendDivide**（分割）- 用基础层颜色除以混合层颜色，产生更亮的图像
- **C7BlendExclusion**（排除）- 类似于差值模式但对比度更低，创建更柔和的效果
- **C7BlendHardLight**（强光）- 结合正片叠底和滤色模式，创建强烈的光照效果
- **C7BlendHue**（色相）- 使用混合层的色相和基础层的饱和度和亮度
- **C7BlendLighten**（变亮）- 保留两个图层中较亮的像素值，产生整体较亮的图像
- **C7BlendLinearBurn**（线性加深）- 通过混合层值线性变暗基础层
- **C7BlendLuminosity**（亮度）- 使用混合层的亮度和基础层的色相和饱和度
- **C7BlendMask**（蒙版混合）- 使用蒙版控制混合层的可见区域
- **C7BlendMultiply**（正片叠底）- 模拟颜料混合效果
- **C7BlendNormal**（正常）- 标准混合模式
- **C7BlendOverlay**（叠加）- 结合正片叠底和滤色效果
- **C7BlendScreen**（滤色）- 提亮图像并混合颜色
- **C7BlendSoftLight**（柔光）- 柔和的混合效果
- **C7BlendSourceOver**（源覆盖）- 默认混合模式，混合层绘制在基础层之上
- **C7BlendSubtract**（减去）- 从基础层颜色中减去混合层颜色，产生更暗的图像
- **C7BlendWithMask**（带蒙版混合）- 使用单独的蒙版纹理控制两个图层的混合
- **C7ColorBurnEnhancedBlend**（增强版颜色加深混合模式）- 增强版颜色加深混合模式
- **C7XORBlendWithMask**（XOR蒙版混合）- 使用蒙版进行XOR混合

#### 🎛️ 实用工具
- **C7ChromaKey**（色度键控）- 绿幕抠图效果
- **C7DepthLuminance**（深度亮度）- 基于深度信息调整亮度
- **C7HighlightShadow**（高光阴影）- 单独调整高光和阴影
- **C7HighlightShadowTint**（高光阴影色调）- 为高光和阴影添加色调
- **C7HighlightShadowTone**（高光阴影色调调整）- 综合调整阴影、高光、中间调和对比度
- **C7Highlights**（高光）- 专门调整图像的高光区域，根据需要增亮或变暗它们
- **C7HighPassSkinSmoothing**（高通皮肤平滑）- 使用频率分离执行皮肤平滑，在平滑皮肤纹理的同时保留细节
- **C7Levels**（色阶）- 调整图像明暗范围
- **C7Luminance**（亮度）- 提取或调整图像亮度
- **C7LuminanceRangeReduction**（亮度范围压缩）- 压缩亮度动态范围
- **C7LuminanceThreshold**（亮度阈值）- 基于亮度创建黑白图像
- **C7Opacity**（不透明度）- 调整图像透明度
- **C7Shadows**（阴影）- 专门调整图像的阴影区域，根据需要增亮或变暗它们

#### 📐 几何变形
- **C7Crop**（裁剪）- 裁剪图像特定区域
- **C7Resize**（调整大小）- 改变图像尺寸
- **C7Rotate**（旋转）- 旋转图像
- **C7Flip**（翻转）- 水平或垂直翻转图像
- **C7Mirror**（镜像）- 创建镜像效果
- **C7Transform**（变换）- 应用仿射变换

#### 🎨 生成器
- **C7SolidColor**（纯色）- 创建纯色图像
- **C7ColorGradient**（颜色渐变）- 创建渐变色背景

#### 📋 查找表
- **C7ColorCube**（颜色立方体）- 使用CUBE文件创建3D LUT滤镜，通过Metal实现高性能色彩转换，支持专业级色彩调整
- **C7LookupTable**（查找表）- 使用LUT文件创建自定义滤镜，通过预设的颜色映射实现快速色彩风格转换
- **C7LookupTable512x512**（查找表）- 512x512 颜色查找表滤镜，用于高质量的颜色调整

#### 🔗 组合滤镜
- **C7CombinationBeautiful**（美颜组合）- 综合美颜效果，包含磨皮、美白、提亮等多种美颜处理，打造自然清透的肌肤效果
- **C7CombinationCinematic**（电影风格组合）- 电影风格效果，模拟电影级色彩分级，增强画面对比度和层次感，营造专业电影氛围
- **C7CombinationColorGrading**（色彩分级组合）- 专业色彩分级效果，包含色温、色调和色调调整，实现电影级色彩控制
- **C7CombinationCreativeAtmosphere**（创意氛围组合）- 创意氛围效果，添加暖光、冷蓝、黄金时段和忧郁等氛围效果
- **C7CombinationCyberpunk**（赛博朋克组合）- 赛博朋克风格效果，带有霓虹光晕、色彩偏移和边缘检测，营造未来科技感
- **C7CombinationDreamy**（梦幻组合）- 梦幻柔和效果，通过高斯模糊、暖色调和降低饱和度，创造出梦幻般的视觉效果
- **C7CombinationFilmSimulation**（胶片模拟组合）- 现代胶片模拟效果，模拟不同类型胶片的色彩和颗粒特性
- **C7CombinationHDRBoost**（HDR增强组合）- HDR增强效果，提升动态范围，增强高光和阴影细节
- **C7CombinationModernHDR**（现代HDR组合）- 现代HDR效果，提升画面动态范围，增强暗部细节和高光层次，呈现更具冲击力的视觉效果
- **C7CombinationVintage**（复古风格组合）- 复古风格效果，模拟胶片质感，添加怀旧色调和颗粒感，重现经典老照片的韵味
- **C7CombinationVintageFilm**（复古胶片组合）- 复古胶片效果，模拟老胶片质感，添加颗粒、暗角和棕褐色调，重现经典胶片摄影的魅力

#### 🎚️ 其他效果
- **C7Fade**（淡入淡出）- 应用淡入淡出效果，使图像逐渐过渡到白色
- **C7Grayed**（灰度化）- 转换为黑白图像
- **C7Haze**（雾霾）- 创建雾霾效果
- **C7Pow**（幂次调整）- 应用幂函数变换
- **C7Vignette**（暗角）- 添加照片暗角效果
- **C7VignetteBlend**（暗角混合）- 应用带有多种混合模式的暗角效果，允许不同风格的边缘变暗

#### 🖼️ Blit 操作
- **C7CopyRegionBlit**（区域复制）- 从一个纹理复制特定区域到另一个纹理
- **C7CropBlit**（裁剪）- 将图像裁剪到指定区域
- **C7GenerateMipmapsBlit**（生成Mipmaps）- 为纹理生成mipmaps，用于高效下采样

#### 🎯 CoreImage 集成
- **CIBrightness**（CoreImage亮度）- CoreImage亮度调整
- **CIColorControls**（CoreImage颜色控制）- CoreImage颜色控制（亮度、对比度、饱和度）
- **CIColorCube**（CoreImage颜色立方体）- CoreImage颜色立方体滤镜
- **CIColorMonochrome**（CoreImage单色）- CoreImage单色效果
- **CIContrast**（CoreImage对比度）- CoreImage对比度调整
- **CIExposure**（CoreImage曝光）- CoreImage曝光调整
- **CIFade**（CoreImage淡出）- CoreImage淡出效果
- **CIGaussianBlur**（CoreImage高斯模糊）- CoreImage高斯模糊
- **CIHighlight**（CoreImage高光）- CoreImage高光调整
- **CILookupTable**（CoreImage查找表）- CoreImage查找表滤镜
- **CINoiseReduction**（CoreImage降噪）- CoreImage降噪
- **CIPhotoEffect**（CoreImage照片效果）- CoreImage照片效果（chrome, fade, instant, mono, noir, process, tonal, transfer）
- **CIResizedSmooth**（CoreImage平滑调整大小）- CoreImage平滑调整大小
- **CISaturation**（CoreImage饱和度）- CoreImage饱和度调整
- **CIShadows**（CoreImage阴影）- CoreImage阴影调整
- **CISharpen**（CoreImage锐化）- CoreImage锐化
- **CISketch**（CoreImage素描）- CoreImage素描效果
- **CITemperature**（CoreImage色温）- CoreImage色温调整
- **CIUnsharpMask**（CoreImage非锐化遮罩）- CoreImage非锐化遮罩锐化
- **CIVignette**（CoreImage暗角）- CoreImage暗角效果
- **CIWhitePoint**（CoreImage白点）- CoreImage白点调整

#### ⚡ Metal Performance Shaders
- **MPSBoxBlur**（MPS盒式模糊）- Metal Performance Shaders盒式模糊
- **MPSGaussianBlur**（MPS高斯模糊）- Metal Performance Shaders高斯模糊
- **MPSHistogram**（MPS直方图）- Metal Performance Shaders直方图计算
- **MPSMedian**（MPS中值模糊）- Metal Performance Shaders中值模糊
- **MPSCanny**（MPS边缘检测）- Metal Performance Shaders Canny边缘检测

### 🔍 滤镜查找指南

根据您的需求，选择合适的滤镜类别：

1. **颜色调整** - 改变图像的色彩属性
2. **模糊效果** - 创建各种模糊和柔化效果
3. **边缘与细节** - 增强或检测图像细节
4. **扭曲与变形** - 创建特殊几何效果
5. **风格化效果** - 应用艺术风格处理
6. **矩阵处理** - 使用数学矩阵变换图像
7. **混合模式** - 混合多个图像或效果
8. **实用工具** - 各种图像处理工具
9. **几何变形** - 改变图像几何属性
10. **生成器** - 创建新的图像效果
11. **查找表** - 使用预设的颜色映射
12. **组合滤镜** - 综合多种效果

### 📱 相机与视频支持

Harbeth 提供了内置的相机采集和视频处理功能：

- **实时相机滤镜**：为相机预览添加实时滤镜效果
- **视频播放滤镜**：为本地或网络视频添加滤镜效果
- **视频导出**：支持带滤镜效果的视频导出

### 🎨 自定义滤镜支持

Harbeth 支持多种自定义滤镜方式：

- **查找表 (LUT)**：使用 .png 格式的 LUT 文件创建自定义滤镜
- **立方体贴图 (Cube)**：使用 .cube 格式的文件创建专业滤镜
- **自定义 Metal 着色器**：通过编写 Metal 着色器创建完全自定义的滤镜效果

## 📖 使用指南

### 🔧 安装方式

#### CocoaPods

在 Podfile 中添加：

```ruby
pod 'Harbeth'
```

#### Swift Package Manager

在 Package.swift 文件中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/yangKJ/Harbeth.git", branch: "master"),
]
```

或者在 Xcode 中通过 "File > Swift Packages > Add Package Dependency" 添加。

### 🚀 快速开始

Harbeth 提供了多种使用方式，适应不同的场景需求：

#### 1. 基本使用

```swift
// 创建滤镜
let brightness = C7Brightness(brightness: 0.2)  // 增加亮度
let contrast = C7Contrast(contrast: 1.5)        // 增加对比度
let saturation = C7Saturation(saturation: 1.2)  // 增加饱和度

// 应用滤镜到图像
let filteredImage = try? originalImage ->> brightness ->> contrast ->> saturation
imageView.image = filteredImage
```

#### 2. 链式操作

```swift
// 使用运算符链式操作
let filters: [C7FilterProtocol] = [
    C7Brightness(brightness: 0.2),
    C7Contrast(contrast: 1.5),
    C7Saturation(saturation: 1.2)
]

imageView.image = originalImage -->>> filters
```

#### 3. 函数式编程

```swift
// 函数式编程风格
var resultImage = originalImage
filters.forEach { resultImage = try! resultImage ->> $0 }
imageView.image = resultImage
```

#### 4. 不定参数

```swift
// 不定参数方式
imageView.image = originalImage.filtering(
    C7Brightness(brightness: 0.2),
    C7Contrast(contrast: 1.5),
    C7Saturation(saturation: 1.2)
)
```

#### 5. HarbethIO 方式

```swift
// 使用 HarbethIO 方式
let io = HarbethIO(element: originalImage, filters: filters)

// 同步处理
imageView.image = try? io.output()

// 异步处理
io.transmitOutput { [weak self] image in
    DispatchQueue.main.async {
        self?.imageView.image = image
    }
}
```

### 📱 相机采集示例

```swift
// 创建相机采集器
let camera = C7CollectorCamera(delegate: self)
camera.captureSession.sessionPreset = .hd1280x720

// 添加滤镜
let edgeDetection = C7EdgeGlow(lineColor: .red)
let grain = C7Granularity(grain: 0.8)
camera.filters = [edgeDetection, grain]

// 实现代理方法
extension ViewController: C7CollectorImageDelegate {
    func preview(_ collector: C7Collector, fliter image: C7Image) {
        // 显示处理后的图像
        DispatchQueue.main.async {
            self.imageView.image = image
        }
    }
}
```

### 🎬 视频处理示例

```swift
// 创建视频处理器
let videoURL = URL(string: "https://example.com/video.mp4")!
let asset = AVURLAsset(url: videoURL)
let playerItem = AVPlayerItem(asset: asset)
let player = AVPlayer(playerItem: playerItem)

let videoProcessor = C7CollectorVideo(player: player, delegate: self)

// 添加滤镜
let vintageFilter = C7ColorMatrix4x4(matrix: Matrix4x4.Color.sepia)
videoProcessor.filters = [vintageFilter]

// 播放视频
videoProcessor.play()

// 实现代理方法
extension ViewController: C7CollectorImageDelegate {
    func preview(_ collector: C7Collector, fliter image: C7Image) {
        // 显示处理后的视频帧
        DispatchQueue.main.async {
            self.imageView.image = image
        }
    }
}
```

### 🎨 SwiftUI 集成

Harbeth 原生支持 SwiftUI 框架：

```swift
import SwiftUI
import Harbeth

struct FilterView: View {
    @State private var inputImage: UIImage = UIImage(named: "sample")!
    @State private var intensity: Float = 0.5
    
    var body: some View {
        let filters: [C7FilterProtocol] = [
            CIHighlight(highlight: intensity),
            C7WaterRipple(ripple: intensity),
        ]
        
        VStack {
            HarbethView(image: inputImage, filters: filters) {
                $0.resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 400)
            }
            
            Slider(value: $intensity, in: 0...1)
                .padding()
        }
        .padding()
    }
}
```

### 📊 性能优化

Harbeth 内置了多种性能优化机制：

- **纹理池**：重用 Metal 纹理，减少内存分配
- **批处理**：合并多个滤镜操作，减少 GPU 往返
- **异步处理**：支持后台线程处理，避免阻塞主线程
- **内存监控**：自动管理内存使用，避免内存溢出

### 🛠️ 性能监控

Harbeth 提供了性能监控工具，帮助开发者优化应用：

```swift
// 启用性能监控
let io = HarbethIO(element: image, filters: filters)
io.enablePerformanceMonitor = true

// 应用滤镜
let result = try? io.output()

// 查看性能统计
print(PerformanceMonitor.shared.getStatistics())
```

## 📖 API 参考

### 核心类

#### HarbethIO

`HarbethIO` 是 Harbeth 的核心处理类，负责管理滤镜应用过程。以下是其详细属性说明：

| 属性 | 类型 | 默认值 | 描述 |
| :--- | :--- | :--- | :--- |
| `element` | `Dest` | - | 要应用滤镜的输入元素。支持 UIImage/NSImage、CGImage、CIImage、MTLTexture、CMSampleBuffer 和 CVPixelBuffer。 |
| `filters` | `[C7FilterProtocol]` | - | 要应用到输入元素的滤镜数组。 |
| `bufferPixelFormat` | `MTLPixelFormat` | `.bgra8Unorm` | 输出缓冲区的像素格式。对于相机捕获尤为重要，通常使用 `kCVPixelFormatType_32BGRA` 以避免蓝色 tint 问题。 |
| `mirrored` | `Bool` | `false` | 是否镜像输出图像。修复从纹理创建 CIImage 时的上下颠倒镜像问题。 |
| `createDestTexture` | `Bool` | `true` | 是否创建单独的输出纹理。禁用此选项可能会导致纹理覆盖问题。 |
| `scaleFactor` | `Float` | `1.0` | 中间纹理的缩放因子（0.0-1.0）。减小此值可以提高性能，但会降低质量。 |
| `transmitOutputRealTimeCommit` | `Bool` | `false` | 是否对 Metal 纹理输出使用实时提交。启用 `MTLCommandBuffer.asyncCommit` 以获得更快的处理速度。 |
| `enableDoubleBuffer` | `Bool` | `true` | 是否为金属滤镜启用双缓冲优化。减少内存使用并提高纹理池效率。 |

**使用示例：**

```swift
// 基本用法
let dest = HarbethIO(element: image, filters: [filter1, filter2])

// 自定义配置
var dest = HarbethIO(element: image, filters: [filter1, filter2])
dest.bufferPixelFormat = .rgba8Unorm
dest.scaleFactor = 0.8
dest.enableDoubleBuffer = true

// 带有自定义配置的异步处理
var dest = HarbethIO(element: image, filters: [filter1, filter2])
dest.transmitOutputRealTimeCommit = true
dest.transmitOutput { result in
    switch result {
    case .success(let output):
        // 处理成功输出
    case .failure(let error):
        // 处理错误
    }
}
```

**性能优化技巧：**

1. **对于实时处理**（例如相机捕获）：
   - 设置 `transmitOutputRealTimeCommit = true`
   - 考虑降低 `scaleFactor` 以获得更快的处理速度
   - 启用 `enableDoubleBuffer` 以更好地管理内存

2. **对于内存受限设备**：
   - 使用 `Device.setMemoryLimitMB(value)` 设置较低的内存限制
   - 确保 `enableDoubleBuffer = true`
   - 使用异步处理以避免内存峰值

3. **对于高质量输出**：
   - 保持 `scaleFactor = 1.0`
   - 设置 `createDestTexture = true` 以避免纹理覆盖
   - 根据输出需求使用适当的 `bufferPixelFormat`

4. **对于性能监控**：
   - 使用 `Device.setEnablePerformanceMonitor(true)` 启用性能监控
   - 使用 `PerformanceMonitor.shared.getStatistics()` 查看性能统计

```swift
public struct HarbethIO<Dest> {
    public let element: Dest
    public let filters: [C7FilterProtocol]
    public var bufferPixelFormat: MTLPixelFormat = .bgra8Unorm
    public var mirrored: Bool = false
    public var createDestTexture: Bool = true
    public var scaleFactor: Float = 1.0
    public var transmitOutputRealTimeCommit: Bool = false
    public var enableDoubleBuffer: Bool = true
    
    public func output() throws -> Dest
    public func transmitOutput(success: @escaping (Dest) -> Void, failed: ((HarbethError) -> Void)? = nil)
}
```

#### C7FilterProtocol

`C7FilterProtocol` 是所有滤镜的基础协议：

```swift
public protocol C7FilterProtocol {
    var modifier: ModifierEnum { get }
    var factors: [Float] { get }
    var otherInputTextures: C7InputTextures { get }
    var hasCount: Bool { get }
    
    func resize(input size: C7Size) -> C7Size
    func setupSpecialFactors(for encoder: MTLCommandEncoder, index: Int)
    func combinationBegin(for buffer: MTLCommandBuffer, source texture: MTLTexture, dest texture2: MTLTexture) throws -> MTLTexture
    func combinationAfter(for buffer: MTLCommandBuffer, input texture: MTLTexture, source texture2: MTLTexture) throws -> MTLTexture
    func applyAtTexture(form texture: MTLTexture, to destTexture: MTLTexture, for buffer: MTLCommandBuffer) throws -> MTLTexture
}
```

#### C7CombinationBase

通过继承 `C7CombinationBase` 创建自定义组合滤镜，实现复杂的多步骤效果：

```swift
class CustomCombinationFilter: C7CombinationBase {
    public var modifier: ModifierEnum {
        return .compute(kernel: "customCombinationKernel")
    }
    
    public func prepareIntermediateTextures(buffer: MTLCommandBuffer, source: MTLTexture) throws -> [MTLTexture] {
        // 准备中间纹理
        let intermediateTexture = try TextureLoader.makeTexture(width: source.width, height: source.height)
        intermediateTextures.append(intermediateTexture)
        return intermediateTextures
    }
    
    public func combinationAfter(for buffer: MTLCommandBuffer, input texture: MTLTexture, source texture2: MTLTexture) throws -> MTLTexture {
        // 实现多步骤处理逻辑
        // 使用中间纹理进行复杂的滤镜组合
        
        cleanupIntermediateTextures()
        return texture
    }
}
```

## 🤝 贡献指南

我们欢迎社区贡献，包括：

1. **错误修复** - 报告和修复 bug
2. **功能增强** - 添加新功能和滤镜
3. **文档改进** - 完善文档和示例
4. **性能优化** - 提高框架性能

## 📄 许可证

Harbeth 使用 MIT 许可证，详情请参阅 LICENSE 文件。

## 📞 联系我们

如果您有任何问题或建议，欢迎联系我们：

- **GitHub Issues**：[https://github.com/yangKJ/Harbeth/issues](https://github.com/yangKJ/Harbeth/issues)
- **邮箱**：[ykj310@126.com](mailto:ykj310@126.com)

## 🙏 致谢

感谢所有为 Harbeth 做出贡献的开发者和用户！

---

**如果 Harbeth 对您有所帮助，欢迎给项目一个 ⭐️ Star，这是对我们最大的鼓励！**

---

<p align="center">
  <img src="https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/bfb6d859b345472aa3a4bf224dee5969~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=828&h=828&s=112330&e=jpg&b=59be6d" width=20% hspace="10px">
  <img src="https://p1-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/6f4bb3a1b49d427fbe0405edc6b7f7ee~tplv-k3u1fbpfcp-jj-mark:0:0:0:0:q75.image#?w=1200&h=1200&s=185343&e=jpg&b=3977f5" width=20% hspace="10px">
</p>

<p align="center">
  <small>支持开发者，让项目持续改进</small>
</p>
