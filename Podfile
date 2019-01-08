source 'https://github.com/CocoaPods/Specs'

workspace 'VideoQuickStart'

abstract_target 'TwilioVideo' do
  pod 'TwilioVideo', '~> 2.6'

  target 'ARKitExample' do
    platform :ios, '11.0'
    project 'ARKitExample.xcproject'
  end

  target 'AudioDeviceExample' do
    platform :ios, '9.0'
    project 'AudioDeviceExample.xcproject'
  end

  target 'AudioSinkExample' do
    platform :ios, '10.0'
    project 'AudioSinkExample.xcproject'
  end

  target 'VideoQuickStart' do
    platform :ios, '9.0'
    project 'VideoQuickStart.xcproject'
  end
  
  target 'VideoCallKitQuickStart' do
    platform :ios, '10.0'
    project 'VideoCallKitQuickStart.xcproject'
  end

  target 'ReplayKitExample' do
    platform :ios, '11.0'
    project 'ReplayKitExample.xcodeproj'
  end

  target 'BroadcastExtension' do
    platform :ios, '11.0'
    project 'ReplayKitExample.xcodeproj'
  end

  target 'ScreenCapturerExample' do
    platform :ios, '9.0'
    project 'ScreenCapturerExample.xcproject'
  end

  target 'DataTrackExample' do
    platform :ios, '9.0'
    project 'DataTrackExample.xcproject'
  end

end

post_install do |installer|
  # Find bitcode_strip
  bitcode_strip_path = `xcrun -sdk iphoneos --find bitcode_strip`.chop!

  # Find path to TwilioVideo dependency
  path = Dir.pwd
  framework_path = "#{path}/Pods/TwilioVideo/Build/iOS/TwilioVideo.framework/TwilioVideo"

  # Strip Bitcode sections from the framework
  strip_command = "#{bitcode_strip_path} #{framework_path} -m -o #{framework_path}" 
  puts "About to strip: #{strip_command}"
  system(strip_command)
end
