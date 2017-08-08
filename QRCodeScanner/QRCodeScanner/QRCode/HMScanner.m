//
//  HMScanner.m
//  HMQRCodeScanner
//
//  Created by 刘凡 on 16/1/2.
//  Copyright © 2016年 itheima. All rights reserved.
//

#import "HMScanner.h"
#import <AVFoundation/AVFoundation.h>

/// 最大检测次数
#define kMaxDetectedCount   20
/** 屏幕宽度*/
#define kScreenWidth    ([UIScreen mainScreen].bounds.size.width)
#define kScreenHeight   ([UIScreen mainScreen].bounds.size.height)


@interface HMScanner() <AVCaptureMetadataOutputObjectsDelegate>
/// 父视图弱引用
@property (nonatomic, weak) UIView *parentView;
/// 扫描范围
@property (nonatomic) CGRect scanFrame;
/// 完成回调
@property (nonatomic, copy) void (^completionCallBack)(NSString *);
@property (nonatomic , strong) AVCaptureDevice *device;

@end

@implementation HMScanner {
    /// 拍摄会话
    AVCaptureSession *session;
    /// 预览图层
    AVCaptureVideoPreviewLayer *previewLayer;
    /// 绘制图层
    CALayer *drawLayer;
    /// 当前检测计数
    NSInteger currentDetectedCount;
    
    ///相机回调次数
    NSInteger currentDelegateCount;
    
}

#pragma mark - 生成二维码
+ (void)qrImageWithString:(NSString *)string avatar:(UIImage *)avatar completion:(void (^)(UIImage *))completion {
    [self qrImageWithString:string avatar:avatar scale:0.20 completion:completion];
}

+ (void)qrImageWithString:(NSString *)string avatar:(UIImage *)avatar scale:(CGFloat)scale completion:(void (^)(UIImage *))completion {
    
    NSAssert(completion != nil, @"必须传入完成回调");
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        CIFilter *qrFilter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
        
        [qrFilter setDefaults];
        [qrFilter setValue:[string dataUsingEncoding:NSUTF8StringEncoding] forKey:@"inputMessage"];
        
        CIImage *ciImage = qrFilter.outputImage;
        
        CGAffineTransform transform = CGAffineTransformMakeScale(10, 10);
        CIImage *transformedImage = [ciImage imageByApplyingTransform:transform];
        
        CIContext *context = [CIContext contextWithOptions:nil];
        CGImageRef cgImage = [context createCGImage:transformedImage fromRect:transformedImage.extent];
        UIImage *qrImage = [UIImage imageWithCGImage:cgImage scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
        CGImageRelease(cgImage);
        
        if (avatar != nil) {
            qrImage = [self qrcodeImage:qrImage addAvatar:avatar scale:scale];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{ completion(qrImage); });
    });
}

+ (UIImage *)qrcodeImage:(UIImage *)qrImage addAvatar:(UIImage *)avatar scale:(CGFloat)scale {
    
    CGFloat screenScale = [UIScreen mainScreen].scale;
    CGRect rect = CGRectMake(0, 0, qrImage.size.width * screenScale, qrImage.size.height * screenScale);
    
    UIGraphicsBeginImageContextWithOptions(rect.size, YES, screenScale);
    
    [qrImage drawInRect:rect];
    
    CGSize avatarSize = CGSizeMake(rect.size.width * scale, rect.size.height * scale);
    CGFloat x = (rect.size.width - avatarSize.width) * 0.5;
    CGFloat y = (rect.size.height - avatarSize.height) * 0.5;
    [avatar drawInRect:CGRectMake(x, y, avatarSize.width, avatarSize.height)];
    
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return [UIImage imageWithCGImage:result.CGImage scale:screenScale orientation:UIImageOrientationUp];
}

#pragma mark - 扫描图像方法
+ (void)scaneImage:(UIImage *)image completion:(void (^)(NSArray *))completion {
    
    NSAssert(completion != nil, @"必须传入完成回调");
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        
        CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{CIDetectorAccuracy: CIDetectorAccuracyHigh}];
        
        CIImage *ciImage = [[CIImage alloc] initWithImage:image];
        
        NSArray *features = [detector featuresInImage:ciImage];
        
        NSMutableArray *arrayM = [NSMutableArray arrayWithCapacity:features.count];
        for (CIQRCodeFeature *feature in features) {
            [arrayM addObject:feature.messageString];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(arrayM.copy);
        });
    });
}

#pragma mark - 构造函数
+ (instancetype)scanerWithView:(UIView *)view scanFrame:(CGRect)scanFrame completion:(void (^)(NSString *))completion {
    NSAssert(completion != nil, @"必须传入完成回调");
    
    return [[self alloc] initWithView:view scanFrame:scanFrame completion:completion];
}

- (instancetype)initWithView:(UIView *)view scanFrame:(CGRect)scanFrame completion:(void (^)(NSString *))completion {
    self = [super init];
    
    if (self) {
        self.parentView = view;
        self.scanFrame = scanFrame;
        self.completionCallBack = completion;
        
        [self setupSession];
    }
    return self;
}

#pragma mark - 公共方法
/// 开始扫描
- (void)startScan {
    if ([session isRunning]) {
        return;
    }
    currentDetectedCount = 0;
    
    currentDelegateCount = 0;
    
    [session startRunning];
}

- (void)stopScan {
    if (![session isRunning]) {
        return;
    }
    [session stopRunning];
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    
    [self clearDrawLayer];

    /** 调整焦距*/
    [self focusOnPoint:CGPointMake(self.scanFrame.size.width/2, self.scanFrame.size.height/2) completionHandler:^{
        
    }];
    
    
    for (id obj in metadataObjects) {
        // 判断检测到的对象类型
        if (![obj isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) {
            return;
        }
        
        // 转换对象坐标
        AVMetadataMachineReadableCodeObject *dataObject = (AVMetadataMachineReadableCodeObject *)[previewLayer transformedMetadataObjectForMetadataObject:obj];
        
        // 判断扫描范围
        if (!CGRectContainsRect(self.scanFrame, dataObject.bounds)) {
            continue;
        }
        
        /** 判断获取的大小是否过小*/
        if (dataObject.bounds.size.width < kScreenWidth/4) {
            
            int a = kScreenWidth/4/ dataObject.bounds.size.width;
            /** 调整放大*/
            [self SetFocalLengthWithCoefficient:a];

            /** 调整焦距*/
            [self focusOnPoint:CGPointMake(dataObject.bounds.size.width/2, dataObject.bounds.size.height/2) completionHandler:^{
                
            }];
            
        }
        
        if (currentDetectedCount++ < kMaxDetectedCount) {
            // 绘制边角
//            [self drawCornersShape:dataObject];
            
            if (currentDetectedCount > 5) {

                /** 调整焦距*/
                [self focusOnPoint:CGPointMake(self.scanFrame.size.width/2, self.scanFrame.size.height/2) completionHandler:^{
                    
                }];
                
            }
            
        } else {
            [self stopScan];
            
            // 完成回调
            if (self.completionCallBack != nil) {
                self.completionCallBack(dataObject.stringValue);
                
                 [previewLayer setAffineTransform:CGAffineTransformMakeScale(1, 1)];
                
            }
        }
    }
}

-(void)SetFocalLengthWithCoefficient:(int )coefficient{
    
    [UIView animateWithDuration:1.5 animations:^{
        /** 设置镜头放大系数*/
        [previewLayer setAffineTransform:CGAffineTransformMakeScale(coefficient, coefficient)];
        
    }];
    
}



/// 清空绘制图层
- (void)clearDrawLayer {
    if (drawLayer.sublayers.count == 0) {
        return;
    }
    
    [drawLayer.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
}

/// 绘制条码形状
///
/// @param dataObject 识别到的数据对象
- (void)drawCornersShape:(AVMetadataMachineReadableCodeObject *)dataObject {
    
    if (dataObject.corners.count == 0) {
        return;
    }
    
    CAShapeLayer *layer = [CAShapeLayer layer];
    
    layer.lineWidth = 4;
    layer.strokeColor = [UIColor greenColor].CGColor;
    layer.fillColor = [UIColor clearColor].CGColor;
    layer.path = [self cornersPath:dataObject.corners];
    
    [drawLayer addSublayer:layer];
}

/// 使用 corners 数组生成绘制路径
///
/// @param corners corners 数组
///
/// @return 绘制路径
- (CGPathRef)cornersPath:(NSArray *)corners {
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGPoint point = CGPointZero;
    
    // 1. 移动到第一个点
    NSInteger index = 0;
    CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)corners[index++], &point);
    [path moveToPoint:point];
    
    // 2. 遍历剩余的点
    while (index < corners.count) {
        CGPointMakeWithDictionaryRepresentation((CFDictionaryRef)corners[index++], &point);
        [path addLineToPoint:point];
    }
    
    // 3. 关闭路径
    [path closePath];
    
    return path.CGPath;
}

#pragma mark - 扫描相关方法
/// 设置绘制图层和预览图层
- (void)setupLayers {
    
    if (self.parentView == nil) {
        NSLog(@"父视图不存在");
        return;
    }
    
    if (session == nil) {
        NSLog(@"拍摄会话不存在");
        return;
    }
    
    // 绘制图层
    drawLayer = [CALayer layer];
    
    drawLayer.frame = self.parentView.bounds;
    
    [self.parentView.layer insertSublayer:drawLayer atIndex:0];
    
    // 预览图层
    previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    previewLayer.frame = self.parentView.bounds;
    
    [self.parentView.layer insertSublayer:previewLayer atIndex:0];
}

-(AVCaptureDevice *)device{
    if (_device == nil) {
        _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if ([_device lockForConfiguration:nil]) {
            //自动闪光灯
            if ([_device isFlashModeSupported:AVCaptureFlashModeAuto]) {
                [_device setFlashMode:AVCaptureFlashModeAuto];
            }
            //自动白平衡
            if ([_device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
                [_device setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
            }
            //自动对焦
            if ([_device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                [_device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
            }
            //自动曝光
            if ([_device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
                [_device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            }
            
            [_device unlockForConfiguration];

        }
    }
    return _device;
}


/// 设置扫描会话
- (void)setupSession {
    
    // 1> 输入设备
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:self.device error:nil];
    
    if (videoInput == nil) {
        NSLog(@"创建输入设备失败");
        return;
    }
    
    // 2> 数据输出
    AVCaptureMetadataOutput *dataOutput = [[AVCaptureMetadataOutput alloc] init];
    
    // 3> 拍摄会话 - 判断能够添加设备
    session = [[AVCaptureSession alloc] init];
    if (![session canAddInput:videoInput]) {
        NSLog(@"无法添加输入设备");
        session = nil;
        
        return;
    }
    if (![session canAddOutput:dataOutput]) {
        NSLog(@"无法添加输入设备");
        session = nil;
        
        return;
    }
    
    // 4> 添加输入／输出设备
    [session addInput:videoInput];
    [session addOutput:dataOutput];
    
    // 5> 设置扫描类型
    dataOutput.metadataObjectTypes = dataOutput.availableMetadataObjectTypes;
    [dataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    // 6> 设置预览图层会话
    [self setupLayers];
}

//对某一点对焦
-(void)focusOnPoint:(CGPoint)point completionHandler:(void(^)())completionHandler
{
    CGPoint pointOfInterest = CGPointZero;
    CGSize frameSize = self.parentView.bounds.size;
    pointOfInterest = CGPointMake(point.y / frameSize.height, 1.f - (point.x / frameSize.width));
    if ([self.device isFocusPointOfInterestSupported] && [self.device isFocusModeSupported:AVCaptureFocusModeAutoFocus])
    {
        NSError *error;
        if ([self.device lockForConfiguration:&error])
        {
            if ([self.device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance])
            {
                [self.device setWhiteBalanceMode:AVCaptureWhiteBalanceModeAutoWhiteBalance];
            }
            if ([self.device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus])
            {
                [self.device setFocusMode:AVCaptureFocusModeAutoFocus];
                [self.device setFocusPointOfInterest:pointOfInterest];
            }
            if([self.device isExposurePointOfInterestSupported] && [self.device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure])
            {
                [self.device setExposurePointOfInterest:pointOfInterest];
                [self.device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            }
            [self.device unlockForConfiguration];
            if(completionHandler)
                completionHandler();
        }
    }
    else
    {
        if(completionHandler)
            completionHandler();
    }
}





@end
