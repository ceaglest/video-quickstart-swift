//
//  PreviewViewController.swift
//  ScreenCapturerExample
//
//  Created by Chris Eagleston on 9/3/17.
//  Copyright © 2017 Twilio, Inc. All rights reserved.
//

import AVFoundation
import UIKit
import TwilioVideo

class PreviewViewController : UIViewController {
    var remoteView: TVIVideoView?

    init(track: TVIVideoTrack) {
        super.init(nibName:nil, bundle:nil)
        remoteView = TVIVideoView.init(frame: CGRect.zero, delegate: self)
        remoteView!.isHidden = true

        track.addRenderer(remoteView!)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.remoteView!)
        self.view.setNeedsLayout()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        // Layout the remote video using frame based techniques. It's also possible to do this using autolayout
        if ((remoteView?.hasVideoData)!) {
            let dimensions = remoteView?.videoDimensions
            let remoteRect = remoteViewSize()
            let aspect = CGSize(width: CGFloat((dimensions?.width)!), height: CGFloat((dimensions?.height)!))
            let padding : CGFloat = 10.0
            let boundedRect = AVMakeRect(aspectRatio: aspect, insideRect: remoteRect).integral
            remoteView?.frame = CGRect(x: self.view.bounds.width - boundedRect.width - padding,
                                       y: self.view.bounds.height - boundedRect.height - padding,
                                       width: boundedRect.width,
                                       height: boundedRect.height)
        } else {
            remoteView?.frame = CGRect.zero
        }
    }

    func remoteViewSize() -> CGRect {
        let traits = self.traitCollection
        let width = traits.horizontalSizeClass == UIUserInterfaceSizeClass.regular ? 188 : 160;
        let height = traits.horizontalSizeClass == UIUserInterfaceSizeClass.regular ? 188 : 120;
        return CGRect(x: 0, y: 0, width: width, height: height)
    }
}

// MARK: TVIVideoViewDelegate
extension PreviewViewController : TVIVideoViewDelegate {
    func videoViewDidReceiveData(_ view: TVIVideoView) {
        if (view == remoteView) {
            remoteView?.isHidden = false
            self.view.setNeedsLayout()
        }
    }

    func videoView(_ view: TVIVideoView, videoDimensionsDidChange dimensions: CMVideoDimensions) {
        self.view.setNeedsLayout()
    }
}
