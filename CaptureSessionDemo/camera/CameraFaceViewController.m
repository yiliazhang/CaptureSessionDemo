//
//  CameraFaceViewController.m
//  CaptureSessionDemo
//
//  Created by Yilia on 2021/4/14.
//

#import "CameraFaceViewController.h"
#import <Vision/Vision.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <Masonry.h>
#import "UIImage+ConversionUtils.h"
#import "CameraView.h"
@interface CameraFaceViewController ()<CameraViewDelegate, UIGestureRecognizerDelegate>
/// 关闭视图控制器
@property(nonatomic, strong) UIButton *closeButton;

/// 提示
@property(nonatomic, strong) UIButton *promoteButton;

/// 提示信息 label
@property(nonatomic, strong) UILabel *promptLabel;

/// 拍照的图片
@property(nonatomic, strong) UIImageView *photoImageView;

/// 拍照按钮背景
@property(nonatomic, strong) UIView *shootingBGView;

/// 拍照
@property(nonatomic, strong) UIButton *shootingButton;

/// 拍摄完成的对号
@property(nonatomic, strong) UIButton *confirmButton;

/// 重新拍摄
@property(nonatomic, strong) UIButton *reShootButton;

/// 切换摄像头
@property(nonatomic, strong) UIButton *switchButton;

/// 面部检测错误结果
@property(nonatomic, strong) NSString *errorResults;

/// 绿框
@property (nonatomic, strong) UIView *rectLayer;
/// 相机视图
@property(nonatomic, strong) UIView *cameraView;
/// 相机视图
@property(nonatomic, strong) UIImage *lastImage;
///
@property (nonatomic) CGSize size;
@property (strong, nonatomic) CameraView *faceCameraView;
@end

@implementation CameraFaceViewController

static CGFloat const kDetectFaceWidth = 355.0;

static CGFloat const kDetectFaceHeight = 384.0;

#define IMAGE_WIDTH     720
#define IMAGE_HEIGHT    1280

#define LOCK() dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER)
#define UNLOCK() dispatch_semaphore_signal(self->_lock)

+ (void)showFromViewController:(UINavigationController *)navigationController
         uploadCompletionBlock:(void (^ __nullable)(NSString *mediaID))uploadCompletionBlock {
    CameraFaceViewController *viewController = [[CameraFaceViewController alloc] init];
    viewController.uploadCompletionBlock = uploadCompletionBlock;
    [navigationController pushViewController:viewController animated:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.size = self.cameraView.frame.size;
    [self.faceCameraView startCaptureSession];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [self.faceCameraView stopCaptureSession];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.faceCameraView setupCaptureSessionPostion:AVCaptureDevicePositionFront];
    // UI 初始化
    [self setupUIs];
}

#pragma mark - public methods

#pragma mark - system delegate && datasource

#pragma mark - custom delegate

/// 本地采集提示
- (void)promoteButtonAction:(id)sender {
//    GWFaceInfoCollectAlertViewController *faceInfoCollectAlertViewController = [[GWFaceInfoCollectAlertViewController alloc] initWithTitle:@"本地采集" andContent:@"将符合人脸识别质量要求的人脸照片采集到本地，再通过其他应用提交给相应的管理员，由其将人脸照片录入系统。" andEnterTitle:@"确定" enterCallback:^{
//    } andCancelTitle:@"" cancelCallback:^{
//    }];
//    [faceInfoCollectAlertViewController showViewController:self];
}

#pragma mark - event && response

#pragma mark - private methods

// UI 初始化
- (void)setupUIs
{
    self.view.backgroundColor = [UIColor orangeColor];
    [self.view addSubview:self.promoteButton];
    [self.view addSubview:self.promptLabel];
    [self.view addSubview:self.cameraView];
    [self.view insertSubview:self.photoImageView aboveSubview:self.cameraView];
    [self.view addSubview:self.shootingBGView];
    [self.view addSubview:self.shootingButton];
    [self.view addSubview:self.reShootButton];
    [self.view addSubview:self.switchButton];
    [self.view insertSubview:self.confirmButton aboveSubview:self.shootingButton];
    [self.view addSubview:self.closeButton];
    
    [self.closeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view.mas_left).offset(10);
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(10);
        make.width.height.equalTo(@80);
    }];
    
    [self.promoteButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.view.mas_right).offset(-20);
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(10);
        make.width.height.equalTo(@80);
    }];
    
    self.promoteButton.hidden = YES;
    
    [self.promptLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view.mas_left).offset(10);
        make.right.equalTo(self.view.mas_right).offset(-10);
        make.top.equalTo(self.closeButton.mas_bottom).offset(35);
        make.height.equalTo(@40);
    }];
    
    [self.cameraView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.promptLabel.mas_bottom).offset(10);
        make.width.equalTo(@(kDetectFaceWidth));
        make.height.equalTo(@(kDetectFaceHeight));
        make.centerX.equalTo(self.view.mas_centerX);
    }];
    
    [self.photoImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.promptLabel.mas_bottom).offset(10);
        make.width.equalTo(@246);
        //        make.height.equalTo(@296);
        make.center.equalTo(self.cameraView);
    }];
    
    [self.shootingBGView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-32);
        make.width.height.equalTo(@80);
    }];
    
    [self.shootingButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.shootingBGView);
        make.width.height.equalTo(@80);
    }];
    
    [self.confirmButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.shootingButton.mas_right);
        make.centerY.equalTo(self.shootingButton);
        make.width.height.equalTo(self.shootingButton);
    }];
    
    [self.reShootButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.shootingBGView);
        make.left.equalTo(@20);
        make.width.height.equalTo(@80);
    }];
    
    // 切换摄像头暂时图片方向有问题
    [self.switchButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.shootingBGView);
        make.right.equalTo(self.view).offset(-20);
        make.width.equalTo(self.reShootButton);
        make.height.equalTo(self.reShootButton);
    }];
    [self.cameraView addSubview:self.faceCameraView];
    [self.faceCameraView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.cameraView);
    }];
}

- (void)closeButtonAction:(UIButton *)sender
{
    [self.faceCameraView stopCaptureSession];
    if (self.uploadCompletionBlock) {
        self.uploadCompletionBlock(@"");
    }
}

/// 拍照
- (void)shootingButtonAction:(UIButton *)sender
{
    self.rectLayer.hidden = YES;
    if (!self.lastImage) {
        NSLog( @"未检测到有效人脸信息");
        return;
    }
    UIImage *image = self.lastImage;
    __weak typeof(self) weakSelf = self;
    
    [self.lastImage faceDetectWithViewSize:self.cameraView.frame.size finish:^(NSString * _Nonnull errorResults, CGRect faceViewBounds) {
#if DEBUG
        
#else
        // 判断时候有检测错误数据
        if ([NSString isNonNullValid:errorResults]) {
            NSLog(errorResults);
            return;
        }
#endif
        NSLog(@"take photo---------1");
        weakSelf.confirmButton.hidden = NO;
        weakSelf.reShootButton.hidden = NO;
        weakSelf.switchButton.hidden = YES;
        [weakSelf faceDectDidTakePhoto: image];
    }];
    
}

/// 重拍
- (void)reShootButtonAction:(UIButton *)sender
{
    self.lastImage = nil;
    self.rectLayer.hidden = YES;
    // 初始化结果
    self.errorResults = @"";
    // 隐藏拍摄结果
    self.confirmButton.hidden = YES;
    self.reShootButton.hidden = YES;
    self.switchButton.hidden = NO;
    self.photoImageView.image = nil;
    self.cameraView.hidden = NO;
}

/// 确定拍摄完成提交或者保存到相册事件
- (void)shootedBtnAction:(UIButton *)sender
{
    UIImage *image = self.photoImageView.image;
    if (!image)
    {
        NSLog(@"未检测到有效人脸信息");
        [self reShootButtonAction:sender];
        return;
    }
//    [self shootedImage:image localCollect:NO];
    if (self.uploadCompletionBlock) {
        self.uploadCompletionBlock(@"asdfasdfas");
    }
}


/**
 拍照回调
 @param photo 照片
 */
- (void)faceDectDidTakePhoto:(UIImage *)photo
{
    // 单击拍照回调
    [photo faceDetectWithViewSize:self.cameraView.frame.size finish:^(NSString * _Nonnull errorResults, CGRect faceViewBounds) {
        // 是否检测成功
        UIImage *photoImg = photo;
        self.cameraView.hidden = YES;
        if (faceViewBounds.size.width == 0
            || faceViewBounds.size.height == 0
            )
        {
            self.photoImageView.image = nil;
            self.cameraView.hidden = NO;
            // 没有虹软人脸特征
            NSLog(@"无法获取人脸特征，请重新拍摄");
            [self reShootButtonAction:nil];
        } else {
            CGRect modifiedBounds = CGRectInset(faceViewBounds, -20, -20);
            CGFloat scaleX = kDetectFaceWidth/photo.size.width;
            CGFloat scaleY = kDetectFaceHeight/(photo.size.height - 100);
            photoImg = [photo gw_imageInRect:modifiedBounds scaleX:scaleX scaleY:scaleY];
            self.photoImageView.image = photoImg;
        }
    }];
}

- (UIButton *)closeButton
{
    if (!_closeButton)
    {
        _closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_closeButton setTitle:@"关闭" forState:UIControlStateNormal];
        [_closeButton addTarget:self action:@selector(closeButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _closeButton;
}

- (UIButton *)promoteButton
{
    if (!_promoteButton)
    {
        _promoteButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_promoteButton setImage:[UIImage imageNamed:@"icon_xiangqing"] forState:UIControlStateNormal];
        _promoteButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_promoteButton addTarget:self action:@selector(promoteButtonAction:) forControlEvents:UIControlEventTouchUpInside];
        _promoteButton.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
        _promoteButton.imageEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
    }
    return _promoteButton;
}

- (UIView *)shootingBGView
{
    if (!_shootingBGView)
    {
        _shootingBGView = [[UIView alloc] init];
        _shootingBGView.backgroundColor = [[UIColor orangeColor] colorWithAlphaComponent:0.1];
        _shootingBGView.layer.cornerRadius = 34;
        _shootingBGView.layer.masksToBounds = YES;
    }
    return _shootingBGView;
}

- (UIButton *)shootingButton
{
    if (!_shootingButton)
    {
        _shootingButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_shootingButton setTitle:@"拍摄" forState:UIControlStateNormal];
        [_shootingButton addTarget:self action:@selector(shootingButtonAction:) forControlEvents:UIControlEventTouchUpInside];
        _shootingButton.layer.cornerRadius = 25;
        _shootingButton.layer.masksToBounds = YES;
        _shootingButton.backgroundColor = [UIColor redColor];
    }
    return _shootingButton;
}

/// 拍摄完成的对号
- (UIButton *)confirmButton
{
    if (!_confirmButton)
    {
        _confirmButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_confirmButton setTitle:@"确定" forState:UIControlStateNormal];
        _confirmButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_confirmButton addTarget:self action:@selector(shootedBtnAction:) forControlEvents:UIControlEventTouchUpInside];
        _confirmButton.hidden = YES;
    }
    return _confirmButton;
}

/// 重新拍摄
- (UIButton *)reShootButton
{
    if (!_reShootButton)
    {
        _reShootButton = [[UIButton alloc] init];
        [_reShootButton setTitle:@"重新拍摄" forState:UIControlStateNormal];
        [_reShootButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _reShootButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_reShootButton addTarget:self action:@selector(reShootButtonAction:) forControlEvents:UIControlEventTouchUpInside];
        _reShootButton.hidden = YES;
    }
    return _reShootButton;
}

- (UIButton *)switchButton
{
    if (!_switchButton)
    {
        _switchButton = [[UIButton alloc] init];
        [_switchButton setTitle:@"前后切换" forState:UIControlStateNormal];
        [_switchButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        _switchButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_switchButton addTarget:self action:@selector(switchCameraAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _switchButton;
}

/// 提示label
- (UILabel *)promptLabel
{
    if (!_promptLabel)
    {
        _promptLabel = [[UILabel alloc] init];
        _promptLabel.font = [UIFont systemFontOfSize:15];
        _promptLabel.textColor = [UIColor grayColor];
        _promptLabel.numberOfLines = 0;
        _promptLabel.text = @"facedetect.content.commonPromote";
        _promptLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _promptLabel;
}

/// 拍照结果页
- (UIImageView *)photoImageView
{
    if (!_photoImageView)
    {
        _photoImageView = [[UIImageView alloc] init];
        _photoImageView.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _photoImageView;
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


- (UIView *)cameraView {
    if (!_cameraView) {
        UIView *view = [[UIView alloc] init];
        view.clipsToBounds = YES;
        _cameraView = view;
    }
    return _cameraView;
}

/// 切换摄像头
- (void)switchCameraAction:(UIButton *)sender {
    self.lastImage = nil;
    self.rectLayer.hidden = YES;
    [self.faceCameraView switchCamera];
}

// 拍照，将当前采样模式切换为拍照

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    __weak __typeof(self)weakSelf = self;
    
        UIImage *image = [UIImage imageNV12FromSampleBuffer:sampleBuffer position:self.faceCameraView.position];
        if (!image || image.size.height == 0 || image.size.width == 0) {
            
        } else {
            self.lastImage = image;
            [image faceDetectWithViewSize:self.size finish:^(NSString * _Nonnull errorResults, CGRect faceViewBounds) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    // 是否检测成功
                    weakSelf.rectLayer.frame = faceViewBounds;
                    weakSelf.rectLayer.hidden = NO;
                });
            }];
        }
}
#pragma mark - Setter

#pragma mark - getters && setters
- (void)dealloc
{
//    [self.videoProcessor uninitProcessor];
    NSLog(@"%s", __func__);
}

/// 自定义相机视图
- (CameraView *)faceCameraView
{
    if (!_faceCameraView)
    {
        
        
        _faceCameraView = [[CameraView alloc] init];
        _faceCameraView.delegate = self;
        _faceCameraView.shouldScaleEnable = YES;
        _faceCameraView.shouldFocusEnable = YES;
        _faceCameraView.shouldFocusEnable = YES;
        _faceCameraView.isShowFaceDetectBorder = YES;
        // 导入到相册的图片尺寸比例
        _faceCameraView.cutoutImageSize = CGSizeMake(246, 260);
        [_faceCameraView addSubview:self.rectLayer];
        self.rectLayer.hidden = YES;
    }
    return _faceCameraView;
}

@end
