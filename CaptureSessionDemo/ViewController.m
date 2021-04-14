//
//  ViewController.m
//  CaptureSessionDemo
//
//  Created by Yilia on 2021/4/2.
//

#import "ViewController.h"
#import "GWDetectFaceViewController.h"
#import "CameraFaceViewController.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor redColor];
}

- (IBAction)showFaceCollect:(id)sender {
    GWDetectFaceViewController *viewController = [[GWDetectFaceViewController alloc] init];
    viewController.uploadCompletionBlock = ^(NSString * _Nonnull mediaID) {
        [self.navigationController popViewControllerAnimated:YES];
    };
    [self.navigationController pushViewController:viewController animated:YES];
}

- (IBAction)showFaceCollect1:(id)sender {
    CameraFaceViewController *viewController = [[CameraFaceViewController alloc] init];
    viewController.uploadCompletionBlock = ^(NSString * _Nonnull mediaID) {
        [self.navigationController popViewControllerAnimated:YES];
    };
    [self.navigationController pushViewController:viewController animated:YES];
}

@end
