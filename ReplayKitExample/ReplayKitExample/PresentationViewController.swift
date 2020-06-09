//
//  PresentationViewController.swift
//  ReplayKitExample
//
//  Copyright © 2020 Twilio. All rights reserved.
//

import UIKit
import TwilioVideo

class PresentationViewController : UIViewController {

    var room: Room?
    var remoteView : VideoView?
    var scrollView : UIScrollView?
    var accessToken: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        connectToPresentation()
    }

    override var prefersStatusBarHidden: Bool {
        get {
            return true
        }
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        get {
            return true
        }
    }

    func connectToPresentation() {
        TwilioVideoSDK.setLogLevel(.info)

        UIApplication.shared.isIdleTimerDisabled = true

        let videoOptions = VideoBandwidthProfileOptions { (builder) in
            // Minimum subscribe priority of Dominant Speaker's RemoteVideoTracks
            builder.dominantSpeakerPriority = .standard

            // Maximum bandwidth (Kbps) to be allocated to subscribed RemoteVideoTracks
            builder.maxSubscriptionBitrate = 6000

            // Max number of visible RemoteVideoTracks. Other RemoteVideoTracks will be switched off
            builder.maxTracks = 4

            // Subscription mode: collaboration, grid, presentation
            builder.mode = .presentation

            // Configure remote track's render dimensions per track priority
            let renderDimensions = VideoRenderDimensions()

            // Desired render dimensions of RemoteVideoTracks with priority low.
            renderDimensions.low = VideoDimensions(width: 160, height: 160)

            // Desired render dimensions of RemoteVideoTracks with priority standard.
            renderDimensions.standard = VideoDimensions(width: 640, height: 480)

            // Desired render dimensions of RemoteVideoTracks with priority high.
            renderDimensions.high = VideoDimensions(width: 1920, height: 1080)

            builder.renderDimensions = renderDimensions

            // Track Switch Off mode: .detected, .predicted, .disabled
            builder.trackSwitchOffMode = .predicted
        }
        let profile = BandwidthProfileOptions(videoOptions: videoOptions)
        let connectOptions = ConnectOptions(token: accessToken!) { (builder) in
            builder.bandwidthProfileOptions = profile

            builder.audioTracks = [LocalAudioTrack()!]

            // Use the preferred signaling region
            if let signalingRegion = Settings.shared.signalingRegion {
                builder.region = signalingRegion
            }
        }

        self.room = TwilioVideoSDK.connect(options: connectOptions, delegate: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        self.scrollView?.frame = self.view.bounds
        self.scrollView?.contentInset = self.additionalSafeAreaInsets
        let contentBounds = self.view.bounds

        if let dimensions = remoteView?.videoDimensions,
            remoteView?.hasVideoData == true {
            let contentRect = AVMakeRect(aspectRatio: CGSize(width: Int(dimensions.width),
                height: Int(dimensions.height)), insideRect: contentBounds).integral
//            let size = CGSize(width: CGFloat(dimensions.width) / scale, height: CGFloat(dimensions.height) / scale)
//            print("\(size)")
            scrollView?.contentSize = contentRect.size
            scrollView?.maximumZoomScale = 2
            scrollView?.minimumZoomScale = 1
            remoteView?.bounds = CGRect(origin: .zero, size: contentRect.size)
            remoteView?.center = CGPoint(x: contentRect.midX, y: contentRect.midY)
        }
    }

    func setupRemoteVideoView(publication: RemoteVideoTrackPublication) {
        // Creating `VideoView` programmatically
        self.remoteView = VideoView(frame: CGRect(origin: CGPoint.zero, size: CGSize(width: 640, height: 480)), delegate: self)
        self.remoteView?.tag = publication.trackSid.hashValue

        let scrollView = UIScrollView()
        scrollView.contentSize = CGSize(width: 640, height: 480)
        scrollView.delegate = self
        scrollView.backgroundColor = nil
        scrollView.scrollsToTop = false
        scrollView.contentInsetAdjustmentBehavior = .always
        self.scrollView = scrollView

        // self.view.insertSubview(remoteView!, at: 0)
        self.view.insertSubview(scrollView, at: 0)
        self.scrollView?.addSubview(self.remoteView!)

        // `VideoView` supports scaleToFill, scaleAspectFill and scaleAspectFit
        // scaleAspectFit is the default mode when you create `VideoView` programmatically.
        self.remoteView?.contentMode = .scaleAspectFit

        publication.videoTrack?.addRenderer(self.remoteView!)

        let recognizer = UITapGestureRecognizer(target: self, action: #selector(tappedScreenParticipant(sender:)))
        recognizer.numberOfTapsRequired = 2;
        self.remoteView!.addGestureRecognizer(recognizer)
    }

    @objc func tappedScreenParticipant(sender: UITapGestureRecognizer) {
        if let view = sender.view {
            view.contentMode = view.contentMode == UIView.ContentMode.scaleAspectFit ?
                UIView.ContentMode.scaleAspectFill : UIView.ContentMode.scaleAspectFit
        }
    }
}

extension PresentationViewController : UIScrollViewDelegate {
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        print("scrollViewDidZoom \(scrollView)")
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        print("scrollViewDidScroll \(scrollView)")
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.remoteView
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        print("scrollViewDidEndZooming \(scrollView) with view \(view!) at scale \(scale)")
    }
}

extension PresentationViewController : VideoViewDelegate {
    func videoViewDidReceiveData(view: VideoView) {
        if view == self.remoteView {
            self.scrollView?.isScrollEnabled = true
            self.view.setNeedsLayout()
        }
    }

    func videoViewDimensionsDidChange(view: VideoView, dimensions: CMVideoDimensions) {
        let scale = UIScreen.main.nativeScale
        scrollView?.contentSize = CGSize(width: CGFloat(dimensions.width) / scale, height: CGFloat(dimensions.height) / scale)
        scrollView?.maximumZoomScale = 2
    }
}

// MARK:- RoomDelegate
extension PresentationViewController : RoomDelegate {
    func roomDidConnect(room: Room) {
        // Listen to events from existing `RemoteParticipant`s
        for remoteParticipant in room.remoteParticipants {
            remoteParticipant.delegate = self
        }

        let connectMessage = "Connected to room \(room.name) as \(room.localParticipant?.identity ?? "")."
        print(connectMessage)
    }

    func roomDidDisconnect(room: Room, error: Error?) {
        if let disconnectError = error {
            print("Disconnected from \(room.name).\ncode = \((disconnectError as NSError).code) error = \(disconnectError.localizedDescription)")
        } else {
            print("Disconnected from \(room.name)")
        }

        self.room = nil
    }

    func roomDidFailToConnect(room: Room, error: Error) {
        print("Failed to connect to Room:\n\(error.localizedDescription)")

        self.room = nil
    }

    func roomIsReconnecting(room: Room, error: Error) {
        print("Reconnecting to room \(room.name), error = \(String(describing: error))")
    }

    func roomDidReconnect(room: Room) {
        print("Reconnected to room \(room.name)")
    }

    func participantDidConnect(room: Room, participant: RemoteParticipant) {
        participant.delegate = self

        print("Participant \(participant.identity) connected with \(participant.remoteAudioTracks.count) audio and \(participant.remoteVideoTracks.count) video tracks")
    }

    func participantDidDisconnect(room: Room, participant: RemoteParticipant) {
        print("Room \(room.name), Participant \(participant.identity) disconnected")
    }
}

// MARK:- RemoteParticipantDelegate
extension PresentationViewController : RemoteParticipantDelegate {
    func remoteParticipantDidPublishVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        // Remote Participant has offered to share the video Track.

        print("Participant \(participant.identity) published \(publication.trackName) video track")
    }

    func remoteParticipantDidUnpublishVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        // Remote Participant has stopped sharing the video Track.

        print( "Participant \(participant.identity) unpublished \(publication.trackName) video track")
    }

    func remoteParticipantDidPublishAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        // Remote Participant has offered to share the audio Track.

        print( "Participant \(participant.identity) published \(publication.trackName) audio track")
    }

    func remoteParticipantDidUnpublishAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        // Remote Participant has stopped sharing the audio Track.

        print("Participant \(participant.identity) unpublished \(publication.trackName) audio track")
    }

    func didSubscribeToVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        // We are subscribed to the remote Participant's video Track. We will start receiving the
        // remote Participant's video frames now.

        print("Subscribed to \(publication.trackName) video track for Participant \(participant.identity)")

        // Start remote rendering, and add a touch handler.
        if (self.remoteView == nil && publication.trackName == "Screen") {
            setupRemoteVideoView(publication: publication)
        }
    }

    func didUnsubscribeFromVideoTrack(videoTrack: RemoteVideoTrack, publication: RemoteVideoTrackPublication, participant: RemoteParticipant) {
        // We are unsubscribed from the remote Participant's video Track. We will no longer receive the
        // remote Participant's video.

        print("Unsubscribed from \(publication.trackName) video track for Participant \(participant.identity)")

        // Stop remote rendering.
        if (publication.trackSid.hashValue == self.remoteView?.tag) {
            self.remoteView?.removeFromSuperview()
            self.remoteView = nil

            self.scrollView?.removeFromSuperview()
            self.scrollView = nil
        }
    }

    func didSubscribeToAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {
        // We are subscribed to the remote Participant's audio Track. We will start receiving the
        // remote Participant's audio now.

        print( "Subscribed to \(publication.trackName) audio track for Participant \(participant.identity)")
    }

    func didUnsubscribeFromAudioTrack(audioTrack: RemoteAudioTrack, publication: RemoteAudioTrackPublication, participant: RemoteParticipant) {
        // We are unsubscribed from the remote Participant's audio Track. We will no longer receive the
        // remote Participant's audio.

        print( "Unsubscribed from \(publication.trackName) audio track for Participant \(participant.identity)")
    }

    func remoteParticipantDidEnableVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        print( "Participant \(participant.identity) enabled \(publication.trackName) video track")
    }

    func remoteParticipantDidDisableVideoTrack(participant: RemoteParticipant, publication: RemoteVideoTrackPublication) {
        print( "Participant \(participant.identity) disabled \(publication.trackName) video track")
    }

    func remoteParticipantDidEnableAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        print( "Participant \(participant.identity) enabled \(publication.trackName) audio track")
    }

    func remoteParticipantDidDisableAudioTrack(participant: RemoteParticipant, publication: RemoteAudioTrackPublication) {
        // We will continue to record silence and/or recognize audio while a Track is disabled.
        print( "Participant \(participant.identity) disabled \(publication.trackName) audio track")
    }

    func didFailToSubscribeToAudioTrack(publication: RemoteAudioTrackPublication, error: Error, participant: RemoteParticipant) {
        print( "FailedToSubscribe \(publication.trackName) audio track, error = \(String(describing: error))")
    }

    func didFailToSubscribeToVideoTrack(publication: RemoteVideoTrackPublication, error: Error, participant: RemoteParticipant) {
        print( "FailedToSubscribe \(publication.trackName) video track, error = \(String(describing: error))")
    }
}
