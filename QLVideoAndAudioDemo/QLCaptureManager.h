//
//  QLCaptureManager.h
//  QLVideoAndAudioDemo
//
//  Created by qiu on 2019/4/1.
//  Copyright © 2019 qiu. All rights reserved.
//

/*!
 此为获取音视频信息流类
 */
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSUInteger,CaptureSessionPreset){
    CaptureSessionPreset640x480,//默认
    CaptureSessionPresetiFrame960x540,
    CaptureSessionPreset1280x720,
};

// 摄像头方向
typedef NS_ENUM(NSInteger, CaptureDevicePosition) {
    CaptureDevicePositionFront = 0,
    CaptureDevicePositionBack
};

@protocol QLVideoCapturerDelegate <NSObject>

//视频采集数据输出
- (void)videoOutputDataWithSampleBuffer:(CMSampleBufferRef)sampleBuffer;

//音频采集数据输出
- (void)audioOutputDataWithSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end


@interface QLCaptureManager : NSObject
/** 代理 */
@property (nonatomic, weak) id<QLVideoCapturerDelegate> delegate;

- (instancetype)initCaptureWithSessionPreset:(CaptureSessionPreset)preset;

//采集会话
@property (nonatomic, strong, readonly) AVCaptureSession *captureSession;
/** 预览图层，把这个图层加在View上并且为这个图层设置frame就能播放  */
@property (nonatomic, strong, readonly) AVCaptureVideoPreviewLayer *videoPreviewLayer;

/** 开始采集 */
- (NSError *)startCapture;

/** 停止采集 */
- (NSError *)stopCapture;

/** 摄像头切换 */
- (void)switchCamera;

@end

