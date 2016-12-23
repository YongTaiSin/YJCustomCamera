//
//  YJCameraViewController.m
//  CustomCameraDemo
//
//  Created by Mac on 16/12/23.
//  Copyright © 2016年 MIT. All rights reserved.
//

#import "YJCameraViewController.h"
#import <AVFoundation/AVFoundation.h>

#define kScreenWidth [[UIScreen mainScreen]bounds].size.width
#define kScreenHeight [[UIScreen mainScreen]bounds].size.height
#define kFlashBtnTag 999
//扫描框颜色
#define kScanColor [UIColor colorWithRed:70/255.0 green:166/255.0 blue:233/255.0 alpha:1]

@interface YJCameraViewController ()<UIAlertViewDelegate>

//捕获设备，通常是前置摄像头，后置摄像头，麦克风（音频输入）
@property (nonatomic, strong) AVCaptureDevice *device;
//AVCaptureDeviceInput 代表输入设备，他使用AVCaptureDevice 来初始化
@property (nonatomic, strong) AVCaptureDeviceInput *input;
//输出图片
@property (nonatomic ,strong) AVCaptureStillImageOutput *imageOutput;
//session：由他把输入输出结合在一起，并开始启动捕获设备（摄像头）
@property (nonatomic, strong) AVCaptureSession *session;
//图像预览层，实时显示捕获的图像
@property (nonatomic ,strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic ,strong) UIView *focusView;
@property (nonatomic ,weak  ) UIView *previewView;
@property (nonatomic ,weak  ) UIImageView *previewImageView;
@property (nonatomic, weak  ) UIView *flashPanel;
@property (nonatomic, weak  ) UIButton *switchFlashBtn;
@property (nonatomic, weak  ) UIButton *selectedFlashButton;
/** 扫描空心区域Rect */
@property (nonatomic, assign) CGRect cutRect;
@property (nonatomic ,strong) UIImage *photoImage;
@end

@implementation YJCameraViewController
#pragma mark - lifeCycle
- (void)viewDidLoad {
    [super viewDidLoad];
    //[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deviceOrientationDidChange) name:UIDeviceOrientationDidChangeNotification object:nil];
    
    if ([self canUserCamear]) {
        [self setupCamera];
        [self setupScanLayer];
        [self setupCameraUI];
    }else{
        return;
    }
}

- (void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:YES];
    
    if (self.session) {
        
        [self.session startRunning];
    }
}


- (void)viewDidDisappear:(BOOL)animated{
    
    [super viewDidDisappear:YES];
    
    if (self.session) {
        
        [self.session stopRunning];
    }
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    NSLog(@"YJCameraViewController--------销毁");
}
#pragma mark - init
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for ( AVCaptureDevice *device in devices )
        if ( device.position == position ){
            return device;
        }
    return nil;
}

- (void)setupCamera
{
    self.session = [[AVCaptureSession alloc] init];
    //     拿到的图像的大小可以自行设定
    //    AVCaptureSessionPreset320x240
    //    AVCaptureSessionPreset352x288
    //    AVCaptureSessionPreset640x480
    //    AVCaptureSessionPreset960x540
    //    AVCaptureSessionPreset1280x720
    //    AVCaptureSessionPreset1920x1080
    //    AVCaptureSessionPreset3840x2160
    self.session.sessionPreset = AVCaptureSessionPresetHigh;
    
    NSError *error;
    
    self.device = [self cameraWithPosition:AVCaptureDevicePositionBack];;
    
    //更改这个设置的时候必须先锁定设备，修改完后再解锁，否则崩溃
    if ([self.device lockForConfiguration:nil]) {
        //自动闪光灯，
        if ([self.device isFlashModeSupported:AVCaptureFlashModeAuto]) {
            [self.device setFlashMode:AVCaptureFlashModeAuto];
        }
        //自动白平衡,但是好像一直都进不去
        if ([self.device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance]) {
            [self.device setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
        }
        [self.device unlockForConfiguration];
    }
    
    self.input = [[AVCaptureDeviceInput alloc] initWithDevice:self.device error:&error];
    if (error) {
        NSLog(@"%@",error);
    }
    self.imageOutput = [[AVCaptureStillImageOutput alloc] init];
    //输出设置。AVVideoCodecJPEG   输出jpeg格式图片
    NSDictionary * outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey, nil];
    [self.imageOutput setOutputSettings:outputSettings];
    
    if ([self.session canAddInput:self.input]) {
        [self.session addInput:self.input];
    }
    if ([self.session canAddOutput:self.imageOutput]) {
        [self.session addOutput:self.imageOutput];
    }
    //初始化预览图层
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    NSLog(@"%f",kScreenWidth);
    self.previewLayer.frame = CGRectMake(0, 0,kScreenWidth, kScreenHeight);
    [self.view.layer addSublayer:self.previewLayer];
}

- (void)setupScanLayer
{
    //中间镂空的矩形框
    CGFloat width = kScreenWidth - 20*2;
    self.cutRect = CGRectMake(20, (kScreenHeight - width*5.5/8.5)/2, kScreenWidth-20*2, width*5.5/8.5);
    //背景
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:self.view.bounds];
    //镂空
    UIBezierPath *cutRectPath = [UIBezierPath bezierPathWithRect:self.cutRect];
    [path appendPath:cutRectPath];
    [path setUsesEvenOddFillRule:YES];
    
    CAShapeLayer *fillLayer = [CAShapeLayer layer];
    fillLayer.path = path.CGPath;
    fillLayer.fillRule = kCAFillRuleEvenOdd;//中间镂空的关键点 填充规则
    fillLayer.backgroundColor = [UIColor lightGrayColor].CGColor;
    fillLayer.opacity = 0.5;
    [self.view.layer addSublayer:fillLayer];
    
    // 边界校准线
    const CGFloat lineWidth = 2;
    const CGFloat cornerWidth = 50;
    UIBezierPath *linePath = [UIBezierPath bezierPathWithRect:CGRectMake(self.cutRect.origin.x - lineWidth,
                                                                         self.cutRect.origin.y - lineWidth,
                                                                         cornerWidth,
                                                                         lineWidth)];
    //        追加路径
    [linePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(self.cutRect.origin.x - lineWidth,
                                                                     self.cutRect.origin.y - lineWidth,
                                                                     lineWidth,
                                                                     cornerWidth)]];
    
    [linePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(CGRectGetMaxX(self.cutRect) - cornerWidth + lineWidth,
                                                                     self.cutRect.origin.y - lineWidth,
                                                                     cornerWidth,
                                                                     lineWidth)]];
    [linePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(CGRectGetMaxX(self.cutRect),
                                                                     self.cutRect.origin.y - lineWidth,
                                                                     lineWidth,
                                                                     cornerWidth)]];
    
    [linePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(self.cutRect.origin.x - lineWidth,
                                                                     CGRectGetMaxY(self.cutRect) - cornerWidth + lineWidth,
                                                                     lineWidth,
                                                                     cornerWidth)]];
    [linePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(self.cutRect.origin.x - lineWidth,
                                                                     CGRectGetMaxY(self.cutRect),
                                                                     cornerWidth,
                                                                     lineWidth)]];
    
    [linePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(CGRectGetMaxX(self.cutRect),
                                                                     CGRectGetMaxY(self.cutRect) - cornerWidth + lineWidth,
                                                                     lineWidth,
                                                                     cornerWidth)]];
    [linePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(CGRectGetMaxX(self.cutRect) - cornerWidth + lineWidth,
                                                                     CGRectGetMaxY(self.cutRect),
                                                                     cornerWidth,
                                                                     lineWidth)]];
    
    CAShapeLayer *pathLayer = [CAShapeLayer layer];
    pathLayer.path = linePath.CGPath;// 从贝塞尔曲线获取到形状
    pathLayer.fillColor = kScanColor.CGColor; // 闭环填充的颜色
    //        pathLayer.lineCap       = kCALineCapSquare;               // 边缘线的类型
    //        pathLayer.strokeColor = [UIColor blueColor].CGColor; // 边缘线的颜色
    //        pathLayer.lineWidth     = 4.0f;                           // 线条宽度
    [self.view.layer addSublayer:pathLayer];
}
#pragma mark 视图UI
- (void)setupCameraUI
{
    self.view.backgroundColor = [UIColor blackColor];
    _focusView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, 80, 80)];
    _focusView.layer.borderWidth = 1.0;
    _focusView.layer.borderColor =[UIColor greenColor].CGColor;
    _focusView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_focusView];
    _focusView.hidden = YES;
    
    [self setupTopView];
    [self setupBottomView];
    [self setupPreviewView];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(focusGesture:)];
    [self.view addGestureRecognizer:tapGesture];
}
- (void)setupTopView
{
    //topView
    CGFloat topHeight = 44;
    UIView *topView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, kScreenWidth, topHeight)];
    topView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:topView];
    //flash
    UIButton *flashBtn = [[UIButton alloc]initWithFrame:CGRectMake(15, 0, 30, 30)];
    CGPoint center = flashBtn.center;
    center.y = topView.center.y;
    flashBtn.center = center;
    [flashBtn setImage:[UIImage imageNamed:@"camera-flash-auto"] forState:UIControlStateNormal];
    [flashBtn setImage:[UIImage imageNamed:@"camera-flash-auto"] forState:UIControlStateSelected];
    [flashBtn addTarget:self action:@selector(showFlashPanelClicked:) forControlEvents:UIControlEventTouchUpInside];
    self.switchFlashBtn = flashBtn;
    [topView addSubview:flashBtn];
    //闪光灯菜单条
    CGFloat panelWidth = kScreenWidth-2*50;
    UIColor *selectColor = [UIColor colorWithRed:247.0/255.0 green:206.0/255.0 blue:5.0/255.0 alpha:1];
    UIColor *normalColor = [UIColor whiteColor];
    UIView *flashPanel = [[UIView alloc]initWithFrame:CGRectMake(50, 0, panelWidth, topHeight)];
    flashPanel.hidden = YES;
    UIButton *autoFlashBtn = [[UIButton alloc]initWithFrame:CGRectMake(0, 0, panelWidth/3, topHeight)];
    autoFlashBtn.tag = kFlashBtnTag+0;
    autoFlashBtn.selected = YES;
    [autoFlashBtn setTitle:@"自动" forState:UIControlStateNormal];
    [autoFlashBtn setTitleColor:normalColor forState:UIControlStateNormal];
    [autoFlashBtn setTitleColor:selectColor forState:UIControlStateSelected];
    [autoFlashBtn addTarget:self action:@selector(flashBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [flashPanel addSubview:autoFlashBtn];
    self.selectedFlashButton = autoFlashBtn;
    UIButton *onFlashBtn = [[UIButton alloc]initWithFrame:CGRectMake(panelWidth/3, 0, panelWidth/3, topHeight)];
    onFlashBtn.tag = kFlashBtnTag+1;
    [onFlashBtn setTitle:@"打开" forState:UIControlStateNormal];
    [onFlashBtn setTitleColor:normalColor forState:UIControlStateNormal];
    [onFlashBtn setTitleColor:selectColor forState:UIControlStateSelected];
    [onFlashBtn addTarget:self action:@selector(flashBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [flashPanel addSubview:onFlashBtn];
    UIButton *offFlashBtn = [[UIButton alloc]initWithFrame:CGRectMake(2*panelWidth/3, 0, panelWidth/3, topHeight)];
    offFlashBtn.tag = kFlashBtnTag+2;
    [offFlashBtn setTitle:@"关闭" forState:UIControlStateNormal];
    [offFlashBtn setTitleColor:normalColor forState:UIControlStateNormal];
    [offFlashBtn setTitleColor:selectColor forState:UIControlStateSelected];
    [offFlashBtn addTarget:self action:@selector(flashBtnClick:) forControlEvents:UIControlEventTouchUpInside];
    [flashPanel addSubview:offFlashBtn];
    autoFlashBtn.titleLabel.font = onFlashBtn.titleLabel.font = offFlashBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [topView addSubview:flashPanel];
    self.flashPanel = flashPanel;
}
- (void)setupBottomView
{
    //bottom
    CGFloat bottomHeight = 120;
    UIView *bottomView = [[UIView alloc]initWithFrame:CGRectMake(0, kScreenHeight-bottomHeight, kScreenWidth, bottomHeight)];
    bottomView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:bottomView];
    //拍照按钮
    UIButton *takePhotoBtn = [[UIButton alloc]initWithFrame:CGRectMake((kScreenWidth-90)/2, bottomHeight-70-15, 70, 70)];
    [takePhotoBtn setImage:[UIImage imageNamed:@"photograph"] forState:UIControlStateNormal];
    [takePhotoBtn setImage:[UIImage imageNamed:@"photograph_Select"] forState:UIControlStateHighlighted];
    [takePhotoBtn addTarget:self action:@selector(takePhotoButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    [bottomView addSubview:takePhotoBtn];
    //取消按钮
    UIButton *cancelBtn = [[UIButton alloc]initWithFrame:CGRectMake(15, 0, 40, 20)];
    CGPoint center = cancelBtn.center;
    center.y = takePhotoBtn.center.y;
    cancelBtn.center = center;
    [cancelBtn setTitle:@"取消" forState:UIControlStateNormal];
    [cancelBtn addTarget:self action:@selector(cancelClicked:) forControlEvents:UIControlEventTouchUpInside];
    [bottomView addSubview:cancelBtn];
    //切换摄像头按钮
    UIButton *switchCameraBtn = [[UIButton alloc]initWithFrame:CGRectMake(kScreenWidth-40-15, bottomHeight-70-15, 40, 30)];
    center = switchCameraBtn.center;
    center.y = takePhotoBtn.center.y;
    switchCameraBtn.center = center;
    [switchCameraBtn setImage:[UIImage imageNamed:@"camera-switch"] forState:UIControlStateNormal];
    [switchCameraBtn addTarget:self action:@selector(switchCameraClick:) forControlEvents:UIControlEventTouchUpInside];
    [bottomView addSubview:switchCameraBtn];
}
//拍照后预览
- (void)setupPreviewView
{
    UIView *previewView = [[UIView alloc]initWithFrame:self.view.bounds];
    previewView.backgroundColor = [UIColor blackColor];
    previewView.hidden = YES;
    [self.view addSubview:previewView];
    self.previewView = previewView;
    //bottomBar
    CGFloat bottomHeight = 100;
    UIView *bottomBar = [[UIView alloc]initWithFrame:CGRectMake(0, kScreenHeight-bottomHeight, kScreenWidth, bottomHeight)];
    bottomBar.backgroundColor = [UIColor blackColor];
    [previewView addSubview:bottomBar];
    //重拍
    UIButton *retakeBtn = [[UIButton alloc]initWithFrame:CGRectMake(15, (bottomHeight-40)/2, 80, 40)];
    retakeBtn.titleLabel.textAlignment = NSTextAlignmentLeft;
    [retakeBtn setTitle:@"重拍" forState:UIControlStateNormal];
    [retakeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [retakeBtn addTarget:self action:@selector(retakePhotoClicked:) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:retakeBtn];
    //使用照片
    UIButton *usePhotoBtn = [[UIButton alloc]initWithFrame:CGRectMake(kScreenWidth-15-80, (bottomHeight-40)/2, 80, 40)];
    usePhotoBtn.titleLabel.textAlignment = NSTextAlignmentRight;
    [usePhotoBtn setTitle:@"使用照片" forState:UIControlStateNormal];
    [usePhotoBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [usePhotoBtn addTarget:self action:@selector(usePhotoClicked:) forControlEvents:UIControlEventTouchUpInside];
    [bottomBar addSubview:usePhotoBtn];
    //preImageView
    UIImageView *previewImageView = [[UIImageView alloc]initWithFrame:CGRectMake(0, bottomHeight, kScreenWidth, kScreenHeight-bottomHeight*2)];
    previewImageView.contentMode = UIViewContentModeScaleAspectFit;
    [previewView addSubview:previewImageView];
    self.previewImageView = previewImageView;
}
#pragma mark - methods
/*- (void)deviceOrientationDidChange
 {
 NSLog(@"deviceOrientationDidChange:%ld",(long)[UIDevice currentDevice].orientation);
 if([UIDevice currentDevice].orientation == UIDeviceOrientationPortrait) {
 [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationPortrait];
 [self orientationChange:NO];
 //注意： UIDeviceOrientationLandscapeLeft 与 UIInterfaceOrientationLandscapeRight
 } else if ([UIDevice currentDevice].orientation == UIDeviceOrientationLandscapeLeft) {
 [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationLandscapeRight];
 [self orientationChange:YES];
 }
 }
 
 - (void)orientationChange:(BOOL)landscapeRight
 {
 if (landscapeRight) {
 [UIView animateWithDuration:0.2f animations:^{
 self.view.transform = CGAffineTransformMakeRotation(M_PI_2);
 self.view.bounds = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
 self.previewLayer.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
 self.photoBtn.frame = CGRectMake(400, 150, 100, 20);
 }];
 } else {
 [UIView animateWithDuration:0.2f animations:^{
 self.view.transform = CGAffineTransformMakeRotation(0);
 self.view.bounds = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
 self.previewLayer.frame = CGRectMake(0, 0, kScreenWidth, kScreenHeight);
 self.photoBtn.frame = CGRectMake((kScreenWidth-100)/2, kScreenHeight-100-50, 100, 20);
 }];
 }
 }*/
#pragma mark 获取设备方向
- (AVCaptureVideoOrientation)avOrientationForDeviceOrientation:(UIDeviceOrientation)deviceOrientation
{
    AVCaptureVideoOrientation result = (AVCaptureVideoOrientation)deviceOrientation;
    if ( deviceOrientation == UIDeviceOrientationLandscapeLeft )
        result = AVCaptureVideoOrientationLandscapeRight;
    else if ( deviceOrientation == UIDeviceOrientationLandscapeRight )
        result = AVCaptureVideoOrientationLandscapeLeft;
    else if ( deviceOrientation == UIDeviceOrientationFaceUp )
        result = AVCaptureVideoOrientationPortrait;
    return result;
}
#pragma 保存至相册
- (void)saveImageToPhotoAlbum:(UIImage*)savedImage
{
    UIImageWriteToSavedPhotosAlbum(savedImage, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
}
// 指定回调方法
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    NSString *msg = nil ;
    if(error != NULL){
        msg = @"保存图片失败" ;
    }else{
        msg = @"保存图片成功" ;
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"保存图片结果提示"
                                                    message:msg
                                                   delegate:self
                                          cancelButtonTitle:@"确定"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)focusGesture:(UITapGestureRecognizer*)gesture{
    CGPoint point = [gesture locationInView:gesture.view];
    [self focusAtPoint:point];
}
- (void)focusAtPoint:(CGPoint)point{
    CGSize size = self.view.bounds.size;
    CGPoint focusPoint = CGPointMake( point.y /size.height ,1-point.x/size.width );
    NSError *error;
    if ([self.device lockForConfiguration:&error]) {
        
        if ([self.device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            [self.device setFocusPointOfInterest:focusPoint];
            [self.device setFocusMode:AVCaptureFocusModeAutoFocus];
        }
        
        if ([self.device isExposureModeSupported:AVCaptureExposureModeAutoExpose ]) {
            [self.device setExposurePointOfInterest:focusPoint];
            [self.device setExposureMode:AVCaptureExposureModeAutoExpose];
        }
        
        [self.device unlockForConfiguration];
        _focusView.center = point;
        _focusView.hidden = NO;
        [UIView animateWithDuration:0.3 animations:^{
            _focusView.transform = CGAffineTransformMakeScale(1.25, 1.25);
        }completion:^(BOOL finished) {
            [UIView animateWithDuration:0.5 animations:^{
                _focusView.transform = CGAffineTransformIdentity;
            } completion:^(BOOL finished) {
                _focusView.hidden = YES;
            }];
        }];
    }
    
}

#pragma mark - 检查相机权限
- (BOOL)canUserCamear{
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusDenied) {
        UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:@"请打开相机权限" message:@"设置-隐私-相机" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:@"取消", nil];
        alertView.tag = 100;
        [alertView show];
        return NO;
    }
    else{
        return YES;
    }
    return YES;
}
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (buttonIndex == 0 && alertView.tag == 100) {
        
        NSURL * url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
        
        if([[UIApplication sharedApplication] canOpenURL:url]) {
            
            [[UIApplication sharedApplication] openURL:url];
            
        }
    }
}
#pragma mark 图片裁剪
//方法一
- (UIImage*)cropImage:(UIImage*)originalImage inRect:(CGRect)cropRect transform:(CGAffineTransform)transform{
    //计算出要裁剪相对与图片的像素尺寸的矩形区域
    CGFloat clipW = self.cutRect.size.width*originalImage.size.width/kScreenWidth;
    CGFloat clipH = clipW*5.5/8.5;
    CGFloat clipX = (originalImage.size.width-clipW)*0.5;
    CGFloat clipY = (originalImage.size.height-clipH)*0.5;
    cropRect = CGRectMake(clipX, clipY, clipW,clipH);
    
    CGSize newSize=cropRect.size;
    UIGraphicsBeginImageContext(newSize);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, newSize.width / 2, newSize.height / 2);
    CGContextConcatCTM(context, transform);
    CGContextTranslateCTM(context, newSize.width / -2, newSize.height / -2);
    [originalImage drawInRect:CGRectMake(-cropRect.origin.x, -cropRect.origin.y, originalImage.size.width, originalImage.size.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}
//方法二
// 通过抽样缓存数据创建一个UIImage对象
- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // 为媒体数据设置一个CMSampleBuffer的Core Video图像缓存对象
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // 锁定pixel buffer的基地址
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // 得到pixel buffer的基地址
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // 得到pixel buffer的行字节数
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // 得到pixel buffer的宽和高
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    //NSLog(@"%zu,%zu",width,height);
    
    // 创建一个依赖于设备的RGB颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // 用抽样缓存的数据创建一个位图格式的图形上下文（graphics context）对象
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    
    // 根据这个位图context中的像素数据创建一个Quartz image对象
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // 解锁pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // 释放context和颜色空间
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    //    cgimageget`
    
    // 用Quartz image创建一个UIImage对象image
    //UIImage *image = [UIImage imageWithCGImage:quartzImage];
    UIImage *image = [UIImage imageWithCGImage:quartzImage scale:1.0f orientation:UIImageOrientationRight];
    
    // 释放Quartz image对象
    CGImageRelease(quartzImage);
    
    return (image);
    
    
}

- (CGRect)calcRect:(CGSize)imageSize{
    NSString* gravity = self.previewLayer.videoGravity;
    CGRect cropRect = self.cutRect;
    CGSize screenSize = self.previewLayer.bounds.size;
    
    CGFloat screenRatio = screenSize.height / screenSize.width ;
    CGFloat imageRatio = imageSize.height /imageSize.width;
    
    CGRect presentImageRect = self.previewLayer.bounds;
    CGFloat scale = 1.0;
    
    
    if([AVLayerVideoGravityResizeAspect isEqual: gravity]){
        
        CGFloat presentImageWidth = imageSize.width;
        CGFloat presentImageHeigth = imageSize.height;
        if(screenRatio > imageRatio){
            presentImageWidth = screenSize.width;
            presentImageHeigth = presentImageWidth * imageRatio;
            
        }else{
            presentImageHeigth = screenSize.height;
            presentImageWidth = presentImageHeigth / imageRatio;
        }
        
        presentImageRect.size = CGSizeMake(presentImageWidth, presentImageHeigth);
        presentImageRect.origin = CGPointMake((screenSize.width-presentImageWidth)/2.0, (screenSize.height-presentImageHeigth)/2.0);
        
    }else if([AVLayerVideoGravityResizeAspectFill isEqual:gravity]){
        
        CGFloat presentImageWidth = imageSize.width;
        CGFloat presentImageHeigth = imageSize.height;
        if(screenRatio > imageRatio){
            presentImageHeigth = screenSize.height;
            presentImageWidth = presentImageHeigth / imageRatio;
        }else{
            presentImageWidth = screenSize.width;
            presentImageHeigth = presentImageWidth * imageRatio;
        }
        
        presentImageRect.size = CGSizeMake(presentImageWidth, presentImageHeigth);
        presentImageRect.origin = CGPointMake((screenSize.width-presentImageWidth)/2.0, (screenSize.height-presentImageHeigth)/2.0);
        
    }else{
        NSAssert(0, @"dont support:%@",gravity);
    }
    
    scale = CGRectGetWidth(presentImageRect) / imageSize.width;
    
    CGRect rect = cropRect;
    rect.origin = CGPointMake(CGRectGetMinX(cropRect)-CGRectGetMinX(presentImageRect), CGRectGetMinY(cropRect)-CGRectGetMinY(presentImageRect));
    
    rect.origin.x /= scale;
    rect.origin.y /= scale;
    rect.size.width /= scale;
    rect.size.height  /= scale;
    
    return rect;
}
#define SUBSET_SIZE 360
- (UIImage*)cropImageInRect:(UIImage*)image{
    
    CGSize size = [image size];
    CGRect cropRect = [self calcRect:size];
    
    float scale = fminf(1.0f, fmaxf(SUBSET_SIZE / cropRect.size.width, SUBSET_SIZE / cropRect.size.height));
    CGPoint offset = CGPointMake(-cropRect.origin.x, -cropRect.origin.y);
    
    size_t subsetWidth = cropRect.size.width * scale;
    size_t subsetHeight = cropRect.size.height * scale;
    
    
    CGColorSpaceRef grayColorSpace = CGColorSpaceCreateDeviceCMYK();
    
    CGContextRef ctx =
    CGBitmapContextCreate(nil,
                          subsetWidth,
                          subsetHeight,
                          8,
                          0,
                          grayColorSpace,
                          kCGImageAlphaNone|kCGBitmapByteOrderDefault);
    CGColorSpaceRelease(grayColorSpace);
    CGContextSetInterpolationQuality(ctx, kCGInterpolationNone);
    CGContextSetAllowsAntialiasing(ctx, false);
    
    // adjust the coordinate system
    CGContextTranslateCTM(ctx, 0.0, subsetHeight);
    CGContextScaleCTM(ctx, 1.0, -1.0);
    
    
    UIGraphicsPushContext(ctx);
    CGRect rect = CGRectMake(offset.x * scale, offset.y * scale, scale * size.width, scale * size.height);
    
    [image drawInRect:rect];
    
    UIGraphicsPopContext();
    
    CGContextFlush(ctx);
    
    
    CGImageRef subsetImageRef = CGBitmapContextCreateImage(ctx);
    
    UIImage* subsetImage = [UIImage imageWithCGImage:subsetImageRef];
    
    CGImageRelease(subsetImageRef);
    
    CGContextRelease(ctx);
    
    
    return subsetImage;
}
#pragma mark 开启暂停相机捕捉
- (void)startRunning
{
    if (self.session) {
        [self.session startRunning];
    }
}

- (void)stopRunning
{
    if (self.session) {
        [self.session stopRunning];
    }
}
#pragma mark 切换闪光灯
- (void)switchFlashMode:(AVCaptureFlashMode)flashMode
{
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //修改前必须先锁定
    [device lockForConfiguration:nil];
    //必须判定是否有闪光灯，否则如果没有闪光灯会崩溃
    if ([device hasFlash]) {
        device.flashMode = flashMode;
    } else {
        NSLog(@"设备不支持闪光灯");
    }
    [device unlockForConfiguration];
}
#pragma mark - Handle
- (void)takePhotoButtonClick:(UIButton *)button
{
    AVCaptureConnection *stillImageConnection = [self.imageOutput connectionWithMediaType:AVMediaTypeVideo];
    if (!stillImageConnection) {
        NSLog(@"拍照失败!");
        return;
    }
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    AVCaptureVideoOrientation avcaptureOrientation = [self avOrientationForDeviceOrientation:curDeviceOrientation];
    [stillImageConnection setVideoOrientation:avcaptureOrientation];
    [stillImageConnection setVideoScaleAndCropFactor:1];
    typeof(self) __weak weakSelf = self;
    [self.imageOutput captureStillImageAsynchronouslyFromConnection:stillImageConnection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer == nil) {
            return ;
        }
        NSData *jpegData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
        UIImage *originalImage = [UIImage imageWithData:jpegData];
        //[self saveImageToPhotoAlbum:originalImage];
        //UIImage *croppedImage = [self cropImageInRect:originalImage];
        UIImage *croppedImage = [weakSelf cropImage:originalImage inRect:weakSelf.cutRect transform:weakSelf.previewLayer.affineTransform];
        weakSelf.photoImage = croppedImage;
        weakSelf.previewView.hidden = NO;
        weakSelf.previewImageView.image = croppedImage;
    }];
}
//展开闪光灯面板
- (void)showFlashPanelClicked:(UIButton *)button
{
    self.flashPanel.hidden = !self.flashPanel.hidden;
    self.switchFlashBtn.selected = !self.flashPanel.hidden;
}
//切换闪光灯
- (void)flashBtnClick:(UIButton *)sender {
    
    NSLog(@"flashButtonClick");
    self.selectedFlashButton.selected = !self.selectedFlashButton.selected;
    sender.selected = YES;
    self.selectedFlashButton = sender;
    self.switchFlashBtn.selected = NO;
    self.flashPanel.hidden = YES;
    switch (sender.tag-kFlashBtnTag) {
        case 0:
            [self switchFlashMode:AVCaptureFlashModeAuto];
            [self.switchFlashBtn setImage:[UIImage imageNamed:@"camera-flash-auto"] forState:UIControlStateNormal];
            break;
        case 1:
            [self switchFlashMode:AVCaptureFlashModeOn];
            [self.switchFlashBtn setImage:[UIImage imageNamed:@"camera-flash-on"] forState:UIControlStateNormal];
            break;
        case 2:
            [self switchFlashMode:AVCaptureFlashModeOff];
            [self.switchFlashBtn setImage:[UIImage imageNamed:@"camera_flash_off"] forState:UIControlStateNormal];
            break;
        default:
            break;
    }
}
//切换摄像头
- (void)switchCameraClick:(UIButton *)sender {
    NSUInteger cameraCount = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
    if (cameraCount > 1) {
        NSError *error;
        //给摄像头的切换添加翻转动画
        CATransition *animation = [CATransition animation];
        animation.duration = .25f;
        animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        animation.type = @"oglFlip";
        
        AVCaptureDevice *newCamera = nil;
        AVCaptureDeviceInput *newInput = nil;
        //拿到另外一个摄像头位置
        AVCaptureDevicePosition position = [[_input device] position];
        if (position == AVCaptureDevicePositionFront){
            newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
            animation.subtype = kCATransitionFromLeft;//动画翻转方向
        }
        else {
            newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
            animation.subtype = kCATransitionFromRight;//动画翻转方向
        }
        //生成新的输入
        newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:nil];
        [self.previewLayer addAnimation:animation forKey:nil];
        if (newInput != nil) {
            [self.session beginConfiguration];
            [self.session removeInput:self.input];
            if ([self.session canAddInput:newInput]) {
                [self.session addInput:newInput];
                self.input = newInput;
                
            } else {
                [self.session addInput:self.input];
            }
            [self.session commitConfiguration];
            
        } else if (error) {
            NSLog(@"toggle carema failed, error = %@", error);
        }
    }
}
//取消
- (void)cancelClicked:(UIButton *)button
{
    NSArray *viewcontrollers=self.navigationController.viewControllers;
    if (self.presentingViewController) {
        //modal出来的
        if (self.navigationController) {
            [self.navigationController dismissViewControllerAnimated:YES completion:^{
                
            }];
        }else
        {
            [self dismissViewControllerAnimated:YES completion:^{
                
            }];
        }
    }else if(viewcontrollers.count>1)
    {
        if ([self.navigationController topViewController]==self) {
            //push方式
            [self.navigationController popViewControllerAnimated:YES];
        }
    }else
    {
        NSLog(@"根控制器");
    }
}
//重拍
- (void)retakePhotoClicked:(UIButton *)button
{
    self.previewView.hidden = YES;
}
//使用照片
- (void)usePhotoClicked:(UIButton *)button
{
    if (self.finishedBlock) {
        self.finishedBlock(self.photoImage);
    }
    [self cancelClicked:nil];
}

#pragma mark - public methods
- (void)takePhotoFinished:(FinishedTakePhotoBlock)finishedBlock
{
    _finishedBlock = [finishedBlock copy];
}
@end
