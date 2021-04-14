//
//  CameraFaceViewController.h
//  CaptureSessionDemo
//
//  Created by Yilia on 2021/4/14.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CameraFaceViewController : UIViewController

/// 拍摄完成回调
@property(nonatomic, copy) void(^shootedAction)(UIImage *photo, BOOL isLocalCollect, NSString *promote);
/// 上传图片 完成回调
@property(nonatomic, copy) void(^uploadCompletionBlock)(NSString *mediaID);

+ (void)showFromViewController:(UINavigationController *)navigationController
         uploadCompletionBlock:(void (^ __nullable)(NSString *mediaID))uploadCompletionBlock;
@end

NS_ASSUME_NONNULL_END
