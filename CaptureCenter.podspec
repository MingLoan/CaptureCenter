#
# Be sure to run `pod lib lint CaptureCenter.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'CaptureCenter'
  s.version          = '0.1.3'
  s.summary          = 'CaptureCenter is a camera capture library for iOS. CaptureCenter helps you to do everything besides UI.'
  s.description      = 'CaptureCenter is a custom camera capture library for iOS. You can fit your custom capture layout with CaptureCenter, CaptureCenter helps you to do everything besides UI'
  s.homepage         = 'https://github.com/mingloan/CaptureCenter'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'mingloan' => 'mingloanchan@gmail.com' }
  s.source           = { :git => 'https://github.com/mingloan/CaptureCenter.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/mingloan'

  s.ios.deployment_target = '9.0'

  s.source_files = 'CaptureCenter/Classes/**/*'
  
  s.ios.resource_bundle = {
    'CaptureCenter' => 'CaptureCenter/Assets/icon.xcassets'
  }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit', 'AVFoundation', 'Photos'

end
