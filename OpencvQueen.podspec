#
# Be sure to run `pod lib lint OpencvQueen.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'OpencvQueen'
  s.version          = '0.0.2'
  s.summary          = 'About Opencv graphics processing.'
  
  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!
  
  s.homepage         = 'https://github.com/yangKJ/MetalQueen/OpenCV'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'yangkejun' => 'ykj310@126.com' }
  s.source           = { :git => 'https://github.com/yangKJ/MetalQueen.git', :tag => "#{s.version}" }
  
  s.platform = :ios
  s.ios.deployment_target = '9.0'
  s.requires_arc = true
  s.static_framework = true
  s.frameworks = "UIKit", "Foundation"
  
  s.pod_target_xcconfig  = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  
  s.source_files = "OpenCV/Sources/*.{h,mm}"
  s.dependency 'OpenCV', "~> 4.1.0"

end
