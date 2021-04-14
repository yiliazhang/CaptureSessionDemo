//
//  GWCameraManager.h
//  SoamO2OEngineer
//
//  Created by Yilia on 2021/4/6.
//  Copyright © 2021 Goldwind. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol GWCameraManagerDelegate <NSObject>

@optional

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection;

@end

@interface GWCameraManager : NSObject

@property (nonatomic, weak, nullable) id<GWCameraManagerDelegate> delegate;

@property (nonatomic, strong, readonly) AVCaptureVideoPreviewLayer *previewLayer;

@property(nonatomic, readonly) AVCaptureDevice *device;
@property (nonatomic, readonly) AVCaptureSession       *captureSession;
@property (nonatomic, readonly) AVCaptureConnection        *videoConnection;

@property (nonatomic, assign) CGPoint                     focusPoint;
@property (nonatomic, assign) CGFloat                     videoZoom;
@property (nonatomic, assign) CGFloat                     exposureValue;

/// 转换摄像头
- (void)switchCamera;

/// 切换闪光灯
- (void)switchFlash;
- (void)setupCaptureSessionPostion:(AVCaptureDevicePosition) position;
- (void)startCaptureSession;
- (void)stopCaptureSession;
@end

NS_ASSUME_NONNULL_END
