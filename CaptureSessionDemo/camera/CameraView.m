//
//  CameraView.m
//  CaptureSessionDemo
//
//  Created by Yilia on 2021/4/14.
//

#import "CameraView.h"
#import "UIImage+ConversionUtils.h"
#import "Masonry.h"
#import "GWCameraManager.h"

@interface CameraView ()<CameraManagerDelegate, UIGestureRecognizerDelegate>
{
    CGFloat _startLocationY;
    CGFloat _startValue;
    CGFloat _currentZoomFactor;
}

@property (nonatomic, strong) GWCameraManager *cameraManager;

@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, strong) UIPinchGestureRecognizer *pinGesture;

@property (nonatomic,strong) UIImageView *glassesImageView;
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UIImageView *focusImageView;
@property (nonatomic, strong) NSTimer *focusTimer;
/// 绿框
@property (nonatomic, strong) UIView *rectLayer;
///
@property (nonatomic) CGSize size;
@end

@implementation CameraView

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

- (void)setupSubviews {
    [self.layer addSublayer:self.cameraManager.previewLayer];
    //[self addSubview:self.blurView];
    [self addSubview:self.focusImageView];
    self.userInteractionEnabled = YES;
    [self addGestureRecognizer:self.tapGesture];
    
    [self addSubview:self.glassesImageView];
    
    [self.glassesImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.top.equalTo(self);
    }];
    [self addSubview:self.rectLayer];
}

- (void)setupCaptureSessionPostion:(AVCaptureDevicePosition) position {
    [self.cameraManager setupCaptureSessionPostion:position];
}

- (void)startCaptureSession {
    self.glassesImageView.hidden = !self.isShowFaceDetectBorder;
    if (!self.cameraManager.captureSession.isRunning) {
        NSLog(@"captureSession %@", self.cameraManager.captureSession.isRunning ? @"运行中" : @"需启动");
        [self.cameraManager.captureSession startRunning];
    }
}

- (void)stopCaptureSession {
    if (self.cameraManager.captureSession.isRunning) {
        [self.cameraManager.captureSession stopRunning];
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
    AVCaptureDevicePosition position = self.cameraManager.device.position;
    
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
    [self.cameraManager.previewLayer addAnimation:animation forKey:nil];
    [self.cameraManager setupCaptureSessionPostion:toPosition];
}

- (void)switchFlash {
    [self.cameraManager switchFlash];
}

- (void)resetCameraFrame:(CGRect)frame {
    self.blurView.hidden = NO;
    
    [UIView animateWithDuration:0.3
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
    self.cameraManager.previewLayer.frame = self.bounds;
    self.focusImageView.center = CGPointMake(self.bounds.size.width / 2.0, self.bounds.size.height / 2.0);
    self.size = self.bounds.size;
}

- (void)setVideoZoom:(CGFloat)zoom {
    if (self.cameraManager.device.activeFormat.videoMaxZoomFactor > zoom && zoom >= 1.0) {
        [self.cameraManager.device lockForConfiguration:nil];
        [self.cameraManager.device rampToVideoZoomFactor:zoom withRate:4.0];
        [self.cameraManager.device unlockForConfiguration];
    }
    
    if (zoom < 1.0 && self.cameraManager.device.videoZoomFactor >= 1) {
        [self.cameraManager.device lockForConfiguration:nil];
        [self.cameraManager.device rampToVideoZoomFactor:(self.cameraManager.device.videoZoomFactor - zoom) withRate:4.0];
        [self.cameraManager.device unlockForConfiguration];
    }
}

- (void)actionTapGesture:(UITapGestureRecognizer *)sender {
    self.focusImageView.hidden = NO;
    
    CGPoint center = [sender locationInView:sender.view];
    CGFloat xValue = center.y / self.bounds.size.height;
    CGFloat yValue = self.cameraManager.device.position == AVCaptureDevicePositionFront ? (center.x / self.bounds.size.width) : (1 - center.x / self.bounds.size.width);
    self.cameraManager.focusPoint = CGPointMake(xValue,yValue);
    self.focusImageView.center = center;
    self.focusImageView.transform = CGAffineTransformIdentity;
    
    [UIView animateWithDuration:0.3
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
        if (currentZoomFactor < self.cameraManager.device.activeFormat.videoMaxZoomFactor
            && currentZoomFactor > 1.0) {
            [self setVideoZoom:currentZoomFactor];
        }
    }
}

#pragma mark - setter && getter

- (AVCaptureDevice *)captureDeviceWithPosition:(AVCaptureDevicePosition)position {
    AVCaptureDeviceDiscoverySession *deviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:position];
    NSArray *devices  = deviceDiscoverySession.devices;
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}

- (UIVisualEffectView *)blurView {
    if (!_blurView)
    {
        UIBlurEffect * effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        _blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
        _blurView.frame = CGRectMake(0, 0, UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.height);
        _blurView.hidden = YES;
    }
    return _blurView;
}

- (UIImageView *)focusImageView {
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

- (UITapGestureRecognizer *)tapGesture {
    if (!_tapGesture)
    {
        _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(actionTapGesture:)];
    }
    return _tapGesture;
}

- (UIPinchGestureRecognizer *)pinGesture {
    if (!_pinGesture)
    {
        _pinGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(actionPinGesture:)];
        _pinGesture.delegate = self;
    }
    return _pinGesture;
}

- (UIImageView *)glassesImageView {
    if (!_glassesImageView)
    {
        _glassesImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _glassesImageView.contentMode = UIViewContentModeScaleToFill;
        _glassesImageView.image = [UIImage imageNamed:@"icon_renxingkuang"];
    }
    return _glassesImageView;
}

#pragma mark - Gesture
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.pinGesture) {
        _currentZoomFactor = self.cameraManager.device.videoZoomFactor;
    }
    return YES;
}

#pragma mark - Touch
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // _shouldExposureEnable NO时不处理
    if (!_shouldExposureEnable) return;
    
    CGPoint center = [touches.allObjects.lastObject locationInView:self];
    
    _startLocationY = center.y;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
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
    self.cameraManager.exposureValue = exposureValue;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // _shouldExposureEnable NO时不处理
    if (!_shouldExposureEnable) return;
}

- (CGRect)convertRect:(CGRect)boundingBox imageSize:(CGSize)imageSize {
    CGFloat w = boundingBox.size.width * imageSize.width;
    CGFloat h = boundingBox.size.height * imageSize.height;
    CGFloat x = boundingBox.origin.x * imageSize.width;
    CGFloat y = imageSize.height * (1 - boundingBox.origin.y - boundingBox.size.height);
    return CGRectMake(x, y, w, h);
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!self.cameraManager.captureSession.isRunning)
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
        if (connection != self.cameraManager.videoConnection) {
            return;
        }
        CFRetain(sampleBuffer);
        UIImage *image = [UIImage imageNV12FromSampleBuffer:sampleBuffer position:self.position];
        if (!image || image.size.height == 0 || image.size.width == 0) {
            self.rectLayer.hidden = YES;
//            image = nil;
        } else {
            if ([self.delegate respondsToSelector:@selector(captureOutputImage:)]) {
                [self.delegate captureOutputImage:image];
            }
            __weak typeof(self) weakSelf = self;
            [image faceDetectWithViewSize:self.size finish:^(NSString * _Nonnull errorResults, CGRect faceViewBounds) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 是否检测成功
                    weakSelf.rectLayer.frame = faceViewBounds;
                    weakSelf.rectLayer.hidden = NO;
                });
            }];
        }
        
        
        if ([self.delegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)]) {
            [self.delegate captureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection];
        }
        CFRelease(sampleBuffer);
        
    }
}

#pragma mark - Setter

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
    
    if (shouldFocusEnable) {
        [self addGestureRecognizer:self.tapGesture];
    } else {
        [self removeGestureRecognizer:self.tapGesture];
    }
}

- (void)dealloc {
    [self stopCaptureSession];
    NSLog(@"%s", __func__);
}

- (GWCameraManager *)cameraManager {
    if (!_cameraManager) {
        _cameraManager = [[GWCameraManager alloc] init];
        _cameraManager.delegate = self;
    }
    return _cameraManager;
}

- (AVCaptureDevicePosition)position {
    return self.cameraManager.device.position;
}

- (UIView *)rectLayer
{
    if (!_rectLayer)
    {
        _rectLayer = [[UIView alloc] init];
        _rectLayer.layer.borderColor = [UIColor greenColor].CGColor;
        _rectLayer.layer.borderWidth = 1.5;
    }
    return _rectLayer;
}
@end
