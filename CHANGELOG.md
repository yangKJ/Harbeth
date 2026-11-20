# Changelog

Harbeth 的公开变更按时间倒序记录，格式遵循 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)，版本号遵循 [Semantic Versioning](https://semver.org/)。这里只记录库使用者升级后需要知道的公开能力、行为、兼容性、性能特征和重要修复，不复制内部提交、测试或维护流水。

`Unreleased` 跨越了一次 major-version 重构，因此按实际完成日期拆成可审阅的交付批次；每个批次内部仍按 Added、Changed、Fixed、Removed 分类。正式发版时，这些批次会整体归入对应版本章节。

## [Unreleased]

> Target: Harbeth 3.0.0. This is a breaking upgrade from 2.x; read the [3.0 migration guide](docs/MIGRATION_3_CN.md) before adopting it.

### 2026-11-20

#### Added

- `C7Curves` 的线性与保形插值可选择下端保持、上端线性外推，保留高于白点的扩展值。
- 摄影中性色 HSL 支持可选的 Lab 局部校正窗口，在同一次 Metal 派发中独立改变明度、色度和色相，并在色域边界收敛位移。
- 摄影中性色 HSL 支持高光去色，可按亮度和颜色窗口抬高较低通道，保留扩展值及预乘透明度。较低亮度可单独收紧色度范围。
- 摄影中性色 HSL 可选配柔和边缘的色相与色度窗口，在同一遍处理中调整局部色相、饱和度和明度，并按饱和度渐退保护强彩色。
- 摄影 HSL 增加可选低色度亮暗偏移，在同一逐像素渲染中支持预乘透明度与扩展范围。
- 摄影 HSL 支持柔和色相窗口和色度门限，可保护暖色、低色度和近黑区域。

#### Changed

- `C7Curves` 的保形插值复用控制点派生的 Hermite 切线，减少固定曲线在逐像素处理中的重复计算，并按当前外推策略直接处理单位通道。
- `C7Curves` 对九点保形曲线使用固定次数的区间比较，对适合分桶的三十二点曲线使用精确段索引，继续按原 Hermite 算式求值。

- `C7ColorCube` 按文件版本复用已准备的 3D LUT 纹理，合并并发加载，并利用缓存的字节预算管理驻留。紧凑 LUT 加载只校验一次样本有限性，单位输入域可直接钳制坐标。
- 冻结的计算参数绑定可显式共享同一设备上的只读 Metal buffer，减少多帧或分块重复分配。

- `C7ColorCube` 的单位输入域四面体路径共用一个 Metal 函数特化，减少分支并保留宿主内核的查找优先级。LUT 直接遍历连续样本字节生成既有资源指纹。

- `C7WhiteBalance` 在预乘 RGB 上求值，并可与相邻基础点运算共享一次派发，保留配方顺序和各步纹理格式舍入。

- 内置 CUBE 可在实际 HLUT 摘要和输入域匹配时复用打包时生成的旧指纹。未注册文件和不匹配的条目继续完整校验并计算指纹。

#### Removed

- 移除命名 CUBE 的算子替代注册接口，`C7ColorCube` 统一通过原生 3D LUT 查表。

### 2026-11-19

#### Fixed

- 加权颜色直方图使用完整线程组汇总，修复不支持非均匀派发的 Metal 设备在统计时可能触发的 API 校验崩溃。

### 2026-11-18

#### Added

- Plugin 支持完整 `RenderedFrame` 输出及对应图像来源，保留 alpha、方向、颜色配置与纹理租约；可按需回传带输入 token 的执行报告与插件诊断。

#### Changed

- 未声明的插件能力默认保守处理；即时插件入口在执行前校验低延迟资格，按声明选择读回档位并限制结果缓存。固定配方仍可直接使用 `pluginOutput` 入口，分析得到的配方继续在原输入上重放。
- 滤镜开发合同增加 `kernelConfigurationIdentity` 及按输入尺寸准备参数绑定的方法，默认保持既有绑定；尺寸依赖包装器应转发准备方法。几何尺寸、画布模式与像素合同进入配方身份和一致性比较，修复普通 `ImageNode.applying` 持久缓存返回旧尺寸或旧裁切位置。
- 程序化渐变、形状、路径及笔刷的局部效果可把构造产物交给首次执行，公开访问或修改 mask 后取消该复用；后续执行、范围/派生/自定义及纹理依赖源保持刷新，保留构造期错误交付。

#### Fixed

- 帧输出合同转换按本次像素重新执行，修复同一纹理换帧后复用旧转换结果；同纹理派生帧继续保留租约及完整交付元数据。
- 显式颜色输出在两条入口的同步/异步图像与帧路径实际转换像素，保留 ICC、Alpha 和扩展范围精度；修复只更新色彩标签导致的偏色。平台图像规划采用实际解码像素尺寸，避免 macOS 显示倍率造成计划失配。
- 裸纹理与帧输出共用 ImageNode 执行准备，统一 Alpha 正规化和采样合同；持久缓存仍由调用方显式选择。
- 区域 Lanczos 高倍率轴向缩小采用完整 L3 支持域的 Float32 可分离执行；一般透视及额度回退采用每轴至多 64 点的全支持域分层近似，限制极端映射的采样工作量并保持全局采样相位。非法几何参数在编码前返回错误。
- 插件透传输入纹理时同时保留输入帧租约，避免结果节点仍在引用的表面提前归池；完整帧转为独立裸纹理时复制像素，帧输出路径继续持有租约。
- Metal 与 Swift 保持同目录，由 Xcode 构建规则自动发现 shader；移除 Package 清单执行时的文件枚举，修复 shader 合并或移动后缓存仍引用已删除文件导致的 SwiftPM 构建失败。命令行构建与测试显式使用 Xcode 构建器。
- 外部命令编码在输出首次被引用前保护租约，阶段失败后不再把待提交纹理提前归池，避免新请求表面被旧命令覆盖；成功帧继续由宿主持有，提交权保持在调用方。
- 遮罩图身份贯通 plane 的资源、revision/generation、坐标和采样合同；原始 mask、组合 base/steps 与范围源区分实际纹理，数值身份保留精确值，修复黑白遮罩及相邻范围/笔刷参数错误命中旧效果。
- Crop 与 Affine 使用像素中心和 Float32 工作值，恢复零裁切/恒等仿射，修正透明边缘、非预乘输入及不透明帧标记。Crop 尺寸查询不再改写 origin，依赖输入的绑定在执行准备时解析；保留采样模式、区域仿射 ABI 与合法负尺度，非法几何规划不再因整数转换终止进程。

### 2026-11-17

#### Added

- 滤镜开发参数绑定支持 `vector4(Vector4)`，在参数编码时先验证四维形状再转换 SIMD；Metal 参数类型及字节布局仍为 Float4。

#### Changed

- 缩放与旋转保留 Float32 工作值及扩展范围颜色；同尺寸内置缩放采用恒等复制，保留目标格式转换和同名自定义内核。Lanczos 缩小按倍率扩展 L3 支持域，并在临时表面额度内采用 Float32 可分离执行，额度不足或非内置包装继续直接求值；负瓣颜色不再一律夹回 SDR，最终覆盖保持有效关联。
- 局部影调在已验收的大尺寸完整 RGBA16Float 画布上按线程组累计整数直方图；区域、小图、其他格式或同名累计内核覆盖继续直接执行。负向原生映射跳过不读取的 CLAHE LUT 准备，公共统计对象的完整准备合同保持。
- 高反差平滑零强度和高光阴影影调全零调整，在内置函数未被宿主/外部替换时使用完整恒等路径，省去引导图和高斯中间表面；Alpha 正规化、目标格式转换和自定义执行继续保留。
- 矩阵/向量、曲线及本批颜色校正使用 Float32 工作值，Float16 目标在最终执行最近值舍入；非中性结果可能较旧 Half 中间舍入略有差异，legacy/linear 曲线的求值域和外推策略保持。
- Hue 保留原 YIQ 系数意图，使用 CPU 准备的旋转系数与 GPU Float32 乘加替代逐像素极坐标往返；原弧度参数槽位保留，零角度及整圈直接保持来源。
- 内置转场按归一化像素中心映射不同尺寸的目标与辅助图，同尺寸保持整数读取；非预乘目标/背面颜色正规化，亮度及位移辅助图继续按数值读取。同次执行复用已准备的转场滤镜。

- `C7OrderedDither` 的内置完整画布路径对单元边长至少 4 的请求按单元派发，减少无效线程且不增加临时纹理；区域包装、显式特化及同名外部内核继续规范派发。
- `C7Blend` 的目录模式共用预乘覆盖合成，保留各模式的不透明颜色意图；Alpha 模式保持背景覆盖，Dissolve 保持关联 RGBA 交叉渐变，Mask 按亮度覆盖同时缩放 RGBA。
- 基础亮度、对比度、Gamma、透明度及相关颜色原语统一预乘输入/输出合同；运算采用单精度，Float16 最终最近值舍入，融合路径按每步实际存储格式量化。透明度同时缩放预乘 RGB 与 Alpha。
- 颜色编码复用同次描述中的向量绑定，标量数组在实际编码时只求值一次；每次请求仍读取当前参数，显式绑定优先于内部辅助槽位。
- 轮廓在已验收的大尺寸 RGBA16Float、半径 8…20 下以同次提交的有界平坦标记跳过可证明无边缘的搜索，保留直接路径、原低 Alpha 裁除、饱和剪枝及模糊。标记额度受 4 MiB 与池预算限制，其他格式、显式特化、外部覆盖、预算不足或分配失败继续直接执行。

- 贴纸轮廓通过最近四邻居的饱和下界省去可证明无贡献的完整搜索，大尺寸输出在支持设备上按 SIMD 组统一剪枝，其余搜索与模糊分布保持；零厚度现在关闭效果并保留软透明像素。
- Voronoi 在大尺寸 RGBA16Float 图上同次提交生成有界格点表，单表与在途总额受 4 MiB 和池预算限制；小图、其他格式、过密格点、预算不足及同名自定义内核保持直接计算。格点路径允许半精度末位的数值差异。

- RGBA 单方向膨胀在大图、大半径及已验收格式下采用上下文代次缓存的 AreaMax，保留小图/小核、Float32、显存额度不足和同名自定义内核的直接路径；不透明临时资源使用有界保守准入。
- 多区域 LUT 只采样权重非零的表，保持三表资源布局与源 alpha。

#### Fixed

- 滤镜 factors、标量/向量/矩阵绑定及函数常量的参数身份保留精确浮点位模式，原始 bytes 包含内容，修复不同参数错误命中持久图像缓存；展示用数值格式保持。
- 旋转改用像素中心的笛卡尔逆映射，修复零角透明中心、半像素偏移及正交角包围盒误差；fit 包围盒向外取整。非有限旋转和不可整数化的正尺寸在执行时报告配置错误，尺寸查询不再触发整数转换陷阱，非正值及 NaN 尺寸继续保留原轴。
- Lanczos 边缘权重按原始 tap 位置计算，夹边只影响读取，修复边缘梯度失真和周期纹理缩小的严重相位混叠。
- 纹理几何在线性采样前正规化非预乘输入，背景明确为已关联原始 RGBA；半透明画布不再错误沿用不透明帧标记。几何采样声明全局坐标依赖，停止误报普通单点分块/融合能力。
- 组合管线的中间纹理在阶段及最终编码失败后也回收，已编码纹理保持至命令完成，未提交缓冲区销毁时归还，减少重复分配。
- HSL、单色及高光阴影染色在直色域执行原有着色方程后恢复源覆盖；透明区域不再贡献颜色，中性调整在危险计算前保留 HDR 与 Float32。非中性 HSL 维持 SDR 夹值策略，乘色继续忽略 tint Alpha 并保持来源 Alpha。
- 本批颜色、混合与叠加的早返路径在目标为 Float16 时也显式执行最近值舍入，避免 Float32 来源仅因中性调整或区域外复制而按截断方式写回。
- 场景布光以直色亮度计算高光压缩，修复同一直色因软覆盖改变增益；输入声明预乘且工作值使用 Float32，恒等 Float32 通道不再先溢出到 Half 后被清零。
- 增强颜色加深保留背景覆盖、strength 与原不透明曲线，前景 Alpha 调制有效混合，空前景和零强度保持来源。纹理叠加补齐预乘输入合同，保留原 over 与矩形裁切。
- `C7BlendChromaKey` 明确使用既有单输入抠色 API，移除未提供的第二纹理依赖，保持原默认 key 与参数槽位；软透明同色正确抠除，输出不再沿用不透明标记。
- 高光阴影影调在 halo 整数化前处理非有限半径，相关质量管线与 MPS 高斯的执行参数使用有限值，避免合同查询因 NaN 终止进程。
- 4×4、4×5矩阵及四维向量解码拒绝错误形状；编码前再次检查可变矩阵和延迟向量，避免非法载荷在 SIMD 转换时终止进程。4×4及延迟向量指纹保留实际 Float32 位模式。
- 矩阵反相/负片使用 Alpha 减 RGB 并保持覆盖，透明度 helper 同时缩放 RGBA，绿色轴旋转修正矩阵索引；通用行主序与任意原始 RGBA 方程保持。会改变覆盖的矩阵结果不再沿用已知不透明标记。
- 矩阵/向量零强度在危险计算前旁路，恒等及中性颜色操作不再提前收窄 Float32。曲线保留 legacy/linear 的存储域和外推策略，shapePreserving 明确声明关联输入，修复非预乘 CGImage 的重复解预乘及帧标记错误。
- 深度镜头模糊按邻居有效覆盖归一化颜色并保留中心 Alpha，透明中心不再从邻居引入可见 RGB；原双环、权重和采样半径保持。
- 白黑调整、综合色彩校正、自适应对比度与伪色映射在直色域求值后恢复源覆盖，透明帧不再向后续合成贡献颜色；中性和非法控制值使用有限旁路或默认值。
- 内置转场在编码时统一正规化可变参数，位移在浮点域有界化后再转整数；RedMonochromeBlur 声明实际不透明输出，保留灰度及双开关的对角采样行为。

- 高光/阴影按真实目标宽高完整写入，正负调整作用于相同亮度分区；`C7HighlightShadow` 高光默认值恢复为文档约定的中性 1，零调整保留原始浮点值。
- Normal 与 SourceOver 修正背景重复乘 Alpha 和覆盖合并；目录混合零强度及缺少前景时直接复制来源，避免有限 HDR 在无效运算后产生非有限值。黑 Mask 清除 RGB 与 Alpha，白 Mask 保持来源。
- 色键在直色域判定颜色，替换色上传预乘 RGBA，软透明同色不再因覆盖率不同而漏抠；零平滑明确定义阈值端点，非法参数使用有限默认值。
- 三纹理前景蒙版按像素中心采样，修正同尺寸白蒙版的半像素偏移。
- 最终量化与通用像素格式转换保留 Float32 工作精度至最终目标，避免 UInt16 输出提前收窄至 Half；OrderedDither 保留所有正覆盖，区域量化和抖动分别使用输入采样坐标与输出全局相位。
- 三向色彩平衡将空色标记恢复为零调整，暗部权重改为随亮度递减，避免高光中间调权重为负；分区按直色亮度求值并恢复覆盖率。
- Gamma、亮度、对比度、暖度及透明度不再向全透明像素留下可见 RGB；颜色海报化保留原 Alpha，独立、通用融合与特化融合保持一致。
- 色温零值恢复中性、有符号参数支持冷暖两侧；色温零强度与中性白平衡在危险运算前旁路，自然饱和度使用稳定单精度均值与差分插值，修复可表示 HDR 灰图的 NaN/Inf。
- Swirl、Bulge、Pinch 与 GlassSphere 声明全局采样和尺寸依赖，停止误报普通单点分块/融合能力；Bulge 使用输入逻辑尺寸映射来源。
- 颜色插值保留两端、修复 RGB 单位及各分量起点；随机颜色在比例计算前转换为浮点，不再因整除恒定。
- 已知非预乘帧输入按工作合同正规化，颜色操作保持源覆盖率及已知不透明性；空编辑继承上游输出合同，不再丢失 Alpha 元数据与一致性信息。
- 两种色阶入口共用有限参数与非退化输入区间正规化，保留输出反向范围与预乘 Alpha。

- 含可选函数常量的内核在未显式传值时先用空常量表特化，避免把未特化函数交给流水线创建器触发 Metal 断言。
- 高级图、帧和带档位物化为允许原地写入的滤镜分配独立目标，避免覆盖共享来源、缓存或已交付帧；轻量同步路线的显式原地能力保持。纯色生成器上传预乘颜色并声明一致的 alpha 合同。
- 像素化从输出全局网格映射回输入 ROI，修正不同原点和 halo 的错位；像素化与点阵滤镜声明真实的空间依赖，零尺度或非法网格宽度旁路。Toon 非法量化级数回退到 10；去雾仅在奇异或非有限调制处旁路，保留普通四通道方程。
- Voronoi 按预乘 source-over 叠加颜色，alpha 为零时保留输入，修正原先忽略 RGB 透明度导致的过强效果。时间、分辨率和强度在计算前有限化。
- 暗角补偿在直色域执行原有 SDR 上限裁剪后重新预乘；去紫绿边以直色比较邻域，覆盖率变化和无效透明邻居不再制造颜色边缘。两者零调制保留 HDR 输入，去边支持环绕色相及饱和度阈值端点。
- 球面折射在实际像素域夹边，修正精确 UV=1 的单侧透明缺口，保留球外透明与零半径空球语义。上述受影响内核采用单精度工作值，Float16 目标显式执行最近值舍入，Float32 旁路不收窄。

- 多区域 LUT 的三个标量参数与 shader 槽位一致，过渡区连续且宽度按阈值间距限制；一维曲线按样本中心定位，不再使恒等表偏色。
- 3×3 矩阵解码拒绝错误元素数，参数编码拒绝后续非法形状修改，避免数组越界终止进程。
- 基础锐化保留中心 alpha；空间卷积 identity 使用单点核，锐化/卷积使用整数夹边、单精度累加及真实零强度旁路，修复边缘暗化、高图错位和有限 HDR 中间溢出。
- Sobel 与 Sketch 补回横向梯度的左下邻居，保留步长 2；Sobel 明确零填充、Sketch 保持夹边，继续输出不透明灰度。
- RGBA 膨胀保留负通道及零半径输入，在整数域按轴裁边并归一化过大半径；正 alpha 的解预乘不再被固定阈值清空。
- 降噪在 straight 亮度域比较、按覆盖率归一化范围均值与脉冲回退，恢复原 alpha，透明像素不再残留 RGB。
- Burn 与 Divide 的零强度直接保留输入，除法前处理零分母。Burn 对零叠加通道采用基底为 1 时取 1、否则取 0；Divide 对零通道分母采用原饱和分支，包括 0/0；颜色公式在直色域求值并使用统一的预乘覆盖合成。

### 2026-11-16

#### Added

- 渲染结果支持有符号零 DC Laplacian 与双方向 Sobel 能量摘要，按明确 Alpha 合同排除无效邻域，在 GPU 分层归约后只读取 16 字节摘要；保持纹理存储域，不隐式转换色域或 transfer，保留取消与数值失败语义。

#### Changed

- `C7ColorCube` 的四面体插值只读取所属四面体的四个顶点；同一资源的冷缓存并发纹理创建复用既有合并机制，保留代次失效与失败重试。
- `C7Deband` 的大图路径按 SIMD 宽度配置有界线程组，零强度路径跳过邻域扫描；GPU 证实完整 halo 不透明的低对比候选组复用等价简化，当边缘对比度已使平坦区权重归零时提前结束扫描，继续执行 SDR 预乘颜色裁剪并保留中心 alpha。
- `C7Morphology` 对大图、大核及已验收的 8/16-bit 格式复用已有 MPS 后端，内核对象随上下文缓存代次复用；小图、Float32、额度不足或同名自定义内核继续使用原 Metal 路径。MPS 不透明临时资源采用有界保守准入。
- 派生资源缓存改用结构化身份索引与节点 LRU，减少多热点命中的锁内扫描和身份字符串构建，保留预算、失效、并发创建合并及失败重试合同。
- 滤镜开发合同中的 `samplingFootprint` 通过协议动态分派，显式声明的邻域或全局依赖在通用滤镜链路中不再退回默认值；已有滤镜继续使用默认实现。
- 外部命令编码的同色域首级缩小几何与双/三平面YCbCr解码融合，直接生成目标尺寸RGBA；保持逐源像素夹紧后插值，并保留解码结果的池租约。
- `C7Clarity` 在尺寸与显存额度允许时采用两次一维高斯，保留逐轴截断归一化和原始 alpha；小图、额度不足或分配失败时保留直接路径。单组 Float32 中间表面最多 128 MiB，并受池容量与并发总额度约束，内部表面进入请求资源估算。
- 纹理池容差查找改用像素格式与尺寸桶索引，LRU 按键常数时间更新；保留完整 descriptor 校验、精确匹配优先、同键多纹理驱逐顺序和租约幂等回收。
- 分析 bundle 将 mask 规范化、统计、直方图与 GPU 预览合入单次提交；CPU 只读取摘要，保留存储域、作用域、Alpha 和回退合同。
- Scoped histogram 按实际 bin 数分配有界线程组内存，每组只合并一次样本总数；支持 SIMD 与通用整数回退，任意有效 bin 数保持样本守恒。
- shared 纹理的小 ROI 统计只读取目标区域；空/越界 ROI 在读回前返回空结果。private/managed 的显式 CPU 回退仍使用安全同步路径。
- 固定 5×5 细节模糊与增强在支持浮点过滤的设备上采用单 pass 九采样打包；其他设备保留修正后的整数读取路径。执行准备复用同次诊断和内置纯点运算的源参数指纹，其余滤镜保留编译后校验；颜色推导直接读取输出合同。
- `PixelGraphOperation.multiplyCoverage` 直接将 red 数值覆盖夹到 0...1 后乘入预乘 RGBA，覆盖合成可省去透明底图和独立覆盖归一化表面。
- 加权 RGB 直方图采用有界 GPU 条带与最终归约，CPU 只读 3076 字节结果，4K 默认调用不再超出读回预算；mask 分析最终只读 72 字节摘要。
- 大图统计采用 GPU 分层归约，scoped histogram 和 scope mask 可直接在 GPU 执行，保留纹理存储域、范围、遮罩及 CPU 回退合同。
- 局部模糊按作用区和半径选择直接或可分离高斯；移轴模糊改为两次一维高斯，保留既有实际半径、过渡和全局坐标；分离路径与双边模糊预计算空间权重，小作用区保留直接计算。
- Kuwahara 大半径与油画整数大半径窗口复用横向列统计，不分配整图积分纹理；小半径保留原路径。浮点归约顺序可能改变几乎等方差象限的选择。
- `C7Transform` 与四角透视路径的 adaptive 缩小路径使用逆映射面积采样，单轴最多 16 taps；nearest、linear 与放大行为保持。
- 无符号与内部有符号 mask 距离场共用单次提交的欧氏距离变换，保留距离截断、阈值及空/满 mask 输出。
- YCbCr 输入在支持的 HarbethIO 与 ImageNode 来源滤镜链中作为解码首阶段执行，与后续滤镜共享提交；同步 TextureLoader 的完成态返回合同保持。

#### Fixed

- 一维 LUT 按样本中心映射包含两端点的曲线；`C7ColorLookup512x512` 修正红绿坐标和蓝切片插值并保留源 alpha，继续使用既有 32³、16 列资源布局。
- 直接构造或更新的 Cube 资源统一验证尺寸、载荷、有限样本和严格递增的有限 domain；非法或缺失资源通过现有错误通道失败，不再静默旁路。校验随不可变资源构造执行，不进入逐帧路径。
- Cube 对合法极窄及跨度溢出的 domain 使用稳定归一化，域判断、插值和强度混合使用单精度；Float32 的域外保留与零强度不再收窄到半精度，Float16 目标显式执行最终最近值舍入，避免隐式写回截断；中间舍入可能与旧输出不同。
- 六边形散景采用单精度解预乘、累加和高亮合成，避免有限 HDR 均值在累加阶段溢出；六边形散景与 Deband 在因素和 halo 计算前统一处理非有限参数。
- Deband 在 straight 颜色域比较亮度、按覆盖率归一化平滑并重新预乘；dither 不再向纯透明像素写入 RGB，变化 alpha 的同色边缘不再增亮。
- `C7Morphology` 与 `C7SurfaceBlur` 在因素和 halo 整数化前处理非有限参数，避免查询诊断时因 NaN 终止进程。
- `C7SharpenEnhanced` 的 1×1 核与零强度保留输入；边缘锐化与细节锐化采用单精度中间运算，避免可表示 HDR 在 Laplacian、局部均值及零调制分支产生 Inf/NaN。
- 极坐标像素化的零 scale 明确为旁路；红色单通道膨胀在有符号域按真实边界夹坐标，保持原对角/单方向采样和不透明灰度输出。
- `C7EdgeGlow` 使用邻居差分与平坦检测，零阈值下十进制常量不再被消减舍入误判为边缘，不扩大用户阈值。
- 色差校正按采样位置的对象 alpha 解预乘并恢复基础 alpha，透明输出不再残留 RGB，同时保留不透明图的画布边缘衰减；镜头与色差校正声明全局坐标和画幅依赖，不再误报可自动分块或点运算融合。
- 分析值域使用可表示的非零窗口和抗溢出归一化，解码复用同一正规化；CPU/GPU 直方图与图像示波器保持一致规则，常规相等端点的单位扩展行为保留。
- 派生资源身份中的分隔符不再导致不同命名空间与代次串用同一缓存条目。
- `C7CircleBlur` 对非正样本数、零半径及非法参数保留输入，使用单精度归一化累加并在转换无符号坐标前夹边，避免 NaN、透明黑和有限 HDR 溢出。
- 修正 `C7EdgeGlow` 将右下端点转换成宽高索引导致的假边缘；常量图、单像素与不同目标尺寸均按真实输入边界采样。
- `C7UnsharpMask` 的零半径、零强度不再执行锐化；正常路径改为单精度高斯与细节运算，继续保留既有 SDR 夹值和中心 alpha。
- 分析统计、直方图和作用域 mask 统一 Rec.709 存储域亮度的显式融合乘加顺序，使 CPU/GPU 对 inclusive 范围端点作出一致判断，不额外扩大范围。
- 修正旧邻域滤镜的负坐标转无符号后跨边采样、高斯右/下边界越界，以及高斯/均值模糊归一化前半精度累加导致的有限 HDR 溢出。
- 零半径、零强度与非法标量参数提前保留输入，避免无效邻域计算；零值路径保留 Float32 像素精度。高斯与均值仍维持既有九点/四点归一化间距语义。
- CPU histogram 对非有限选中分量返回 nil，避免整数索引转换崩溃；ROI 读回保留全局坐标与原始尺寸，unsupported shape/format 的空结果行为保持。
- 修正大图 CPU 均值的顺序单精度累加误差、双边模糊的半精度累加溢出，以及零半径局部/移轴模糊产生非法像素的问题；双边模糊采用单精度计算，结果不再逐位复现旧半精度舍入。
- 修正 Canny 灰度变换、sigma 和双阈值接线；C7Canny 使用完整滞后连接并统一输出灰度 RGB 与不透明 alpha，参数进入缓存身份。
- mask coverage 比例保留低于活动阈值的软覆盖值，活动计数与质心继续遵循阈值语义。

### 2026-11-15

#### Added

- Added `ImageRasterPlan` for strict RGB CPU raster adaptation and shared CGImage precision selection; texture upload retains its existing color-space, row-alignment, and buffer policies.
- Added `ProjectiveTransform` for explicit double-precision projective mapping/inversion and `ImageDifferenceStatistics` for aligned RGBA8 byte-domain difference summaries; consumer fallback and display policies remain outside the engine.
- `MaskGradientRecipe.makeTexture(in:pixelFormat:)` 可在整图归一化区域直接生成 GPU 渐变 tile，支持非等比区域与画布外 halo；默认整图入口保持原坐标与像素格式。

#### Changed

- Reuse bounded scalar fingerprint descriptions across filter and mask planning while preserving the existing POSIX formatting bytes, rounding, signed-zero, and non-finite-value identities.

#### Fixed

- 深层 `ImageNode` 规划与执行准备改为迭代收集上游依赖，再自来源向输出装配，避免 Debug 后台小栈随局部效果链叠加大型准备栈帧；保留滤镜顺序、来源物化、缓存、采样和派生尺寸合同。

### 2026-11-11

#### Added

- `RenderedFrame.makePixelBuffer(...)` 支持显式色彩转换及 NV12/P010 GPU 双平面输出，覆盖 8/10-bit、full/video range、BT.709/BT.2020 矩阵与明确的 alpha 舍弃准入；实时缓冲池支持 RGBAHalf 和 P010。

- Added shared mesh-render pipeline creation with cached function/format/thread-limit identity, concurrent creation coalescing, and generation-aware invalidation.
- Added weighted GPU RGB histograms and exact alpha bounds with explicit readback budgets. Histograms use alpha-times-coverage weights and block Float accumulation; alpha bounds preserve finite positive binary16 subnormals; the GPU route returns a fixed 24-byte summary.
- Added versioned lookup-texture loading and coalesced derived-texture creation, including retry, recursive-creation rejection, namespace isolation, and stale-insertion protection. Preloaded lookup initializers retain serializable resource identity.
- Added pure sRGB/Display-P3/OKLab transforms and inverse-coordinate grids with cached numeric RG32Float uploads and conservative input-region bounds.
- Added `C7DepthLensBlur` and `DepthLensBlurDescriptor` as framework-owned primitives, preserving the existing depth sampling, alpha, extended-range, and region contracts. Direct users must import Harbeth.

#### Changed

- Weighted histograms combine uniform active SIMD lanes on supported devices to avoid flat-color atomic contention; other devices and Simulator retain the original atomic kernel.
- Alpha bounds use budgeted CPU inspection for small inputs and the 24-byte GPU summary for larger inputs, avoiding unprofitable small shared-texture submissions without changing alpha classification.
- Inverse grids memoize immutable fingerprints and accept lazy producer revisions; region queries can access producer-owned corners without copying or validating a whole point array.

#### Fixed

- 渲染计划使用实际 YUV 解码目标和浮点缓冲精度，避免将真实 HDR 误报为 8-bit；HLG/PQ 跨域转换使用平台 GPU 媒体颜色管理并与线性色彩参考对照。
- 局部 mix/replace 混合补齐扩展范围和采样合同，其他混合模式继续保守准入。
- Gamma 及其融合路径对负扩展范围分量采用保留符号的幂变换，避免分数次幂产生 NaN；正分量与 alpha 行为保持，并补齐显式像素合同。

### 2026-11-10

#### Fixed

- `C7Clarity` 显式使用框架 Metal 内核，避免外部同名内核覆盖；区域合同覆盖完整采样半径，零半径直接保留输入像素与透明度。

### 2026-11-09

#### Added

- `HarbethIO.transmitFrame` 在 GPU 完成后交付带最终纹理租约的 `RenderedFrame`；`replacingInput(with:)` 复用同一链的执行准备并核对参数、逐步尺寸与执行代次。
- `TextureLoader.resolveTextureSource` 支持显式 BGRA sRGB 硬件解码，`MPSLanczosResize` 支持直接缩放指定源区域。
- 局部细节与降噪增加 `sampleSpacing`，可将原生像素邻域投影到预览；默认间距 1 保持原照片输出。
- `RenderView` 支持显式逐帧绘制、像素尺寸变化反馈与主线程 GPU 完成反馈，无法绘制时返回跳过结果，便于媒体宿主限制在途帧；默认显示策略保持。
- `ImageTIFF16Encoder` 支持直接从 `RenderedFrame` 输出整数 TIFF16，颜色转换和整数化留在纹理链路，最终编码前才读取像素；原有 `CIImage` 与 `CGImage` 入口保留。

#### Changed

- `RenderView` 仅在颜色、动态范围或屏幕能力变化时重设显示颜色配置；没有观察者时不再派发空的宿主报告回调。
- 任意 ICC 纹理转换在可建立颜色转换合同时使用 MPS GPU 路径，其余情况沿用 Core Image GPU 路径；TIFF16 的 `CIImage` 输入复用进程级 Metal 背书 `CIContext`。

#### Fixed

- `RenderView` 补齐系统自动调整 drawable 与观察者晚挂接后的像素尺寸通知；相同尺寸去重，避免上游预览继续使用初始低分辨率。
- 单平面 `PixelBufferTextureSource` 同时持有采集缓冲与 `CVMetalTexture` 桥接句柄，所有权随单次纹理源释放，避免将 owner 长期附着到借用纹理。

### 2026-11-08

#### Changed

- 图指纹共享不可变前缀并按需展开诊断文本，缓存计划预存执行位置和资源生命周期，减少长链构建及重复执行的准备开销；现有指纹文本和当前滤镜绑定保持。
- 常用点运算序列使用有界函数常量专门化，保留逐步半精度运算及通用顺序回退；双边模糊使用平方距离，减少邻域内重复开方。
- CLAHE 在较大输入上先在线程组内统计再合并直方图，LUT 使用并行整数归约和前缀和；透明度、HDR 跳过、均匀区域、临时 buffer 生命周期和四个编码阶段保持。

#### Fixed

- 缓存渲染计划保存创建时的滤镜参数指纹，避免引用类型滤镜修改参数后错误复用旧计划；执行位置复用仍绑定本次滤镜实例。

### 2026-11-06

#### Changed

- 连续滤镜节点改为迭代展开，指纹、编辑描述和建图共用分组遍历；建图复用请求内的上游指纹与来源信息，保持滤镜顺序、参数刷新和非滤镜节点边界。
- 图优化与共享依赖统计使用请求内查询索引，执行步骤预先索引阶段与诊断信息；采样覆盖名单和预热阶段分组一次汇总，保持图重写顺序、资源生命周期和预热数量上限。
- 诊断快照复用同次来源准备和已编译根计划，资源优化指标合并为单次阶段与生命周期汇总，保持快照内容、资源估算及诊断决策顺序。
- 派生资源缓存、上下文缓存和纹理池减少重复 LRU 扫描；派生缓存批量失效与容量收缩保留淘汰顺序、代次和字节账目，纹理池减少未命中扫描及 heap 统计的临时聚合。
- CPU 统计与 histogram 在单次遍历内复用读回字节，减少逐像素借用开销；统一 CPU histogram 预览附件构造，保持存储域解码、采样与累加顺序、辅助附件通道及 GPU fallback。

#### Fixed

- 修复 Debug 构建中深层连续滤镜链生成编辑描述时的递归栈溢出，保留完整描述与非滤镜节点边界。
- 修复上游处理跨 edit 边界后丢失 parity 身份的问题，嵌套 edit、后续滤镜及缓存包装保留有序处理指纹；像素输出和合法交付差异不变，新增可选配方信息兼容旧数据解码。
- 交付尺寸追加的 resize 不再混入视觉处理对比；几何计划键保留声明参数，避免 1×1 占位规划使不同目标几何误命中同一缓存。
- 修复非默认请求采样合同跨编辑、后续滤镜与缓存包装时的描述丢失，按步骤保留处理指纹并统一请求/配方/快照传播；实际 sampler 适配、覆盖能力和像素输出不变。

### 2026-11-04

#### Fixed

- 局部高光阴影影调的采样声明扩至8σ，覆盖窄画布与完整配方混合中的邻域截断误差；像素算法、参数和零半径行为保持。

### 2026-11-01

#### Added

- Added reusable RGBA8 buffers, validated print resolution, integer TIFF16 encoding, stable image-content hashing, affine/region geometry, half-float conversion, and dynamic-range statistics. Existing payload layouts, identifiers, and numerical behavior are preserved.
- Moved image-sizing helpers and the luminance matrix into the existing image and matrix API families.
- Integrated primitive validation and TIFF16 encoding failures with `HarbethError`, including stable diagnostic codes for image destination creation and encoding.

- Added caller-owned filter encoding, resident-region perspective sampling, inverse-grid sampling, and numeric pixel replacement primitives.
- Added texture-backed output-contract and arbitrary ICC frame conversions, plus a shared numeric Core Image context.

### 2026-10-30

#### Added

- Added `C7LocalTone` for signed local histogram-based enhancement and compression, with fixed-grid region accumulation and premultiplied-alpha/extended-range boundaries.
- Added `C7LocalLaplacian` with sampled Gaussian/Laplacian residual interpolation, bounded scratch reuse, and a shared region-encoding contract for fixed-phase multiscale processing.

### 2026-10-29

#### Fixed

- 超过 4 KB 的滤镜参数改用 Metal buffer 绑定，避免长笔触或大型数组触发 inline bytes 长度断言；小参数继续使用原有绑定路径。

### 2026-10-26

#### Fixed

- 多层局部蒙版的冷规划改走轻量递归分派，避免 Debug 构建在后台小栈线程叠加大型规划栈帧；保留效果顺序、采样、尺寸与来源准备合同。
- 空曲线控制点在 GPU 执行时仍绑定占位 buffer，避免使用部分通道曲线的配方触发 Metal 参数断言；空通道继续按原语义跳过。

### 2026-10-25

#### Added

- C7SelectiveHSL 增加显式 photographic 响应：色相与饱和度选择在近黑区渐隐，明度偏移按输入亮度加权并保持黑白端点；默认 additive 响应、参数布局、透明度和超域偏移策略保持不变。

#### Fixed

- 浮点数组执行指纹改用规范小端Float32完整位模式，减少重复十进制格式化开销，并区分原先四位小数舍入后相同的参数；参数编码与实际绑定不变，派生缓存键重新生成。

- 缺失 Metal 函数或管线创建失败时，同步与异步计算路径不再留下未结束的编码器；渲染批次及分析路径同步补齐错误退出的编码器生命周期，避免将可报告错误升级为 Metal 断言崩溃。

### 2026-10-23

#### Added

- C7Vignette 增加默认关闭的 usesPixelAspect 选项，按完整画布短边归一化像素距离，保持不同宽高比及区域渲染的圆形渐晕轮廓；默认仍使用既有归一化坐标。

- 命名 CUBE 支持通过 ColorCubeReplacementProvider 注册版本化逐像素原子替代链；保留 C7ColorCube 类型、资源名称、强度及原生 LUT 回退，具体风格与准入由资源 owner 持有。
- 可融合的线性曲线—矩阵—曲线使用单次 GPU 执行，其余替代链使用半浮点中间纹理；两条路径均在末尾混合一次，保留原始 alpha、零强度及超域策略；HarbethIO 与 ImageNode 共用现有管线执行。

#### Fixed

- 局部高光阴影影调使用 6σ 的输入采样声明，避免模糊参考的边缘截断在非线性调整后形成分块量化差；完整图像算法、参数及零半径语义不变。

### 2026-10-20

#### Fixed

- SwiftPM 的 Metal 资源发现使用只读目录遍历，避免清单求值依赖 CoreServices 目录属性查询；保留相对路径、排序与不跟随目录符号链接的行为。

### 2026-10-16

#### Fixed

- RenderView 补齐 Mac Catalyst/macOS 原生应用激活、主窗口与遮挡变化通知的保留帧失效请求；延后至主队列重新核对纹理，保留帧身份、色彩与宿主暂停策略。

### 2026-10-15

#### Fixed

- RenderView 释放时同步完成原生 UI 主线程清理，避免 TaskLocal 作用域下隔离析构触发运行时崩溃；保留通知、宿主统计和显示层池注销。
- 默认局部混合模式正确消费效果强度；预览与正式渲染中的零强度和部分强度不再被当作满强度。

#### Added

- MTLTexture 的 rawBytes(maximumBytes:) 提供有界、保留存储格式的读取；半浮点与 BGRA 通道顺序不再需要转为 RGBA8，复用既有 shared/private/managed 同步路径。

### 2026-10-14

#### Added

- OrderedDither 支持每通道2…256色阶、1…32像素单元与确定性图案；单元颜色按Alpha加权平均，保持逐像素透明度，并声明有界邻域和唯一写入归属。
- OutputQuantization 增加 2×2、8×8 有序抖动图案；完整坐标、Alpha 与确定性回放合同共用现有入口，原 4×4 默认值与因子布局保持不变。

#### Fixed

- Swirl按完整画布像素中心计算扭转采样，消除水平/垂直镜像后的半像素方向偏移；保留原有扭转量、半径与RGBA点采样合同。
- Grayed的六种灰阶内核保留输入Alpha，半透明与透明像素不再随去色强度变为不透明；RGB算法、参数与不透明结果不变。
- OutputQuantization 按完整输入坐标生成有序与交错梯度抖动，区域输出不再从局部原点重置图案；整帧原点、量化因子与 Alpha 保持原有语义。

### 2026-10-13

#### Added

- SceneRelightDescriptor 新增近景/远景曝光、深度分界与柔和过渡；C7SceneRelight 在同一线性光照通道消费深度，保留置信度、高光与 alpha 保护。新参数默认中性，旧 Codable 数据保持原有输出。
- SceneLightDescriptor 支持逐灯深度区间及羽化；SceneRelightDescriptor 增加深度断层边缘保护。默认参数兼容既有输出，Swift/Metal 参数布局同步升级为 76 Float。

#### Changed

- 高斯模糊统一为 MPSGaussianBlur；精确 sigma 与显式边缘模式直接由同一滤镜提供，保留既有 radius 入口的取整效果，移除未发布的 GaussianBlur 类型及专用错误类型。

#### Fixed

- ChannelControl 的透明度同步衰减预乘 RGB 与 alpha；ImageNode 和帧输出保留滤镜的实际透明类型，避免预览继续按不透明来源显示。

- MotionBlur 与 ZoomBlur 使用完整画布坐标、像素中心及对称的有符号边界采样，避免镜像偏移和分块尺寸改变效果；零半径保持原始RGBA，并声明动态ROI与预乘扩展范围像素合同。

### 2026-10-12

#### Added

- MPSGaussianBlur 的 sigma 入口精确使用浮点标准差（0 < sigma ≤ 100），支持显式边缘模式并声明 ceil(4×sigma) 的采样 halo，可通过 HarbethIO 与现有滤镜链执行。

### 2026-10-11

#### Added

- RenderQuadTransform 增加可选 alignsViewportToPixels；最小包围输出按原始像素坐标向外对齐，保留分数角点外沿，并避免奇数尺寸 identity 被扩大。默认输出行为保持不变。

### 2026-10-10

#### Added

- 公开现有 LayerComposite 滤镜原语；LayerBlendMode 补齐线性加深、除法、亮光、线性光、点光、实色混合及色相/饱和度/颜色/亮度，支持纹理链直接使用同一预乘合成公式。

- RenderView 增加类型化显示视口与 linear/nearest 采样选择，缩放和平移直接作用于 GPU quad，drawable 继续受宿主尺寸约束；显式显示配置使用 Metal 宿主。

#### Fixed

- 图层采样使用像素中心，同尺寸图层保持逐像素对应，避免区域大小改变导致重采样；颜色加深/减淡规范化到有限端点结果。

- 显示 quad 顶点使用 command encoder 捕获，避免下一次重绘覆写 GPU 在途的单个可复用顶点缓冲。

### 2026-10-07

#### Fixed

- 修复 ImageNode 采样器包装丢失混合、光栅化、目标纹理及像素合同的问题；图层合成在 texture、frame 和 attachment 输出中保留预乘透明度混合与背景预载，附件 pipeline 按实际输出格式创建。
- 编辑节点的计划、配方描述和延迟请求不再提前执行上游滤镜；单次准备共享源物化，局部效果的参数化 mask 在执行时解析。
- 合并同一 Render pipeline 的并发冷启动；失败会唤醒等待者并允许重试，缓存重置或 binary archive 重配后旧创建结果不会写回新缓存。

#### Changed

- ImageNode 的连续普通滤镜采用统一批处理，链式和数组写法共享执行组织，并保留编辑、缓存、采样器及 kernel 合同边界。

### 2026-10-05

#### Fixed

- 修复组合滤镜作为通用协议进入嵌套顺序或并行管线时跳过内部步骤的问题；子管线现在完整执行并向最终节点绑定辅助纹理。

### 2026-09-28

#### Fixed

- 高精度图片的手动纹理上传采用复制混合模式，避免半透明像素与未初始化缓冲混合，产生随机颜色、错误 alpha 或非有限值。

### 2026-09-24

#### Fixed

- 修复不透明 XRGB/RGBX 图片加载时占位通道被当成颜色或透明度的问题，避免原图往返和滤镜输出出现严重偏色、变亮与错误透明度。

### 2026-09-19

#### Fixed

- 修复 Mac Catalyst 计算滤镜对 shared/private 输出纹理调用 managed 资源同步 API 导致的 Metal 校验崩溃；仅对 managed 纹理保留同步。

### 2026-09-12

#### Fixed

- Clamped `C7Sketch` Sobel taps to the source extent, preventing synthetic lines along image boundaries.

### 2026-09-07

#### Added

- Added `ViewSnapshotSource` and versioned `ViewSnapshot` for explicit `C7View` / `CALayer` raster capture. A snapshot uploads its immutable UI pixels once and can then feed `RenderLayerComposite` or `ImageLayer` without repeatedly capturing or uploading the same UI content. Capture failures use `HarbethError`.

#### Fixed

- Fixed `C7View.toImage(bezierPath:)` mutating the source view's `layer.mask`; clipped snapshots now render offscreen without changing host UI state.
- Consolidated public runtime failure types into `HarbethError` while preserving their stable `harbethDiagnosticCode` and metadata bridge through `HarbethDiagnosticCoding`.

### 2026-09-06

#### Changed

- 构建工具基线明确为 Xcode 26+、Swift 6.2 与 Apple SDK 26+；Swift 语言模式仍为 6，iOS/iPadOS 15、macOS 12、tvOS 15 部署下限保持不变。

#### Fixed

- 修复 `HarbethIO.output()` 与 `transmitOutput()` 对非空滤镜链的不支持输入静默返回原值成功的问题，现在一致返回 `renderableUnsupportedInputType`。需要色彩空间物化的空链同样报告不支持输入；无需物化的空链快速返回及已有 Data/URL/ImageAsset 加载路线保持不变。
- 修复共享纹理加载器首次并发访问时可能重复初始化的问题，色彩空间改为初始化后不可变的资源。
- 合并相同函数 identity 的并发 Compute Pipeline 创建，标准名称与结构化 identity 共用缓存。创建失败会结束等待并允许后续重试；缓存重置后，旧创建结果不会重新写入新缓存，不同 identity 的创建仍可并行。

### 2026-09-02

#### Add

- Add verified compact LUT loading

#### Fixed

- Fixed Swift 6 asynchronous texture-delivery compilation by declaring the internal raw texture rendering result as sendable across completion closures, and removed the simulator-only end-of-scope `defer` warning from context texture-cache flushing.

### 2026-08-25

#### Changed

- Consolidated realtime pixel-buffer reuse, temporary CLAHE buffers, Metal fallback libraries and external-library provider state under the process-lifetime `HarbethContext` / internal `Device` owner boundary. Feature-specific transient resources are now created only on first use, while runtime cache reset, recovery and memory pressure purge only resources that were created without removing registered providers.
- `HarbethContext.coreImageContext` now initializes on first access and retains stable identity across execution recovery, avoiding Core Image setup for Metal-only runtime use.
- Performance diagnostics now create their cleanup timer only while monitoring is enabled, while preserving the context-owned monitor identity across enable and disable cycles.

#### Fixed

- Routed Harbeth-owned Mask GPU work through the recoverable context command-buffer path while keeping an explicit local queue fallback for textures owned by another Metal device.

### 2026-08-06

#### Added

- Added `TextureAnalysisValueRange` so histogram and image-scope callers can explicitly map HDR/EDR storage values without implicit tone mapping or transfer-function decoding.
- Added `encodeImageScope(_:into:)` for composing scope generation into a caller-owned Metal command buffer without submission or waiting.

#### Changed

- Kept `C7` for established platform adapters, geometry primitives and filter-development contracts, while removing it from unrelated public Metal capability and filter-configuration types. Use `MetalCapability`, `MetalCapabilityStatus`, `MetalCapabilityReport`, `DisplacementEncoding`, `DisplacementUnit`, `SceneLightKind`, `SceneLightDescriptor`, `SceneRelightDescriptor` and `SceneRelightDescriptorError`.
- Removed `RenderProfile.usesRealTimeCommit` from the public surface and stopped `HarbethIO.configured(for:)` from implicitly changing real-time delivery; `transmitOutputRealTimeCommit` is now the only public HarbethIO control for that behavior.
- Simplified `bufferPixelFormat` into the single source of truth: it is now optional, where `nil` preserves the source texture format and a value explicitly overrides it. The redundant setter-tracking state was removed.
- Removed mutable destination-allocation and double-buffer switches from `HarbethIO`; allocation now derives from `RenderProfile`, `bufferPixelFormat` and each filter's destination contract. `HarbethIO` remains the direct source-plus-filters-to-output entry point.
- Kept `HarbethIO.mirrored` public as the legacy explicit CIImage orientation correction; it is not an execution policy and has no replacement source-orientation contract yet.
- Replaced the broad advanced-Metal abstraction with `C7MetalCommandEncodingProtocol`, an opaque command-encoding escape hatch used only when standard filters and `C7FilterPipelineProtocol` cannot express the resource graph. External libraries and function constants now remain on ordinary Compute filters, including `C7ProgrammableBlend` and `LayerProgrammableBlend` without a capability parameter.
- Added `FilterDestinationTextureContract` and `DestinationTextureAliasingPolicy` to the common filter contract so Compute, Render, MPS, Blit and Metal-command filters can declare destination usage, storage mode and aliasing without changing execution category.
- Expanded CPU analysis readback to normalized 8-bit and `r` / `rg` / `rgba` 16-bit and 32-bit floating-point textures while preserving texture-storage component semantics.
- Reused Analysis readback work inside frame and attachment bundles, kept single-metric `RenderRequest` calls selective, reused the shared execution queue where possible, and normalized GPU scope density against a 1080p reference.

#### Fixed

- Fixed `ImageNode.makeAnalysisBundle` dropping mask, luminance, color-range and coverage inputs, and fixed `makeAttachmentAnalysis` ignoring an explicitly selected histogram channel.
- Fixed attachment-analysis summary fingerprints omitting histogram contents and statistic values.

- Preserved `transmitOutputRealTimeCommit` as the single public real-time submission switch while restoring its original texture-first meaning: enabled asynchronous texture output is delivered after command-buffer scheduling, while the default waits for GPU completion.
- Kept synchronous output and CPU-materialized image, pixel-buffer and sample-buffer results completion-safe even when real-time texture delivery is enabled.
- Kept managed output textures leased for the lifetime of synchronous direct-filter `ImageNode` frames, allowing texture-backed CIImage results to return their storage to the pool only after the frame and escaped image views are released.
- Enforced destination aliasing and output contracts across low-latency allocation, render-plan cache identity and multi-filter graph compilation, while preserving explicit in-place support for primitives that stage their own source safely.

#### Removed

- Removed the legacy `HarbethView` and `HarbethViewInput` SwiftUI image-readback bridge. Render work now belongs to `HarbethIO` or `ImageNode`, while `HarbethRenderView` remains the texture- and `RenderedFrame`-first output host. Keep any intentional static image readback local to the host UI.
- Removed direct public access to `HarbethIO.createDestTexture`, `HarbethIO.enableDoubleBuffer`, `HarbethIO.configured(for:)`, frame-capability construction, convenience fallback output, filter operators, and texture-backed CIImage frame delivery. Use `ImageNode` with a `RenderProfile` when structured execution is required; call `RenderedFrame.makeTextureBackedCIImage(for:)` for CIImage source-preserving delivery.
- Removed `PerformanceMonitor` and its configuration/metrics types from the public API. Hosts now use only `HarbethContext.enablePerformanceMonitor` to opt into internal diagnostics; benchmark and test consumers use the package's internal test surface.
- Removed `C7AdvancedMetalKernelProtocol`, `MetalCapability.customAdvancedEncoder` and the redundant custom-encoder-kind classification. Ordinary kernels remain on `C7FilterProtocol`, texture-only multi-pass work remains on `C7FilterPipelineProtocol`, and only non-standard command/resource graphs use `C7MetalCommandEncodingProtocol`.

### 2026-08-05 — macOS texture readback correctness, deterministic tone mapping and GPU filter primitives

#### Added

- Added `C7ToneMapping` for deterministic linear-RGB luminance mapping from explicit source nits into SDR or EDR output headroom, with preserved alpha and declared dynamic-range behavior.
- Added `C7DisplacementMap` for single-frame deformation from signed or normalized displacement textures, with pixel/normalized units, sampler and edge policies, optional confidence weighting and full-canvas coordinate semantics.
- Added `KernelDynamicRangeBehavior.toneMapsToEDR` so render planning can distinguish EDR-safe tone mapping from SDR clamping and HDR-preserving execution.
- Added `C7HighPassSkinSmoothing` as a full-frame high-pass detail-preserving smoothing pipeline, without claiming face or skin-region detection.
- Added `C7DocumentBinarization` for locally adaptive document black-and-white output under uneven paper illumination.
- Added `C7CLAHE` with tile luminance histograms, clip redistribution, CDF lookup tables and neighboring-tile interpolation for local SDR contrast enhancement.
- Added `C7HexagonalBokehBlur` with two-stage three-axis aperture sampling, rotation, highlight control and optional per-pixel circle-of-confusion input.
- Added `C7Palettize` for premultiplied-alpha-safe nearest-color quantization against a caller-provided palette of up to 32 colors.
- Added `C7CMYKHalftone` with four independent print-screen angles, full-canvas coordinates and an explicit conservative region-of-interest contract for tiled renderers.
- Added an `ImageNode` Page Curl transition primitive with normalized curl geometry, optional backside imagery, analytic shading, soft contact shadows and explicit non-tileable full-canvas execution semantics.
- Added `MPSConvolution`, `MPSLanczosResize` and `MPSMorphology` as validated out-of-place MPS execution atoms.
- Added `RenderMeshWarp`, `RenderLayerComposite` and `RenderVectorMask`, together with render topology, fixed-function premultiplied source-over blending and multisample resolve contracts.

#### Changed

- Routed `RenderOutputContract` SDR and EDR tone-mapping policies through the deterministic luminance primitive instead of approximating output with independent highlight/shadow and exposure adjustments.
- Aligned the public filter catalog with the source tree, including the previously omitted color grading, selective HSL, whites/blacks, output quantization and scene relighting primitives.
- Kept pipeline stage outputs independent from the final destination so combination shaders never bind the same texture for auxiliary reads and output writes.
- Upgraded `C7HighlightShadowTone` to a complete local pipeline backed by an MPS Gaussian reference texture, while preserving its existing adjustment API and premultiplied alpha.
- Extended `C7HighPassSkinSmoothing` with configurable tone-curve midpoints and optional final detail sharpening while preserving the previous default visual path.

#### Fixed

- Routed managed and private Metal texture readback through shared staging memory, preventing blank macOS image and pixel-buffer outputs when GPU-written data is not directly CPU-visible.
- Made `C7SurfaceBlur` return the original pixel for zero radius, zero threshold or zero intensity, and corrected signed edge-coordinate checks.
- Made `MPSGaussianBlur` preserve its configured public radius and expose the conservative sampling halo required by region-based executors.
- Made `C7ToneMapping` operate in straight-alpha color space before restoring premultiplied output, preventing translucent HDR pixels from violating the alpha contract.
- Made `C7HexagonalBokehBlur` sample optional CoC inputs through normalized canvas coordinates so lower-resolution control textures cannot be read out of bounds.
- Made `C7ColorCube` accept standard full-line and trailing `#` comments in CUBE resources instead of treating comment text as malformed sample data.

### 2026-08-04 — Production frame access and self-owned CIImage output

#### Added

- Add fail-closed `FrameProcessingCapability` based on `RenderPlanDiagnostics`, `RenderRequest`, `HarbethIO` and `ImageNode`, covering kernel declaration evidence, CPU readback, global dependence, certainty, sampler execution and extended dynamic range output requirements.
- Add `TextureBackedCIImageFrame` and `HarbethIO<CIImage>.outputTextureBackedFrame(...) `, let the Core Image frame-by-frame caller hold a rendering texture lease with color, dynamic range, tone mapping and source contract.

#### Changed

- Distinguish between explicitly declared kernel pixel contracts and conservative inferences that have not been declared contracts; production frame access does not allow evidence, sampler or external boundary access control.
- Reuse the source size prompt when parsing the frame color contract, and no longer duplicate the CIImage source just to check the descriptor.

#### Fixed

- Bind the reuse timing of managed texture to the typed Core Image frame output life cycle to avoid the texture lease returning the pool in advance when the packaging is still in use.
- Normalize the Core Image coordinates of direct PixelBuffer backing sources to avoid vertical flipping of dynamic media after texture filtering.
- Let escaped and cropped Core Image recipes retain their texture resources, avoiding premature lease reuse during deferred evaluation by AVFoundation and other hosts.

### 2026-08-02 — Asynchronous render submission, white balance and HDR preview hosting

#### Added

- Added `RenderSubmissionPolicy`, `RenderSubmissionHandle` and terminal snapshots for explicit cancellation and opt-in latest-only delivery across `HarbethIO` and `ImageNode` asynchronous work.
- Added `C7WhiteBalance.recipeFactors(temperature:tint:)` for constructing white-balance filters from recipe-oriented temperature and tint factors.
- Added typed output color-space, dynamic-range and tone-mapping metadata to `RenderedFrame`, so preview hosts no longer infer HDR semantics from texture pixel format.
- Added `PreviewDynamicRangePolicy` and observable `PreviewDisplayState` to `RenderView`; frame-driven previews now select SDR/16-bit float drawables, configure `CAMetalLayer` color space, request EDR when supported and report deterministic SDR fallback.
- Extended `HarbethRenderView` with the same dynamic-range policy and display-state callback while preserving the existing raw-texture SDR default.

#### Changed

- Routed the two public asynchronous processing routes through one generation-aware submission state machine while preserving independent, non-dropping delivery as the default.
- Made direct `ImageNode` filter-frame submissions encode and commit through that same state machine instead of wrapping synchronous frame rendering on the operation queue, while preserving completed-frame delivery semantics.
- Encoded contiguous layer-local filtering and compositing passes into one recipe-owned command buffer instead of synchronously committing each GPU stage.
- Kept finite `CIImage` inputs on the GPU by reusing pixel-buffer or Metal backing when available and otherwise rendering through the process-lifetime Core Image context directly into a Metal texture.
- Propagated Swift task cancellation into queued render submissions and made superseded or recovery-invalidated work terminate exactly once instead of leaving continuations suspended.
- Unified HarbethIO and ImageNode filter lowering around one internal execution program that freezes sampler adaptation, pointwise fusion, render planning, executable steps and diagnostics from the same input chain.
- Connected optimized stage lifecycle decisions to executable step liveness so intermediate textures are recycled only after their final GPU consumer completes.
- Added `SamplerAdaptation.partial` and the required `RenderProtocol.renderSamplerConsumption` contract, so every render filter explicitly declares whether its shader consumes runtime-bound or shader-defined sampler state.
- Harbeth 3.0 no longer preserves the former implicit sampler behavior for arbitrary `RenderProtocol` filters; custom render filters must declare `.runtimeBound` or `.shaderDefined` directly on the primary render protocol.

#### Fixed

- Suppressed stale host callbacks from already committed GPU work after cancellation, scope replacement or execution recovery without claiming that Metal command buffers can be synchronously cancelled.
- Bound each submission to its captured command queue and commit gate so work from an invalidated execution generation cannot migrate onto the replacement queue.
- Kept managed output and intermediate texture leases fenced until GPU completion, preventing early caller release from returning in-flight textures to the shared pool.
- Recycled committed outputs that lost delivery rights only after GPU completion, and isolated asynchronous performance metrics per submission without changing stable frame identifiers.
- Made synchronous command-buffer submission throw on GPU failure and release uncommitted raw/managed outputs instead of returning undefined textures or leases as successful results.
- Prepared `RenderRequest` and `ImageNode.makeFrame(...)` from one execution snapshot, so ordinary filter execution and diagnostics share the same compiled program while recipe, transition and layer routes retain explicit orchestration boundaries.
- Isolated `PreviewDisplaying` and `RenderView` to the main actor so drawable/layer mutation and preview display-state callbacks cannot run on a background render completion queue.
- Rejected structurally stale cached render plans even when a custom filter exposes an incomplete recipe fingerprint.
- Stopped reporting arbitrary render filters as sampler-covered when their shaders use fixed inline samplers, and now report mixed min/mag, address-mode or mip mappings as partial coverage instead of silently claiming full execution.
- Applied ImageNode sampler descriptors consistently across FrameRenderer's synchronous and asynchronous filter paths.
- Prevented nested ImageNode cache and sampler wrappers from retaining recursive render-plan compiler stack frames on small worker queues during cold transition rendering.

### 2026-08-01 — Runtime resource ownership and context migration

#### Added

- Added explicit execution generations and queue recovery through `HarbethContext`, plus resource-policy, texture-pool and cache diagnostics on the same supporting boundary.
- Added DocC guidance that separates host-facing runtime resources from Harbeth's concrete schedulers, pools, allocators and caches.

#### Changed

- Made `HarbethContext.shared` the single owner and public access point for process-lifetime Metal resources, Core Video texture caching, external Metal libraries and runtime recovery.
- Kept performance diagnostics as an internal listener owned by `HarbethContext`; hosts only use the opt-in `enablePerformanceMonitor` switch and no longer retain a monitor object.
- Migrated Harbeth sources, demos, tests and public examples away from retaining `Shared` or calling `Device` directly.
- Kept `Device` as an internal reference type with stable identity and moved command-queue ownership into a recoverable execution scheduler.

#### Fixed

- Invalidated compiled render plans when the texture allocation strategy changes, preventing plans from retaining allocator assumptions from the previous policy.

#### Removed

- Removed the internal `Cacheable` protocol and its Objective-C associated storage; `HarbethContext` now owns the Core Video texture cache directly.
- Removed the duplicate `Shared` facade completely, and removed `Device`, the raw command queue and concrete texture-pool ownership from the public API surface.

### 2026-07-31 — Frame interop, HDR image fidelity, scene relighting and mask correctness (4 commits)

#### Added

- Added RGB/RGBA SIMD conversion helpers for `C7Color` and SIMD2 bridges for normalized and unclamped point types.
- Added `encodeAttachmentSet(...)` for encoding multi-attachment output into a caller-owned, same-device, retained-reference Metal command buffer without implicit submission or waiting, allowing subsequent GPU work to stay in the same batch.
- Added `C7SceneRelight`, a depth-aware 2.5D relighting primitive with up to three point, spot, directional or rim lights, explicit linear-RGB/HDR/alpha contracts, confidence-aware fallback and region-rendering depth-plane binding.

#### Fixed

- Preserved 16-bit and 32-bit floating-point precision when loading or reading back HDR `CGImage` content instead of silently narrowing it to 8-bit image IO.
- Propagated inferred high-precision image formats through source descriptors so render planning and diagnostics reflect the actual HDR input contract.
- Kept `MaskPlane` storage diagnostics aligned with the actual texture format and honored explicit sampling-contract changes even when the requested extent is unchanged.
- Made incremental mask painting and erasing coverage-monotonic, skipped zero-flow or zero-density false revisions, and removed low-flow seams across multi-kernel brush batches.

### 2026-07-28 — Production runtime, professional masks and GPU governance (14 commits)

#### Added

- Added generation-safe derived GPU resource governance for output-contract textures, derived masks and 3D LUTs, with shared byte/count budgets, LRU eviction, namespaces, targeted invalidation, stale-write rejection, diagnostics and memory-pressure cleanup.
- Added host-configured Metal binary archives for compute and render pipelines, including memory-only warmup, explicit persistence, reload diagnostics and a clean disabled fallback.
- Added true single-dispatch pointwise fusion for ordered brightness, contrast, saturation, exposure, gamma and opacity chains, with conservative barriers around unsupported kernels.
- Added request-level GPU resource budgets with compile-time admission, typed violations, fail-fast execution, allocator-observed allocation/reuse reports and frame-metadata traceability.
- Added `RenderResourceBudget`, `RenderResourceEstimate`, admission results and `RenderResourceReport` so texture count/bytes, allocator reuse and heap-backed allocation decisions are observable per request.
- Added request-level preview/export parity signatures and structured visual-versus-delivery mismatch reports, with the evaluated parity fingerprint propagated to rendered-frame metadata.
- Added a unified kernel pixel contract covering color, alpha, precision, dynamic-range behavior, sampling footprint, global dependencies, CPU readback and pass-fusion eligibility, with graph-level coverage diagnostics.
- Added `KernelPixelContract` coverage reporting so custom filters can declare tile, HDR, alpha, precision and fusion safety instead of relying on name-based inference.
- Added source color-profile identity propagation and deterministic final-output quantization with ordered or interleaved-gradient dithering before integer pixel-format conversion.
- Added GPU-only luminance waveform, RGB waveform and vectorscope analysis attachments with deterministic density visualization and no source-pixel CPU readback.
- Rebuilt 3D `.cube` LUT handling with strict domain-aware parsing, cached native 3D textures, stable resource identity and trilinear or tetrahedral interpolation.
- Added opt-in, real `MTLHeap` texture allocation with capability fallback, bounded heap arenas, descriptor-safe reuse, lease ownership, memory-pressure cleanup and observable reserved/used/fallback statistics.
- Added heap allocation diagnostics for reserved bytes, used bytes, active arenas, fallback allocations, reuse hits and memory-pressure cleanup without exposing heap ownership as a new public workflow.
- Added explicit mipmap, CPU-cache, hazard-tracking and honored storage-mode options for runtime-created textures.
- Added `MaskPlane` as the explicit mask-coverage contract for coordinate space, source transforms, sampling, storage, resource identity, generations, revisions and modified bounds.
- Added a persistent incremental GPU mask canvas with dirty-rectangle encoding, pressure, flow, density, paint/erase modes, generation safety, cancellation and unbounded chunked centerlines.
- Added composable mask-expression DAGs with common-subexpression reuse, intermediate-memory diagnostics and allocator/heap strategy reporting.
- Added expression planning for ordered add, intersection, subtraction, exclusion, inversion and opacity while reusing common subexpressions and rejecting stale generation writes.
- Added compiled derived-mask graphs for threshold, grow/shrink, edge bands, distance fields, guided feathering, edge contraction and cleanup, with cancellation, resource-aware caching, GPU analysis, halo planning and dirty-region diagnostics.
- Added a public persistent/transient execution policy for derived masks without exposing cache implementation objects.

#### Fixed

- Preserved complete long brush paths beyond the 512-point GPU segment budget and retained off-canvas context for tiled rendering.
- Prevented subpixel brush widths from disappearing between pixel centers by using pixel-footprint-aware edge coverage.
- Prevented texture-pool aliasing across incompatible usage, storage, sample-count, texture-type, mipmap, array/depth, CPU-cache and hazard-tracking contracts.
- Stopped ordinary runtime textures from creating mipmap chains by default and consuming avoidable GPU memory.
- Replaced count-only persistent image-cache eviction with a byte-budgeted LRU and system memory-pressure cleanup.
- Corrected performance monitoring to use completed Metal command-buffer GPU timestamps instead of reporting command-submission wall time as GPU time.
- Corrected realtime benchmark first-frame and dropped-frame metrics and removed hundreds of simultaneously resident benchmark input buffers.

### 2026-07-23 — Professional color processing and support diagnostics (2 commits)

#### Added

- Added professional color-grading, selective-HSL and whites/blacks primitives with explicit parameter ranges and kernel contracts.
- Added structured diagnostic errors, stable diagnostic codes, outcomes, origins, metadata and correlation identifiers through opt-in `HarbethLogger` logging.
- Added a privacy-safe `HarbethSupportSnapshot` and user-facing Issue templates to make integration failures reproducible.

#### Fixed

- Changed missing Metal-function lookup from a Debug-build crash into a typed `HarbethError.readFunction` failure.
- Hardened mutable runtime registries and caches for Swift 6 concurrency checks.

### 2026-07-21 — Public 3.0 baseline and masked-effect entry point (3 commits)

#### Added

- Added a Harbeth 3.0 migration guide, DocC contract documentation and a post-3.0 public API breakage gate.
- Added public API-surface, capability-map, custom-filter, filter-catalog and troubleshooting documentation aligned to the two-route model.
- Added `HarbethRenderView`, a SwiftUI texture-first host for `MTLTexture` and `RenderedFrame` that reuses Harbeth's `RenderView` preview substrate.
- Added an `ImageNode` masked-effect composite entry point that reuses the same pixel-exact primitive as local edit recipes.

#### Changed

- Raised the supported baseline to iOS/iPadOS 15, macOS 12 and tvOS 15, with Swift 6 as the package and project language mode.
- Made throwing `output()` the canonical synchronous `HarbethIO` integration surface and documented `transmitOutput(...)` as its same-level asynchronous counterpart.
- Exposed render-profile configuration publicly while keeping Runtime, Graph, Kernel, Analysis and Recipe families as supporting layers rather than additional user routes.
- Kept Combination filters and the `RenderView` / preview-host substrate in public Harbeth as reusable render-engine capabilities.
- Isolated `C7View` image-capture helpers to `MainActor`, matching UIKit's actual threading contract.

#### Removed

- Removed watchOS from the published platform contract.
- Removed deprecated typo aliases, legacy runtime accessors, the unsafe `Outputable` generic extension, `C7CombinationBase` and the transitive `AVFoundation` re-export instead of carrying them into the new major baseline.
- Removed the global `R.width` / `R.height` main-screen shortcuts; layout code must derive size from its actual container.

#### Fixed

- Replaced deprecated Core Video attachment access with retained copy APIs required by the 3.0 platform baseline.
- Isolated derived-mask cache entries by guide-texture identity so identical graphs cannot reuse results produced from a different guide.

### 2026-07-20 — Compiled mask graphs and tiled execution (3 commits)

#### Added

- Added pressure-aware open brush masks, luminance/color range masks, generic texture-channel mask sources and single-channel mask storage formats.
- Added `MaskBrushRecipe`, `MaskRangeRecipe`, `MaskTextureRecipe`, `MaskMorphologyRecipe`, `MaskDistanceFieldRecipe` and reusable mask-analysis results as composable public primitives.
- Added area-preserving coverage resampling, signed-distance edge shift and asymmetric feathering, MPS guided matte refinement, foreground-color decontamination, topology inspection/cleanup, auxiliary scalar masks and single-frame flow warping.
- Added foreground-color decontamination controls and matte refinement policies that keep coverage correction separate from product-level subject-selection strategy.
- Added compiled composite-mask batches that preserve ordered add, subtract, intersect, XOR, inversion, opacity and feather semantics while processing up to four mask layers per GPU pass.
- Added tile-aware mask-graph execution with halo planning, regional diagnostics and semantics consistent with full-frame rendering.
- Added full-frame fallback reporting for mask operations whose global dependency or sampling footprint cannot be evaluated safely inside a tile.

### 2026-07-19 — Path-mask coordinate and feathering contracts (1 commit)

#### Added

- Added explicit path-mask coordinate-space handling and scale-aware feathering so normalized, pixel and transformed paths remain stable across output sizes.

### 2026-07-15 — Region-aware rendering and source fidelity (10 commits)

#### Added

- Added shared region-coordinate and texture-mapping contexts for compute and distortion filters, including mapped source/output rectangles and tile-aware sampling.
- Added `TextureMappingContext` propagation through crop, rotate, transform, morphology and distortion families so normalized coordinates can be resolved against the logical full canvas rather than an isolated tile.
- Restored `CIImage` as a supported source while keeping Core Image filters outside the Harbeth execution model.
- Added Metal-backed `CIImage` source loading with finite-extent validation and preservation of source color/orientation metadata.

#### Fixed

- Fixed transformed mask paths being clipped at their pre-transform bounds and corrected rotations on non-square canvases.
- Fixed region-aware coordinates for legacy filters so tiled execution matches the full-frame result.
- Hardened command-buffer, texture-owner and cache lifetimes across deferred, asynchronous and preview delivery.
- Fixed borrowed plane textures, pooled outputs and deferred command buffers outliving or releasing their true owners at the wrong execution boundary.

### 2026-07-10 — ROI execution and advanced canvas geometry (4 commits)

#### Added

- Added a complete region-of-interest foundation with propagation, halo expansion, full-frame fallback and diagnostics for graph and multi-pass execution.
- Added `TextureRegionRect`, `TextureRegionContext`, `SamplingFootprint`, texture pyramids and multi-pass execution helpers for filters whose output region depends on neighboring pixels.
- Added mask morphology, grow/shrink, edge-band and distance-field recipes on top of the same ROI/halo contract.
- Added composition anchors, quad transforms and quad rectification for structured placement and perspective workflows.
- Added explicit projective and cylindrical canvas renderers with transparent out-of-bounds behavior and independent coverage attachments.
- Added `.coverage` attachments for projective/cylindrical geometry so callers can inspect valid canvas area independently from the rendered color output.

### 2026-07-09 — HDR delivery, optics and preview telemetry (4 commits)

#### Added

- Added HDR/EDR output contracts, PQ and HLG transfer handling, explicit tone-mapping policies and display-oriented SDR/P3 output presets.
- Added `hdrPQTexture`, `hdrHLGTexture` and `toneMappedDisplayP3Texture` output presets while preserving explicit working/output gamut, transfer, alpha and pixel-format decisions in frame metadata.
- Added structured optics recipes and lens profiles routed through `ImageNode.applying(optics:)`.
- Added lens-profile builders for distortion, chromatic-aberration, vignette, defringe, diffraction and sharpness-falloff correction without turning optics into a separate runtime route.
- Added preview-host telemetry and runtime hints for frame visibility, fallback behavior and host diagnostics.

#### Fixed

- Hardened realtime Demo delivery, cancellation and frame ordering without moving camera, player or recording ownership into Harbeth.

### 2026-07-08 — Unified IO, frame bridges, masks and plugin boundary (8 commits)

#### Added

- Added structured gradient, shape, path, brush, range, texture-channel and composite mask primitives with deterministic graph fingerprints and reusable descriptors.
- Added mask component selection, invert, opacity, feather, blend and ordered add/intersect/subtract/exclude composition contracts.
- Added plugin-boundary types that let external capabilities return filters, recipes, local effects, layer composites or textures while execution remains on the `ImageNode` route.
- Added sampler-adaptation contracts shared by filtering, editing, transitions and composition.
- Added source/loading contracts for encoded data and `ImageAsset`, including source tier, intended role/purpose, loading options and stable cache behavior.

#### Changed

- Routed structured editing through `ImageNode` and refined runtime IO so direct work stays on `HarbethIO` while frame, metadata, request and recipe workflows stay on `ImageNode`.
- Unified `ImageNode` instance-chain entry points for editing, geometry, optics, transition and layer composition, retaining static factories only for callers that begin with an `ImageSource`.
- Made sampler execution coverage observable when legacy compute geometry or optics can only honor part of a requested sampling contract.

#### Fixed

- Preserved sample timing, attachments, source identity, alpha and YUV decode contracts across `CVPixelBuffer` / `CMSampleBuffer` frame bridges.
- Normalized `UIImage` orientation during texture loading and readback instead of allowing orientation metadata to diverge from rendered pixels.
- Fixed frame recipes and diagnostics degrading pixel-buffer/sample-buffer sources into anonymous intermediate textures after decoding.

### 2026-06-29 — Render-plan cache correctness (1 commit)

#### Fixed

- Fixed cached render plans retaining stale mutable filter state by separating stable plan identity from per-execution filter values.

### 2026-06-28 — First-frame startup reliability (1 commit)

#### Fixed

- Removed the eager Metal source-fallback scan that could stall the first rendered frame; fallback resolution is now lazy and observable.

### 2026-06-27 — Advanced routes, transitions and pixel-buffer output (7 commits)

#### Added

- Added complete `ImageNode` advanced-route coverage for structured recipes, transitions, layer composition, masks, diagnostics and delivery contracts.
- Added reusable custom transition primitives and a Showcase-oriented Demo presentation while preserving the complete sample catalog.
- Added advanced-route result bundles that expose frame, diagnostics, graph, request and analysis from the same effective node contract.
- Added UIKit validation workbenches and a unified Bento/Glass/Dark Demo navigation system for discovering ImageNode, masks, transitions and the full filter catalog.

#### Changed

- Tightened `ImageNode` planning so the public node remains the source of truth while render plans, cached execution and diagnostics use immutable derived descriptions.

#### Fixed

- Fixed `HarbethIO` pixel-buffer rematerialization so requested output buffers receive rendered pixels instead of stale source storage.
- Fixed transition endpoint continuity so progress 0 and 1 reproduce their respective input frames exactly.
- Fixed advanced routes losing observability or output metadata when execution crossed recipe, layer, mask or deferred-request boundaries.

### 2026-06-24 — Preview-host substrate and cache identity (6 commits)

#### Added

- Added reusable frame-host metadata, preview runtime hints and an internal sample-buffer fallback substrate for texture/frame hosts.
- Added preview decisions for texture-host, sample-buffer passthrough and sample-buffer rematerialization paths, with visible fallback/recovery telemetry rather than silent host switching.
- Added source and replay metadata that let preview hosts preserve orientation, timing, cache identity and original frame semantics while displaying an already-rendered texture.

#### Changed

- Improved `RenderView` sizing, invalidation and host metadata handling while keeping preview hosting inside Harbeth's frame-output boundary.
- Kept `RenderView` and `SampleBufferPreviewHost` texture/frame-first: Harbeth provides display substrate and frame metadata but does not take ownership of capture sessions, players or timelines.

#### Fixed

- Fixed image-source cache fingerprints so distinct source content cannot collide when render plans or frames are replayed.
- Fixed replayed frame requests losing the final node's source, derivative and output contract after intermediate texture materialization.

### 2026-06-23 — ImageNode orchestration, local effects and plugins (11 commits)

#### Added

- Added the `ImageNode` plugin bridge foundation and unified frame-first local-effect rendering with mask-aware composition.
- Added plugin outputs for direct textures, filter chains, edit recipes, local effects and layer-composite recipes, all lowered back into existing `ImageNode` execution instead of creating a separate plugin renderer.
- Added `ImageNode` convenience routes for applying one or many filters inside gradient, shape, path, composite or texture masks.

#### Changed

- Unified editing, mask, transition, layer and filter-pipeline orchestration under `ImageNode`, with instance-chain entry points for existing nodes.
- Consolidated filter and Combination pipeline application so direct, recipe and node routes share the same intensity and ordered-execution semantics.
- Internalized editing implementation filters and kept recipes as public description primitives rather than parallel execution APIs.
- Renamed the masked foreground blend primitive and removed duplicate XOR-specific implementation paths while preserving public mask-composite behavior.

#### Fixed

- Closed synchronous, callback, task and async execution-contract gaps across `ImageNode` and `HarbethIO`.

### 2026-06-22 — Analysis, attachments and color/YUV contracts (11 commits)

#### Added

- Added scoped texture analysis, deferred color probes, histograms, statistics and mask-aware analysis without creating a third public route.
- Added `TextureAnalysisScope` selectors for regions, masks, luminance ranges, RGB component ranges and named tone bands, reusable from textures, frames, attachments and deferred requests.
- Added `RenderedAnalysisBundle` and `RenderedAttachmentAnalysisBundle` with typed lookup, summaries, previews and JSON export for reproducible inspection.
- Added render attachment sets for luminance, mask coverage, clipping and other auxiliary outputs, plus attachment-level analysis.
- Added typed primary/auxiliary color, coverage, mask, luminance, histogram, analysis and debug attachment semantics, plus highlight/shadow clipping and false-color auxiliary render primitives.
- Added explicit color-space conversion, working/output color contracts, alpha contracts and attachment export semantics.
- Added native RGB color-space conversion and debanding primitives for controlled output preparation.
- Added direct bi-planar YCbCr plane bridges and fallback decoding with observable bridge diagnostics.
- Added linear, radial, angular, diamond, reflected, band, ring and multi-stop mask gradients plus rectangle, ellipse, rounded-rectangle, polygon, path and parametric composite-mask recipes.
- Added mask-aware histogram/statistics/probe operations that can derive the same selection as a reusable `MaskDescriptor` for subsequent local effects.

#### Fixed

- Preserved render color and source contracts through attachment, analysis and image readback paths.
- Preserved YCbCr matrix, primaries, transfer function, timing and source attachments through plane-based texture bridges and pixel-buffer rematerialization.

### 2026-06-21 — Harbeth 3.0 render-engine foundation (34 commits)

#### Added

- Added `ImageNode` as the advanced unified source, graph, editing, geometry, optics, mask, transition, composition, request, diagnostics and frame-delivery route.
- Added unified `ImageSource` cases for `C7Image`, `CGImage`, `CIImage`, `MTLTexture`, `CVPixelBuffer`, `CMSampleBuffer`, encoded `Data` and `ImageAsset`, preserving source tier, orientation, alpha, color and cache identity in descriptors.
- Added texture, image, frame, pixel-buffer and encoded PNG/JPEG/TIFF/HEIC delivery surfaces, with `RenderedFrame` retaining source, output, timing, host, replay and attachment metadata.
- Added render profiles for interactive latency, response latency, stable preview, inspection, export and CPU-readback workloads, plus generation tokens for rejecting stale frame results.
- Added lazy `ImageGraph` planning, conservative optimization, stable kernel identity, function constants, render-plan caching and debug snapshots.
- Added deferred `RenderRequest`, cancellable/observable `RenderTask`, graph DOT/JSON diagnostics, replay-base contracts and stable render-cache identities.
- Added reusable pixel-buffer output, output-quality profiles and explicit pixel-format/output-size contracts.
- Added structured `EditRecipe` and `ImageTransformRecipe` support for crop regions, fit/fill sizing, anchored output, rotate, mirror, flip, perspective, guided upright and explicit canvas policies.
- Added single-frame layer composition with ordered layers, transforms, opacity, blend modes, programmable blend functions, masks, corner curves, tint and layer-local filter chains.
- Added transition recipes with explicit from/to sources, progress, kernel identity, auxiliary textures, preview/final profiles and deterministic endpoint behavior.
- Added geometry and optics primitives for 3D transforms, lens distortion, chromatic aberration, vignette, defringe, diffraction and sharpness falloff.
- Added identity-aware image resolution caching and reusable runtime/context ownership through `Shared.shared`.
- Added native RGB transfer conversion, noise reduction, Lanczos resizing, chromatic-aberration, lens-distortion, diffraction, sharpness-falloff, defringe and lens-vignette correction primitives.
- Added native Metal replacements for the previously exposed Core Image filter wrappers and hardened Metal-library fallback resolution.
- Added reusable direct and fallback YCbCr pixel-buffer loading, plane bridge contracts and diagnostics for formats that cannot use a single packed Metal texture.

#### Changed

- Refocused the public model on `HarbethIO` for lightweight direct processing and `ImageNode` for advanced structured processing.
- Moved `ImageNode.transmitFrame(...)` and `makeFrameAsync()` onto the render operation queue so their asynchronous contract no longer renders synchronously on the caller.
- Reworked Combination filters as explicit reusable pipelines instead of product-level look or preset assets.

#### Removed

- Removed the public Core Image filter-wrapper family; `CIImage` remains an accepted source, but processing is performed by Harbeth's Metal runtime.

#### Fixed

- Fixed realtime command-buffer delivery so performance monitoring no longer changes callback timing; texture-first output is delivered only after Metal schedules the work.
- Ensured image and pixel-buffer outputs wait for GPU completion before CPU readback, while scheduled-only realtime delivery remains texture-first.
- Fixed reusable output textures, graph execution, kernel lookup, cache identity, allocator ownership and frame-source contract gaps found while making the new runtime executable.

### 2026-06-20 — Mask alpha correctness (1 commit)

#### Fixed

- Fixed synthetic mask inputs leaking unintended alpha into source-over composition.

## [2.0.1] - 2026-06-12

### Added

- Added `C7AdvancedMetalKernelProtocol` as a reusable abstraction for custom Metal execution with explicit capability checks, advanced encoding and compute fallback behavior.
- Added Metal capability reports for custom encoders, mesh shaders, MetalFX, Metal IO, dynamic libraries, function pointers, ray tracing and sparse textures, with explicit advanced-path availability and compute fallback behavior.

### Changed

- Optimized realtime processing and compute threadgroup sizing across the filter catalog.
- Expanded English and Chinese integration documentation and refreshed Demo examples.

### Fixed

- Fixed input/output texture misalignment during rendering.

## [2.0.0] - 2026-03-26

### Added

- Added render concurrency control, double-buffered processing, command-buffer pooling and expanded texture reuse for realtime workloads.
- Added `C7LocalBlur`, `C7TiltShift`, enhanced sharpen, sticker-outline, enhanced color-burn blend and masked XOR primitives.
- Added Apple Log decoding, channel control, clarity, enhanced color balance, color correction, curves, HSL, temperature, warmth and highlight/shadow tone controls.
- Added 1D and multi-zone LUT processing plus reusable color-grading, creative-atmosphere, cyberpunk, dreamy, film-simulation, HDR-boost and vintage-film Combination filters.
- Added basic render-pipeline filters and MPS Canny support alongside the compute-filter catalog.
- Added Codable support for reusable filter and parameter descriptions.
- Expanded iOS, macOS and SwiftUI Demos with camera, player, curves, HSL, channel, chroma-key and realtime examples.

### Changed

- Reworked the render/filter architecture, texture management and performance monitoring for lower allocation pressure and clearer execution ownership.
- Expanded texture-pool compatibility checks and command-buffer reuse to reduce allocation churn during repeated camera/video frame processing.
- Made shader math safe for HDR extended-range values and removed redundant `[0, 1]` output clamps where they destroyed valid HDR content.

### Fixed

- Fixed crashes and memory-lifetime issues in realtime processing.
- Fixed a priority inversion in the render pipeline.
- Fixed missing Metal resources, Apple Log decoding and Swift type-checker timeouts in `C7LuminanceThreshold`.

[Unreleased]: https://github.com/yangKJ/Harbeth/compare/2.0.1...HEAD
[2.0.1]: https://github.com/yangKJ/Harbeth/compare/2.0.0...2.0.1
[2.0.0]: https://github.com/yangKJ/Harbeth/compare/1.3.1...2.0.0
