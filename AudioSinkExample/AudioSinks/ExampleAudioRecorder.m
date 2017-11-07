//
//  ExampleAudioRecorder.m
//  AudioSinkExample
//
//  Copyright © 2017 Twilio, Inc. All rights reserved.
//

#import "ExampleAudioRecorder.h"

#import <AVFoundation/AVFoundation.h>

@interface ExampleAudioRecorder()

@property (nonatomic, strong) AVAssetWriter *audioRecorder;
@property (nonatomic, strong) AVAssetWriterInput *audioRecorderInput;
@property (nonatomic, assign) CMTime recorderTimestamp;
@property (nonatomic, assign) int numberOfChannels;

@property (nonatomic, weak) TVIAudioTrack *audioTrack;

@end

@implementation ExampleAudioRecorder

- (instancetype)initWithAudioTrack:(TVIAudioTrack *)audioTrack identifier:(NSString *)identifier {
    self = [super init];
    if (self) {
        _recorderTimestamp = kCMTimeInvalid;

        [self startRecordingAudioTrack:audioTrack withIdentifier:identifier];
    }
    return self;
}

- (void)startRecordingAudioTrack:(TVIAudioTrack *)audioTrack withIdentifier:(NSString *)identifier {
    NSParameterAssert(audioTrack);
    NSParameterAssert(identifier);

    // Setup Recorder
    NSError *error = nil;
    _audioRecorder = [[AVAssetWriter alloc] initWithURL:[[self class] recordingURLWithIdentifier:identifier]
                                               fileType:AVFileTypeWAVE
                                                  error:&error];

    if (error) {
        NSLog(@"Error setting up audio recorder: %@", error);
        return;
    }

    // The iOS audio device captures in mono.
    // The mixer produces stereo audio for each remote Participant, even if they send mono audio.
    _numberOfChannels = [audioTrack isKindOfClass:[TVILocalAudioTrack class]] ? 1 : 2;

    // Assume that TVIAudioTrack will produce interleaved stereo LPCM @ 16-bit / 48khz
    NSDictionary<NSString *, id> *outputSettings = @{AVFormatIDKey : @(kAudioFormatLinearPCM),
                                                     AVSampleRateKey : @(48000),
                                                     AVNumberOfChannelsKey : @(self.numberOfChannels),
                                                     AVLinearPCMBitDepthKey : @(16),
                                                     AVLinearPCMIsFloatKey : @(NO),
                                                     AVLinearPCMIsBigEndianKey : @(NO),
                                                     AVLinearPCMIsNonInterleaved : @(NO)};

    _audioRecorderInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:outputSettings];
    _audioRecorderInput.expectsMediaDataInRealTime = YES;

    if ([_audioRecorder canAddInput:_audioRecorderInput]) {
        [_audioRecorder addInput:_audioRecorderInput];
        BOOL success = [_audioRecorder startWriting];

        if (success) {
            NSLog(@"Started recording audio track to: %@", _audioRecorder.outputURL);
            [audioTrack addSink:self];
            _audioTrack = audioTrack;
            _identifier = identifier;
        } else {
            NSLog(@"Couldn't start the AVAssetWriter: %@ error: %@", _audioRecorder, _audioRecorder.error);
        }
    }

    // TODO: CE - Backgrounding support. We could start a task here, and handle cleanup if it expires.
}

- (void)stopRecording {
    if (self.audioTrack) {
        [self.audioTrack removeSink:self];
        self.audioTrack = nil;
    }

    [self.audioRecorderInput markAsFinished];

    // Teardown the recorder
    [self.audioRecorder finishWritingWithCompletionHandler:^{
        if (self.audioRecorder.status == AVAssetWriterStatusFailed) {
            NSLog(@"AVAssetWriter failed with error: %@", self.audioRecorder.error);
        } else if (self.audioRecorder.status == AVAssetWriterStatusCompleted) {
            NSLog(@"AVAssetWriter finished writing to: %@", self.audioRecorder.outputURL);
        }
        self.audioRecorder = nil;
        self.audioRecorderInput = nil;
        self.recorderTimestamp = kCMTimeInvalid;
    }];
}

+ (NSURL *)recordingURLWithIdentifier:(NSString *)identifier {
    NSURL *documentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];

    NSString *filename = [NSString stringWithFormat:@"%@.wav", identifier];

    return [documentsDirectory URLByAppendingPathComponent:filename];
}

#pragma mark - TVIAudioSink

- (void)renderSample:(CMSampleBufferRef)audioSample {
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(audioSample);

    // Detect and discard the initial invalid samples...
    // Waits for the track to start producing the expected number of channels, and for the timestamp to be reset.
    if (CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)->mChannelsPerFrame != _numberOfChannels) {
        return;
    }

    CMTime presentationTimestamp = CMSampleBufferGetPresentationTimeStamp(audioSample);

    if (CMTIME_IS_INVALID(self.recorderTimestamp)) {
        [self.audioRecorder startSessionAtSourceTime:presentationTimestamp];
        self.recorderTimestamp = presentationTimestamp;
    }

    BOOL success = [self.audioRecorderInput appendSampleBuffer:audioSample];
    if (!success) {
        NSLog(@"Failed to append sample to writer: %@, error: %@", self.audioRecorder, self.audioRecorder.error);
    }
}

@end
