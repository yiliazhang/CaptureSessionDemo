//
//  UIImage+ConversionUtils.h
//  GWFaceDetect
//
//  Created by admin on 2020/4/7.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Vision/Vision.h>
NS_ASSUME_NONNULL_BEGIN

/// 图片转换工具类
@interface UIImage (ConversionUtils)


/// CMSampleBufferRef 转换为Image类型
/// @param sampleBuffer 采样信息
//+ (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;


/// CVPixelBufferRef转换为UIImage类型
/// @param pixelBufferRef 像素缓冲池
//+ (UIImage *)imageFromPixelBuffer:(CVPixelBufferRef)pixelBufferRef;
+ (UIImage *)clipWithImageRect:(CGRect)clipRect clipImage:(UIImage *)clipImage;

/// 裁剪图片
/// @param image 图片源数据
/// @param size 需要的图片尺寸
+ (UIImage *)cutoutImage:(UIImage *)image andWithImageSize:(CGSize)size;

/// CMSampleBufferRef 转换为Image类型 并修正图片方向
/// @param sampleBuffer 采样信息
/// @param position 相机方向
//+ (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer position:(AVCaptureDevicePosition)position;
/**
 从图片中按指定的位置大小截取图片的一部分
 @param rect CGRect rect 要截取的区域
 @param scaleX scaleX
 @param scaleY scaleY
 @return UIImage
 */
- (UIImage *)gw_imageInRect:(CGRect)rect scaleX:(CGFloat )scaleX scaleY:(CGFloat )scaleY;

/// nv12 CMSampleBufferRef 转换为Image类型 并修正图片方向
/// @param sampleBuffer 采样信息
/// @param position 相机方向
+ (UIImage *)imageNV12FromSampleBuffer:(CMSampleBufferRef)sampleBuffer position:(AVCaptureDevicePosition)position;

/**
 从图片中按指定的位置大小截取图片的一部分
 @param rect CGRect rect 要截取的区域
 @param scaleX scaleX
 @param scaleY scaleY
 @return UIImage
 */
+ (UIImage *)gw_imageInRect:(CGRect)rect scaleX:(CGFloat )scaleX scaleY:(CGFloat )scaleY;

/// 面部识别
/// @param viewSize 图片真实的显示区域
/// @param finish 识别完成回调(错误信息, 面部方框坐标)
- (void)faceDetectWithViewSize:(CGSize)viewSize finish:(void(^)(NSString *errorResults, CGRect faceViewBounds))finish;

/// Vision框架面部识别，支持iOS11+
/// @param viewSize 图片真实的显示区域
/// @param finish 识别完成回调(面部特征信息对象, 错误信息, 面部方框坐标)
- (void)visionFaceDetectWithViewSize:(CGSize)viewSize finish:(void (^)(VNFaceObservation *observation, NSString *errorResults, CGRect faceViewBounds))finish;
@end

NS_ASSUME_NONNULL_END
