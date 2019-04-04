//
//  QLVideoTools.m
//  QLVideoAndAudioDemo
//
//  Created by qiu on 2019/4/2.
//  Copyright © 2019 qiu. All rights reserved.
//

#import "QLVideoTools.h"
#import <VideoToolbox/VideoToolbox.h>

#define CURRENT_SYSTEM_VERSION  ([[[UIDevice currentDevice] systemVersion] floatValue])

@implementation QLVideoTools

+ (UIImage *)pixelBufferToImage:(CVPixelBufferRef)pixelBuffer {
    UIImage *image = nil;
    if(CURRENT_SYSTEM_VERSION < 9){
        image = [[UIImage alloc] initWithCIImage:[CIImage imageWithCVPixelBuffer:pixelBuffer]];
    }
    else{
        CGImageRef giImageRef;
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, NULL, &giImageRef);
        image = [UIImage imageWithCGImage:giImageRef];
        CGImageRelease(giImageRef);
    }
    return image;
}

+ (CVPixelBufferRef)imageToPixelBuffer:(UIImage *)uiImage {
    if(!uiImage)return NULL;
    CGSize bufferSize = uiImage.size;
    CGImageRef image = uiImage.CGImage;
    
    NSDictionary *options = @{(id)kCVPixelBufferCGImageCompatibilityKey: @YES,
                              (id)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES};
    CVPixelBufferRef pxbuffer = NULL;
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          bufferSize.width,
                                          bufferSize.height, kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, kCVPixelBufferLock_ReadOnly);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 bufferSize.width,
                                                 bufferSize.height,
                                                 8,
                                                 4 * bufferSize.width,
                                                 rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    
    CGContextDrawImage(context,
                       CGRectMake((bufferSize.width - CGImageGetWidth(image))/2,
                                  (bufferSize.height - CGImageGetHeight(image))/2,
                                  CGImageGetWidth(image),
                                  CGImageGetHeight(image)),
                       image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, kCVPixelBufferLock_ReadOnly);
    
    return pxbuffer;
}

@end
