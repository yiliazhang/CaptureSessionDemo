//
//  CameraView.h
//  CaptureSessionDemo
//
//  Created by Yilia on 2021/4/14.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
NS_ASSUME_NONNULL_BEGIN
@class CameraView;

@protocol CameraViewDelegate <NSObject>
@optional
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;
@end

@interface CameraView : UIView

@property (nonatomic, weak, nullable) id<CameraViewDelegate> delegate;
/// 摄像头位置
@property (nonatomic, assign, readonly) AVCaptureDevicePosition position;

/// 是否显示边框
@property(nonatomic, assign) BOOL isShowFaceDetectBorder;

/// 要裁剪图片比例
@property (nonatomic, assign) CGSize cutoutImageSize;

/// 是否捏合缩放,默认NO
@property (nonatomic, assign) BOOL shouldScaleEnable;

/// 是否点击为聚焦点, 默认YES
@property (nonatomic, assign) BOOL shouldFocusEnable;

/// 是否上下滑修改曝光值, 默认YES
@property (nonatomic, assign) BOOL shouldExposureEnable;

/// 聚焦点图片, 如果需要设置的赋值, 否则使用默认
@property (nonatomic, strong) UIImage *focusImage;

/// 转换摄像头
- (void)switchCamera;

/// 切换闪光灯
- (void)switchFlash;
/**
  重置坐标
  重置时有动画, 并且有蒙层过度坐标转换
 */

- (void)startCaptureSession;
- (void)stopCaptureSession;
- (void)setupCaptureSessionPostion:(AVCaptureDevicePosition) position;
@end

NS_ASSUME_NONNULL_END
