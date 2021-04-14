//
//  GWCameraManager.m
//  SoamO2OEngineer
//
//  Created by Yilia on 2021/4/6.
//  Copyright © 2021 Goldwind. All rights reserved.
//

#import "GWCameraManager.h"
#import <UIKit/UIKit.h>

@interface GWCameraManager ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate
>
///
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, strong) AVCaptureSession           *captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput       *deviceInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput   *dataOutput;
@property (nonatomic, strong) AVCaptureConnection        *videoConnection;
@property (nonatomic, assign) AVCaptureVideoOrientation   videoOrientation;
@property (nonatomic, strong) dispatch_queue_t            videoCaptureQueue;
@end
@implementation GWCameraManager
- (instancetype)init
{
    self = [super init];
    if (self) {
        [self config];
    }
    return self;
}


- (AVCaptureVideoDataOutput *)videoDataOutput {
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    [captureOutput setAlwaysDiscardsLateVideoFrames:YES];
#ifdef __OUTPUT_BGRA__
    NSDictionary *dic = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
#else
    NSDictionary *dic = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
#endif
    [captureOutput setVideoSettings:dic];
//    dispatch_queue_t videoCaptureQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    [captureOutput setSampleBufferDelegate:self queue:self.videoCaptureQueue];
    return captureOutput;
}

- (void)setupCaptureSessionPostion:(AVCaptureDevicePosition) position {
    [self.captureSession beginConfiguration];
    if (self.deviceInput) {
        [self.captureSession removeInput:self.deviceInput];
    }
    self.deviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self cameraWithPosition:position] error:nil];
    if ([self.captureSession canAddInput:self.deviceInput]) {
        [self.captureSession addInput:self.deviceInput];
    }
    if (self.dataOutput) {
        [self.dataOutput setSampleBufferDelegate:nil queue:self.videoCaptureQueue];
        [self.captureSession removeOutput:self.dataOutput];
    }
    self.dataOutput = [self videoDataOutput];
    
    if ([self.captureSession canAddOutput:self.dataOutput])
    {
        [self.captureSession addOutput:self.dataOutput];
    }
    self.videoConnection = [self.dataOutput connectionWithMediaType:AVMediaTypeVideo];
    
    if (self.videoConnection.supportsVideoMirroring) {
        [self.videoConnection setVideoMirrored:YES];
    }
    
    if ([self.videoConnection isVideoOrientationSupported]) {
        [self.videoConnection setVideoOrientation:self.videoOrientation];
    }
    
    [self.captureSession commitConfiguration];
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices  = [self captureDevices];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}

- (NSArray<AVCaptureDevice *> *)captureDevices {
    AVCaptureDeviceDiscoverySession *deviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
    return deviceDiscoverySession.devices;
}

- (AVCaptureSession *)captureSession {
    if (!_captureSession)
    {
        _captureSession = [[AVCaptureSession alloc] init];
        _captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    }
    return _captureSession;
}


- (void)startCaptureSession {
    [self startCapture];
}

- (void)stopCaptureSession {
    [self stopCapture];
}

- (void)config {
    UIInterfaceOrientation uiOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    self.videoOrientation = (AVCaptureVideoOrientation)uiOrientation;
}

- (void)startCapture {
//    self.glassesImageView.hidden = !self.isShowFaceDetectBorder;
    if (!self.captureSession.isRunning) {
        NSLog(@"captureSession %@", self.captureSession.isRunning ? @"运行中" : @"需启动");
        [self.captureSession startRunning];
    }
}

- (void)stopCapture {
    if (self.captureSession.isRunning) {
        [self.captureSession stopRunning];
        self.captureSession = nil;
    }
}
/**
 切换摄像头按钮的点击方法的实现（切换摄像头时可以添加转场动画）
 */
- (void)switchCamera {
    //获取摄像头的数量（该方法会返回当前能够输入视频的全部设备，包括前后摄像头和外接设备）
    AVCaptureDeviceDiscoverySession *deviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified];
    NSInteger cameraCount = deviceDiscoverySession.devices.count;
    //摄像头的数量小于等于1的时候直接返回
    if (cameraCount <= 1) {
        return;
    }
    //获取当前相机的方向（前/后）
    AVCaptureDevicePosition position = self.deviceInput.device.position;
    
    //为摄像头的转换加转场动画
    CATransition *animation = [CATransition animation];
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.duration = 0.5;
    animation.type = @"oglFlip";
    AVCaptureDevicePosition toPosition = AVCaptureDevicePositionFront;
    if (position == AVCaptureDevicePositionFront) {
        toPosition = AVCaptureDevicePositionBack;
        animation.subtype = kCATransitionFromLeft;
        
    }else if (position == AVCaptureDevicePositionBack){
        toPosition = AVCaptureDevicePositionFront;
        animation.subtype = kCATransitionFromRight;
    }
    [self setupCaptureSessionPostion:toPosition];
}

- (void)switchFlash {
    AVCaptureTorchMode newMode = AVCaptureTorchModeOff;
    if (self.deviceInput.device.torchMode == AVCaptureTorchModeOff) {
        newMode = AVCaptureTorchModeAuto;
    } else if (self.deviceInput.device.torchMode == AVCaptureTorchModeAuto) {
        newMode = AVCaptureTorchModeOn;
    } else {
        newMode = AVCaptureTorchModeOff;
    }
    
    [self.deviceInput.device lockForConfiguration:nil];
    self.deviceInput.device.torchMode = newMode;
    [self.deviceInput.device unlockForConfiguration];
}

- (void)setVideoZoom:(CGFloat)zoom {
    if (self.deviceInput.device.activeFormat.videoMaxZoomFactor > zoom && zoom >= 1.0) {
        [self.deviceInput.device lockForConfiguration:nil];
        [self.deviceInput.device rampToVideoZoomFactor:zoom withRate:4.0];
        [self.deviceInput.device unlockForConfiguration];
    }
    
    if (zoom < 1.0 && self.deviceInput.device.videoZoomFactor >= 1) {
        [self.deviceInput.device lockForConfiguration:nil];
        [self.deviceInput.device rampToVideoZoomFactor:(self.deviceInput.device.videoZoomFactor - zoom) withRate:4.0];
        [self.deviceInput.device unlockForConfiguration];
    }
}

- (CGFloat)videoZoom {
//    return self.deviceInput.device.videoZoomFactor;
    return self.deviceInput.device.activeFormat.videoMaxZoomFactor;
}

- (void)resetFocusAndExposure {
    AVCaptureFocusMode focusMode = AVCaptureFocusModeContinuousAutoFocus;
    BOOL canResetFocus = [self.deviceInput.device isFocusPointOfInterestSupported] && [self.deviceInput.device isFocusModeSupported:focusMode];
    
    AVCaptureExposureMode exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    BOOL canResetExposure = [self.deviceInput.device isExposurePointOfInterestSupported] && [self.deviceInput.device isExposureModeSupported:exposureMode];
    
    CGPoint centerPoint = CGPointMake(0.5f, 0.5f);
    
    if (![self.deviceInput.device lockForConfiguration:nil]) return;
    if (canResetFocus) {
        self.deviceInput.device.focusMode = focusMode;
    }
    if (canResetExposure) {
        self.deviceInput.device.exposureMode = exposureMode;
        self.deviceInput.device.exposurePointOfInterest = centerPoint;
    }
    [self.deviceInput.device unlockForConfiguration];
}

#pragma mark - setter && getter

- (AVCaptureDevice *)captureDeviceWithPosition:(AVCaptureDevicePosition)position
{
    AVCaptureDeviceDiscoverySession *deviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:position];
    NSArray *devices  = deviceDiscoverySession.devices;
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}

#pragma mark - Gesture

#pragma mark - Touch

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (!self.captureSession.isRunning)
    {
        return;
    }
    if (!sampleBuffer) {
        return;
    }
    if (!_delegate) {
        return;
    }
    @autoreleasepool {
        CFRetain(sampleBuffer);
        if (connection == self.videoConnection) {
            if ([self.delegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
                [self.delegate captureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection];
            }
            CFRelease(sampleBuffer);
        }
    }
}

#pragma mark - Setter
- (void)setFocusPoint:(CGPoint)focusPoint {
    _focusPoint = focusPoint;
    
    if (!self.deviceInput.device.focusPointOfInterestSupported) return;
    if (![self.deviceInput.device lockForConfiguration:nil]) return;
    self.deviceInput.device.focusPointOfInterest = focusPoint;
    self.deviceInput.device.focusMode = AVCaptureFocusModeAutoFocus;
    [self.deviceInput.device unlockForConfiguration];
}

- (void)setExposureValue:(CGFloat)exposureValue {
    _exposureValue = exposureValue;
    
    if (![self.deviceInput.device lockForConfiguration:nil]) return;
    self.deviceInput.device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    [self.deviceInput.device setExposureTargetBias:exposureValue completionHandler:nil];
    [self.deviceInput.device unlockForConfiguration];
}
- (dispatch_queue_t)videoCaptureQueue
{
    if (!_videoCaptureQueue)
    {
        _videoCaptureQueue = dispatch_queue_create("com.faceDectCamera.videoCaptureQueue", NULL);
    }
    return _videoCaptureQueue;
}
- (void)dealloc
{
    [self stopCapture];
    NSLog(@"%s", __func__);
}

- (AVCaptureDevice *)device {
    return self.deviceInput.device;
}

- (AVCaptureVideoPreviewLayer *)previewLayer
{
    if (!_previewLayer)
    {
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
        [_previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    }
    return _previewLayer;
}
@end
