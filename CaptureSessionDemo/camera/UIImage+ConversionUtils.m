//
//  UIImage+ConversionUtils.m
//  GWFaceDetect
//
//  Created by Yilia on 2021/4/6.
//  Copyright © 2021 Goldwind. All rights reserved.
//

#import "UIImage+ConversionUtils.h"
//#import "Endian.h"
#import <Endian.h>
#import <AVFoundation/AVFoundation.h>
#define clamp(a) (a> 255 ? 255 : (a< 0 ? 0:a))
static CGFloat const kFaceDetectConfidence = 0.5;
/// 6/6s屏幕宽度
static double const kScreenWidth = 375;
@implementation UIImage (ConversionUtils)

/// CMSampleBufferRef 转换为Image类型
/// @param sampleBuffer 采样信息
/// @param position 相机方向
+ (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer position:(AVCaptureDevicePosition)position
{
    if (!sampleBuffer) {
        return nil;
    }
    // 旋转
    UIImage *orignImage = [self imageFromSampBuffer:sampleBuffer position:position];
    // 修复图片方向
    return [self fixOrientation:orignImage];
}

/// CVPixelBufferRef转换为UIImage类型
/// @param sampleBuffer 采样信息
/// @param position 相机方向
+ (UIImage *)imageFromSampBuffer:(CMSampleBufferRef)sampleBuffer position:(AVCaptureDevicePosition)position
{
    // 为媒体数据设置一个CMSampleBuffer的Core Video图像缓存对象
    CVImageBufferRef pixelBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer);
    @try {
        // 锁定pixel buffer的基地址
        CVPixelBufferLockBaseAddress(pixelBufferRef, 0);
        // 得到pixel buffer的基地址
        void *baseAddress = CVPixelBufferGetBaseAddress(pixelBufferRef);
        // 得到pixel buffer的行字节数
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBufferRef);
        // 得到pixel buffer的宽和高
        float width = CVPixelBufferGetWidth(pixelBufferRef);
        float height = CVPixelBufferGetHeight(pixelBufferRef);
        
        // 创建一个依赖于设备的RGB颜色空间
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        // 用抽样缓存的数据创建一个位图格式的图形上下文（graphics context）对象
        CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                     bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        
        // 根据这个位图context中的像素数据创建一个Quartz image对象
        CGImageRef quartzImage = CGBitmapContextCreateImage(context);
        // 解锁pixel buffer
        CVPixelBufferUnlockBaseAddress(pixelBufferRef, 0);
//        CVBufferRelease(pixelBufferRef);
        // 释放context和颜色空间
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);
        UIImage *image = nil;
        if (width > height)
        {
            image = [UIImage imageWithCGImage:quartzImage scale:1.0f orientation:(position == AVCaptureDevicePositionFront) ? UIImageOrientationLeftMirrored : UIImageOrientationRight];
            // NSLog(@"旋转了，旋转了o(*￣︶￣*)oo(*￣︶￣*)o");
        }
        else
        {
            image = [UIImage imageWithCGImage:quartzImage];
        }
        // 释放Quartz image对象
        CGImageRelease(quartzImage);
        return image;
    } @catch (NSException *exception) {}
}

/// nv12 CMSampleBufferRef 转换为Image类型 并修正图片方向
/// @param sampleBuffer 采样信息
/// @param position 相机方向
+ (UIImage *)imageNV12FromSampleBuffer:(CMSampleBufferRef)sampleBuffer position:(AVCaptureDevicePosition)position
{
    // 为媒体数据设置一个CMSampleBuffer的Core Video图像缓存对象
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    @try {
        CVPixelBufferLockBaseAddress(imageBuffer,0);
        
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        uint8_t *yBuffer = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
        size_t yPitch = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
        uint8_t *cbCrBuffer = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
        size_t cbCrPitch = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1);
        
        int bytesPerPixel = 4;
        uint8_t *rgbBuffer = malloc(width * height * bytesPerPixel);
        
        for(int y = 0; y < height; y++) {
            uint8_t *rgbBufferLine = &rgbBuffer[y * width * bytesPerPixel];
            uint8_t *yBufferLine = &yBuffer[y * yPitch];
            uint8_t *cbCrBufferLine = &cbCrBuffer[(y >> 1) * cbCrPitch];
            
            for(int x = 0; x < width; x++) {
                int16_t y = yBufferLine[x];
                int16_t cb = cbCrBufferLine[x & ~1] - 128;
                int16_t cr = cbCrBufferLine[x | 1] - 128;
                
                uint8_t *rgbOutput = &rgbBufferLine[x*bytesPerPixel];
                
                int16_t r = (int16_t)roundf( y + cr *  1.4 );
                int16_t g = (int16_t)roundf( y + cb * -0.343 + cr * -0.711 );
                int16_t b = (int16_t)roundf( y + cb *  1.765);
                
                rgbOutput[0] = 0xff;
                rgbOutput[1] = clamp(b);
                rgbOutput[2] = clamp(g);
                rgbOutput[3] = clamp(r);
            }
        }
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(rgbBuffer, width, height, 8, width * bytesPerPixel, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipLast);
        CGImageRef quartzImage = CGBitmapContextCreateImage(context);
//        UIImage *image = [UIImage imageWithCGImage:quartzImage];
        UIImage *image = nil;
        if (width > height)
        {
            image = [UIImage imageWithCGImage:quartzImage scale:1.0f orientation:(position == AVCaptureDevicePositionFront) ? UIImageOrientationLeftMirrored : UIImageOrientationRight];
            // NSLog(@"旋转了，旋转了o(*￣︶￣*)oo(*￣︶￣*)o");
        }
        else
        {
            image = [UIImage imageWithCGImage:quartzImage];
        }
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);
        CGImageRelease(quartzImage);
        free(rgbBuffer);
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        
        return image;
    } @catch (NSException *exception) {
        
    }
}

/// CMSampleBufferRef 转换为Image类型
/// @param sampleBuffer 采样信息
+ (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (!sampleBuffer) {
        return nil;
    }
    CVPixelBufferRef buffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    return [self imageFromPixelBuffer:buffer];
}

/// CVPixelBufferRef转换为UIImage类型
/// @param pixelBufferRef 像素缓冲池
+ (UIImage *)imageFromPixelBuffer:(CVPixelBufferRef)pixelBufferRef
{
    if (!pixelBufferRef) {
        return nil;
    }
    CVPixelBufferLockBaseAddress(pixelBufferRef, 0);
    
    float width = CVPixelBufferGetWidth(pixelBufferRef);
    float height = CVPixelBufferGetHeight(pixelBufferRef);
    
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBufferRef];
    
    CIContext *temporaryContext = [CIContext contextWithOptions:nil];
    CGImageRef videoImage = [temporaryContext
                             createCGImage:ciImage
                             fromRect:CGRectMake(0, 0,
                                                 width,
                                                 height)];
    
    UIImage *image = [UIImage imageWithCGImage:videoImage];
    CGImageRelease(videoImage);
    CVPixelBufferUnlockBaseAddress(pixelBufferRef, 0);
    return image;
}

/// 裁剪图片
/// @param image 图片源数据
/// @param size 需要的图片尺寸
+ (UIImage *)cutoutImage:(UIImage *)image andWithImageSize:(CGSize)size
{
    //    CGSize size = self.frame.size;
    CGFloat rWidth = size.width;
    CGFloat rHeight = size.height;
    CGFloat imageWidth = image.size.width;
    CGFloat imageHeight = image.size.height;
    CGFloat oWidth;
    CGFloat oHeight;
    CGRect rect;
    if (rWidth/rHeight > imageWidth/imageHeight) {
        oWidth = imageWidth;
        oHeight = imageWidth*rHeight/rWidth;
        rect = CGRectMake(0, floor((imageHeight-oHeight)/2.0), floor(oWidth), floor(oHeight));
    } else {
        oHeight = imageHeight;
        oWidth = imageHeight*rWidth/rHeight;
        rect = CGRectMake(floor((imageWidth-oWidth)/2.0), 0, floor(oWidth), floor(oHeight));
    }
    UIImage *cropImage = [UIImage crop:rect image:image];
    return cropImage;
}

+ (UIImage*)crop:(CGRect)rect image:(UIImage *)image
{
    CGPoint origin = CGPointMake(-rect.origin.x, -rect.origin.y);
    UIImage *img = nil;
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, image.scale);
    [image drawAtPoint:origin];
    img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

/// 修复图片方向
/// @param srcImg 竖着的图片资源
+ (UIImage *)fixOrientation:(UIImage *)srcImg
{
    if (srcImg.imageOrientation == UIImageOrientationUp) return srcImg;
    CGAffineTransform transform = CGAffineTransformIdentity;
    switch (srcImg.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, srcImg.size.width, srcImg.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
            
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, srcImg.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
            
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, srcImg.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
            break;
    }
    
    switch (srcImg.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, srcImg.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
            
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, srcImg.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationDown:
        case UIImageOrientationLeft:
        case UIImageOrientationRight:
            break;
    }
    
    CGContextRef ctx = CGBitmapContextCreate(NULL, srcImg.size.width, srcImg.size.height,
                                             CGImageGetBitsPerComponent(srcImg.CGImage), 0,
                                             CGImageGetColorSpace(srcImg.CGImage),
                                             CGImageGetBitmapInfo(srcImg.CGImage));
    CGContextConcatCTM(ctx, transform);
    switch (srcImg.imageOrientation) {
        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            CGContextDrawImage(ctx, CGRectMake(0,0,srcImg.size.height,srcImg.size.width), srcImg.CGImage);
            break;
            
        default:
            CGContextDrawImage(ctx, CGRectMake(0,0,srcImg.size.width,srcImg.size.height), srcImg.CGImage);
            break;
    }
    
    CGImageRef cgimg = CGBitmapContextCreateImage(ctx);
    UIImage *img = [UIImage imageWithCGImage:cgimg];
    CGContextRelease(ctx);
    CGImageRelease(cgimg);
    return img;
}

/**
 从图片中按指定的位置大小截取图片的一部分
 @param rect CGRect rect 要截取的区域
 @param scaleX scaleX
 @param scaleY scaleY
 @return UIImage
 */
- (UIImage *)gw_imageInRect:(CGRect)rect scaleX:(CGFloat )scaleX scaleY:(CGFloat )scaleY
{
    // 这里因为不是横屏布局 所以需要横纵坐标变换一下
    CGFloat origX = (rect.origin.x - 0) / scaleX;
    CGFloat origY = (rect.origin.y - 0) / scaleY;
    CGFloat oriWidth = rect.size.width / scaleX;
    CGFloat oriHeight = rect.size.height / scaleY;
    CGRect myRect = CGRectMake(origX, origY, oriWidth, oriHeight);
    CGImageRef imageRef = CGImageCreateWithImageInRect(self.CGImage, myRect);
    UIGraphicsBeginImageContext(myRect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextDrawImage(context, myRect, imageRef);
    UIImage *clipImage = [UIImage imageWithCGImage:imageRef];
    UIGraphicsEndImageContext();
    return clipImage;
}


/// 面部识别
/// @param image 传入采样图片
/// @param viewSize 图片真实的显示区域
/// @param finish 识别完成回调(错误信息, 面部方框坐标)
- (void)faceDetectWithViewSize:(CGSize)viewSize finish:(void(^)(NSString *errorResults, CGRect faceViewBounds))finish {
        // Vision 框架识别
        [self visionFaceDetectWithViewSize:viewSize finish:^(VNFaceObservation * _Nonnull observation, NSString * _Nonnull errorResults, CGRect faceViewBounds) {
            finish(errorResults, faceViewBounds);
        }];
    
}


/// Vision boundingBox 转换Rect，返回在image上真实的面部坐标
/// @param boundingBox Vision 返回的面部相对坐标
+ (CGRect)convertRect:(CGRect)boundingBox viewSize:(CGSize)viewSize {
    CGFloat w = boundingBox.size.width * viewSize.width;
    CGFloat h = boundingBox.size.height * viewSize.height;
    CGFloat x = boundingBox.origin.x * viewSize.width;
    CGFloat y = viewSize.height * (1 - boundingBox.origin.y - boundingBox.size.height);
    // 修正X、Y
    CGFloat offsetX = h>w ? (h - w)/2.f : 0.f;
    CGFloat offsetY = w>h ? (w - h)/2.f : 0.f;
    return CGRectMake(x - offsetX, y - offsetY, MAX(w,h), MAX(w,h));
}

/// 根据面部方框位置返回提示
/// @param obsFaceViewBounds 面部方框的坐标
+ (NSString *)promoteInfoWithFaceRect:(CGRect)obsFaceViewBounds {
    CGFloat obsFaceViewBoundsWidth = obsFaceViewBounds.size.width;
    CGFloat obsFaceViewBoundsOriginX = obsFaceViewBounds.origin.x;
    CGFloat obsFaceViewBoundsOriginY = obsFaceViewBounds.origin.y;
    CGFloat obsFaceViewBoundsCenterX = obsFaceViewBoundsOriginX + obsFaceViewBounds.size.width/2.f;
    CGFloat obsFaceViewBoundsCenterY = obsFaceViewBoundsOriginY + obsFaceViewBounds.size.height/2.f;
    
//    NSLog(@"obsFaceViewBounds:(x: %f, y: %f, w: %f, H:%f, centerX:%f)", obsFaceViewBounds.origin.x, obsFaceViewBounds.origin.y, obsFaceViewBoundsWidth, obsFaceViewBounds.size.height, obsFaceViewBoundsCenterX);
    
    if (obsFaceViewBoundsWidth > kScreenWidth/ 9.0 * 5.0)
    {
        return @"facedetect.content.kFailDetectFaceInfoPromote";
        // return GWFDLocalizedString(@"facedetect.content.kDetectFacePromoteFar", @"请离远一点");
    }
    else if (obsFaceViewBoundsWidth < kScreenWidth/3.f)
    {
        return @"facedetect.content.kFailDetectFaceInfoPromote";
        // return GWFDLocalizedString(@"facedetect.content.kDetectFacePromoteNearly", @"请离近一点");
    }
    else if (obsFaceViewBoundsCenterX < (kScreenWidth/2.f - 40))
    {
        return @"facedetect.content.kFailDetectFaceInfoPromote";
        // return GWFDLocalizedString(@"facedetect.content.kDetectFacePromoteToRight", @"请往右一点");
    }
    else if (obsFaceViewBoundsCenterX > (kScreenWidth/2.f + 40))
    {
        return @"facedetect.content.kFailDetectFaceInfoPromote";
        // return GWFDLocalizedString(@"facedetect.content.kDetectFacePromoteToLeft", @"请往左一点");
    }
    else if (obsFaceViewBoundsCenterY > 240)
    {
        return @"facedetect.content.kFailDetectFaceInfoPromote";
        // return GWFDLocalizedString(@"facedetect.content.kDetectFacePromoteToTop", @"请往上一点");
    }
    else if (obsFaceViewBoundsOriginY < 50)
    {
        return @"facedetect.content.kFailDetectFaceInfoPromote";
    }
    else
    {
        return @"";
    }
}
/// Vision框架面部识别，支持iOS11+
/// @param image 传入采样转换后的图片
/// @param viewSize 图片真实的显示区域
/// @param finish 识别完成回调(面部特征信息对象, 错误信息, 面部方框坐标)
- (void)visionFaceDetectWithViewSize:(CGSize)viewSize finish:(void (^)(VNFaceObservation *observation, NSString *errorResults, CGRect faceViewBounds))finish {
    if (!self) {
        return finish(nil, @"facedetect.content.kShootPhotoPromote", CGRectZero);
    }
    CIImage *ciImg = [CIImage imageWithCGImage:self.CGImage];
    if(!ciImg) {
        return finish(nil, @"facedetect.content.kShootPhotoPromote", CGRectZero);
    }
    
    // 图片检测 三种 VNDetectFaceLandmarksRequest/VNDetectFaceRectanglesRequest/VNDetectTextRectanglesRequest
    VNDetectFaceLandmarksRequest *faceRequest = [[VNDetectFaceLandmarksRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
        
        // 解析出错，提示请对准摄像头
        if (error) {
            return finish(nil, @"facedetect.content.kShootPhotoPromote", CGRectZero);
        }
        // 遍历面部信息数据
        NSMutableArray <VNFaceObservation *>*observationFaces = [NSMutableArray array];
        // 取出所有人脸
        [request.results enumerateObjectsUsingBlock:^(VNFaceObservation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj isKindOfClass:[VNFaceObservation class]])
            {
                [observationFaces addObject:obj];
            }
        }];
        
        // 判断取到的人脸数组
        if (observationFaces && observationFaces.count > 0)
        {
            // 是否有完整的面部信息
            BOOL iSCompleteFaceInformation = NO;
            for (VNFaceObservation *faceFeature in observationFaces)
            {
                // 获取面部信息完整度[0, 1]之间
                double landmarkScore = 0;
                @try {
                    id score = [faceFeature valueForKey:@"_landmarkScore"];
                    landmarkScore = [score floatValue];
                }
                @catch (NSException *exception) {
                    [NSError errorWithDomain:exception.reason code:250 userInfo:nil];
                }
//                NSLog(@"landmarkScore:(%f)", landmarkScore);
                // 判断是否有左眼位置 判断是否有右眼位置 判断是否有嘴位置
                if(landmarkScore > kFaceDetectConfidence && faceFeature.landmarks.leftEye && faceFeature.landmarks.rightEye && faceFeature.landmarks.nose && faceFeature.landmarks.noseCrest)
                {
                    iSCompleteFaceInformation = YES;
                }
            }
            
            // 遍历面部特征
            VNFaceObservation *observation = observationFaces.firstObject;
            if (iSCompleteFaceInformation && observationFaces && observationFaces.count == 1)
                // if (iSCompleteFaceInformation && observationFaces.count == 1)
            {
                // boundingBox
                CGRect obsFaceViewBounds = [UIImage convertRect:observation.boundingBox viewSize:viewSize];
                // 获取提示语
                NSString *promoteInfo = [UIImage promoteInfoWithFaceRect:obsFaceViewBounds];
                return finish(observation, promoteInfo, obsFaceViewBounds);
            }
            else
            {
                return finish(nil, @"facedetect.content.kFailDetectFaceInfoPromote", CGRectZero);
            }
        }
        else
        {
            return finish(nil, @"facedetect.content.kShootPhotoPromote", CGRectZero);
        }
    }];
    
    // 处理与多个图像序列有关的图像分析请求的对象
    // VNSequenceRequestHandler *sequenceRequestHandler = [[VNSequenceRequestHandler alloc] init];
    // [sequenceRequestHandler performRequests:@[faceRequest] onCGImage:cgImage error:NULL];
    // CGImageRef cgImage = image.CGImage;
    VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCIImage:ciImg options:@{}];
    // 发送识别请求
    NSError *faceRequestError = nil;
    [handler performRequests:@[faceRequest] error:&faceRequestError];
    if (faceRequestError)
    {
        NSLog(@"----------%@", faceRequestError);
        return finish(nil,@"facedetect.content.kShootPhotoPromote", CGRectZero);
    }
}
+ (UIImage *)clipWithImageRect:(CGRect)clipRect clipImage:(UIImage *)clipImage {
    UIGraphicsBeginImageContext(clipRect.size);
    [clipImage drawInRect:CGRectMake(0,0,clipRect.size.width,clipRect.size.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return  newImage;
}
@end
