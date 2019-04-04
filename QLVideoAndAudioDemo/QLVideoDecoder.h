//
//  QLVideoDecoder.h
//  QLVideoAndAudioDemo
//
//  Created by qiu on 2019/4/2.
//  Copyright © 2019 qiu. All rights reserved.
//

/*!
 此类为H264硬解码类
 */
#import <Foundation/Foundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <UIKit/UIKit.h>

@protocol QLVideoDecoderDelegate <NSObject>
- (void)displayDecodedFrame:(CVImageBufferRef)imageBuffer;
- (void)didH264Decompress:(UIImage *)image;
@end

@interface QLVideoDecoder : NSObject
- (BOOL)initH264Decoder;
- (void)decodeNalu:(uint8_t *)frame withSize:(uint32_t)frameSize;
@property (nonatomic,weak) id<QLVideoDecoderDelegate>delegate;

@end
