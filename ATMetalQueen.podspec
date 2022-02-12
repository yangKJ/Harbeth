#
# Be sure to run `pod lib lint ATMetalQueen.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'ATMetalQueen'
  s.version          = '0.0.1'
  s.summary          = 'About Metal graphics processing.'
  
  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!
  
  s.homepage         = 'https://github.com/yangKJ/ATMetalQueen'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Condy' => 'ykj310@126.com' }
  s.source           = { :git => 'https://github.com/yangKJ/ATMetalQueen.git', :tag => s.version }
  s.module_name      = s.name
  
  s.swift_version    = '5.0'
  s.requires_arc     = true
  s.static_framework = true
  s.ios.deployment_target = '10.0'
  s.ios.frameworks = ["UIKit", "CoreImage"]
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }
  
  s.subspec 'Core' do |xx|
    xx.source_files = 'Sources/Core/*.{h,swift,metal}'
  end
  
  s.subspec 'Compute' do |xx|
    xx.source_files = 'Sources/Compute/**/*.{h,swift,metal}'
    xx.dependency 'ATMetalQueen/Core'
  end
  
end
