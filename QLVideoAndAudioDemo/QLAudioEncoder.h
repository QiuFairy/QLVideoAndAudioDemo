//
//  QLAudioEncoder.h
//  QLVideoAndAudioDemo
//
//  Created by qiu on 2019/4/2.
//  Copyright © 2019 qiu. All rights reserved.
//

/*!
 此为音频硬编码类
 ACC
 */
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface QLAudioEncoder : NSObject

- (void)audioEncodeInputDataWithSampleBuffer:(CMSampleBufferRef)sampleBuffer completianBlock:(void (^)(NSData *encodedData, NSError *error))completionBlock;
@end

NS_ASSUME_NONNULL_END
