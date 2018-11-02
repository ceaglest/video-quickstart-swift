//
//  ExampleAVAudioEngineDevice.h
//  AudioDeviceExample
//
//  Copyright © 2018 Twilio Inc. All rights reserved.
//

#import <TwilioVideo/TwilioVideo.h>

#import "TPCircularBuffer+AudioBufferList.h"

typedef struct TapContext {
    TPCircularBuffer buffer;
} TapContext;

NS_CLASS_AVAILABLE(NA, 11_0)
@interface ExampleAVAudioEngineDevice : NSObject <TVIAudioDevice>

- (void)playMusic;
- (MTAudioProcessingTapRef)setupTap;
- (AVAudioPCMBuffer *)updateWithAudioBuffer:(AudioBufferList *)list
                     capacity:(AVAudioFrameCount)capacity;

@end
