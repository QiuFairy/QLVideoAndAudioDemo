//
//  QLVideoTools.h
//  QLVideoAndAudioDemo
//
//  Created by qiu on 2019/4/2.
//  Copyright © 2019 qiu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVKit/AVKit.h>

@interface QLVideoTools : NSObject

+ (UIImage *)pixelBufferToImage:(CVPixelBufferRef)pixelBuffer;
+ (CVPixelBufferRef)imageToPixelBuffer:(UIImage *)image;

@end
