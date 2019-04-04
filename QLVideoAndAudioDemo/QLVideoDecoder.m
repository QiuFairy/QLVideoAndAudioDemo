//
//  QLVideoDecoder.m
//  QLVideoAndAudioDemo
//
//  Created by qiu on 2019/4/2.
//  Copyright © 2019 qiu. All rights reserved.
//

#import "QLVideoDecoder.h"
#import "QLVideoTools.h"

#define h264outputWidth 800
#define h264outputHeight 600

@interface QLVideoDecoder() {
    uint8_t *sps;
    uint8_t *pps;
    int spsSize;
    int ppsSize;
    VTDecompressionSessionRef session;
    CMVideoFormatDescriptionRef description;
}
@end

@implementation QLVideoDecoder

//解码回调函数
static void outputCallback(void *decompressionOutputRefCon,
                           void *sourceFrameRefCon,
                           OSStatus status,
                           VTDecodeInfoFlags infoFlags,
                           CVImageBufferRef pixelBuffer,
                           CMTime presentationTimeStamp,
                           CMTime presentationDuration)
{
//    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
//    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
//    QLVideoDecoder *decoder = (__bridge QLVideoDecoder *)decompressionOutputRefCon;
//    if ([decoder.delegate respondsToSelector:@selector(displayDecodedFrame:)]){
//        [decoder.delegate displayDecodedFrame:pixelBuffer];
//    }
    if(!pixelBuffer) return;
    UIImage *image = [QLVideoTools pixelBufferToImage:pixelBuffer];

    QLVideoDecoder *decoder = (__bridge QLVideoDecoder *)decompressionOutputRefCon;
    if (decoder.delegate && [decoder.delegate respondsToSelector:@selector(didH264Decompress:)]) {
        [decoder.delegate didH264Decompress:image];
    }
}

//创建解码器
- (BOOL)initH264Decoder {
    if(session) {
        return YES;
    }
    const uint8_t *parameterSetPointers[2] = {sps,pps};
    const size_t parameterSetSizes[2] = {spsSize,ppsSize};
    //设置参数
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2,//param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4,//nal start code size
                                                                          &description);
    if(status==noErr) {
        //设置属性
        NSDictionary *destinationPixelBufferAttributes = @{
                                                           //硬解必须为kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange或kCVPixelFormatType_420YpCbCr8Planar,因为iOS是nv12,其他是nv21
                                                           (id)kCVPixelBufferPixelFormatTypeKey:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
                                                           //宽高与编码相反
                                                           (id)kCVPixelBufferWidthKey:[NSNumber numberWithInt:h264outputHeight*2],
                                                           (id)kCVPixelBufferHeightKey:[NSNumber numberWithInt:h264outputWidth*2],
                                                           (id)kCVPixelBufferOpenGLCompatibilityKey:[NSNumber numberWithBool:YES]
                                                           };
        //设置回调
        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = outputCallback;
        callBackRecord.decompressionOutputRefCon = (__bridge void *)self;
        //创建session
        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              description,
                                              NULL,
                                              (__bridge CFDictionaryRef)destinationPixelBufferAttributes,
                                              &callBackRecord,
                                              &session);
        //设置属性
        VTSessionSetProperty(description, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef)[NSNumber numberWithInt:1]);
        VTSessionSetProperty(description, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
    }
    else {
        NSLog(@"创建失败,status=%d",status);
    }
    return YES;
}

//获取nalu数据
- (void)decodeNalu:(uint8_t *)frame withSize:(uint32_t)frameSize {
    int nalu_type = (frame[4] & 0x1F);//用于判断nalu类型
    uint32_t nalSize = (uint32_t)(frameSize - 4);
    uint8_t *pNalSize = (uint8_t*)(&nalSize);
    frame[0] = *(pNalSize + 3);
    frame[1] = *(pNalSize + 2);
    frame[2] = *(pNalSize + 1);
    frame[3] = *(pNalSize);
    //传输的时候I帧(关键帧)不能丢数据,否则绿屏,B/P帧可以丢但会卡顿
    switch (nalu_type)
    {
        case 0x05:
            //I帧
            if([self initH264Decoder]) {
                //解码I帧
                [self decode:frame withSize:frameSize];
            }
            break;
        case 0x07:
            //sps
            spsSize = frameSize - 4;
            sps = malloc(spsSize);
            memcpy(sps, &frame[4], spsSize);
            break;
        case 0x08:
            //pps
            ppsSize = frameSize - 4;
            pps = malloc(ppsSize);
            memcpy(pps, &frame[4], ppsSize);
            break;
        default:
            //P/B帧
            if([self initH264Decoder]) {
                //解码P/B帧
                [self decode:frame withSize:frameSize];
            }
            break;
    }
}

//解码
- (CVPixelBufferRef)decode:(uint8_t *)frame withSize:(uint32_t)frameSize {
    CVPixelBufferRef outputPixelBuffer = NULL;
    CMBlockBufferRef blockBuffer = NULL;
    //创建blockBuffer
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL,
                                                         (void *)frame,
                                                         frameSize,
                                                         kCFAllocatorNull,
                                                         NULL,
                                                         0,
                                                         frameSize,
                                                         FALSE,
                                                         &blockBuffer);
    if(status==kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {frameSize};
        //创建sampleBuffer
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           description,
                                           1,
                                           0,
                                           NULL,
                                           1,
                                           sampleSizeArray,
                                           &sampleBuffer);
        if (status==kCMBlockBufferNoErr && sampleBuffer) {
            VTDecodeFrameFlags flags = 0;
            VTDecodeInfoFlags flagOut = 0;
            //解码
            OSStatus status = VTDecompressionSessionDecodeFrame(session,
                                                                sampleBuffer,
                                                                flags,
                                                                &outputPixelBuffer,
                                                                &flagOut);
            if (status==kVTInvalidSessionErr) {
                NSLog(@"无效session");
            }
            else if (status==kVTVideoDecoderBadDataErr) {
                NSLog(@"解码失败(Bad data),status=%d",status);
            }
            else if (status!=noErr) {
                NSLog(@"解码失败,status=%d",status);
            }
            CFRelease(sampleBuffer);
        }
        CFRelease(blockBuffer);
    }
    return outputPixelBuffer;
}

@end
