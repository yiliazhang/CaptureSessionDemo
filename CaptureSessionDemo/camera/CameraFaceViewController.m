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
#import "Utility.h"
#import "CameraView.h"
@interface CameraFaceViewController ()<CameraViewDelegate, UIGestureRecognizerDelegate>
/// 关闭视图控制器
@property(nonatomic, strong) UIButton *closeBtn;

/// 提示
@property(nonatomic, strong) UIButton *promoteBtn;

/// 提示信息 label
@property(nonatomic, strong) UILabel *promptLab;

/// 拍照的图片
@property(nonatomic, strong) UIImageView *takePhotoImgV;

/// 拍照按钮背景
@property(nonatomic, strong) UIView *shootingBackView;

/// 拍照
@property(nonatomic, strong) UIButton *shootingBtn;

/// 拍摄完成的对号
@property(nonatomic, strong) UIButton *confirmButton;

/// 重新拍摄
@property(nonatomic, strong) UIButton *reShootBtn;

/// 切换摄像头
@property(nonatomic, strong) UIButton *switchBtn;

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
- (void)promoteBtnAction:(id)sender {
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
    [self.view addSubview:self.promoteBtn];
    [self.view addSubview:self.promptLab];
    [self.view addSubview:self.cameraView];
    [self.view insertSubview:self.takePhotoImgV aboveSubview:self.cameraView];
    [self.view addSubview:self.shootingBackView];
    [self.view addSubview:self.shootingBtn];
    [self.view addSubview:self.reShootBtn];
    [self.view addSubview:self.switchBtn];
    [self.view insertSubview:self.confirmButton aboveSubview:self.shootingBtn];
    [self.view addSubview:self.closeBtn];
    
    [self.closeBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view.mas_left).offset(10);
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(10);
        make.width.height.equalTo(@80);
    }];
    
    [self.promoteBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.view.mas_right).offset(-20);
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(10);
        make.width.height.equalTo(@80);
    }];
    
    self.promoteBtn.hidden = YES;
    
    [self.promptLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view.mas_left).offset(10);
        make.right.equalTo(self.view.mas_right).offset(-10);
        make.top.equalTo(self.closeBtn.mas_bottom).offset(35);
        make.height.equalTo(@40);
    }];
    
    [self.cameraView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.promptLab.mas_bottom).offset(10);
        make.width.equalTo(@(kDetectFaceWidth));
        make.height.equalTo(@(kDetectFaceHeight));
        make.centerX.equalTo(self.view.mas_centerX);
    }];
    
    [self.takePhotoImgV mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.promptLab.mas_bottom).offset(10);
        make.width.equalTo(@246);
        //        make.height.equalTo(@296);
        make.center.equalTo(self.cameraView);
    }];
    
    [self.shootingBackView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-32);
        make.width.height.equalTo(@80);
    }];
    
    [self.shootingBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.shootingBackView);
        make.width.height.equalTo(@80);
    }];
    
    [self.confirmButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.shootingBtn.mas_right);
        make.centerY.equalTo(self.shootingBtn);
        make.width.height.equalTo(self.shootingBtn);
    }];
    
    [self.reShootBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.shootingBackView);
        make.left.equalTo(@20);
        make.width.height.equalTo(@80);
    }];
    
    // 切换摄像头暂时图片方向有问题
    [self.switchBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.shootingBackView);
        make.right.equalTo(self.view).offset(-20);
        make.width.equalTo(self.reShootBtn);
        make.height.equalTo(self.reShootBtn);
    }];
    [self.cameraView addSubview:self.faceCameraView];
    [self.faceCameraView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.cameraView);
    }];
}

- (void)closeBtnAction:(UIButton *)sender
{
    [self.faceCameraView stopCaptureSession];
    [self.navigationController popViewControllerAnimated:YES];
}

/// 拍照
- (void)shootingBtnAction:(UIButton *)sender
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
        weakSelf.reShootBtn.hidden = NO;
        weakSelf.switchBtn.hidden = YES;
        [weakSelf faceDectDidTakePhoto: image];
    }];
    
}

/// 重拍
- (void)reShootBtnAction:(UIButton *)sender
{
    self.lastImage = nil;
    self.rectLayer.hidden = YES;
    // 初始化结果
    self.errorResults = @"";
    // 隐藏拍摄结果
    self.confirmButton.hidden = YES;
    self.reShootBtn.hidden = YES;
    self.switchBtn.hidden = NO;
    self.takePhotoImgV.image = nil;
    self.cameraView.hidden = NO;
}

/// 确定拍摄完成提交或者保存到相册事件
- (void)shootedBtnAction:(UIButton *)sender
{
    UIImage *image = self.takePhotoImgV.image;
    if (!image)
    {
        NSLog(@"未检测到有效人脸信息");
        [self reShootBtnAction:sender];
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
            self.takePhotoImgV.image = nil;
            self.cameraView.hidden = NO;
            // 没有虹软人脸特征
            NSLog(@"无法获取人脸特征，请重新拍摄");
            [self reShootBtnAction:nil];
        } else {
            CGRect modifiedBounds = CGRectInset(faceViewBounds, -20, -20);
            CGFloat scaleX = kDetectFaceWidth/photo.size.width;
            CGFloat scaleY = kDetectFaceHeight/(photo.size.height - 100);
            photoImg = [photo gw_imageInRect:modifiedBounds scaleX:scaleX scaleY:scaleY];
            self.takePhotoImgV.image = photoImg;
        }
    }];
}

- (UIButton *)closeBtn
{
    if (!_closeBtn)
    {
        _closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_closeBtn setTitle:@"关闭" forState:UIControlStateNormal];
        [_closeBtn addTarget:self action:@selector(closeBtnAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _closeBtn;
}

- (UIButton *)promoteBtn
{
    if (!_promoteBtn)
    {
        _promoteBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_promoteBtn setImage:[UIImage imageNamed:@"icon_xiangqing"] forState:UIControlStateNormal];
        _promoteBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_promoteBtn addTarget:self action:@selector(promoteBtnAction:) forControlEvents:UIControlEventTouchUpInside];
        _promoteBtn.semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
        _promoteBtn.imageEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);
    }
    return _promoteBtn;
}

- (UIView *)shootingBackView
{
    if (!_shootingBackView)
    {
        _shootingBackView = [[UIView alloc] init];
        _shootingBackView.backgroundColor = [[UIColor orangeColor] colorWithAlphaComponent:0.1];
        _shootingBackView.layer.cornerRadius = 34;
        _shootingBackView.layer.masksToBounds = YES;
    }
    return _shootingBackView;
}

- (UIButton *)shootingBtn
{
    if (!_shootingBtn)
    {
        _shootingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_shootingBtn setTitle:@"拍摄" forState:UIControlStateNormal];
        [_shootingBtn addTarget:self action:@selector(shootingBtnAction:) forControlEvents:UIControlEventTouchUpInside];
        _shootingBtn.layer.cornerRadius = 25;
        _shootingBtn.layer.masksToBounds = YES;
        _shootingBtn.backgroundColor = [UIColor redColor];
    }
    return _shootingBtn;
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
- (UIButton *)reShootBtn
{
    if (!_reShootBtn)
    {
        _reShootBtn = [[UIButton alloc] init];
        [_reShootBtn setTitle:@"重新拍摄" forState:UIControlStateNormal];
        [_reShootBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _reShootBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_reShootBtn addTarget:self action:@selector(reShootBtnAction:) forControlEvents:UIControlEventTouchUpInside];
        _reShootBtn.hidden = YES;
    }
    return _reShootBtn;
}

- (UIButton *)switchBtn
{
    if (!_switchBtn)
    {
        _switchBtn = [[UIButton alloc] init];
        [_switchBtn setTitle:@"前后切换" forState:UIControlStateNormal];
        [_switchBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        _switchBtn.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [_switchBtn addTarget:self action:@selector(switchCameraAction:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _switchBtn;
}

/// 提示label
- (UILabel *)promptLab
{
    if (!_promptLab)
    {
        _promptLab = [[UILabel alloc] init];
        _promptLab.font = [UIFont systemFontOfSize:15];
        _promptLab.textColor = [UIColor grayColor];
        _promptLab.numberOfLines = 0;
        _promptLab.text = @"facedetect.content.commonPromote";
        _promptLab.textAlignment = NSTextAlignmentCenter;
    }
    return _promptLab;
}

/// 拍照结果页
- (UIImageView *)takePhotoImgV
{
    if (!_takePhotoImgV)
    {
        _takePhotoImgV = [[UIImageView alloc] init];
        _takePhotoImgV.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _takePhotoImgV;
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
        _faceCameraView.shouldExposureEnable = YES;
        _faceCameraView.isShowFaceDetectBorder = YES;
        // 导入到相册的图片尺寸比例
        _faceCameraView.cutoutImageSize = CGSizeMake(246, 260);
        [_faceCameraView addSubview:self.rectLayer];
        self.rectLayer.hidden = YES;
    }
    return _faceCameraView;
}

@end
