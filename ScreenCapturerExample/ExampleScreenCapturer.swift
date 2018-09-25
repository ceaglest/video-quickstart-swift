//
//  ExampleScreenCapturer.swift
//  ScreenCapturerExample
//
//  Copyright © 2016-2017 Twilio, Inc. All rights reserved.
//

import TwilioVideo

class ExampleScreenCapturer: NSObject, TVIVideoCapturer {

    public var isScreencast: Bool = true
    public var supportedFormats: [TVIVideoFormat]

    // Private variables
    weak var captureConsumer: TVIVideoCaptureConsumer?
    weak var view: UIView?
    var displayTimer: CADisplayLink?
    var willEnterForegroundObserver: NSObjectProtocol?
    var didEnterBackgroundObserver: NSObjectProtocol?

    // Constants
    let displayLinkFrameRate = 60
    let desiredFrameRate = 5
    let captureScaleFactor: CGFloat = 1.0
    let manageCGContext: Bool = true;

    init(aView: UIView) {
        captureConsumer = nil
        view = aView

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
        DispatchQueue.main.async {
            if (self.view == nil || self.view?.superview == nil) {
                print("Can't capture from a nil view, or one with no superview:", self.view as Any)
                consumer.captureDidStart(false)
                return
            }

            if #available(iOS 10.0, *) {
                print("Start capturing. UIView.layer.contentsFormat was", self.view?.layer.contentsFormat as Any)
            } else {
                print("Start capturing.")
            }

            self.startTimer()
            self.registerNotificationObservers()

            self.captureConsumer = consumer;
            consumer.captureDidStart(true)
        }
    }

    func stopCapture() {
        print("Stop capturing.")

        DispatchQueue.main.async {
            self.unregisterNotificationObservers()
            self.invalidateTimer()
        }
    }

    func startTimer() {
        invalidateTimer()

        // Use a CADisplayLink timer so that our drawing is synchronized to the display vsync.
        displayTimer = CADisplayLink(target: self, selector: #selector(ExampleScreenCapturer.captureView))

        // On iOS 10.0+ use preferredFramesPerSecond, otherwise fallback to intervals assuming a 60 hz display
        if #available(iOS 10.0, *) {
            displayTimer?.preferredFramesPerSecond = desiredFrameRate
        } else {
            displayTimer?.frameInterval = displayLinkFrameRate / desiredFrameRate
        };

        displayTimer?.add(to: RunLoop.main, forMode: RunLoopMode.commonModes)
        displayTimer?.isPaused = UIApplication.shared.applicationState == UIApplicationState.background
    }

    func invalidateTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    func registerNotificationObservers() {
        let notificationCenter = NotificationCenter.default;

        willEnterForegroundObserver = notificationCenter.addObserver(forName: NSNotification.Name.UIApplicationWillEnterForeground,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { (Notification) in
                                                                        self.displayTimer?.isPaused = false;
        })

        didEnterBackgroundObserver = notificationCenter.addObserver(forName: NSNotification.Name.UIApplicationDidEnterBackground,
                                                                     object: nil,
                                                                     queue: OperationQueue.main,
                                                                     using: { (Notification) in
                                                                        self.displayTimer?.isPaused = true;
        })
    }

    func unregisterNotificationObservers() {
        let notificationCenter = NotificationCenter.default

        notificationCenter.removeObserver(willEnterForegroundObserver!)
        notificationCenter.removeObserver(didEnterBackgroundObserver!)

        willEnterForegroundObserver = nil
        didEnterBackgroundObserver = nil
    }

    func captureView( timer: CADisplayLink ) {

        // Ensure the view is alive for the duration of our capture to make Swift happy.
        guard let targetView = self.view else { return }
        // We cant capture a 0x0 image.
        let targetSize = targetView.bounds.size
        guard targetSize != CGSize.zero else {
            return
        }

        // This is our main drawing loop. Start by using the UIGraphics APIs to draw the UIView we want to capture.
        var contextImage: UIImage? = nil
        var pixelFormat: TVIPixelFormat = TVIPixelFormat.format32BGRA
        var orientation: TVIVideoOrientation = TVIVideoOrientation.up

        autoreleasepool {
            /*
             * We will use UIGraphicsImageRenderer for more control over color management when rendering a UIView.
             * On iOS 12, UIGraphicsBeginImageContextWithOptions performs an expensive color conversion on devices with
             * wide gamut screens.
             */
            if (manageCGContext) {
                // According to Apple's docs UIGraphicsBeginImageContextWithOptions uses device RGB.
//                let colorSpace = CGColorSpaceCreateDeviceRGB()
                guard let colorSpace = CGColorSpace.init(name: CGColorSpace.sRGB),
                    var context = CGContext(data: nil, width: Int(targetSize.width), height: Int(targetSize.height), bitsPerComponent: 8, bytesPerRow: Int(targetSize.width) * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
                else {
                    return
                }

                // Prepare CGContext to be used with UIKit, matching the top to bottom y-axis coordinate system.
//                context.scaleBy(x: -1, y: 1)
                pixelFormat = TVIPixelFormat.format32ARGB
                // Not quite...
                orientation = TVIVideoOrientation.down
                UIGraphicsPushContext(context); defer { UIGraphicsPopContext() }

                // No special drawing to do, we just want an opaque image of the UIView contents.
                targetView.drawHierarchy(in: targetView.bounds, afterScreenUpdates: true)

                guard let imageRef = context.makeImage()
                else { return }

                contextImage = UIImage(cgImage: imageRef)
            } else if #available(iOS 12.0, *) {
                let rendererFormat = UIGraphicsImageRendererFormat.init()
                rendererFormat.opaque = true
                rendererFormat.scale = captureScaleFactor
                // WebRTC expects content to be rec.709, and does not properly handle video in other color spaces.
                rendererFormat.preferredRange = UIGraphicsImageRendererFormat.Range.standard
//                let rendererFormat = UIGraphicsImageRendererFormat.default()
                let renderer = UIGraphicsImageRenderer.init(bounds: targetView.bounds, format: rendererFormat)

                contextImage = renderer.image(actions: { (UIGraphicsImageRendererContext) in
                    // No special drawing to do, we just want an opaque image of the UIView contents.
                    targetView.drawHierarchy(in: targetView.bounds, afterScreenUpdates: false)
                });
            } else {
                UIGraphicsBeginImageContextWithOptions((self.view?.bounds.size)!, true, captureScaleFactor)
                targetView.drawHierarchy(in: (self.view?.bounds)!, afterScreenUpdates: false)
                contextImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
            }
        }

        /*
         * Make a copy of the UIImage's underlying data. We do this by getting the CGImage, and its CGDataProvider.
         * Note that this technique is inefficient because it causes an extra malloc / copy to occur for every frame.
         * For a more performant solution, provide a pool of buffers and use them to back a CGBitmapContext.
         */
        let image: CGImage? = contextImage?.cgImage
        let dataProvider: CGDataProvider? = image?.dataProvider
        let data: CFData? = dataProvider?.data
        let baseAddress = CFDataGetBytePtr(data!)
        contextImage = nil

        /*
         * We own the copied CFData which will back the CVPixelBuffer, thus the data's lifetime is bound to the buffer.
         * We will use a CVPixelBufferReleaseBytesCallback callback in order to release the CFData when the buffer dies.
         */
        let unmanagedData = Unmanaged<CFData>.passRetained(data!)
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreateWithBytes(nil,
                                                  (image?.width)!,
                                                  (image?.height)!,
                                                  pixelFormat.rawValue,
                                                  UnsafeMutableRawPointer( mutating: baseAddress!),
                                                  (image?.bytesPerRow)!,
                                                  { releaseContext, baseAddress in
                                                    let contextData = Unmanaged<CFData>.fromOpaque(releaseContext!)
                                                    contextData.release()
                                                  },
                                                  unmanagedData.toOpaque(),
                                                  nil,
                                                  &pixelBuffer)

        if let buffer = pixelBuffer {
            // Deliver a frame to the consumer. Images drawn by UIGraphics do not need any rotation tags.
            let frame = TVIVideoFrame(timeInterval: timer.timestamp,
                                      buffer: buffer,
                                      orientation: orientation)

            // The consumer retains the CVPixelBuffer and will own it as the buffer flows through the video pipeline.
            captureConsumer?.consumeCapturedFrame(frame!)
        } else {
            print("Capture failed with status code: \(status).")
        }
    }
}
