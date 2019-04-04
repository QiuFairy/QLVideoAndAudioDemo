//
//  QLVideoEncoder.h
//  QLVideoAndAudioDemo
//
//  Created by qiu on 2019/4/1.
//  Copyright © 2019 qiu. All rights reserved.
//

/*!
 此为视频硬解码类
 H264
 */
#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>

@interface QLVideoEncoderParam : NSObject

/** 编码内容的宽度 default:480*/
@property (nonatomic, assign) NSInteger encodeWidth;
/** 编码内容的高度 default:640*/
@property (nonatomic, assign) NSInteger encodeHeight;
/** 编码类型 */
@property (nonatomic, assign) CMVideoCodecType encodeType;
/** 码率 单位kbps 1024*1024*/
@property (nonatomic, assign) NSInteger bitRate;

@end


@protocol QLVideoEncoderDelegate <NSObject>

/**
 编码输出数据
 
 @param data 输出数据
 @param isKeyFrame 是否为关键帧
 */
- (void)videoEncodeOutputDataCallback:(NSData *)data isKeyFrame:(BOOL)isKeyFrame;

@end

@interface QLVideoEncoder : NSObject

@property (nonatomic, weak) id<QLVideoEncoderDelegate> delegate;
/** 编码参数 */
@property (nonatomic, strong) QLVideoEncoderParam *videoEncodeParam;
/**
 初始化方法
 
 @param param 编码参数
 @return 实例
 */
- (instancetype)initWithParam:(QLVideoEncoderParam *)param;


/**
 停止编码
 */
- (void)stopVideoEncode;

/**
 输入待编码数据
 
 @param sampleBuffer 待编码数据
 */
- (void)videoEncodeInputData:(CMSampleBufferRef)sampleBuffer;
@end

