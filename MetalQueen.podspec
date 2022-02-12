#
# Be sure to run `pod lib lint MetalQueen.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MetalQueen'
  s.version          = '0.0.1'
  s.summary          = 'About Metal graphics processing.'
  
  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!
  
  s.homepage         = 'https://github.com/yangKJ/MetalQueen'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'yangkejun' => 'ykj310@126.com' }
  s.source           = { :git => 'https://github.com/yangKJ/MetalQueen.git', :tag => "#{s.version}" }
  
  s.ios.deployment_target = '9.0'
  s.swift_version    = '5.0'
  s.requires_arc     = true
  s.static_framework = true
  
  s.subspec 'Core' do |xx|
    xx.source_files = 'Sources/Core/*.swift'
  end
  
  s.subspec 'Filter' do |xx|
    xx.source_files = 'Sources/Filter/*'
    xx.dependency 'MetalQueen/Core'
  end
  
end
