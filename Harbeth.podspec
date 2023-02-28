#
# Be sure to run 'pod lib lint Harbeth.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Harbeth'
  s.version          = '0.6.3'
  s.summary          = 'About Metal image processing and video add filter.'
  
  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!
  
  s.homepage         = 'https://github.com/yangKJ/Harbeth'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Condy' => 'yangkj310@gmail.com' }
  s.source           = { :git => 'https://github.com/yangKJ/Harbeth.git', :tag => s.version }
  
  s.swift_version    = '5.0'
  s.requires_arc     = true
  s.static_framework = true
  s.ios.deployment_target = '10.0'
  s.macos.deployment_target = '10.13'
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }
  
  s.subspec 'Basic' do |xx|
    xx.source_files = 'Sources/Basic/**/*.swift'
    xx.weak_frameworks = 'ImageIO', 'MetalKit', 'AVFoundation'
  end
  
  s.subspec 'Collector' do |xx|
    xx.source_files = 'Sources/Collector/*.swift'
    xx.dependency 'Harbeth/Basic'
  end
  
  s.subspec 'Compute' do |xx|
    xx.source_files = 'Sources/Compute/**/*.swift'
    xx.resource_bundles = { s.name => [ 'Sources/Compute/**/*.metal' ] }
    xx.weak_frameworks = 'MetalPerformanceShaders', 'MetalKit'
    xx.dependency 'Harbeth/Basic'
    xx.pod_target_xcconfig = {
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => 'HARBETH_COMPUTE',
      'GCC_PREPROCESSOR_DEFINITIONS' => 'HARBETH_COMPUTE=1'
    }
  end
  
  s.subspec 'CoreImage' do |xx|
    xx.source_files = 'Sources/CoreImage/**/*.swift'
    xx.weak_frameworks = 'CoreImage'
    xx.dependency 'Harbeth/Basic'
  end
  
end
