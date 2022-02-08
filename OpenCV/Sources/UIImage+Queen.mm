//
//  UIImage+Queen.m
//  MetalQueen
//
//  Created by 77。 on 2021/3/20.
//

#import "UIImage+Queen.h"

#if __has_include(<opencv2/imgcodecs/ios.h>)

#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wdeprecated-declarations"

#include <iostream>
#import <opencv2/imgcodecs/ios.h>
#import <opencv2/core.hpp>
#import <opencv2/highgui.hpp>
#import <opencv2/imgproc.hpp>
#import <opencv2/photo.hpp>

using namespace cv;
using namespace std;
@implementation UIImage (Queen)

#pragma mark - 常用卷积算子
//NS_INLINE cv::Mat kRobertKernel(bool x){
//    if (x) {//X方向，提取左右差异
//        return (Mat_<int>(2,2) << 1, 0, 0, -1);
//    } else {//Y方向，提取上下差异
//        return (Mat_<int>(2,2) << 0, 1, -1, 0);
//    }
//}
//图像边缘提取，求梯度比较常用
//NS_INLINE cv::Mat kSobelKernel(bool x){
//    if (x) {
//        return (Mat_<int>(3,3) << -1, 0, 1, -2, 0, 2, -1, 0, 1);
//    } else {
//        return (Mat_<int>(3,3) << -1, -2, -1, 0, 0, 0, 1, 2, 1);
//    }
//}

#pragma mark - commom method

/// 将C++图片转换为UIImage
NS_INLINE UIImage * kMatToUIImage(const cv::Mat &image) {
    NSData *data = [NSData dataWithBytes:image.data length:image.elemSize()*image.total()];
    CGColorSpaceRef colorSpace;
    if (image.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    bool alpha = image.channels() == 4;
    //kCGImageAlphaPremultipliedLast保留透明度
    CGBitmapInfo bitmapInfo = (alpha ? kCGImageAlphaPremultipliedLast : kCGImageAlphaNone) | kCGBitmapByteOrderDefault;
    CGImageRef imageRef = CGImageCreate(image.cols,
                                        image.rows,
                                        8,
                                        8 * image.elemSize(),
                                        image.step.p[0],
                                        colorSpace,
                                        bitmapInfo,
                                        provider,
                                        NULL,
                                        false,
                                        kCGRenderingIntentDefault);
    UIImage *newImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    return newImage;
}
/// 图片压缩
NS_INLINE void kBitmapChangeImageSize(UIImage **image, CGSize size){
    const size_t width = size.width, height = size.height;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 width,
                                                 height,
                                                 8,
                                                 width * 4,
                                                 space,
                                                 kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (!context) return;
    UIImage *tempImage = *image;
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), tempImage.CGImage);
    UInt8 * data = (UInt8*)CGBitmapContextGetData(context);
    if (!data){
        CGContextRelease(context);
        return;
    }
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    *image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGContextRelease(context);
}
/* 4通道转成3通道 */
NS_INLINE cv::Mat kFourChannelsBecomeThree(const cv::Mat src){
    Mat dst;
    if (src.channels() == 4) {
        cv::cvtColor(src, dst, COLOR_RGBA2RGB);
        return dst;
    }
    return src;
}
/* 最大的轮廓边框 */
NS_INLINE int kMaxContourIndex(std::vector<vector<cv::Point>> contours){
    double max_area = 0;
    int index = -1;
    for (int i = 0; i < contours.size(); i++) {
        double tempArea = contourArea(contours[i]);
        if (tempArea > max_area) {
            max_area = tempArea;
            index = i;
        }
    }
    return index;
}
/* 提升对比度 */
NS_INLINE cv::Mat kPromoteImageContrast(const cv::Mat &dst){
    cv::Mat kernel = kLaplanceKernel(5);// 拉普拉斯算子
    cv::Mat reslut;
    filter2D(dst, reslut, -1, kernel);
    return reslut;
}
//拉普拉斯算子，边缘检测算子
NS_INLINE cv::Mat kLaplanceKernel(int k){
    return (Mat_<int>(3,3) << 0, -1, 0, -1, k, -1, 0, -1, 0);
}

#pragma mark -
/* 图片平铺 */
- (UIImage *)kj_opencvTiledRows:(int)row cols:(int)col{
    cv::Mat src,dst;
    UIImageToMat(self,src,true);
    src = kFourChannelsBecomeThree(src);
    int rows = src.rows,cols = src.cols;
    int new_rows = src.rows * row;
    int new_cols = src.cols * col;
    dst.create(new_rows, new_cols, src.type());
    int channels = src.channels();
    for (int i = 0; i < new_rows; i++){
        for (int j = 0; j < new_cols; j++){
            if (channels == 4) {
                dst.at<Vec3b>(i, j)[0] = src.at<Vec3b>(i%rows, j%cols)[0];
                dst.at<Vec3b>(i, j)[1] = src.at<Vec3b>(i%rows, j%cols)[1];
                dst.at<Vec3b>(i, j)[2] = src.at<Vec3b>(i%rows, j%cols)[2];
                dst.at<Vec3b>(i, j)[3] = src.at<Vec3b>(i%rows, j%cols)[3];
            } else if (channels == 3) {
                dst.at<Vec3b>(i, j)[0] = src.at<Vec3b>(i%rows, j%cols)[0];
                dst.at<Vec3b>(i, j)[1] = src.at<Vec3b>(i%rows, j%cols)[1];
                dst.at<Vec3b>(i, j)[2] = src.at<Vec3b>(i%rows, j%cols)[2];
            } else if (channels == 1) {
                dst.at<uchar>(i, j) = dst.at<uchar>(i%rows, j%cols);
            }
        }
    }
    return kMatToUIImage(dst);
}
/* 根据透视四点透视图片 */
- (UIImage *)kj_opencvWarpPerspectiveWithKnownPoints:(KJKnownPoints)points size:(CGSize)size{
    cv::Mat src,dst;
    UIImageToMat(self,src,true);
    float scale = [UIScreen mainScreen].scale;
    cv::Point2f src_point[] = {
        cv::Point2f(0,0),
        cv::Point2f(self.size.width,0),
        cv::Point2f(self.size.width,self.size.height),
        cv::Point2f(0,self.size.height)
    };
    cv::Point2f dst_point[] = {
        cv::Point2f(points.PointA.x*scale, points.PointA.y*scale),
        cv::Point2f(points.PointB.x*scale, points.PointB.y*scale),
        cv::Point2f(points.PointC.x*scale, points.PointC.y*scale),
        cv::Point2f(points.PointD.x*scale, points.PointD.y*scale)
    };
    cv::Mat transform = getPerspectiveTransform(src_point, dst_point);
    cv::warpPerspective(src, dst, transform, cv::Size(size.width*scale,size.height*scale), cv::INTER_AREA);
    return kMatToUIImage(dst);
}
/* 消除图片高光，beta[0-2],alpha[0-2] */
- (UIImage *)kj_opencvIlluminationChangeBeta:(double)beta alpha:(double)alpha{
    cv::Mat src,gray,mask,dst;
    UIImageToMat(self,src,true);
    src = kFourChannelsBecomeThree(src);
    cv::cvtColor(src, gray, cv::COLOR_BGR2GRAY);
    //得到二值图像
    threshold(gray, mask, 0, 255, THRESH_OTSU);
    
    //消除source中mask锁定的高亮区域，后两个参数0-2调整
    //alpha，beta两个参数共同决定消除高光后图像的模糊程度（范围0~2，0比较清晰，2比较模糊）
    cv::illuminationChange(src, mask, dst, alpha, beta);
    
    for (int i = 0; i < dst.cols; i++){
        for (int j = 0; j < dst.rows; j++){
            if (dst.at<Vec3b>(j, i)[0] == 0) dst.at<Vec3b>(j, i)[0] = 1e-8;
            if (dst.at<Vec3b>(j, i)[1] == 0) dst.at<Vec3b>(j, i)[1] = 1e-8;
            if (dst.at<Vec3b>(j, i)[2] == 0) dst.at<Vec3b>(j, i)[2] = 1e-8;
        }
    }
    dst = kPromoteImageContrast(dst);
    return kMatToUIImage(dst);
}
/* 图片混合，前提条件两张图片必须大小和类型均一致 */
- (UIImage *)kj_opencvBlendImage:(UIImage *)image alpha:(double)alpha{
    if (!CGSizeEqualToSize(self.size, image.size)) {
        kBitmapChangeImageSize(&image, self.size);
    }
    cv::Mat src,src2,dst;
    UIImageToMat(self,src,true);
    UIImageToMat(image,src2,true);
    if (src.type() != src2.type()) {
        return self;
    }
    addWeighted(src, alpha, src2, 1.0-alpha, 0.0, dst);
    
    return kMatToUIImage(dst);
}
/* 调整图片亮度和对比度，contrast[0-100],luminance[0-2] */
- (UIImage *)kj_opencvChangeContrast:(int)contrast luminance:(double)luminance{
    cv::Mat src,dst;
    UIImageToMat(self,src,true);
    src = kFourChannelsBecomeThree(src);
    dst = Mat::zeros(src.size(), src.type());
    int channels = src.channels();
    for (int i = 0; i < src.rows; i++) {
        for (int j = 0; j < src.cols; j++) {
            if (channels == 3) {//rgb
                dst.at<Vec3b>(i, j)[0] = saturate_cast<uchar>(src.at<Vec3b>(i, j)[0] * luminance + contrast);
                dst.at<Vec3b>(i, j)[1] = saturate_cast<uchar>(src.at<Vec3b>(i, j)[1] * luminance + contrast);
                dst.at<Vec3b>(i, j)[2] = saturate_cast<uchar>(src.at<Vec3b>(i, j)[2] * luminance + contrast);
            } else if (channels == 1) {//gray
                dst.at<uchar>(i, j) = saturate_cast<uchar>(src.at<uchar>(i, j) * luminance + contrast);
            }
        }
    }
    return kMatToUIImage(dst);
}
/* 修改图片通道值颜色，r,g,b[0-255] */
- (UIImage *)kj_opencvChangeR:(int)r g:(int)g b:(int)b{
    cv::Mat src,dst;
    UIImageToMat(self,src,true);
    src = kFourChannelsBecomeThree(src);
    dst = Mat::zeros(src.size(), src.type());
    int width = src.rows;
    int height = src.cols;
    int channels = src.channels();
    for (int i = 0; i < width; i++) {
        for (int j = 0; j < height; j++) {
            if (channels == 4) {//rgba
                if (b == -1) b = src.at<Vec3b>(i, j)[0];
                if (g == -1) g = src.at<Vec3b>(i, j)[1];
                if (r == -1) r = src.at<Vec3b>(i, j)[2];
                dst.at<Vec3b>(i, j)[0] = b;
                dst.at<Vec3b>(i, j)[1] = g;
                dst.at<Vec3b>(i, j)[2] = r;
                dst.at<Vec3b>(i, j)[3] = src.at<Vec3b>(i, j)[3];
            } else if (channels == 3) {//rgb
                if (b == -1) b = src.at<Vec3b>(i, j)[0];
                if (g == -1) g = src.at<Vec3b>(i, j)[1];
                if (r == -1) r = src.at<Vec3b>(i, j)[2];
                dst.at<Vec3b>(i, j)[0] = b;
                dst.at<Vec3b>(i, j)[1] = g;
                dst.at<Vec3b>(i, j)[2] = r;
            } else if (channels == 1) {//gray
                dst.at<uchar>(i, j) = r;//src.at<uchar>(i, j);
            }
        }
    }
    return kMatToUIImage(dst);
}
#pragma mark - 滤波模糊板块
/* 模糊处理 */
- (UIImage *)kj_opencvBlurX:(int)x y:(int)y{
    cv::Mat src,dst;
    UIImageToMat(self,src,true);
    //均值滤波处理
    blur(src, dst, cv::Size(x,y));
    return kMatToUIImage(dst);
}
/* 高斯模糊，xy需要正数且为奇数 */
- (UIImage *)kj_opencvGaussianBlurX:(int)x y:(int)y{
    cv::Mat src,dst;
    UIImageToMat(self,src,true);
    //高斯滤波处理，Size高斯内核大小必须为正奇数
    GaussianBlur(src, dst, cv::Size(x,y), 0);
    return kMatToUIImage(dst);
}
/* 中值模糊，可以去掉白色小颗粒，ksize必须为正数且奇数 */
- (UIImage *)kj_opencvMedianBlurksize:(int)ksize{
    cv::Mat src,dst;
    UIImageToMat(self,src,true);
    //中值滤波主要处理椒盐小颗粒
    medianBlur(src, dst, ksize);
    return kMatToUIImage(dst);
}
/* 高斯双边模糊，可以做磨皮美白效果 */
- (UIImage *)kj_opencvBilateralFilterBlurRadio:(int)radio sigma:(int)sigma{
    cv::Mat src,dst;
    UIImageToMat(self,src,true);
    src = kFourChannelsBecomeThree(src);
    //双边滤波器可以很好的保存图像边缘细节而滤除掉低频分量的噪音，
    //sigma<10，则对滤波器影响很小，如果sigma>150则会对滤波器产生较大的影响，会使图片看起来像卡通
    //图像必须是8位或浮点型单通道、三通道的图像
    bilateralFilter(src, dst, radio, sigma, 5);
    
    dst = kPromoteImageContrast(dst);
    return kMatToUIImage(dst);
}
/* 自定义线性模糊 */
- (UIImage *)kj_opencvCustomBlurksize:(int)ksize{
    cv::Mat src,dst;
    UIImageToMat(self,src,true);
    if (!(ksize%2)) ksize++;//保证为奇数
    Mat kernel = Mat::ones(cv::Size(ksize,ksize), CV_32F/(float)(ksize*ksize));
    filter2D(src, dst, -1, kernel);
    return kMatToUIImage(dst);
}

#pragma mark - 图像形态学相关
- (UIImage *)kj_opencvMorphology:(KJOpencvMorphologyStyle)type element:(int)element{
    cv::Mat src,dst;
    UIImageToMat(self,src,true);
    if (src.channels() != 1) {
        Mat gray;
        cvtColor(src, gray, cv::COLOR_BGR2GRAY);
        threshold(gray, src, 0, 255, THRESH_BINARY);//得到二值图像
    }
    if (element <= 1) element = 1;
    cv::Mat kernel = getStructuringElement(MORPH_RECT, cv::Size(element,element));
    int op = MORPH_ERODE;
    switch (type) {
        case KJOpencvMorphologyStyleOPEN:op = MORPH_OPEN;break;//开操作，先腐蚀后膨胀，可以去掉小的对象
        case KJOpencvMorphologyStyleCLOSE:op = MORPH_CLOSE;break;//闭操作，先膨胀后腐蚀，可以填补小洞
        case KJOpencvMorphologyStyleGRADIENT:op = MORPH_GRADIENT;break;//形态学梯度，膨胀减去腐蚀
        case KJOpencvMorphologyStyleTOPHAT:op = MORPH_TOPHAT;break;//顶帽，源图像与开操作之间的差值
        case KJOpencvMorphologyStyleBLACKHAT:op = MORPH_BLACKHAT;break;//黑帽，闭操作与源图像之间的差值
        default:break;
    }
    //形态学操作
    morphologyEx(src, dst, op, kernel);
    return kMatToUIImage(dst);
}

#pragma mark - 综合效果处理
/* 修复图片，可以去水印 */
- (UIImage *)kj_opencvInpaintImage:(int)radius{
    cv::Mat src,dst,gray;
    UIImageToMat(self,src,true);
    src = kFourChannelsBecomeThree(src);
    //转换为灰度图
    cvtColor(src, gray, COLOR_RGB2GRAY);
    Mat mask = Mat(src.size(), CV_8UC1, Scalar::all(0));
    //通过阈值处理生成Mask
    threshold(gray, mask, 235, 255, THRESH_BINARY);
    Mat kernel = getStructuringElement(MORPH_RECT, cv::Size(3, 3));
    //对Mask膨胀处理，增加Mask面积
    dilate(mask, mask, kernel);
    //图像修复
    inpaint(src, mask, dst, radius, INPAINT_TELEA);
    dst = kPromoteImageContrast(dst);
    return kMatToUIImage(dst);
}
double kTransform(double x){
    if (x <= 0.05) return x * 2.64;
    return 1.099 * pow(x, 0.9 / 2.2) - 0.099;
}
struct zxy {
    double x, y, z;
}ks[2500][2500];
/* 图片修复，效果增强处理 */
- (UIImage *)kj_opencvRepairImage{
    cv::Mat src,dst;
    UIImageToMat(self,src,true);
    src = kFourChannelsBecomeThree(src);
    dst = Mat::zeros(src.size(), src.type());
    int rows = src.rows;
    int cols = src.cols;
    double r, g, b;
    double lwmax = -1.0, base = 0.75;
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            b = (double)src.at<Vec3b>(i, j)[0] / 255.0;
            g = (double)src.at<Vec3b>(i, j)[1] / 255.0;
            r = (double)src.at<Vec3b>(i, j)[2] / 255.0;
            ks[i][j].x = (0.4124*r + 0.3576*g + 0.1805*b);
            ks[i][j].y = (0.2126*r + 0.7152*g + 0.0722*b);
            ks[i][j].z = (0.0193*r + 0.1192*g + 0.9505*b);
            lwmax = max(lwmax, ks[i][j].y);
        }
    }
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            double xx = ks[i][j].x / (ks[i][j].x + ks[i][j].y + ks[i][j].z);
            double yy = ks[i][j].y / (ks[i][j].x + ks[i][j].y + ks[i][j].z);
            //修改CIE:X,Y,Z
            ks[i][j].y = log(ks[i][j].y+1)/log(2+8.0*pow((ks[i][j].y/lwmax), log(base)/log(0.5)))/log10(lwmax+1);
            double x = ks[i][j].y / yy*xx;
            double y = ks[i][j].y;
            double z = ks[i][j].y / yy*(1 - xx - yy);
            //转化为用RGB表示
            r =  3.2410*x - 1.5374*y - 0.4986*z;
            g = -0.9692*x + 1.8760*y + 0.0416*z;
            b =  0.0556*x - 0.2040*y + 1.0570*z;
            if (r < 0)r = 0; if (r>1)r = 1;
            if (g < 0)g = 0; if (g>1)g = 1;
            if (b < 0)b = 0; if (b>1)b = 1;
            //修正补偿
            r = kTransform(r);
            g = kTransform(g);
            b = kTransform(b);
            dst.at<Vec3b>(i, j)[0] = int(b * 255);
            dst.at<Vec3b>(i, j)[1] = int(g * 255);
            dst.at<Vec3b>(i, j)[2] = int(r * 255);
        }
    }
    //提升对比度
    dst = kPromoteImageContrast(dst);
    return kMatToUIImage(dst);
}
/* 图像裁剪算法，裁剪出最大内部矩形区域 */
- (UIImage *)kj_opencvCutMaxRegionImage{
    cv::Mat src,dst,gray,binary;
    UIImageToMat(self,src,true);
    //扩大边缘，然后转成灰度图
    copyMakeBorder(src, src, 10,10,10,10, cv::BORDER_CONSTANT, true);
    cv::cvtColor(src, gray, cv::COLOR_BGR2GRAY);
    
    //中值滤波，祛除小颗粒干扰项
    cv::medianBlur(gray, gray, 7);
    
    //二值图像
    threshold(gray, binary, 0, 255, THRESH_BINARY);

    //找到最大轮廓的边界框，
    vector<vector<cv::Point>> contours;
    vector<Vec4i> hierarchy = vector<Vec4i>();
    findContours(binary.clone(), contours, hierarchy, RETR_TREE, CHAIN_APPROX_SIMPLE);//获取轮廓
    int index = kMaxContourIndex(contours);//计算最大轮廓的边界框
    if (index == -1) return self;
    
    //绘制轮廓，用于绘制找到的图像轮廓
    drawContours(binary, contours, index, Scalar(255,0,0));

    //得到轮廓矩形蒙板
    Mat mask = Mat::zeros(binary.size(), CV_8UC1);
    rectangle(mask, cv::boundingRect(contours[index]), cv::Scalar(255, 0, 0), -1);

    Mat minRect = mask.clone(),subRect = mask.clone();
    //while循环，得到满足要求的矩形区域minRect
    while (countNonZero(subRect)) {
        erode(minRect, minRect, Mat());
        subtract(minRect, binary, subRect);
    }
    
    //找出最大轮廓区域，得到包覆此轮廓的最小正矩形
    findContours(minRect.clone(), contours, hierarchy, RETR_TREE, CHAIN_APPROX_SIMPLE);
    cv::Rect resultRect = boundingRect(contours[kMaxContourIndex(contours)]);
    
    dst = Mat(src, resultRect).clone();

    return kMatToUIImage(dst);
}

/* 图片拼接技术，多张类似图合成一张 */
- (UIImage *)kj_opencvCompoundMoreImage:(UIImage *)image,...{
    NSMutableArray<UIImage*>* temps = [NSMutableArray arrayWithObjects:self,image,nil];
    va_list args;UIImage *tempImage;
    va_start(args, image);
    while ((tempImage = va_arg(args, UIImage*))) {
        [temps addObject:tempImage];
    }
    va_end(args);
    std::vector<cv::Mat> imgs;//存放c++图片数组
    for (int i = 0; i < temps.count; i++) {
        cv::Mat src;
        UIImageToMat(temps[i], src);
        src = kFourChannelsBecomeThree(src);
        imgs.push_back(src);
    }
    //3.x
    //Stitcher stitcher = Stitcher::createDefault(false);
    //Mat pano;
    //Stitcher::Status status = stitcher.stitch(imgs, pano);// 使用stitch函数进行拼接
    
    //TODO:
    return self;
}
/* 特征提取，基于Sobel算子 */
- (UIImage *)kj_opencvFeatureExtractionFromSobel{
    cv::Mat src,dst;
    UIImageToMat(self,src,true);
    dst = kSobelFeatureExtraction(src);
    return kMatToUIImage(dst);
}
NS_INLINE cv::Mat kSobelFeatureExtraction(cv::Mat &src){
    cv::Mat gray,dst;
    GaussianBlur(src, dst, cv::Size(3,3), 0);
    cv::cvtColor(dst, gray, cv::COLOR_BGR2GRAY);
    
    cv::Mat xgray,ygray;//获取梯度图
    Sobel(gray, xgray, CV_16S, 1, 0);
    Sobel(gray, ygray, CV_16S, 0, 1);
    //取绝对值
    convertScaleAbs(xgray, xgray);
    convertScaleAbs(ygray, ygray);
    
    cv::Mat xygray;//相加
    addWeighted(xgray, 0.5, ygray, 0.5, 0, xygray);
    
    return xygray;
}
/* 文本类型图片矫正，基于霍夫线判断矫正 */
- (UIImage *)kj_opencvHoughLinesCorrectTextImageFillColor:(UIColor *)color{
    cv::Mat src,dst;
    UIImageToMat(self,src,true);
    
    //基于直线探测的矫正算法思路
    //1.提取边缘信息，
    //2.用霍夫线变换探测出图像中的所有直线
    //3.计算出每条直线的倾斜角，求他们的平均值
    //4.根据倾斜角旋转矫正
    
    double degree = kHoughLinesCalcDegree(src);
    if (abs(degree) < 2) return self;
    
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    //旋转图片
    dst = kRotateImageWarpAffine(src, degree, Scalar(b*255, g*255, r*255, a*255));
    //最大内部矩形区域裁剪
    return kMatToUIImage(dst);
}
//逆时针旋转图像degree角度（原尺寸）
NS_INLINE Mat kRotateImageWarpAffine(Mat src, double degree, Scalar color){
    //扩大一点区域，防止旋转之后超出区域
    copyMakeBorder(src, src, src.rows/10,src.rows/10,src.cols/10,src.cols/10, BORDER_CONSTANT, color);
    Mat dst;
    Point2f center;
    center.x = float(src.cols / 2.0);
    center.y = float(src.rows / 2.0);
    //int length = sqrt(src.cols*src.cols + src.rows*src.rows);
    //计算二维旋转的仿射变换矩阵
    Mat M = getRotationMatrix2D(center, degree, 1);
    warpAffine(src, dst, M, cv::Size(src.cols, src.rows), 1, BORDER_CONSTANT, color);
    return dst;
}
//通过霍夫变换计算角度
NS_INLINE double kHoughLinesCalcDegree(const Mat src){
    Mat cannyImage;
    Canny(src, cannyImage, 50, 200, 3);//边缘检测
    //通过霍夫变换检测直线
    vector<Vec2f> lines;
    int index = 0;
    //由于图像不同，阈值不好设定，因为阈值设定过高导致无法检测直线，阈值过低直线太多，速度很慢
    while (!lines.size()) {
        if (index > 3) break;
        //第5个参数就是阈值，阈值越大，检测精度越高
        HoughLines(cannyImage, lines, 1, CV_PI/180, 300-index*50, 0, 0);
        index++;
    }
    if (!lines.size()) return 0;
    float sum = 0;
    for (int i = 0; i < lines.size(); i++) {
        sum += lines[i][1];
    }
    //对所有角度求平均，这样做旋转效果会更好
    return (sum / lines.size()) / CV_PI * 180 - 90;
}

@end
#pragma clang diagnostic pop
#endif
