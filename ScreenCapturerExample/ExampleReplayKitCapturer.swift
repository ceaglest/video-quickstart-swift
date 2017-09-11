//
//  ExampleReplayKitCapturer.swift
//  ScreenCapturerExample
//
//  Created by Chris Eagleston on 9/2/17.
//  Copyright © 2017 Twilio, Inc. All rights reserved.
//

import ReplayKit
import TwilioVideo

@available(iOS 11.0, *)
class ExampleReplayKitCapturer: NSObject, TVIVideoCapturer, RPScreenRecorderDelegate {

    public var isScreencast: Bool = true
    public var supportedFormats: [TVIVideoFormat]

    // Private variables
    weak var captureConsumer: TVIVideoCaptureConsumer?

    // Constants
    let displayLinkFrameRate = 60
    let desiredFrameRate = 5
    let captureScaleFactor: CGFloat = 1.0

    override init() {
        captureConsumer = nil

        /*
         * Describe the supported format.
         * For this example we cheat and assume that we will be capturing the entire screen.
         */
        let screenSize = UIScreen.main.bounds.size
        let format = TVIVideoFormat()
        format.pixelFormat = TVIPixelFormat.format32BGRA
        format.frameRate = UInt(desiredFrameRate)
        format.dimensions = CMVideoDimensions(width: Int32(screenSize.width), height: Int32(screenSize.height))
        supportedFormats = [format]

        // We don't need to call startCapture, this method is invoked when a TVILocalVideoTrack is added with this capturer.
    }

    func startCapture(_ format: TVIVideoFormat, consumer: TVIVideoCaptureConsumer) {
        let screenRecorder = RPScreenRecorder.shared()
        let isRecordingAvailable = screenRecorder.isAvailable;

        if (!isRecordingAvailable) {
            print("ReplayKit not available, failing capture.")
            consumer.captureDidStart(false)
            return
        }

        print("Start capturing.")

        screenRecorder.delegate = self
        captureConsumer = consumer;
        captureConsumer?.captureDidStart(true)

        // TODO: Better error handling.
        RPScreenRecorder.shared().startCapture(handler: { (buffer, type, error) in
            if (type == RPSampleBufferType.video) {
                let time = CMSampleBufferGetPresentationTimeStamp(buffer)
                let timestamp = Int64( CMTimeGetSeconds(time) * 1000000 );
                let imageBuffer = CMSampleBufferGetImageBuffer(buffer)
                let videoFrame = TVIVideoFrame.init(timestamp: timestamp, buffer: (imageBuffer)!, orientation: TVIVideoOrientation.up)

                self.captureConsumer?.consumeCapturedFrame(videoFrame!)
            }
        }) { (error) in
            print("Error starting screen capture.");
        }

    }

    func stopCapture() {
        print("Stop capturing.")

        // TODO: Better error handling.
        RPScreenRecorder.shared().stopCapture { (error) in
            if (error != nil) {

            }
        }
    }

    func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
        print("ScreenRecorder did change availability. isAvailable = \(screenRecorder.isAvailable)")
    }
}
