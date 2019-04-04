//
//  QLAudioDecoder.h
//  QLVideoAndAudioDemo
//
//  Created by qiu on 2019/4/2.
//  Copyright © 2019 qiu. All rights reserved.
//
/*!
 此为音频硬解码类
 ACC
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QLAudioDecoder : NSObject
- (void)decoderAACBuffer:(NSData *)adtsAAC
        completionBlock:(void (^)(NSData * pcmData, NSError* error))completionBlock;
@end

NS_ASSUME_NONNULL_END
