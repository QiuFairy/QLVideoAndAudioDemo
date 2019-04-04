//
//  QLCaptureManager.m
//  QLVideoAndAudioDemo
//
//  Created by qiu on 2019/4/1.
//  Copyright © 2019 qiu. All rights reserved.
//

#import "QLCaptureManager.h"

@interface QLCaptureManager () <AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate>

/** 采集会话 */
@property (nonatomic, strong) AVCaptureSession *captureSession;

/*!
 视频配置
 */
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;     // 视频输入对象
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;    // 视频输出对象

/*!
 音频配置
 */
@property (nonatomic, strong) AVCaptureDevice *audioDevice; // 音频设备对象
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;     // 音频输入对象
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput;    // 音频输出对象

/** 预览图层，把这个图层加在View上就能播放 */
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;

@property (nonatomic, assign) CaptureSessionPreset definePreset;
@property (nonatomic, strong) NSString *realPreset;

@end

@implementation QLCaptureManager

- (instancetype)init{
    return [self initCaptureWithSessionPreset:CaptureSessionPreset640x480];
}

- (instancetype)initCaptureWithSessionPreset:(CaptureSessionPreset)preset {
    if ([super init]) {
        
        [self initAVcaptureSession];
        _definePreset = preset;
    }
    return self;
}

- (void)initAVcaptureSession {
    
    //初始化AVCaptureSession
    self.captureSession = [[AVCaptureSession alloc] init];
    // 设置录像分辨率
    if (![self.captureSession canSetSessionPreset:self.realPreset]) {
        if (![self.captureSession canSetSessionPreset:AVCaptureSessionPresetiFrame960x540]) {
            if (![self.captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {
            }
        }
    }
    
    /** 注意: 配置AVCaptureSession 的时候, 必须先开始配置, beginConfiguration, 配置完成, 必须提交配置 commitConfiguration, 否则配置无效  **/
    
    // 开始配置
    [self.captureSession beginConfiguration];
    
    
    // 设置视频 I/O 对象 并添加到session
    [self videoInputAndOutput];
    
    // 设置音频 I/O 对象 并添加到session
    [self audioInputAndOutput];
    
    //展示视频的试图
    self.videoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    self.videoPreviewLayer.connection.videoOrientation = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo].videoOrientation;
    self.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    // 提交配置
    [self.captureSession commitConfiguration];
}

// 设置视频 I/O 对象
- (void)videoInputAndOutput{
    NSError *error;
    // 初始化视频设备对象
    AVCaptureDevice *captureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionFront];
    if (!captureDevice)
    {
        NSLog(@"取得前置摄像头时出现问题.");
        
        return;
    }
    // 视频输入
    // 根据视频设备来初始化输入对象
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    if (error) {
        NSLog(@"== 摄像头错误 ==");
        return;
    }
    // 将输入对象添加到管理者 AVCaptureSession 中
    // 需要先判断是否能够添加输入对象
    if ([self.captureSession canAddInput:self.videoInput]) {
        // 可以添加, 才能添加
        [self.captureSession addInput:self.videoInput];
    }
    
    // 视频输出对象
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    // 是否允许卡顿时丢帧
    self.videoOutput.alwaysDiscardsLateVideoFrames = NO;
    
    if ([self supportsFastTextureUpload]) {
        // 是否支持全频色彩编码 YUV 一种色彩编码方式, 即YCbCr, 现在视频一般采用该颜色空间, 可以分离亮度跟色彩, 在不影响清晰度的情况下来压缩视频
        BOOL supportFullYUVRange = NO;
        
        // 获取输出对象所支持的像素格式
        NSArray *supportedPixelFormats = self.videoOutput.availableVideoCVPixelFormatTypes;
        for (NSNumber *currentPixelFormat in supportedPixelFormats) {
            if ([currentPixelFormat integerValue] == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
                supportFullYUVRange = YES;
            }
        }
        
        // 根据是否支持全频色彩编码 YUV 来设置输出对象的视频像素压缩格式
        if (supportFullYUVRange) {
            [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        } else {
            [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        }
    } else {
        // 设置像素格式
        [self.videoOutput setVideoSettings:@{
                                             (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
                                             }];
    }
    
    // 创建设置代理是所需要的线程队列 优先级设为高
    dispatch_queue_t videoQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    // 设置代理
    [self.videoOutput setSampleBufferDelegate:self queue:videoQueue];
    
    // 判断session 是否可添加视频输出对象
    if ([self.captureSession canAddOutput:self.videoOutput]) {
        [self.captureSession addOutput:self.videoOutput];
        
        // 链接视频 I/O 对象
        [self connectionVideoInputVideoOutput];
    }
    
}
// 链接 视频 I/O 对象
- (void)connectionVideoInputVideoOutput {
    // AVCaptureConnection是一个类，用来在AVCaptureInput和AVCaptureOutput之间建立连接。AVCaptureSession必须从AVCaptureConnection中获取实际数据。
    AVCaptureConnection *connection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
    
    // 设置视频的方向, 如果不设置的话, 视频默认是旋转 90°的
    connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    // 设置视频的稳定性, 先判断connection 连接对象是否支持 视频稳定
    if ([connection isVideoStabilizationSupported]) {
        connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
    }
    // 缩放裁剪系数, 设为最大
    connection.videoScaleAndCropFactor = connection.videoMaxScaleAndCropFactor;
}

// 设置音频 I/O 对象
- (void)audioInputAndOutput{
    NSError *error;
    // 初始音频设备对象
    self.audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    // 音频输入对象
    self.audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.audioDevice error:&error];
    if (error) {
        NSLog(@"== 录音设备出错");
    }
    
    // 判断session 是否可以添加 音频输入对象
    if ([self.captureSession canAddInput:self.audioInput]) {
        [self.captureSession addInput:self.audioInput];
    }
    
    // 音频输出对象
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    
    // 判断是否可以添加音频输出对象
    if ([self.captureSession canAddOutput:self.audioOutput]) {
        [self.captureSession addOutput:self.audioOutput];
    }
    
    // 创建设置音频输出代理所需要的线程队列
    dispatch_queue_t audioQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    [self.audioOutput setSampleBufferDelegate:self queue:audioQueue];
}

#pragma mark - AVCaptureVideoDataAndAudioDataOutputSampleBufferDelegate
// 实现视频输出对象和音频输出对象的代理方法, 在该方法中获取音视频采集的数据, 或者叫做帧数据
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    // 判断 captureOutput 多媒体输出对象的类型
    if (captureOutput == self.audioOutput) {    // 音频输出对象
        if (self.delegate && [self.delegate respondsToSelector:@selector(audioOutputDataWithSampleBuffer:)]) {
            [self.delegate audioOutputDataWithSampleBuffer:sampleBuffer];
        }
    } else {                                    // 视频输出对象
        if (self.delegate && [self.delegate respondsToSelector:@selector(videoOutputDataWithSampleBuffer:)]) {
            [self.delegate videoOutputDataWithSampleBuffer:sampleBuffer];
        }
    }
}

- (NSString*)realPreset {
    switch (_definePreset) {
        case CaptureSessionPreset640x480:
            _realPreset = AVCaptureSessionPreset640x480;
            break;
        case CaptureSessionPresetiFrame960x540:
            _realPreset = AVCaptureSessionPresetiFrame960x540;
            
            break;
        case CaptureSessionPreset1280x720:
            _realPreset = AVCaptureSessionPreset1280x720;
            
            break;
        default:
            _realPreset = AVCaptureSessionPreset640x480;
            
            break;
    }
    
    return _realPreset;
}

/** 开始采集 */
- (NSError *)startCapture{
    [self.captureSession startRunning];
    return nil;
}

/** 停止采集 */
- (NSError *)stopCapture{
    [self.captureSession stopRunning];
    return nil;
}

#pragma mark - 翻转摄像头
- (void)switchCamera{
    
    AVCaptureDevice *currentDevice = [self.videoInput device];
    
    AVCaptureDevicePosition currentPosition = [currentDevice position];
    
    AVCaptureDevice *toChangeDevice;
    
    AVCaptureDevicePosition toChangePosition = AVCaptureDevicePositionFront;
    
    if (currentPosition == AVCaptureDevicePositionUnspecified || currentPosition == AVCaptureDevicePositionFront)
    {
        toChangePosition = AVCaptureDevicePositionBack;
    }
    
    toChangeDevice = [self getCameraDeviceWithPosition:toChangePosition];
    
    [self changeDevicePropertySafety:^(AVCaptureDevice *captureDevice) {
        NSError *error;
        AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:toChangeDevice error:&error];
        
        if (newVideoInput != nil) {
            //必选先 remove 才能询问 canAdd
            [self.captureSession removeInput:self.videoInput];
            if ([self.captureSession canAddInput:newVideoInput]) {
                [self.captureSession addInput:newVideoInput];
                self.videoInput = newVideoInput;
            }else{
                [self.captureSession addInput:self.videoInput];
            }
        } else if (error) {
            NSLog(@"切换前/后摄像头失败, error = %@", error);
        }
    }];
}
// 获取需要的设备对象
- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position
{
    NSArray *cameras = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:position].devices;
    
    for (AVCaptureDevice *camera in cameras)
    {
        if ([camera position] == position)
        {
            return camera;
        }
    }
    return nil;
}

#pragma mark  更改设备属性前一定要锁上
-(void)changeDevicePropertySafety:(void (^)(AVCaptureDevice *captureDevice))propertyChange{
    //也可以直接用_videoDevice,但是下面这种更好
    AVCaptureDevice *captureDevice= [_videoInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁,意义是---进行修改期间,先锁定,防止多处同时修改
    BOOL lockAcquired = [captureDevice lockForConfiguration:&error];
    if (!lockAcquired) {
        NSLog(@"锁定设备过程error，错误信息：%@",error.localizedDescription);
    }else{
        //调整设备前后要调用beginConfiguration/commitConfiguration
        [self.captureSession beginConfiguration];
        propertyChange(captureDevice);
        
        [captureDevice unlockForConfiguration];
        [self.captureSession commitConfiguration];
    }
}
#pragma mark -

// 是否支持快速纹理更新
- (BOOL)supportsFastTextureUpload;
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
    return (CVOpenGLESTextureCacheCreate != NULL);
#pragma clang diagnostic pop
    
#endif
}

- (void)dealloc {
    [self stopCapture];
    
    // 取消代理, 回到主线程
    [self.videoOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
    [self.audioOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
}
@end
