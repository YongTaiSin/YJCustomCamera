//
//  YJCameraViewController.h
//  CustomCameraDemo
//
//  Created by Mac on 16/12/23.
//  Copyright © 2016年 MIT. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^FinishedTakePhotoBlock)(UIImage *image);
@interface YJCameraViewController : UIViewController
@property (nonatomic, copy) FinishedTakePhotoBlock finishedBlock;
- (void)takePhotoFinished:(FinishedTakePhotoBlock)finishedBlock;
@end
