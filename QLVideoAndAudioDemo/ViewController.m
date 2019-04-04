//
//  ViewController.m
//  QLVideoAndAudioDemo
//
//  Created by qiu on 2019/4/1.
//  Copyright © 2019 qiu. All rights reserved.
//

#import "ViewController.h"
//信息流
#import "QLCaptureManager.h"
//视频编码
#import "QLVideoEncoder.h"
//音频编码
#import "QLAudioEncoder.h"
//视频解码
#import "QLVideoDecoder.h"
//音频解码
#import "QLAudioDecoder.h"
//视频工具类
#import "QLVideoTools.h"

@interface ViewController ()<QLVideoCapturerDelegate,QLVideoEncoderDelegate,QLVideoDecoderDelegate>
@property (nonatomic, strong) QLCaptureManager *captureManager;
/** 视频编码器 */
@property (nonatomic, strong) QLVideoEncoder *videoEncoder;
/** 音频编码器 */
@property (nonatomic, strong) QLAudioEncoder *audioEncoder;

@property (nonatomic, strong) QLVideoDecoder *videoDecoder;

@property (nonatomic, strong) QLAudioDecoder *audioDecoder;

@property (nonatomic, strong) UIImageView *cameraImageView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    //创建音视频采集会话
    self.captureManager = [[QLCaptureManager alloc]initCaptureWithSessionPreset:CaptureSessionPreset640x480];
    //采集代理
    self.captureManager.delegate = self;
    [self.captureManager startCapture];
    
    AVCaptureVideoPreviewLayer *preViewLayer = self.captureManager.videoPreviewLayer;
    //创建视频展示layer
    preViewLayer.frame = CGRectMake(0.f, 0.f, self.view.bounds.size.width, self.view.bounds.size.height);
    // 设置layer展示视频的方向
//    preViewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:preViewLayer];
    
    // 初始化并开启视频编码
    QLVideoEncoderParam *encodeParam = [[QLVideoEncoderParam alloc] init];
    encodeParam.encodeWidth = 180;
    encodeParam.encodeHeight = 320;
    encodeParam.bitRate = 512 * 1024;
    //视频编码h264
    _videoEncoder = [[QLVideoEncoder alloc] initWithParam:encodeParam];
    _videoEncoder.delegate = self;
    //音频密码acc
    _audioEncoder = [[QLAudioEncoder alloc]init];
    
    //创建解码对象
    _videoDecoder = [[QLVideoDecoder alloc] init];
    _videoDecoder.delegate = self;
    
    _audioDecoder = [[QLAudioDecoder alloc] init];
    
    [self.view addSubview:self.cameraImageView];
}

#pragma mark - QLVideoCapturerDelegate
//视频信息流
- (void)videoOutputDataWithSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    [self.videoEncoder videoEncodeInputData:sampleBuffer];
}
//音频信息流
- (void)audioOutputDataWithSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    __weak typeof(self) weakSelf = self;
    [self.audioEncoder audioEncodeInputDataWithSampleBuffer:sampleBuffer completianBlock:^(NSData * _Nonnull encodedData, NSError * _Nonnull error) {
        //ACC音频编码回调
        NSLog(@"ACC音频编码回调>>>%ld",encodedData.length);
        [weakSelf.audioDecoder decoderAACBuffer:encodedData completionBlock:^(NSData *pcmData, NSError *error) {
            //ACC音频解码回调
        }];
    }];
}

#pragma mark - H264视频编码回调
- (void)videoEncodeOutputDataCallback:(NSData *)data isKeyFrame:(BOOL)isKeyFrame{
    //此处为解码
    [_videoDecoder decodeNalu:(uint8_t *)[data bytes] withSize:(uint32_t)data.length];
}
#pragma mark - H264解码回调
- (void)displayDecodedFrame:(CVImageBufferRef)imageBuffer{
    //解码回调
    
    NSLog(@"decode success");
    CVPixelBufferRelease(imageBuffer);
    
    [self.cameraImageView setImage:[QLVideoTools pixelBufferToImage:imageBuffer]];
}
- (void)didH264Decompress:(UIImage *)image {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.cameraImageView setImage:image];
    });
}

#pragma mark - Property
- (UIImageView *)cameraImageView {
    if(!_cameraImageView) {
        _cameraImageView = [[UIImageView alloc]init];
        _cameraImageView.frame = CGRectMake(100, 100, 200, 200);
        _cameraImageView.backgroundColor = [UIColor lightGrayColor];
    }
    return _cameraImageView;
}

@end
