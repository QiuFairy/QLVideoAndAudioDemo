//
//  QLVideoEncoder.m
//  QLVideoAndAudioDemo
//
//  Created by qiu on 2019/4/1.
//  Copyright © 2019 qiu. All rights reserved.
//

#import "QLVideoEncoder.h"
@implementation QLVideoEncoderParam

- (instancetype)init{
    self = [super init];
    if (self){
        self.encodeWidth = 480;
        self.encodeHeight = 640;
        self.encodeType = kCMVideoCodecType_H264;
        self.bitRate = 1024 * 1024;
    }
    return self;
}

@end

@interface QLVideoEncoder ()

@property (nonatomic, assign) VTCompressionSessionRef compressionSessionRef;

@property (nonatomic, strong) dispatch_queue_t operationQueue;

@property (nonatomic, assign) int timeStamp;

@end

@implementation QLVideoEncoder

- (void)dealloc
{
    NSLog(@"%s", __func__);
    if (NULL == _compressionSessionRef)
    {
        return;
    }
    VTCompressionSessionCompleteFrames(_compressionSessionRef, kCMTimeInvalid);
    VTCompressionSessionInvalidate(_compressionSessionRef);
    CFRelease(_compressionSessionRef);
    _compressionSessionRef = NULL;
}

- (instancetype)initWithParam:(QLVideoEncoderParam *)param
{
    if (self = [super init])
    {
        self.videoEncodeParam = param;
        self.operationQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        self.timeStamp = 0;
        
        [self encoderDefault];
    }
    return self;
}

- (void)encoderDefault{
    // 创建硬编码器
    OSStatus status = VTCompressionSessionCreate(NULL, (int)self.videoEncodeParam.encodeWidth, (int)self.videoEncodeParam.encodeHeight, self.videoEncodeParam.encodeType, NULL, NULL, NULL, encodeOutputDataCallback, (__bridge void *)(self), &_compressionSessionRef);
    if (noErr != status){
        NSLog(@"VEVideoEncoder::VTCompressionSessionCreate:failed status:%d", (int)status);
    }
    
    //******设置会话的属性******
    //提示视频编码器，压缩是否实时执行。
    status = VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    NSLog(@"set realtime  return: %d", (int)status);
    
    //指定编码比特流的配置文件和级别。直播一般使用baseline，可减少由于b帧带来的延时
    status = VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    NSLog(@"set profile   return: %d", (int)status);
    
    // 设置关键帧（GOPsize)间隔
    int frameInterval = 24;
    CFNumberRef frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
    VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
    CFRelease(frameIntervalRef);
    
    // 设置期望帧率
    int fps = 24;
    CFNumberRef fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
    VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
    CFRelease(fpsRef);
    
    // 设置码率 ‘均值’ 和 ‘上限’
    if (![self adjustBitRate:self.videoEncodeParam.bitRate]){
        NSLog(@">>");
    }
    
//#warning 设置Parma
//    //设置码率，均值，单位是byte
//    int bitRate = 1024*1024*1024;
//    CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
//    VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
//    CFRelease(bitRateRef);
//
//    //设置码率，上限，单位是bps
//    int bitRateLimit = 1024 *1024*1024;
//    CFNumberRef bitRateLimitRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRateLimit);
//    VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_DataRateLimits, bitRateLimitRef);
//    CFRelease(bitRateLimitRef);
    
    // Tell the encoder to start encoding
    VTCompressionSessionPrepareToEncodeFrames(_compressionSessionRef);
}


void encodeOutputDataCallback(void * CM_NULLABLE outputCallbackRefCon, void * CM_NULLABLE sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CM_NULLABLE CMSampleBufferRef sampleBuffer){
    // 1.判断状态是否等于没有错误
    if (noErr != status || nil == sampleBuffer){
        NSLog(@"VEVideoEncoder::encodeOutputCallback Error : %d!", (int)status);
        return;
    }
    
    if (nil == outputCallbackRefCon){
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)){
        return;
    }
    
    if (infoFlags & kVTEncodeInfo_FrameDropped){
        NSLog(@"VEVideoEncoder::H264 encode dropped frame.");
        return;
    }
    
    // 2.根据传入的参数获取对象
    QLVideoEncoder *encoder = (__bridge QLVideoEncoder *)outputCallbackRefCon;
    const char header[] = "\x00\x00\x00\x01";
    size_t headerLen = (sizeof header) - 1;
    NSData *headerData = [NSData dataWithBytes:header length:headerLen];
    
    // 3.判断是否是关键帧
    bool isKeyFrame = !CFDictionaryContainsKey((CFDictionaryRef)CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0), (const void *)kCMSampleAttachmentKey_NotSync);
    // 判断当前帧是否为关键帧
    // 获取sps & pps数据
    if (isKeyFrame){
        NSLog(@"VEVideoEncoder::编码了一个关键帧");
        // 获取编码后的信息（存储于CMFormatDescriptionRef中）
        CMFormatDescriptionRef formatDescriptionRef = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        // 关键帧需要加上SPS、PPS信息
        size_t sParameterSetSize, sParameterSetCount;
        // 获取SPS信息
        const uint8_t *sParameterSet;
        OSStatus spsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescriptionRef, 0, &sParameterSet, &sParameterSetSize, &sParameterSetCount, 0);
        // 获取PPS信息
        size_t pParameterSetSize, pParameterSetCount;
        const uint8_t *pParameterSet;
        OSStatus ppsStatus = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescriptionRef, 1, &pParameterSet, &pParameterSetSize, &pParameterSetCount, 0);
        
        if (noErr == spsStatus && noErr == ppsStatus)
        {
            // 装sps/pps转成NSData，以方便写入文件
            NSData *sps = [NSData dataWithBytes:sParameterSet length:sParameterSetSize];
            NSData *pps = [NSData dataWithBytes:pParameterSet length:pParameterSetSize];
            NSMutableData *spsData = [NSMutableData data];
            // 写入文件
            [spsData appendData:headerData];
            [spsData appendData:sps];
            if ([encoder.delegate respondsToSelector:@selector(videoEncodeOutputDataCallback:isKeyFrame:)])
            {
                [encoder.delegate videoEncodeOutputDataCallback:spsData isKeyFrame:isKeyFrame];
            }
            
            NSMutableData *ppsData = [NSMutableData data];
            [ppsData appendData:headerData];
            [ppsData appendData:pps];
            
            if ([encoder.delegate respondsToSelector:@selector(videoEncodeOutputDataCallback:isKeyFrame:)])
            {
                [encoder.delegate videoEncodeOutputDataCallback:ppsData isKeyFrame:isKeyFrame];
            }
        }
    }
    
    // 获取数据块
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    status = CMBlockBufferGetDataPointer(blockBuffer, 0, &length, &totalLength, &dataPointer);
    if (noErr != status)
    {
        NSLog(@"VEVideoEncoder::CMBlockBufferGetDataPointer Error : %d!", (int)status);
        return;
    }
    
    size_t bufferOffset = 0;
    // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
    static const int avcHeaderLength = 4;
    // 循环获取nalu数据
    while (bufferOffset < totalLength - avcHeaderLength)
    {
        // 读取 NAL 单元长度
        uint32_t nalUnitLength = 0;
        memcpy(&nalUnitLength, dataPointer + bufferOffset, avcHeaderLength);
        
        // 大端转小端
        nalUnitLength = CFSwapInt32BigToHost(nalUnitLength);
        
        NSData *frameData = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + avcHeaderLength) length:nalUnitLength];
        
        NSMutableData *outputFrameData = [NSMutableData data];
        [outputFrameData appendData:headerData];
        [outputFrameData appendData:frameData];
        
        // 移动到写一个块，转成NALU单元
        // Move to the next NAL unit in the block buffer
        bufferOffset += avcHeaderLength + nalUnitLength;
        
        if ([encoder.delegate respondsToSelector:@selector(videoEncodeOutputDataCallback:isKeyFrame:)])
        {
            [encoder.delegate videoEncodeOutputDataCallback:outputFrameData isKeyFrame:isKeyFrame];
        }
    }
}

/**
 编码过程中调整码率
 设置码率 均值和上限
 
 @param bitRate 码率
 */
- (BOOL)adjustBitRate:(NSInteger)bitRate
{
    if (bitRate <= 0){
        NSLog(@"VEVideoEncoder::adjustBitRate failed! bitRate <= 0");
        return NO;
    }
    //设置码率，均值，单位是byte
    OSStatus status = VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(bitRate));
    if (noErr != status){
        NSLog(@"VEVideoEncoder::kVTCompressionPropertyKey_AverageBitRate failed status:%d", (int)status);
        return NO;
    }
    
    //设置码率，上限，单位是byte
    // 参考webRTC 限制最大码率不超过平均码率的1.5倍
    int64_t dataLimitBytesPerSecondValue =
    bitRate * 1.5 / 8;
    CFNumberRef bytesPerSecond = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &dataLimitBytesPerSecondValue);
    int64_t oneSecondValue = 1;
    CFNumberRef oneSecond = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &oneSecondValue);
    const void* nums[2] = {bytesPerSecond, oneSecond};
    CFArrayRef dataRateLimits = CFArrayCreate(NULL, nums, 2, &kCFTypeArrayCallBacks);
    status = VTSessionSetProperty( _compressionSessionRef, kVTCompressionPropertyKey_DataRateLimits, dataRateLimits);
    if (noErr != status){
        NSLog(@"VEVideoEncoder::kVTCompressionPropertyKey_DataRateLimits failed status:%d", (int)status);
        return NO;
    }
    return YES;
}

/**
 停止编码
 */
- (void)stopVideoEncode{
    VTCompressionSessionCompleteFrames(_compressionSessionRef, kCMTimeInvalid);
    
    VTCompressionSessionInvalidate(_compressionSessionRef);
    
    CFRelease(_compressionSessionRef);
    _compressionSessionRef = NULL;
}

- (void)videoEncodeInputData:(CMSampleBufferRef)sampleBuffer{
    dispatch_sync(self.operationQueue, ^{
        //CVImageBuffer的媒体数据。
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        // 此帧的呈现时间戳，将附加到样本缓冲区，传递给会话的每个显示时间戳必须大于上一个。
        self.timeStamp ++;
        CMTime pts = CMTimeMake(self.timeStamp, 1000);
        //此帧的呈现持续时间
        CMTime duration = kCMTimeInvalid;
        VTEncodeInfoFlags flags;
        // 调用此函数可将帧呈现给压缩会话。
        OSStatus statusCode = VTCompressionSessionEncodeFrame(self.compressionSessionRef,
                                                              imageBuffer,
                                                              pts, duration,
                                                              NULL, NULL, &flags);
        
        if (statusCode != noErr) {
            NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
            
            [self stopVideoEncode];
            return;
        }
    });
}

@end
