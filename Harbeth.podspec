#
# Be sure to run `pod lib lint Harbeth.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Harbeth'
  s.version          = '0.1.3'
  s.summary          = 'About Metal graphics processing.'
  
  # This description is used to generate tags and improve search results.
  #   * Think: What does it do? Why did you write it? What is the focus?
  #   * Try to keep it short, snappy and to the point.
  #   * Write the description between the DESC delimiters below.
  #   * Finally, don't worry about the indent, CocoaPods strips it!
  
  s.homepage         = 'https://github.com/yangKJ/Harbeth'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Condy' => 'ykj310@126.com' }
  s.source           = { :git => 'https://github.com/yangKJ/Harbeth.git', :tag => s.version }
  s.module_name      = s.name
  
  s.swift_version    = '5.0'
  s.requires_arc     = true
  s.static_framework = true
  s.ios.deployment_target = '10.0'
  s.ios.frameworks = ["UIKit", 'MetalKit', 'ImageIO', "CoreImage"]
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }
  
  s.subspec 'Basic' do |xx|
    xx.source_files = 'Sources/Basic/**/*.swift'
    xx.resource_bundles = {
      'ATMetalLibrary' => [ 'Sources/Compute/**/*.metal' ]
    }
  end
  
  s.subspec 'Compute' do |xx|
    xx.subspec 'ColorProcess' do |xxx|
      xxx.source_files = 'Sources/Compute/ColorProcess/*'
      xxx.dependency 'Harbeth/Basic'
    end
    xx.subspec 'Lookup' do |xxx|
      xxx.source_files = 'Sources/Compute/Lookup/*'
      xxx.dependency 'Harbeth/Basic'
    end
    xx.subspec 'Blur' do |xxx|
      xxx.source_files = 'Sources/Compute/Blur/*'
      xxx.dependency 'Harbeth/Basic'
    end
    xx.subspec 'Blend' do |xxx|
      xxx.source_files = 'Sources/Compute/Blend/*'
      xxx.dependency 'Harbeth/Basic'
    end
    xx.subspec 'Effect' do |xxx|
      xxx.source_files = 'Sources/Compute/Effect/*'
      xxx.dependency 'Harbeth/Basic'
    end
    xx.subspec 'Shape' do |xxx|
      xxx.source_files = 'Sources/Compute/Shape/*'
      xxx.dependency 'Harbeth/Basic'
    end
    xx.subspec 'Matrix' do |xxx|
      xxx.source_files = 'Sources/Compute/Matrix/*'
      xxx.dependency 'Harbeth/Basic'
    end
  end
  
end
