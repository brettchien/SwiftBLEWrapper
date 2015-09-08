Pod::Spec.new do |s|
  s.name         = "EPLBLEWrapper"
  s.version      = "0.1.1"
  s.summary      = "Swift BLE Wrapper for easier profile handling"
  s.homepage     = "https://github.com/brettchien/SwiftBLEWrapper"
  s.license      = { :type => "MIT" }
  s.author       = { "Brett Chien" => "brett.chien@gmail.com" }

  s.osx.deployment_target = '10.10'
  s.ios.deployment_target = '8.0'

  s.source       = { :git => "https://github.com/brettchien/SwiftBLEWrapper.git", :tag => "#{s.version}"}
  s.source_files  = "*.swift"
  s.frameworks = "CoreBluetooth"
  s.dependency 'XCGLogger'
# The real dependency
#  s.dependency 'Async', :git => 'https://github.com/duemunk/Async.git'
  s.dependency 'BrightFutures', '= 1.0.1'
  s.requires_arc = true
end
