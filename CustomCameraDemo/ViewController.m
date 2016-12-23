//
//  ViewController.m
//  CustomCameraDemo
//
//  Created by Mac on 16/12/20.
//  Copyright © 2016年 MIT. All rights reserved.
//

#import "ViewController.h"
#import "YJCameraViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@end

@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    
}

- (IBAction)showCamera:(id)sender {
    YJCameraViewController *cameraVC = [[YJCameraViewController alloc]init];
    [cameraVC takePhotoFinished:^(UIImage *image) {
        self.imageView.image = image;
    }];
    [self presentViewController:cameraVC animated:YES completion:nil];
}

@end
