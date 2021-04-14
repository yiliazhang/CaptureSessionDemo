//
//  GWArcFaceCameraView.m
//  GWFaceDetect
//
//  Created by admin on 2020/4/1.
//

#import "GWArcFaceCameraView.h"
#import "UIImage+ConversionUtils.h"
#import "Masonry.h"

/// 动画间隔
static CGFloat GWArcFaceCameraAnimationDuration = 0.3;

@interface GWArcFaceCameraView ()<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, UIGestureRecognizerDelegate>
{
    CGFloat _startLocationY;
    CGFloat _startValue;
    CGFloat _currentZoomFactor;
}
///

@property (nonatomic, strong) AVCaptureSession           *captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput       *deviceInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput   *dataOutput;
@property (nonatomic, strong) AVCaptureConnection        *videoConnection;
@property (nonatomic, assign) AVCaptureVideoOrientation   videoOrientation;
@property (nonatomic, strong) dispatch_queue_t            videoCaptureQueue;

@property (nonatomic, assign) CGPoint                     focusPoint;
@property (nonatomic, assign) CGFloat                     exposureValue;


@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, strong) UITapGestureRecognizer      *tapGesture;
@property (nonatomic, strong) UIPinchGestureRecognizer    *pinGesture;

@property (nonatomic,strong) UIImageView *glassesImageView;
@property (nonatomic, strong) UIVisualEffectView          *blurView;
@property (nonatomic, strong) UIImageView                 *focusImageView;

@property (nonatomic, strong) NSTimer                     *focusTimer;

@end
@implementation GWArcFaceCameraView

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupSubviews];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupSubviews];
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

- (void)setupSubviews {
    
    UIInterfaceOrientation uiOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    self.videoOrientation = (AVCaptureVideoOrientation)uiOrientation;
    //        self.isShowFaceDetectBorder = YES;
    self.shouldExposureEnable = NO;
    [self.layer addSublayer:self.previewLayer];
    //[self addSubview:self.blurView];
    [self addSubview:self.focusImageView];
    self.userInteractionEnabled = YES;
    [self addGestureRecognizer:self.tapGesture];
    
    [self addSubview:self.glassesImageView];
    
    [self.glassesImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.top.equalTo(self);
    }];
}

- (void)startCapture {
    self.glassesImageView.hidden = !self.isShowFaceDetectBorder;
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
    [self.previewLayer addAnimation:animation forKey:nil];
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

- (void)resetCameraFrame:(CGRect)frame {
    self.blurView.hidden = NO;
    
    [UIView animateWithDuration:GWArcFaceCameraAnimationDuration
                          delay:0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
        self.frame = frame;
    } completion:^(BOOL finished) {
        if (finished) {
            self.blurView.hidden = YES;
        }
    }];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.previewLayer.frame = self.bounds;
    self.focusImageView.center = CGPointMake(self.bounds.size.width / 2.0, self.bounds.size.height / 2.0);
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

- (void)actionTapGesture:(UITapGestureRecognizer *)sender {
    self.focusImageView.hidden = NO;
    
    CGPoint center = [sender locationInView:sender.view];
    CGFloat xValue = center.y / self.bounds.size.height;
    CGFloat yValue = self.deviceInput.device.position == AVCaptureDevicePositionFront ? (center.x / self.bounds.size.width) : (1 - center.x / self.bounds.size.width);
    self.focusPoint = CGPointMake(xValue,yValue);
    self.focusImageView.center = center;
    self.focusImageView.transform = CGAffineTransformIdentity;
    
    [UIView animateWithDuration:GWArcFaceCameraAnimationDuration
                          delay:0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
        self.focusImageView.transform = CGAffineTransformMakeScale(0.67, 0.67);
    } completion:nil];
    
    [self hidenFocusImageView];
}

- (void)hidenFocusImageView {
    [self.focusTimer invalidate];
    
    self.focusTimer = [NSTimer timerWithTimeInterval:2.5 repeats:NO block:^(NSTimer * _Nonnull timer) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.focusImageView.hidden = YES;
            // self.lightView.hidden = YES;
            [timer invalidate];
        });
    }];
    
    [[NSRunLoop mainRunLoop] addTimer:self.focusTimer forMode:NSDefaultRunLoopMode];
}

- (void)actionPinGesture:(UIPinchGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan || sender.state == UIGestureRecognizerStateChanged) {
        CGFloat currentZoomFactor = _currentZoomFactor * sender.scale;
        if (currentZoomFactor < self.deviceInput.device.activeFormat.videoMaxZoomFactor
            && currentZoomFactor > 1.0) {
            [self setVideoZoom:currentZoomFactor];
        }
    }
}

#pragma mark - setter && getter
- (AVCaptureVideoPreviewLayer *)previewLayer
{
    if (!_previewLayer)
    {
        _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
        [_previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
        _previewLayer.frame = self.bounds;
    }
    return _previewLayer;
}

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

- (UIVisualEffectView *)blurView
{
    if (!_blurView)
    {
        UIBlurEffect * effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        _blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
        _blurView.frame = CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height);
        _blurView.hidden = YES;
    }
    return _blurView;
}

- (UIImageView *)focusImageView
{
    if (!_focusImageView)
    {
        _focusImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"camera_focus"]];
        _focusImageView.contentMode = UIViewContentModeScaleAspectFit;
        _focusImageView.frame = CGRectMake(0, 0, 70, 70);
        _focusImageView.center = CGPointMake(self.bounds.size.width / 2.0, self.bounds.size.height / 2.0);
        _focusImageView.hidden = YES;
    }
    return _focusImageView;
}

- (UITapGestureRecognizer *)tapGesture
{
    if (!_tapGesture)
    {
        _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(actionTapGesture:)];
    }
    return _tapGesture;
}

- (UIPinchGestureRecognizer *)pinGesture
{
    if (!_pinGesture)
    {
        _pinGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(actionPinGesture:)];
        _pinGesture.delegate = self;
    }
    return _pinGesture;
}

- (UIImageView *)glassesImageView
{
    if (!_glassesImageView)
    {
        _glassesImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _glassesImageView.contentMode = UIViewContentModeScaleToFill;
        _glassesImageView.image = [UIImage imageNamed:@"icon_renxingkuang"];
    }
    return _glassesImageView;
}

#pragma mark - Gesture
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if (gestureRecognizer == self.pinGesture) {
        _currentZoomFactor = self.deviceInput.device.videoZoomFactor;
    }
    return YES;
}

#pragma mark - Touch
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    // _shouldExposureEnable NO时不处理
    if (!_shouldExposureEnable) return;
    
    CGPoint center = [touches.allObjects.lastObject locationInView:self];
    
    _startLocationY = center.y;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    // _shouldExposureEnable NO时不处理
    if (!_shouldExposureEnable) return;
    
    CGPoint movePoint = [touches.allObjects.lastObject locationInView:self];
    CGFloat movePointY = movePoint.y - _startLocationY;
    CGFloat height = CGRectGetHeight(self.bounds) / 2.0;
    CGFloat scale = movePointY / height;
    CGFloat value = _startValue + scale;
    if (value <= 0 ) value = 0;
    if (value >= 1) value = 1;
    
    // 0 - 1的范围改成 (-2, 2)
    CGFloat exposureValue = value - 1;
    if (value < 0.5) {
        exposureValue = (0.5 - value) * -4;
    } else {
        exposureValue = (value - 0.5) * 4;
    }
    self.exposureValue = exposureValue;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    // _shouldExposureEnable NO时不处理
    if (!_shouldExposureEnable) return;
}

- (CGRect)convertRect:(CGRect)boundingBox imageSize:(CGSize)imageSize
{
    CGFloat w = boundingBox.size.width * imageSize.width;
    CGFloat h = boundingBox.size.height * imageSize.height;
    CGFloat x = boundingBox.origin.x * imageSize.width;
    CGFloat y = imageSize.height * (1 - boundingBox.origin.y - boundingBox.size.height);//- (boundingBox.origin.y * imageSize.height) - h;
    return CGRectMake(x, y, w, h);
}

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

- (void)setFocusImage:(UIImage *)focusImage {
    _focusImage = focusImage;
    self.focusImageView.image = focusImage;
}

- (void)setShouldScaleEnable:(BOOL)shouldScaleEnable {
    _shouldScaleEnable = shouldScaleEnable;
    
    if (shouldScaleEnable) {
        [self addGestureRecognizer:self.pinGesture];
    } else {
        [self removeGestureRecognizer:self.pinGesture];
    }
}

- (void)setShouldFocusEnable:(BOOL)shouldFocusEnable {
    _shouldFocusEnable = shouldFocusEnable;
    
    if (shouldFocusEnable)
    {
        [self addGestureRecognizer:self.tapGesture];
    }
    else
    {
        [self removeGestureRecognizer:self.tapGesture];
    }
}

- (AVCaptureTorchMode)flashMode
{
    return self.deviceInput.device.torchMode;
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

@end
